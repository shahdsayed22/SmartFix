import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Technician from '@/models/Technician';
import WalletTransaction from '@/models/WalletTransaction';

// GET /api/wallet?technicianId=<uid>           → a worker's wallet + history
// GET /api/wallet?scope=platform               → platform finance summary (admin)
export async function GET(request) {
    try {
        await dbConnect();
        const { searchParams } = new URL(request.url);
        const scope = searchParams.get('scope') || '';

        if (scope === 'platform') {
            // Platform finance: revenue (fee + commission), VAT collected, payouts.
            const agg = await WalletTransaction.aggregate([
                { $group: { _id: '$type', total: { $sum: '$amount' }, count: { $sum: 1 } } },
            ]);
            const by = Object.fromEntries(agg.map((r) => [r._id, r.total]));
            const counts = Object.fromEntries(agg.map((r) => [r._id, r.count]));
            const platformFee = by.platform_fee || 0;
            const commission = by.commission || 0;
            const vat = by.vat || 0;
            const payouts = by.payout || 0;
            const withdrawals = by.withdrawal || 0;
            const owedToWorkers = payouts - withdrawals; // credited but not yet cashed out
            return NextResponse.json({
                revenue: platformFee + commission,
                platformFee,
                commission,
                vatCollected: vat,
                totalPayouts: payouts,
                totalWithdrawals: withdrawals,
                owedToWorkers,
                jobsSettled: counts.payout || 0,
                currency: 'EGP',
            });
        }

        const technicianId = searchParams.get('technicianId') || '';
        if (!technicianId) {
            return NextResponse.json({ error: 'technicianId is required' }, { status: 400 });
        }
        const tech = await Technician.findOne({ uid: technicianId }).lean()
            || (await Technician.findById(technicianId).lean().catch(() => null));
        const transactions = await WalletTransaction.find({
            technicianId,
            type: { $in: ['payout', 'withdrawal'] },
        }).sort({ createdAt: -1 }).limit(50).lean();

        return NextResponse.json({
            technicianId,
            balance: tech ? (tech.walletBalance || 0) : 0,
            totalEarned: tech ? (tech.totalEarned || 0) : 0,
            currency: 'EGP',
            transactions,
        });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}
