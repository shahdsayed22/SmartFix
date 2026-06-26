// SmartFix money ledger (Stage 5).
// Turns a settled Payment into actual (virtual) money movement: credits the
// worker's in-app wallet with the payout and records platform revenue + VAT as
// ledger rows. No real cash — this is the internal accounting that makes the
// full "client pays → worker receives" cycle real and auditable in the app and
// dashboard. Safe to call from every paid-path: it is IDEMPOTENT (keyed on
// paymentId), so duplicate webhooks/redirects/PATCH never double-credit.

import Technician from '../models/Technician.js';
import WalletTransaction from '../models/WalletTransaction.js';

/** Resolve a Technician doc from the id stored on the Payment (uid or _id). */
async function findTechnician(technicianId) {
    if (!technicianId) return null;
    let tech = await Technician.findOne({ uid: technicianId });
    if (!tech) {
        try { tech = await Technician.findById(technicianId); } catch { /* not an ObjectId */ }
    }
    return tech;
}

/**
 * Settle a paid Payment into the ledger + worker wallet. Idempotent.
 * @returns {Promise<{ settled:boolean, alreadySettled?:boolean, payout?:number, balanceAfter?:number }>}
 */
export async function settlePayment(payment) {
    if (!payment || !payment._id) return { settled: false };

    const paymentId = String(payment._id);
    // Idempotency guard: if we already recorded the payout for this payment, stop.
    const existing = await WalletTransaction.findOne({ paymentId, type: 'payout' }).lean();
    if (existing) return { settled: false, alreadySettled: true };

    const currency = payment.currency || 'EGP';
    const payout = Math.max(0, Number(payment.payoutAmount) || 0);
    const fee = Math.max(0, Number(payment.platformFee) || 0);
    const commission = Math.max(0, Number(payment.workerCommission) || 0);
    const vat = Math.max(0, Number(payment.vat) || 0);

    // Credit the worker wallet first (atomic $inc) so balanceAfter is accurate.
    const tech = await findTechnician(payment.technicianId);
    let balanceAfter = null;
    if (tech) {
        const updated = await Technician.findByIdAndUpdate(
            tech._id,
            { $inc: { walletBalance: payout, totalEarned: payout } },
            { new: true },
        ).lean();
        balanceAfter = updated ? updated.walletBalance : null;
    }

    const base = {
        paymentId,
        issueId: payment.issueId || '',
        customerId: payment.customerId || '',
        currency,
    };
    const rows = [
        { ...base, technicianId: payment.technicianId || '', type: 'payout', direction: 'credit', amount: payout, status: 'settled', balanceAfter, note: 'Job payout credited to wallet' },
        { ...base, technicianId: '', type: 'platform_fee', direction: 'credit', amount: fee, status: 'settled', note: 'Platform service fee' },
        { ...base, technicianId: '', type: 'commission', direction: 'credit', amount: commission, status: 'settled', note: 'Platform worker commission' },
        { ...base, technicianId: '', type: 'vat', direction: 'credit', amount: vat, status: 'settled', note: 'VAT collected (to remit)' },
    ];
    await WalletTransaction.insertMany(rows);

    return { settled: true, payout, balanceAfter };
}

export default { settlePayment };
