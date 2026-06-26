import mongoose from 'mongoose';

// SmartFix internal money ledger (Stage 5).
// Every movement of (virtual) money is one immutable row, so the full cycle is
// auditable: a settled payment fans out into a worker payout credit + platform
// revenue (fee + commission) + VAT collected; a withdrawal is a worker debit.
// No real cash moves — this is the in-app accounting that makes "the client
// pays and the worker receives" a real, visible process.
//
//   client pays total  =  payout(credit→worker) + platform_fee + commission + vat
//
const WalletTransactionSchema = new mongoose.Schema({
    // Who/what this row belongs to.
    technicianId: { type: String, default: '', index: true }, // worker uid (payout/withdrawal) or '' for platform rows
    paymentId: { type: String, default: '', index: true },
    issueId: { type: String, default: '' },
    customerId: { type: String, default: '' },

    // Ledger classification.
    type: {
        type: String,
        enum: ['payout', 'platform_fee', 'commission', 'vat', 'withdrawal'],
        required: true,
    },
    // Sign relative to the holder (worker for payout/withdrawal, platform for the rest).
    direction: { type: String, enum: ['credit', 'debit'], required: true },
    amount: { type: Number, required: true },
    currency: { type: String, default: 'EGP' },
    // payout/fee/commission/vat are 'settled' immediately; a withdrawal starts
    // 'pending' (awaiting payout to the worker) until marked 'settled'.
    status: { type: String, enum: ['pending', 'settled', 'failed'], default: 'settled' },
    balanceAfter: { type: Number, default: null }, // worker wallet balance after this row (payout/withdrawal only)
    note: { type: String, default: '' },

    createdAt: { type: Date, default: Date.now },
});

WalletTransactionSchema.index({ technicianId: 1, createdAt: -1 });
WalletTransactionSchema.index({ type: 1 });

export default mongoose.models.WalletTransaction
    || mongoose.model('WalletTransaction', WalletTransactionSchema);
