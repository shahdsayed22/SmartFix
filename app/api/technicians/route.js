import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Technician from '@/models/Technician';

export async function GET(request) {
    try {
        await dbConnect();
        const { searchParams } = new URL(request.url);

        const page = parseInt(searchParams.get('page')) || 1;
        const limit = parseInt(searchParams.get('limit')) || 20;
        const search = searchParams.get('search') || '';
        const city = searchParams.get('city') || '';
        const category = searchParams.get('category') || '';
        const verified = searchParams.get('verified');
        const sortBy = searchParams.get('sortBy') || 'createdAt';
        const sortOrder = searchParams.get('sortOrder') === 'asc' ? 1 : -1;

        const filter = {};
        if (search) {
            filter.$or = [
                { name: { $regex: search, $options: 'i' } },
                { phone: { $regex: search, $options: 'i' } },
            ];
        }
        if (city) filter.city = city;
        if (category) filter.category = category;
        if (verified !== null && verified !== '') filter.isVerified = verified === 'true';
        // Let a worker look up its own record by Firebase uid (the app uses this
        // to gate access behind admin approval).
        const uid = searchParams.get('uid') || '';
        if (uid) filter.uid = uid;

        const skip = (page - 1) * limit;
        const [technicians, total] = await Promise.all([
            Technician.find(filter)
                .sort({ [sortBy]: sortOrder })
                .skip(skip)
                .limit(limit)
                .lean(),
            Technician.countDocuments(filter),
        ]);

        return NextResponse.json({
            technicians,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit),
            },
        });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}

export async function POST(request) {
    try {
        await dbConnect();
        const body = await request.json();
        // When a uid is provided (registered worker syncing from the app),
        // upsert by uid so re-registration / re-sync updates rather than
        // creating duplicate technician records.
        if (body.uid) {
            const technician = await Technician.findOneAndUpdate(
                { uid: body.uid },
                { $set: body },
                { new: true, upsert: true, runValidators: true, setDefaultsOnInsert: true },
            ).lean();
            return NextResponse.json(technician, { status: 201 });
        }
        const technician = await Technician.create(body);
        return NextResponse.json(technician, { status: 201 });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}
