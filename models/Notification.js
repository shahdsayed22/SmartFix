import mongoose from 'mongoose';

const NotificationSchema = new mongoose.Schema({
    userId: {
        type: String,
        default: '',
        index: true,
    },
    role: {
        type: String,
        enum: ['customer', 'worker', 'admin'],
        default: 'customer',
    },
    type: {
        type: String,
        default: '',
    },
    title: {
        type: String,
        default: '',
    },
    body: {
        type: String,
        default: '',
    },
    icon: {
        type: String,
        default: '',
    },
    tone: {
        type: String,
        enum: ['info', 'success', 'warning', 'danger'],
        default: 'info',
    },
    relatedId: {
        type: String,
        default: '',
    },
    read: {
        type: Boolean,
        default: false,
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

NotificationSchema.index({ userId: 1, read: 1 });
NotificationSchema.index({ createdAt: -1 });

export default mongoose.models.Notification || mongoose.model('Notification', NotificationSchema);
