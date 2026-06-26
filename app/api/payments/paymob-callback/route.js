import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Payment from '@/models/Payment';
import { verifyHmac } from '@/lib/paymob';
import { completePaidPayment, notifyPaymentFailed } from '@/lib/payment-complete';

/* ============================================================
   Paymob callback (Stage 4).
   ------------------------------------------------------------
   Configure BOTH callbacks in the Paymob dashboard to point here:
     • Transaction processed (webhook)  → POST  (authoritative)
     • Transaction response  (redirect) → GET   (renders a result page)
   We verify the HMAC-SHA512 over Paymob's ordered fields, then flip our
   Payment doc to paid/failed, complete the issue, and notify both parties.
   The app/dashboard polls GET /api/payments/[id] and reflects the status.

   Mock mode (no live keys) never reaches here — createInvoice points the
   mock paymentUrl at /api/payments/callback instead.
   ============================================================ */

function resultPage(status) {
    const ok = status === 'paid';
    const failed = status === 'failed';
    const title = ok ? 'تم الدفع بنجاح' : failed ? 'فشل الدفع' : 'حالة الدفع قيد المعالجة';
    const titleEn = ok ? 'Payment successful' : failed ? 'Payment failed' : 'Payment processing';
    const color = ok ? '#1C8C8C' : failed ? '#c0392b' : '#6366f1';
    const mark = ok ? '✓' : failed ? '✕' : '…';
    const html = `<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SmartFix — ${titleEn}</title></head>
<body style="margin:0;min-height:100vh;display:grid;place-items:center;background:radial-gradient(1100px 520px at 50% -10%,rgba(28,140,140,.22),transparent 70%),#0b1117;font-family:-apple-system,'Segoe UI',Tahoma,sans-serif">
  <div style="max-width:360px;width:90%;text-align:center;background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.1);border-radius:24px;padding:36px 26px;color:#e9f3f3;box-shadow:0 30px 80px -30px rgba(0,0,0,.8)">
    <div style="width:72px;height:72px;border-radius:50%;margin:0 auto 18px;display:grid;place-items:center;background:${color};font-size:36px;color:#fff">${mark}</div>
    <h1 style="margin:0 0 6px;font-size:22px;font-weight:800">${title}</h1>
    <p style="margin:0 0 4px;color:#9fb2bb;font-size:14px">${titleEn}</p>
    <p style="margin:16px 0 0;color:#7e919a;font-size:13px;line-height:1.7">
      يمكنك العودة إلى تطبيق سمارت فيكس الآن — ستُحدَّث الحالة تلقائياً.<br/>
      You can return to the SmartFix app — the status updates automatically.
    </p>
  </div>
</body></html>`;
    return new NextResponse(html, {
        status: 200,
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
    });
}

// Map Paymob's success/pending flags to our Payment status vocabulary.
function statusFrom(obj) {
    const truthy = (v) => v === true || v === 'true';
    if (truthy(obj.success)) return 'paid';
    if (truthy(obj.pending)) return 'pending';
    return 'failed';
}

// Apply the verified transaction to our Payment + Issue. Idempotent: a doc
// already paid/refunded is left untouched (webhook + redirect both arrive).
async function applyTransaction(obj) {
    const orderId = obj?.order?.id != null ? String(obj.order.id) : '';
    const txnId = obj?.id != null ? String(obj.id) : '';
    let status = statusFrom(obj);

    if (!orderId && !txnId) return status;

    let payment = null;
    if (orderId) payment = await Payment.findOne({ providerInvoiceId: orderId }).lean();
    if (!payment && txnId) payment = await Payment.findOne({ providerPaymentId: txnId }).lean();
    if (!payment) return status;

    if (payment.status === 'paid' || payment.status === 'refunded') return payment.status;

    // Never complete a job / pay out on a smaller or wrong-currency transaction.
    if (status === 'paid') {
        const expectedCents = Math.round((Number(payment.total) || 0) * 100);
        const gotCents = Math.round(Number(obj.amount_cents) || 0);
        const curOk = !obj.currency
            || String(obj.currency).toUpperCase() === String(payment.currency || 'EGP').toUpperCase();
        if (gotCents !== expectedCents || !curOk) {
            console.warn(`paymob: amount/currency mismatch for payment ${payment._id} — got ${gotCents}/${obj.currency}, expected ${expectedCents}/${payment.currency}`);
            status = 'failed';
        }
    }

    const next = status === 'paid' ? 'paid' : status === 'failed' ? 'failed' : payment.status;
    if (next === payment.status) return next;

    // Atomic + idempotent: only the writer that flips pending→paid/failed acts,
    // so a concurrent webhook + browser redirect never double-completes/notifies.
    const setFields = { status: next, updatedAt: new Date() };
    if (txnId) setFields.providerPaymentId = txnId;
    if (next === 'paid') setFields.paidAt = new Date();
    const updated = await Payment.findOneAndUpdate(
        { _id: payment._id, status: { $nin: ['paid', 'refunded'] } },
        setFields,
        { new: true },
    ).lean();
    if (!updated) return next; // someone else already applied it

    if (next === 'paid') {
        await completePaidPayment(updated);
    } else if (next === 'failed') {
        await notifyPaymentFailed(updated);
    }
    return next;
}

// Webhook (authoritative). Body: { type:'TRANSACTION', obj:{...} }; hmac is a
// query param. We verify, apply, and ACK with 200 so Paymob stops retrying.
export async function POST(request) {
    try {
        await dbConnect();
        const { searchParams } = new URL(request.url);
        const hmac = searchParams.get('hmac') || '';
        const body = await request.json().catch(() => ({}));
        const obj = body?.obj || {};

        if (!verifyHmac(obj, hmac)) {
            return NextResponse.json({ error: 'Invalid HMAC' }, { status: 401 });
        }
        const status = await applyTransaction(obj);
        return NextResponse.json({ ok: true, status });
    } catch (error) {
        console.error('paymob webhook error', error);
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}

// Redirect (browser). Paymob appends the (flattened) transaction fields + hmac
// to the URL. We reconstruct the object, verify, apply, and render a page.
export async function GET(request) {
    let status = 'pending';
    try {
        await dbConnect();
        const q = new URL(request.url).searchParams;
        const obj = {
            amount_cents: q.get('amount_cents'),
            created_at: q.get('created_at'),
            currency: q.get('currency'),
            error_occured: q.get('error_occured'),
            has_parent_transaction: q.get('has_parent_transaction'),
            id: q.get('id'),
            integration_id: q.get('integration_id'),
            is_3d_secure: q.get('is_3d_secure'),
            is_auth: q.get('is_auth'),
            is_capture: q.get('is_capture'),
            is_refunded: q.get('is_refunded'),
            is_standalone_payment: q.get('is_standalone_payment'),
            is_voided: q.get('is_voided'),
            order: { id: q.get('order') },
            owner: q.get('owner'),
            pending: q.get('pending'),
            source_data: {
                pan: q.get('source_data.pan'),
                sub_type: q.get('source_data.sub_type'),
                type: q.get('source_data.type'),
            },
            success: q.get('success'),
        };
        const hmac = q.get('hmac') || '';
        if (verifyHmac(obj, hmac)) {
            status = await applyTransaction(obj);
        } else {
            console.warn('paymob redirect: HMAC mismatch — not applying');
        }
        return resultPage(status);
    } catch (error) {
        console.error('paymob redirect error', error);
        return resultPage(status);
    }
}
