import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Payment from '@/models/Payment';
import { notifyEvent } from '@/lib/notifications';
import { getPaymentStatus } from '@/lib/paymob';
import { completePaidPayment, notifyPaymentFailed, reconcilePendingPayment } from '@/lib/payment-complete';

export async function GET(request, { params }) {
    try {
        await dbConnect();
        const { id } = await params;
        let payment = await Payment.findById(id).lean();
        if (!payment) {
            return NextResponse.json({ error: 'Payment not found' }, { status: 404 });
        }
        // Self-healing: the customer's checkout screen polls this endpoint. If
        // the payment is still pending, ask the provider for the real status and
        // apply it here — so the status reflects to BOTH the client and (via
        // settlePayment) the worker even when no inbound webhook can reach us
        // (e.g. a localhost / LAN demo, which Paymob's servers can't call back).
        if (payment.status === 'pending') {
            payment = await reconcilePendingPayment(payment);
        }
        return NextResponse.json(payment);
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}

export async function PATCH(request, { params }) {
    try {
        await dbConnect();
        const { id } = await params;
        const body = await request.json();

        // SECURITY: never trust a client-supplied 'paid'. Marking a payment paid
        // completes the job and triggers the worker payout, so it must be backed
        // by the provider. Re-verify with Paymob (mock mode returns 'paid', so
        // the demo still completes) before honoring it.
        if (body.status === 'paid') {
            const current = await Payment.findById(id).lean();
            if (!current) {
                return NextResponse.json({ error: 'Payment not found' }, { status: 404 });
            }
            const verify = await getPaymentStatus(current.providerInvoiceId || current.providerPaymentId);
            if (verify.status !== 'paid') {
                return NextResponse.json(
                    { error: 'Payment not confirmed as paid by the provider.', providerStatus: verify.status },
                    { status: 409 },
                );
            }
        }

        const update = { updatedAt: new Date() };
        if (body.status !== undefined) update.status = body.status;
        if (body.method !== undefined) update.method = body.method;
        if (body.providerPaymentId !== undefined) update.providerPaymentId = body.providerPaymentId;
        if (body.status === 'paid') update.paidAt = new Date();
        if (body.status === 'refunded') update.refundedAt = new Date();

        const payment = await Payment.findByIdAndUpdate(id, update, {
            new: true,
            runValidators: true,
        }).lean();
        if (!payment) {
            return NextResponse.json({ error: 'Payment not found' }, { status: 404 });
        }

        // On successful payment: complete the issue, credit the worker wallet,
        // and notify both parties (shared with every other paid-path).
        if (body.status === 'paid') {
            await completePaidPayment(payment);
        } else if (body.status === 'failed') {
            await notifyPaymentFailed(payment);
        } else if (body.status === 'refunded') {
            try {
                await notifyEvent('payment_refunded', {
                    userId: payment.customerId,
                    role: 'customer',
                    relatedId: payment._id.toString(),
                    total: payment.total,
                    currency: payment.currency,
                });
            } catch (notifyError) {
                console.error('Failed to send payment_refunded notification:', notifyError);
            }
        }

        return NextResponse.json(payment);
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}
