import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Payment from '@/models/Payment';
import { getPaymentStatus } from '@/lib/paymob';
import { completePaidPayment, notifyPaymentFailed } from '@/lib/payment-complete';

/* ============================================================
   MyFatoorah payment callback (CallBackUrl + ErrorUrl target).
   ------------------------------------------------------------
   After the hosted payment page, MyFatoorah redirects the
   customer's browser here with ?paymentId=<MyFatoorah PaymentId>.
   We verify the real status (GetPaymentStatus by PaymentId),
   update our Payment doc (and complete the issue + notify), then
   render a small bilingual result page. The app/dashboard polls
   GET /api/payments/[id] and flips to paid on its own.

   Mock mode (no MyFatoorah key): the paymentUrl already carries
   ?mock=1&invoiceId=...&status=paid so the flow completes offline.
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

export async function GET(request) {
    let status = 'pending';
    let providerPaymentId = '';
    try {
        await dbConnect();
        const { searchParams } = new URL(request.url);
        const mock = searchParams.get('mock');
        let invoiceId = searchParams.get('invoiceId') || '';

        if (mock) {
            status = (searchParams.get('status') || 'paid').toLowerCase();
        } else {
            // MyFatoorah appends ?paymentId=... (sometimes ?Id=...).
            providerPaymentId = searchParams.get('paymentId') || searchParams.get('Id') || '';
            if (providerPaymentId) {
                const st = await getPaymentStatus(providerPaymentId, 'PaymentId');
                status = st.status;
                if (st.invoiceId) invoiceId = st.invoiceId;
            }
        }

        let payment = null;
        if (invoiceId) payment = await Payment.findOne({ providerInvoiceId: invoiceId });
        if (!payment && providerPaymentId) {
            payment = await Payment.findOne({ providerPaymentId });
        }

        if (payment && payment.status !== 'paid' && payment.status !== 'refunded') {
            const next = status === 'paid' ? 'paid' : status === 'failed' ? 'failed' : payment.status;
            if (next !== payment.status) {
                payment.status = next;
                payment.updatedAt = new Date();
                if (providerPaymentId) payment.providerPaymentId = providerPaymentId;
                if (next === 'paid') payment.paidAt = new Date();
                await payment.save();

                if (next === 'paid') {
                    await completePaidPayment(payment);
                } else if (next === 'failed') {
                    await notifyPaymentFailed(payment);
                }
            }
        }

        return resultPage(status);
    } catch (error) {
        console.error('payment callback error', error);
        return resultPage(status);
    }
}
