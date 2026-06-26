import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import TrainingSample from '@/models/TrainingSample';

const CATEGORIES = ['plumbing', 'electrical', 'carpentry', 'painting', 'hvac', 'cleaning', 'appliance_repair', 'welding', 'tiling'];
const URGENCIES = ['low', 'medium', 'high', 'emergency'];

// POST — log one labelled training sample from a reported issue.
export async function POST(request) {
    try {
        await dbConnect();
        const body = await request.json();
        const text = typeof body?.text === 'string' ? body.text.trim() : '';
        const category = typeof body?.category === 'string' ? body.category : '';

        if (!text || text.length < 3) {
            return NextResponse.json({ error: 'Field "text" is required' }, { status: 400 });
        }
        if (!CATEGORIES.includes(category)) {
            return NextResponse.json({ error: 'Invalid category' }, { status: 400 });
        }

        const doc = await TrainingSample.create({
            text,
            category,
            urgency: URGENCIES.includes(body?.urgency) ? body.urgency : 'medium',
            aiSuggestedCategory: typeof body?.aiSuggestedCategory === 'string' ? body.aiSuggestedCategory : '',
            aiMethod: typeof body?.aiMethod === 'string' ? body.aiMethod : '',
            corrected: !!body?.corrected,
            source: typeof body?.source === 'string' ? body.source : 'report',
        });

        return NextResponse.json({ ok: true, id: doc._id }, { status: 201 });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}

// GET — list collected samples (for inspection / export tooling).
export async function GET(request) {
    try {
        await dbConnect();
        const { searchParams } = new URL(request.url);
        const limit = Math.min(parseInt(searchParams.get('limit')) || 1000, 5000);
        const [samples, total, corrected] = await Promise.all([
            TrainingSample.find().sort({ createdAt: -1 }).limit(limit).lean(),
            TrainingSample.countDocuments(),
            TrainingSample.countDocuments({ corrected: true }),
        ]);
        return NextResponse.json({ total, corrected, samples });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}
