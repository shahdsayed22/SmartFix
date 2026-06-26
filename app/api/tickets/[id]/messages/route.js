import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Ticket from '@/models/Ticket';
import { notifyEvent } from '@/lib/notifications';

export async function POST(request, { params }) {
    try {
        await dbConnect();
        const { id } = await params;
        const body = await request.json();

        if (!body.senderRole) {
            return NextResponse.json({ error: 'senderRole is required' }, { status: 400 });
        }

        const message = {
            senderId: body.senderId || '',
            senderRole: body.senderRole,
            senderName: body.senderName || '',
            text: body.text || '',
            attachments: Array.isArray(body.attachments) ? body.attachments : [],
            at: new Date(),
        };

        const ticket = await Ticket.findByIdAndUpdate(
            id,
            { $push: { messages: message }, $set: { updatedAt: new Date() } },
            { new: true, runValidators: true }
        ).lean();
        if (!ticket) {
            return NextResponse.json({ error: 'Ticket not found' }, { status: 404 });
        }

        // Reply notifications: admin -> customer, customer/bot -> admin.
        try {
            if (body.senderRole === 'admin') {
                await notifyEvent('ticket_reply', {
                    userId: ticket.customerId,
                    role: 'customer',
                    relatedId: ticket._id.toString(),
                    ticketId: ticket.ticketId,
                    subject: ticket.subject,
                });
            } else {
                await notifyEvent('ticket_reply', {
                    userId: 'admin',
                    role: 'admin',
                    relatedId: ticket._id.toString(),
                    ticketId: ticket.ticketId,
                    subject: ticket.subject,
                    customerName: ticket.customerName,
                });
            }
        } catch (notifyError) {
            console.error('Failed to send ticket_reply notification:', notifyError);
        }

        return NextResponse.json(ticket, { status: 201 });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}
