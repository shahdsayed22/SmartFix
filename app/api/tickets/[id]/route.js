import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Ticket from '@/models/Ticket';
import Issue from '@/models/Issue';

const isObjectId = (s) => /^[a-f0-9]{24}$/i.test(s || '');

export async function GET(request, { params }) {
    try {
        await dbConnect();
        const { id } = await params;
        const ticket = await Ticket.findById(id).lean();
        if (!ticket) {
            return NextResponse.json({ error: 'Ticket not found' }, { status: 404 });
        }
        return NextResponse.json(ticket);
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}

export async function PATCH(request, { params }) {
    try {
        await dbConnect();
        const { id } = await params;
        const body = await request.json();

        // Status/priority/category are updatable here; messages go through the
        // dedicated messages route so notifications fire correctly.
        const update = { updatedAt: new Date() };
        if (body.status !== undefined) update.status = body.status;
        if (body.priority !== undefined) update.priority = body.priority;
        if (body.category !== undefined) update.category = body.category;

        // Linking a ticket to a service request (Issue): denormalize the issue
        // number and its assigned worker onto the ticket so the dashboard shows
        // the worker name. Passing an empty value unlinks and clears the worker.
        if (body.relatedIssueId !== undefined) {
            const rid = (body.relatedIssueId || '').trim();
            if (rid && isObjectId(rid)) {
                const iss = await Issue.findById(rid)
                    .select('issueNumber assignedTechnicianId assignedTechnicianName')
                    .lean();
                if (!iss) {
                    return NextResponse.json({ error: 'Issue not found' }, { status: 404 });
                }
                update.relatedIssueId = rid;
                update.relatedIssueNumber = iss.issueNumber || '';
                update.technicianId = iss.assignedTechnicianId || '';
                update.technicianName = iss.assignedTechnicianName || '';
            } else {
                update.relatedIssueId = '';
                update.relatedIssueNumber = '';
                update.technicianId = '';
                update.technicianName = '';
            }
        }

        const ticket = await Ticket.findByIdAndUpdate(id, update, {
            new: true,
            runValidators: true,
        }).lean();
        if (!ticket) {
            return NextResponse.json({ error: 'Ticket not found' }, { status: 404 });
        }
        return NextResponse.json(ticket);
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}
