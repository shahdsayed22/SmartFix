import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Ticket from '@/models/Ticket';
import Issue from '@/models/Issue';
import { notifyEvent } from '@/lib/notifications';

// Human-readable ticket id, e.g. TKT-1A2B3C.
function generateTicketId() {
    const rand = Math.random().toString(36).slice(2, 8).toUpperCase();
    return `TKT-${rand}`;
}

export async function GET(request) {
    try {
        await dbConnect();
        const { searchParams } = new URL(request.url);

        const page = parseInt(searchParams.get('page')) || 1;
        const limit = parseInt(searchParams.get('limit')) || 20;
        const search = searchParams.get('search') || '';
        const customerId = searchParams.get('customerId') || '';
        const status = searchParams.get('status') || '';
        const priority = searchParams.get('priority') || '';
        const category = searchParams.get('category') || '';
        const sortBy = searchParams.get('sortBy') || 'createdAt';
        const sortOrder = searchParams.get('sortOrder') === 'asc' ? 1 : -1;

        const filter = {};
        if (search) {
            filter.$or = [
                { subject: { $regex: search, $options: 'i' } },
                { ticketId: { $regex: search, $options: 'i' } },
                { customerName: { $regex: search, $options: 'i' } },
            ];
        }
        if (customerId) filter.customerId = customerId;
        if (status) filter.status = status;
        if (priority) filter.priority = priority;
        if (category) filter.category = category;

        const skip = (page - 1) * limit;
        const [tickets, total] = await Promise.all([
            Ticket.find(filter)
                .sort({ [sortBy]: sortOrder })
                .skip(skip)
                .limit(limit)
                .lean(),
            Ticket.countDocuments(filter),
        ]);

        // Enrich each ticket with its related issue (human number, status, and
        // the assigned worker) so the dashboard can connect ticket# ↔ issue# ↔
        // worker without per-row fetches. Batch-load by _id; this also backfills
        // tickets created before the denormalized fields existed.
        const isObjectId = (s) => /^[a-f0-9]{24}$/i.test(s || '');
        const issueIds = [...new Set(
            tickets.map((t) => t.relatedIssueId).filter(isObjectId),
        )];
        let issueMap = {};
        if (issueIds.length) {
            const issues = await Issue.find({ _id: { $in: issueIds } })
                .select('issueNumber status assignedTechnicianId assignedTechnicianName')
                .lean();
            issueMap = Object.fromEntries(issues.map((i) => [i._id.toString(), i]));
        }
        const enriched = tickets.map((t) => {
            const iss = t.relatedIssueId ? issueMap[t.relatedIssueId] : null;
            return {
                ...t,
                relatedIssueNumber: t.relatedIssueNumber || iss?.issueNumber || '',
                technicianName: t.technicianName || iss?.assignedTechnicianName || '',
                technicianId: t.technicianId || iss?.assignedTechnicianId || '',
                relatedIssue: iss
                    ? {
                        id: t.relatedIssueId,
                        issueNumber: iss.issueNumber || '',
                        status: iss.status || '',
                        assignedTechnicianName: iss.assignedTechnicianName || '',
                        assignedTechnicianId: iss.assignedTechnicianId || '',
                    }
                    : null,
            };
        });

        return NextResponse.json({
            tickets: enriched,
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

        // Build the messages array. A chatbot source may seed several messages;
        // a manual ticket may carry a single first message via body.message.
        let messages = [];
        if (Array.isArray(body.messages) && body.messages.length) {
            messages = body.messages;
        } else if (body.message) {
            messages = [
                {
                    senderId: body.customerId || '',
                    senderRole: 'customer',
                    senderName: body.customerName || '',
                    text: body.message,
                    at: new Date(),
                },
            ];
        }

        // If the ticket is linked to a service request, resolve that issue and
        // DENORMALIZE its human number + assigned worker onto the ticket at
        // creation time. This is what wires ticket ↔ issue ↔ worker so the
        // dashboard shows the related request and its technician (and lets us
        // message that worker below). The client may pass these, but we trust
        // the issue as the source of truth and backfill anything missing.
        const isObjectId = (s) => /^[a-f0-9]{24}$/i.test(s || '');
        let linkedIssue = null;
        if (isObjectId(body.relatedIssueId)) {
            linkedIssue = await Issue.findById(body.relatedIssueId)
                .select('issueNumber category assignedTechnicianId assignedTechnicianName')
                .lean();
        }

        const ticket = await Ticket.create({
            ...body,
            ticketId: body.ticketId || generateTicketId(),
            messages,
            ...(linkedIssue
                ? {
                    relatedIssueNumber: body.relatedIssueNumber || linkedIssue.issueNumber || '',
                    technicianId: body.technicianId || linkedIssue.assignedTechnicianId || '',
                    technicianName: body.technicianName || linkedIssue.assignedTechnicianName || '',
                }
                : {}),
        });

        // Notify admin(s) that a new ticket was created.
        try {
            await notifyEvent('ticket_created', {
                userId: 'admin',
                role: 'admin',
                relatedId: ticket._id.toString(),
                ticketId: ticket.ticketId,
                subject: ticket.subject,
                customerName: ticket.customerName,
            });
        } catch (notifyError) {
            console.error('Failed to send ticket_created notification:', notifyError);
        }

        // If a worker is assigned to the linked job, message them: a customer
        // raised a query about their work and we need to know what happened.
        if (ticket.technicianId) {
            try {
                await notifyEvent('ticket_worker_query', {
                    userId: ticket.technicianId,
                    role: 'worker',
                    relatedId: ticket._id.toString(),
                    ticketId: ticket.ticketId,
                    issueNumber: ticket.relatedIssueNumber,
                    subject: ticket.subject,
                });
            } catch (notifyError) {
                console.error('Failed to send ticket_worker_query notification:', notifyError);
            }
        }

        return NextResponse.json(ticket, { status: 201 });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}
