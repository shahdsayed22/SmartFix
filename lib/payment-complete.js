// Shared "a payment just turned paid" side-effect, used by every paid-path:
//   • the Paymob webhook + redirect (app/api/payments/paymob-callback)
//   • the MyFatoorah/mock callback (app/api/payments/callback)
//   • the manual PATCH (app/api/payments/[id])
//   • the self-healing poll reconciliation (GET app/api/payments/[id])
//
// Keeping this in one place means the demo can complete a job, credit the
// worker wallet, and notify both parties identically no matter which path
// confirmed the money. settlePayment() is idempotent (keyed on paymentId), so
// calling this from more than one path can never double-pay.

import Issue from '@/models/Issue';
import Payment from '@/models/Payment';
import { notifyEvent } from '@/lib/notifications';
import { settlePayment } from '@/lib/ledger';
import { getPaymentStatus } from '@/lib/paymob';

/**
 * Apply the consequences of a Payment becoming `paid`:
 *   1) complete the linked Issue (status → completed + history),
 *   2) move the money (settlePayment → worker wallet + platform ledger),
 *   3) notify the customer and the worker.
 * Safe to call repeatedly for the same payment.
 * @param {object} payment - a plain Payment doc (already flipped to paid).
 */
export async function completePaidPayment(payment) {
    if (!payment) return;
    if (payment.issueId) {
        try {
            const at = new Date();
            await Issue.findByIdAndUpdate(payment.issueId, {
                status: 'completed',
                paymentId: payment._id.toString(),
                updatedAt: at,
                $push: { statusHistory: { status: 'completed', at, by: 'system' } },
            });
        } catch (e) {
            console.error('completePaidPayment: failed to complete issue', e);
        }
    }
    try {
        await settlePayment(payment);
    } catch (e) {
        console.error('completePaidPayment: failed to settle ledger', e);
    }
    try {
        await notifyEvent('payment_completed', {
            userId: payment.customerId, role: 'customer',
            relatedId: payment._id.toString(), total: payment.total, currency: payment.currency,
        });
        await notifyEvent('payment_completed', {
            userId: payment.technicianId, role: 'worker',
            relatedId: payment._id.toString(), payoutAmount: payment.payoutAmount, currency: payment.currency,
        });
    } catch (e) {
        console.error('completePaidPayment: failed to notify', e);
    }
}

/** Fire the customer "payment failed" notification (best-effort). */
export async function notifyPaymentFailed(payment) {
    if (!payment) return;
    try {
        await notifyEvent('payment_failed', {
            userId: payment.customerId, role: 'customer',
            relatedId: payment._id.toString(), total: payment.total, currency: payment.currency,
        });
    } catch (e) {
        console.error('notifyPaymentFailed: notify failed', e);
    }
}

/**
 * Self-healing reconciliation: ask the provider for the true status of a
 * still-`pending` payment and apply it. This is what makes the demo work
 * WITHOUT a reachable inbound webhook — Paymob can't POST to a localhost / LAN
 * dev box, so the customer's poll (GET /api/payments/[id]) drives confirmation
 * instead. Atomic + idempotent: only the writer that flips pending→paid/failed
 * runs the side-effects.
 *
 * @param {object} payment - a plain (lean) Payment doc.
 * @returns {Promise<object>} the (possibly updated) payment doc.
 */
export async function reconcilePendingPayment(payment) {
    if (!payment || payment.status !== 'pending') return payment;
    const providerKey = payment.providerInvoiceId || payment.providerPaymentId;
    if (!providerKey) return payment;

    let verify;
    try {
        verify = await getPaymentStatus(providerKey);
    } catch (e) {
        console.error('reconcilePendingPayment: provider lookup failed', e);
        return payment;
    }
    const next = verify?.status;
    if (next !== 'paid' && next !== 'failed') return payment; // still pending

    const setFields = { status: next, updatedAt: new Date() };
    if (next === 'paid') setFields.paidAt = new Date();
    if (verify.providerPaymentId) setFields.providerPaymentId = verify.providerPaymentId;

    const updated = await Payment.findOneAndUpdate(
        { _id: payment._id, status: { $nin: ['paid', 'refunded'] } },
        setFields,
        { new: true },
    ).lean();
    if (!updated) {
        // Someone else applied it already — return the freshest doc.
        return (await Payment.findById(payment._id).lean()) || payment;
    }

    if (next === 'paid') await completePaidPayment(updated);
    else if (next === 'failed') await notifyPaymentFailed(updated);
    return updated;
}

export default { completePaidPayment, notifyPaymentFailed, reconcilePendingPayment };
