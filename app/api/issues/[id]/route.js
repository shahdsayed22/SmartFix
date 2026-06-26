import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Issue from '@/models/Issue';
import { notifyEvent } from '@/lib/notifications';

export async function GET(request, { params }) {
    try {
        await dbConnect();
        const { id } = await params;
        const issue = await Issue.findById(id).lean();
        if (!issue) {
            return NextResponse.json({ error: 'Issue not found' }, { status: 404 });
        }
        return NextResponse.json(issue);
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}

export async function PUT(request, { params }) {
    try {
        await dbConnect();
        const { id } = await params;
        const body = await request.json();
        body.updatedAt = new Date();
        // Constraint: an issue cannot enter the 'assigned' state without a
        // technician. Reject the transition if neither the request nor the
        // stored document supplies an assigned technician.
        if (body.status === 'assigned') {
            const current = await Issue.findById(id).lean();
            if (!current) {
                return NextResponse.json({ error: 'Issue not found' }, { status: 404 });
            }
            const techId = body.assignedTechnicianId || current.assignedTechnicianId;
            if (!techId) {
                return NextResponse.json(
                    { error: 'Cannot set status to "assigned" without an assigned technician.' },
                    { status: 400 },
                );
            }
        }
        const issue = await Issue.findByIdAndUpdate(id, body, {
            new: true,
            runValidators: true,
        }).lean();
        if (!issue) {
            return NextResponse.json({ error: 'Issue not found' }, { status: 404 });
        }
        return NextResponse.json(issue);
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

        // No action → generic partial update (same semantics as PUT).
        if (!action) {
            body.updatedAt = new Date();
            const issue = await Issue.findByIdAndUpdate(id, body, {
                new: true,
                runValidators: true,
            }).lean();
            if (!issue) {
                return NextResponse.json({ error: 'Issue not found' }, { status: 404 });
            }
            return NextResponse.json(issue);
        }

        const at = new Date();

        // ── Uber-style offer/accept (Stage 3) ──────────────────────────────
        // These two read the current offer queue, so they fetch-then-update and
        // return directly instead of going through the generic update below.
        if (action === 'accept-offer' || action === 'decline-offer') {
            const current = await Issue.findById(id).lean();
            if (!current) {
                return NextResponse.json({ error: 'Issue not found' }, { status: 404 });
            }
            if (current.status !== 'offered') {
                return NextResponse.json(
                    { error: `Issue is not awaiting an offer response (status: ${current.status}).` },
                    { status: 409 },
                );
            }
            // The caller must be the technician currently holding the offer.
            const techId = body.technicianId || body.assignedTechnicianId || null;
            if (techId && current.offeredTo && String(techId) !== String(current.offeredTo)) {
                return NextResponse.json(
                    { error: 'This offer is no longer assigned to you.' },
                    { status: 409 },
                );
            }

            const queue = Array.isArray(current.offerQueue) ? current.offerQueue : [];
            const idx = current.offerIndex || 0;
            const offer = queue[idx] || null;
            let update;
            let event;

            // Atomicity: the filter re-asserts the offer state we read, so a
            // concurrent accept/decline (or decline-then-accept) can't win twice.
            // Whoever flips it first matches; the loser gets 409.
            const filter = { _id: id, status: 'offered' };
            if (current.offeredTo) filter.offeredTo = current.offeredTo;

            if (action === 'accept-offer') {
                // Lock the job to this worker at the quoted fare; clear the offer.
                update = {
                    status: 'assigned',
                    assignedTechnicianId: current.offeredTo,
                    assignedTechnicianName: current.offeredToName || (offer && offer.name) || '',
                    price: offer && offer.fare != null ? offer.fare : current.price,
                    offeredTo: null,
                    offeredToName: '',
                    offerExpiresAt: null,
                    updatedAt: at,
                    $push: { statusHistory: { status: 'assigned', at, by: body.by || 'worker' } },
                };
                event = 'offer_accepted';
            } else {
                // Decline → cascade to the next candidate, or back to pending.
                // Pin offerIndex too so two declines can't both advance the queue.
                filter.offerIndex = idx;
                const nextIdx = idx + 1;
                const next = queue[nextIdx] || null;
                if (next) {
                    update = {
                        offerIndex: nextIdx,
                        offeredTo: next.techId,
                        offeredToName: next.name || '',
                        price: next.fare != null ? next.fare : current.price,
                        updatedAt: at,
                    };
                } else {
                    // Queue exhausted → unassign and re-open for manual claim.
                    update = {
                        status: 'pending',
                        offeredTo: null,
                        offeredToName: '',
                        updatedAt: at,
                        $push: { statusHistory: { status: 'pending', at, by: body.by || 'worker' } },
                    };
                }
                event = 'offer_declined';
            }

            const issue = await Issue.findOneAndUpdate(filter, update, {
                new: true,
                runValidators: true,
            }).lean();
            if (!issue) {
                return NextResponse.json(
                    { error: 'This offer was already taken or has moved on.' },
                    { status: 409 },
                );
            }

            // Notify: accept → customer; decline-with-next → the next worker.
            try {
                if (action === 'accept-offer') {
                    await notifyEvent(event, {
                        userId: issue.customerId || '',
                        role: 'customer',
                        relatedId: issue._id.toString(),
                        issueTitle: issue.title,
                    });
                } else if (issue.status === 'offered' && issue.offeredTo) {
                    await notifyEvent(event, {
                        userId: issue.offeredTo,
                        role: 'worker',
                        relatedId: issue._id.toString(),
                        issueTitle: issue.title,
                    });
                }
            } catch (notifyError) {
                console.error(`Failed to send ${event} notification:`, notifyError);
            }

            return NextResponse.json(issue);
        }

        let update = { updatedAt: at };
        let event = null;
        let notifyRole = null;
        let notifyUserField = null;
        let allowedFrom = null; // statuses this action may transition FROM

        if (action === 'request-completion') {
            // Worker reports the job done → awaiting customer approval.
            update.status = 'awaitingApproval';
            update.completionRequestedAt = at;
            update.completionSummary = body.completionSummary || '';
            update.completionPhotos = Array.isArray(body.completionPhotos)
                ? body.completionPhotos
                : [];
            update.$push = { statusHistory: { status: 'awaitingApproval', at, by: body.by || 'worker' } };
            event = 'completion_requested';
            notifyRole = 'customer';
            notifyUserField = 'customerId';
            allowedFrom = ['assigned', 'inProgress'];
        } else if (action === 'approve-completion') {
            // Customer approves → awaiting payment.
            update.status = 'awaitingPayment';
            update.$push = { statusHistory: { status: 'awaitingPayment', at, by: body.by || 'customer' } };
            event = 'completion_approved';
            notifyRole = 'worker';
            notifyUserField = 'assignedTechnicianId';
            allowedFrom = ['awaitingApproval'];
        } else if (action === 'reject-completion') {
            // Customer rejects → back to inProgress (or disputed) with a reason.
            const nextStatus = body.dispute ? 'disputed' : 'inProgress';
            update.status = nextStatus;
            update.rejectionReason = body.rejectionReason || '';
            update.$push = { statusHistory: { status: nextStatus, at, by: body.by || 'customer' } };
            event = 'completion_rejected';
            notifyRole = 'worker';
            notifyUserField = 'assignedTechnicianId';
            allowedFrom = ['awaitingApproval'];
        } else {
            return NextResponse.json({ error: `Unknown action: ${action}` }, { status: 400 });
        }

        // Enforce a valid lifecycle transition atomically: only flip if the
        // issue is currently in an allowed prior status (no jumping pending →
        // awaitingPayment, no approving a job that was never completed).
        const filter = { _id: id };
        if (allowedFrom) filter.status = { $in: allowedFrom };
        const issue = await Issue.findOneAndUpdate(filter, update, {
            new: true,
            runValidators: true,
        }).lean();
        if (!issue) {
            const exists = await Issue.findById(id).lean();
            if (!exists) {
                return NextResponse.json({ error: 'Issue not found' }, { status: 404 });
            }
            return NextResponse.json(
                { error: `Cannot ${action} from status "${exists.status}".` },
                { status: 409 },
            );
        }

        // Notify the relevant counterparty about the state change.
        try {
            await notifyEvent(event, {
                userId: issue[notifyUserField] || '',
                role: notifyRole,
                relatedId: issue._id.toString(),
                issueTitle: issue.title,
                rejectionReason: issue.rejectionReason,
            });
        } catch (notifyError) {
            console.error(`Failed to send ${event} notification:`, notifyError);
        }

        return NextResponse.json(issue);
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}

export async function DELETE(request, { params }) {
    try {
        await dbConnect();
        const { id } = await params;
        const issue = await Issue.findByIdAndDelete(id).lean();
        if (!issue) {
            return NextResponse.json({ error: 'Issue not found' }, { status: 404 });
        }
        return NextResponse.json({ message: 'Issue deleted successfully' });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}
