import mongoose from 'mongoose';

const IssueSchema = new mongoose.Schema({
    // Human-readable issue number (e.g. ISS-1A2B3C), shown next to the ticket
    // number in the dashboard so support can connect a ticket to its job.
    issueNumber: {
        type: String,
        default: () => `ISS-${Math.random().toString(36).slice(2, 8).toUpperCase()}`,
        index: true,
    },
    title: {
        type: String,
        required: [true, 'Please provide a title'],
        maxlength: [200, 'Title cannot exceed 200 characters'],
    },
    description: {
        type: String,
        required: [true, 'Please provide a description'],
        maxlength: [2000, 'Description cannot exceed 2000 characters'],
    },
    category: {
        type: String,
        required: true,
        enum: ['plumbing', 'electrical', 'carpentry', 'painting', 'hvac', 'cleaning', 'appliance_repair', 'welding', 'tiling'],
    },
    urgency: {
        type: String,
        required: true,
        enum: ['low', 'medium', 'high', 'emergency'],
        default: 'medium',
    },
    status: {
        type: String,
        required: true,
        enum: ['pending', 'offered', 'assigned', 'inProgress', 'awaitingApproval', 'awaitingPayment', 'completed', 'cancelled', 'disputed', 'rejected'],
        default: 'pending',
    },
    customerId: {
        type: String,
        default: '',
        index: true,
    },
    customerName: {
        type: String,
        required: true,
    },
    customerEmail: {
        type: String,
        default: '',
    },
    customerPhone: {
        type: String,
        default: '',
    },
    assignedTechnicianId: {
        type: String,
        default: null,
    },
    assignedTechnicianName: {
        type: String,
        default: '',
    },
    // --- Uber-style offer/accept dispatch (Stage 3) ---
    // The workflow ranks nearest AVAILABLE technicians and OFFERS the job to
    // them one at a time (rather than hard-assigning). The worker accepts or
    // declines; a decline cascades the offer to the next candidate in the queue.
    offeredTo: {
        type: String,
        default: null,
    },
    offeredToName: {
        type: String,
        default: '',
    },
    offerQueue: {
        // Ranked candidates: { techId, name, km, fare, rating }
        type: [
            {
                techId: { type: String },
                name: { type: String, default: '' },
                km: { type: Number, default: null },
                fare: { type: Number, default: null },
                rating: { type: Number, default: 0 },
            },
        ],
        default: [],
    },
    offerIndex: {
        type: Number,
        default: 0,
    },
    offerExpiresAt: {
        type: Date,
        default: null,
    },
    address: {
        type: String,
        default: '',
    },
    city: {
        type: String,
        default: 'Cairo',
    },
    latitude: {
        type: Number,
        default: 0,
    },
    longitude: {
        type: Number,
        default: 0,
    },
    estimatedCost: {
        type: Number,
        default: 0,
    },
    price: {
        type: Number,
        default: 0,
    },
    photoUrls: {
        type: [String],
        default: [],
    },
    // --- Completion / approval workflow fields ---
    completionRequestedAt: {
        type: Date,
        default: null,
    },
    completionSummary: {
        type: String,
        default: '',
    },
    completionPhotos: {
        type: [String],
        default: [],
    },
    rejectionReason: {
        type: String,
        default: '',
    },
    reviewId: {
        type: String,
        default: '',
    },
    paymentId: {
        type: String,
        default: '',
    },
    statusHistory: {
        type: [
            {
                status: { type: String },
                at: { type: Date, default: Date.now },
                by: { type: String, default: '' },
            },
        ],
        default: [],
    },
    // --- AI triage fields (populated by the durable issue-triage workflow) ---
    aiUrgencyScore: {
        type: Number,
        default: null,
    },
    aiAnomalyScore: {
        type: Number,
        default: null,
    },
    aiSuggestedCategory: {
        type: String,
        default: '',
    },
    aiClassification: {
        type: Object,
        default: null,
    },
    aiProcessedAt: {
        type: Date,
        default: null,
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

IssueSchema.index({ status: 1 });
IssueSchema.index({ category: 1 });
IssueSchema.index({ urgency: 1 });
IssueSchema.index({ city: 1 });
IssueSchema.index({ createdAt: -1 });
IssueSchema.index({ customerName: 'text', title: 'text' });

export default mongoose.models.Issue || mongoose.model('Issue', IssueSchema);
