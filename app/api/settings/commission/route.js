import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import CommissionSettings from '@/models/CommissionSettings';

export async function GET() {
    try {
        await dbConnect();
        const settings = await CommissionSettings.getSettings();
        return NextResponse.json(settings);
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}

export async function PUT(request) {
    try {
        await dbConnect();
        const body = await request.json();

        const update = { updatedAt: new Date() };
        const percentFields = ['platformFeePercent', 'vatPercent', 'workerCommissionPercent'];
        for (const field of percentFields) {
            if (body[field] !== undefined) {
                const v = Number(body[field]);
                if (!Number.isFinite(v) || v < 0 || v > 100) {
                    return NextResponse.json(
                        { error: `${field} must be a number between 0 and 100` },
                        { status: 400 },
                    );
                }
                update[field] = v;
            }
        }
        if (body.minPlatformFee !== undefined) {
            const v = Number(body.minPlatformFee);
            if (!Number.isFinite(v) || v < 0) {
                return NextResponse.json(
                    { error: 'minPlatformFee must be a non-negative number' },
                    { status: 400 },
                );
            }
            update.minPlatformFee = v;
        }
        if (body.currency !== undefined) update.currency = body.currency;

        const settings = await CommissionSettings.findOneAndUpdate(
            { key: 'default' },
            { $set: update },
            { new: true, upsert: true, runValidators: true, setDefaultsOnInsert: true }
        ).lean();

        return NextResponse.json(settings);
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}
