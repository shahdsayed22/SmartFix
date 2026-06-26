import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Notification from '@/models/Notification';
import { createNotification } from '@/lib/notifications';

export async function GET(request) {
    try {
        await dbConnect();
        const { searchParams } = new URL(request.url);

        const page = parseInt(searchParams.get('page')) || 1;
        const limit = parseInt(searchParams.get('limit')) || 30;
        const userId = searchParams.get('userId') || '';
        const role = searchParams.get('role') || '';
        const unreadOnly = searchParams.get('unreadOnly') === 'true';
        const sortBy = searchParams.get('sortBy') || 'createdAt';
        const sortOrder = searchParams.get('sortOrder') === 'asc' ? 1 : -1;

        const filter = {};
        if (userId) filter.userId = userId;
        if (role) filter.role = role;
        if (unreadOnly) filter.read = false;

        const skip = (page - 1) * limit;
        const [notifications, total, unreadCount] = await Promise.all([
            Notification.find(filter)
                .sort({ [sortBy]: sortOrder })
                .skip(skip)
                .limit(limit)
                .lean(),
            Notification.countDocuments(filter),
            Notification.countDocuments({ ...filter, read: false }),
        ]);

        return NextResponse.json({
            notifications,
            unreadCount,
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
        const notification = await createNotification(body);
        return NextResponse.json(notification, { status: 201 });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}

export async function PATCH(request) {
    try {
        await dbConnect();
        const body = await request.json();

        // Mark a single notification read by id, or all of a user's as read.
        if (body.id) {
            const notification = await Notification.findByIdAndUpdate(
                body.id,
                { read: true },
                { new: true }
            ).lean();
            if (!notification) {
                return NextResponse.json({ error: 'Notification not found' }, { status: 404 });
            }
            return NextResponse.json(notification);
        }

        if (body.userId) {
            const result = await Notification.updateMany(
                { userId: body.userId, read: false },
                { read: true }
            );
            return NextResponse.json({ modified: result.modifiedCount ?? 0 });
        }

        return NextResponse.json({ error: 'Provide an id or userId' }, { status: 400 });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}
