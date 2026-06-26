import mongoose from 'mongoose';

const TicketMessageSchema = new mongoose.Schema({
    senderId: {
        type: String,
        default: '',
    },
    senderRole: {
        type: String,
        enum: ['customer', 'admin', 'bot'],
        required: true,
    },
    senderName: {
        type: String,
        default: '',
    },
    text: {
        type: String,
        default: '',
    },
    attachments: {
        type: [String],
        default: [],
    },
    at: {
        type: Date,
        default: Date.now,
    },
}, { _id: true });

const TicketSchema = new mongoose.Schema({
    ticketId: {
        type: String,
        unique: true,
        required: true,
    },
    customerId: {
        type: String,
        default: '',
        index: true,
    },
    customerName: {
        type: String,
        default: '',
    },
    subject: {
        type: String,
        required: [true, 'Please provide a subject'],
    },
    category: {
        type: String,
        enum: ['general', 'payment', 'service_quality', 'technician', 'account', 'complaint', 'other'],
        default: 'general',
    },
    status: {
        type: String,
        enum: ['open', 'pending', 'resolved', 'closed'],
        default: 'open',
    },
    priority: {
        type: String,
        enum: ['low', 'medium', 'high'],
        default: 'medium',
    },
    relatedIssueId: {
        type: String,
        default: '',
    },
    // Human-readable number of the related issue (ISS-XXXX), denormalized at
    // escalation time so the dashboard can show it next to the ticket number.
    relatedIssueNumber: {
        type: String,
        default: '',
    },
    // The worker handling the related issue (denormalized from the Issue) so a
    // support agent sees ticket# + issue# + assigned worker together.
    technicianId: {
        type: String,
        default: '',
    },
    technicianName: {
        type: String,
        default: '',
    },
    // Whether the person who opened the ticket is a customer or a technician
    // (the Ticket message enum only has customer|admin|bot).
    requesterRole: {
        type: String,
        enum: ['customer', 'worker'],
        default: 'customer',
    },
    source: {
        type: String,
        enum: ['manual', 'chatbot'],
        default: 'manual',
    },
    messages: {
        type: [TicketMessageSchema],
        default: [],
    },
    createdAt: {
        type: Date,
        default: Date.now,
    },
    updatedAt: {
        type: Date,
        default: Date.now,
    },
});

TicketSchema.index({ customerId: 1 });
TicketSchema.index({ status: 1 });
TicketSchema.index({ priority: 1 });
TicketSchema.index({ createdAt: -1 });

export default mongoose.models.Ticket || mongoose.model('Ticket', TicketSchema);
