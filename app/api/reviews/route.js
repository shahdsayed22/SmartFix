import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Review from '@/models/Review';
import Issue from '@/models/Issue';
import Technician from '@/models/Technician';
import { notifyEvent } from '@/lib/notifications';

export async function GET(request) {
    try {
        await dbConnect();
        const { searchParams } = new URL(request.url);

        const page = parseInt(searchParams.get('page')) || 1;
        const limit = parseInt(searchParams.get('limit')) || 20;
        const technicianId = searchParams.get('technicianId') || '';
        const customerId = searchParams.get('customerId') || '';
        const issueId = searchParams.get('issueId') || '';
        const sortBy = searchParams.get('sortBy') || 'createdAt';
        const sortOrder = searchParams.get('sortOrder') === 'asc' ? 1 : -1;

        const filter = {};
        if (technicianId) filter.technicianId = technicianId;
        if (customerId) filter.customerId = customerId;
        if (issueId) filter.issueId = issueId;

        const skip = (page - 1) * limit;
        const [reviews, total] = await Promise.all([
            Review.find(filter)
                .sort({ [sortBy]: sortOrder })
                .skip(skip)
                .limit(limit)
                .lean(),
            Review.countDocuments(filter),
        ]);

        return NextResponse.json({
            reviews,
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

        if (!body.issueId) {
            return NextResponse.json({ error: 'issueId is required' }, { status: 400 });
        }

        // One review per job — reject duplicates with 409 Conflict.
        const existing = await Review.findOne({ issueId: body.issueId }).lean();
        if (existing) {
            return NextResponse.json(
                { error: 'A review already exists for this issue' },
                { status: 409 }
            );
        }

        const review = await Review.create(body);

        // Link the review back to its issue.
        try {
            await Issue.findByIdAndUpdate(body.issueId, {
                reviewId: review._id.toString(),
                updatedAt: new Date(),
            });
        } catch (linkError) {
            console.error('Failed to link review to issue:', linkError);
        }

        // Recompute the technician's rating average + issuesResolved.
        if (body.technicianId) {
            try {
                const agg = await Review.aggregate([
                    { $match: { technicianId: body.technicianId } },
                    {
                        $group: {
                            _id: '$technicianId',
                            avgRating: { $avg: '$rating' },
                            count: { $sum: 1 },
                        },
                    },
                ]);
                const avgRating = agg.length ? Number(agg[0].avgRating.toFixed(2)) : body.rating;
                await Technician.findByIdAndUpdate(body.technicianId, {
                    rating: avgRating,
                    $inc: { issuesResolved: 1 },
                });
            } catch (techError) {
                console.error('Failed to update technician rating:', techError);
            }
        }

        // Notify the technician of the new rating.
        try {
            await notifyEvent('rating_submitted', {
                userId: body.technicianId,
                role: 'worker',
                relatedId: review._id.toString(),
                rating: review.rating,
                customerName: review.customerName,
            });
        } catch (notifyError) {
            console.error('Failed to send rating_submitted notification:', notifyError);
        }

        return NextResponse.json(review, { status: 201 });
    } catch (error) {
        // Mongo duplicate-key (unique issueId) — surface as 409.
        if (error.code === 11000) {
            return NextResponse.json(
                { error: 'A review already exists for this issue' },
                { status: 409 }
            );
        }
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}
