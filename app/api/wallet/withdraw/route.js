import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Technician from '@/models/Technician';
import WalletTransaction from '@/models/WalletTransaction';
import { notifyEvent } from '@/lib/notifications';

// POST /api/wallet/withdraw { technicianId, amount }
// Simulated cash-out: debits the worker's in-app wallet and records a pending
// withdrawal in the ledger. No real money — the demo's "worker gets paid" step.
export async function POST(request) {
    try {
        await dbConnect();
        const body = await request.json();
        const technicianId = body.technicianId || '';
        if (!technicianId) {
            return NextResponse.json({ error: 'technicianId is required' }, { status: 400 });
        }

        const tech = await Technician.findOne({ uid: technicianId })
            || (await Technician.findById(technicianId).catch(() => null));
        if (!tech) {
            return NextResponse.json({ error: 'Technician not found' }, { status: 404 });
        }

        const balance = tech.walletBalance || 0;
        // Default: withdraw the full balance.
        const amount = Math.max(0, Number(body.amount) || balance);
        if (amount <= 0) {
            return NextResponse.json({ error: 'Nothing to withdraw' }, { status: 400 });
        }
        if (amount > balance) {
            return NextResponse.json(
                { error: 'Withdrawal exceeds wallet balance', balance },
                { status: 400 },
            );
        }

        // Atomic guarded debit: only succeeds if the balance is still sufficient.
        const updated = await Technician.findOneAndUpdate(
            { _id: tech._id, walletBalance: { $gte: amount } },
            { $inc: { walletBalance: -amount } },
            { new: true },
        ).lean();
        if (!updated) {
            return NextResponse.json({ error: 'Balance changed, please retry' }, { status: 409 });
        }

        const txn = await WalletTransaction.create({
            technicianId,
            type: 'withdrawal',
            direction: 'debit',
            amount,
            currency: 'EGP',
            status: 'pending', // awaiting real cash-out / settlement
            balanceAfter: updated.walletBalance,
            note: 'Wallet withdrawal request',
        });

        try {
            await notifyEvent('payment_completed', {
                userId: technicianId, role: 'worker',
                relatedId: txn._id.toString(), payoutAmount: amount, currency: 'EGP',
            });
        } catch (e) {
            console.error('withdraw: notify failed', e);
        }

        return NextResponse.json({
            ok: true,
            withdrawn: amount,
            balance: updated.walletBalance,
            transaction: txn,
        }, { status: 201 });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}
