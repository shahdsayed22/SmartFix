import mongoose from 'mongoose';

const ReviewSchema = new mongoose.Schema({
    issueId: {
        type: String,
        required: true,
        unique: true,
    },
    technicianId: {
        type: String,
        default: '',
    },
    technicianName: {
        type: String,
        default: '',
    },
    customerId: {
        type: String,
        default: '',
    },
    customerName: {
        type: String,
        default: '',
    },
    rating: {
        type: Number,
        required: [true, 'Please provide a rating'],
        min: 1,
        max: 5,
    },
    tags: {
        type: [String],
        default: [],
    },
    comment: {
        type: String,
        default: '',
    },
    category: {
        type: String,
        default: '',
    },
    createdAt: {
        type: Date,
        default: Date.now,
    },
});

ReviewSchema.index({ technicianId: 1 });
ReviewSchema.index({ issueId: 1 }, { unique: true });

export default mongoose.models.Review || mongoose.model('Review', ReviewSchema);
