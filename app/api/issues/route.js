import { NextResponse } from 'next/server';
import { start } from 'workflow/api';
import dbConnect from '@/lib/mongodb';
import Issue from '@/models/Issue';
import { triageIssue } from '@/workflows/issue-triage';
import { detectCategory } from '@/lib/nlp';

export async function GET(request) {
    try {
        await dbConnect();
        const { searchParams } = new URL(request.url);

        const page = parseInt(searchParams.get('page')) || 1;
        const limit = parseInt(searchParams.get('limit')) || 20;
        const search = searchParams.get('search') || '';
        const category = searchParams.get('category') || '';
        const status = searchParams.get('status') || '';
        const urgency = searchParams.get('urgency') || '';
        const city = searchParams.get('city') || '';
        const sortBy = searchParams.get('sortBy') || 'createdAt';
        const sortOrder = searchParams.get('sortOrder') === 'asc' ? 1 : -1;

        const filter = {};
        if (search) {
            filter.$or = [
                { title: { $regex: search, $options: 'i' } },
                { customerName: { $regex: search, $options: 'i' } },
                { description: { $regex: search, $options: 'i' } },
            ];
        }
        if (category) filter.category = category;
        if (status) filter.status = status;
        if (urgency) filter.urgency = urgency;
        if (city) filter.city = city;

        // Support filtering by customerId from mobile app
        const customerId = searchParams.get('customerId') || '';
        if (customerId) filter.customerId = customerId;

        // Worker offers view (Stage 3): jobs currently OFFERED to this worker.
        // Pair with status=offered to show only live, actionable offers.
        const offeredTo = searchParams.get('offeredTo') || '';
        if (offeredTo) filter.offeredTo = offeredTo;

        // Worker-gating: jobs a worker may claim — pending, unassigned, and in
        // one of the worker's skill categories. csv of category keys.
        const availableForCategories = searchParams.get('availableForCategories') || '';
        if (availableForCategories) {
            const cats = availableForCategories
                .split(',')
                .map((c) => c.trim())
                .filter(Boolean);
            if (cats.length) filter.category = { $in: cats };
            filter.status = 'pending';
            filter.$and = [
                ...(filter.$and || []),
                {
                    $or: [
                        { assignedTechnicianId: null },
                        { assignedTechnicianId: '' },
                        { assignedTechnicianId: { $exists: false } },
                    ],
                },
            ];
        }

        const skip = (page - 1) * limit;
        const [issues, total] = await Promise.all([
            Issue.find(filter)
                .sort({ [sortBy]: sortOrder })
                .skip(skip)
                .limit(limit)
                .lean(),
            Issue.countDocuments(filter),
        ]);

        return NextResponse.json({
            issues,
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

        // Run lightweight NLP over the title+description. Always record the
        // suggested category; if the request omits the category or it disagrees
        // with the detection, fall back to the suggestion for the stored category.
        const detection = detectCategory(`${body.title || ''} ${body.description || ''}`);
        if (detection.category) {
            body.aiSuggestedCategory = detection.category;
            if (!body.category) {
                body.category = detection.category;
            }
        }

        const issue = await Issue.create(body);

        // Fire-and-forget durable AI triage (classify + match technician).
        // Wrapped so a workflow-runtime hiccup can never block issue creation.
        try {
            await start(triageIssue, [issue._id.toString()]);
        } catch (triageError) {
            console.error('Failed to start issue-triage workflow:', triageError);
        }

        return NextResponse.json(issue, { status: 201 });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}
