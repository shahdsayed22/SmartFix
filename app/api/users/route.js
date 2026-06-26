import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import User from '@/models/User';

export async function GET(request) {
    try {
        await dbConnect();
        const { searchParams } = new URL(request.url);

        const page = parseInt(searchParams.get('page')) || 1;
        const limit = parseInt(searchParams.get('limit')) || 1000;
        const search = searchParams.get('search') || '';
        const role = searchParams.get('role') || '';
        const city = searchParams.get('city') || '';
        const verified = searchParams.get('verified');
        const sortBy = searchParams.get('sortBy') || 'createdAt';
        const sortOrder = searchParams.get('sortOrder') === 'asc' ? 1 : -1;

        const filter = {};
        if (search) {
            filter.$or = [
                { name: { $regex: search, $options: 'i' } },
                { email: { $regex: search, $options: 'i' } },
                { phone: { $regex: search, $options: 'i' } },
            ];
        }
        if (role) filter.role = role;
        if (city) filter.city = city;
        if (verified !== null && verified !== '' && verified !== undefined) {
            filter.isVerified = verified === 'true';
        }

        const skip = (page - 1) * limit;
        const [users, total] = await Promise.all([
            User.find(filter)
                .sort({ [sortBy]: sortOrder })
                .skip(skip)
                .limit(limit)
                .lean(),
            User.countDocuments(filter),
        ]);

        return NextResponse.json({
            users,
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

        // Admin "Add User" path: create-or-409. Never silently overwrite an
        // existing account when an admin adds a user from the dashboard.
        if (body.source === 'admin') {
            if (!body.email) {
                return NextResponse.json({ error: 'Email is required' }, { status: 400 });
            }
            const existing = await User.findOne({ email: body.email }).lean();
            if (existing) {
                return NextResponse.json(
                    { error: 'A user with this email already exists' },
                    { status: 409 }
                );
            }
            const { source, ...data } = body;
            const created = await User.create(data);
            return NextResponse.json(created, { status: 201 });
        }

        // Mobile syncUser path: upsert by email — prevents duplicates when the
        // mobile app calls syncUser on sign-up/sign-in.
        if (body.email) {
            const user = await User.findOneAndUpdate(
                { email: body.email },
                { $set: body },
                { upsert: true, new: true, runValidators: true }
            ).lean();
            return NextResponse.json(user, { status: 200 });
        }

        const user = await User.create(body);
        return NextResponse.json(user, { status: 201 });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}
