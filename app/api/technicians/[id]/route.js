import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Technician from '@/models/Technician';
import { notifyEvent } from '@/lib/notifications';

export async function GET(request, { params }) {
    try {
        await dbConnect();
        const { id } = await params;
        const technician = await Technician.findById(id).lean();
        if (!technician) {
            return NextResponse.json({ error: 'Technician not found' }, { status: 404 });
        }
        return NextResponse.json(technician);
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}

export async function PUT(request, { params }) {
    try {
        await dbConnect();
        const { id } = await params;
        const body = await request.json();
        const technician = await Technician.findByIdAndUpdate(id, body, {
            new: true,
            runValidators: true,
        }).lean();
        if (!technician) {
            return NextResponse.json({ error: 'Technician not found' }, { status: 404 });
        }
        return NextResponse.json(technician);
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}

export async function PATCH(request, { params }) {
    try {
        await dbConnect();
        const { id } = await params;
        const body = await request.json();
        const { action } = body;

        const update = {};

        if (action === 'verify') {
            update.verificationStatus = 'verified';
            update.isVerified = true;
        } else if (action === 'reject') {
            update.verificationStatus = 'rejected';
            update.isVerified = false;
        }

        // Manual rating override. Accepts { action:'set-rating', rating } or a
        // bare numeric { rating }. Validate the 0..5 range before persisting.
        if (action === 'set-rating' || body.rating !== undefined) {
            const rating = Number(body.rating);
            if (!Number.isFinite(rating) || rating < 0 || rating > 5) {
                return NextResponse.json({ error: 'Rating must be a number between 0 and 5' }, { status: 400 });
            }
            update.rating = Math.round(rating * 100) / 100;
        }

        // Multi-skill categories assignment.
        if (Array.isArray(body.categories)) {
            update.categories = body.categories;
        }

        // Allow plain field updates alongside (e.g. specialization) when no action.
        if (!action && body.verificationStatus !== undefined) {
            update.verificationStatus = body.verificationStatus;
        }

        if (Object.keys(update).length === 0) {
            return NextResponse.json({ error: 'No supported fields to update' }, { status: 400 });
        }

        const technician = await Technician.findByIdAndUpdate(id, update, {
            new: true,
            runValidators: true,
        }).lean();
        if (!technician) {
            return NextResponse.json({ error: 'Technician not found' }, { status: 404 });
        }

        // Notify the technician when their account is verified.
        if (action === 'verify') {
            try {
                await notifyEvent('worker_verified', {
                    userId: technician._id.toString(),
                    role: 'worker',
                    relatedId: technician._id.toString(),
                    technicianName: technician.name,
                });
            } catch (notifyError) {
                console.error('Failed to send worker_verified notification:', notifyError);
            }
        }

        return NextResponse.json(technician);
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}

export async function DELETE(request, { params }) {
    try {
        await dbConnect();
        const { id } = await params;
        const technician = await Technician.findByIdAndDelete(id).lean();
        if (!technician) {
            return NextResponse.json({ error: 'Technician not found' }, { status: 404 });
        }
        return NextResponse.json({ message: 'Technician deleted successfully' });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}
