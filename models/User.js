import mongoose from 'mongoose';

const UserSchema = new mongoose.Schema({
    name: {
        type: String,
        required: [true, 'Please provide a name'],
        maxlength: [100, 'Name cannot exceed 100 characters'],
    },
    email: {
        type: String,
        required: [true, 'Please provide an email'],
        unique: true,
    },
    phone: {
        type: String,
        default: '',
    },
    role: {
        type: String,
        required: true,
        enum: ['customer', 'worker'],
    },
    skills: {
        type: [String],
        default: [],
    },
    city: {
        type: String,
        default: 'Cairo',
    },
    address: {
        type: String,
        default: '',
    },
    profileImageUrl: {
        type: String,
        default: '',
    },
    isVerified: {
        type: Boolean,
        default: false,
    },
    verificationStatus: {
        type: String,
        enum: ['pending', 'verified', 'rejected'],
        default: 'pending',
    },
    isActive: {
        type: Boolean,
        default: true,
    },
    issuesReported: {
        type: Number,
        default: 0,
    },
    issuesCompleted: {
        type: Number,
        default: 0,
    },
    createdAt: {
        type: Date,
        default: Date.now,
    },
});

UserSchema.index({ role: 1 });
UserSchema.index({ isVerified: 1 });
UserSchema.index({ city: 1 });
UserSchema.index({ email: 1 });
UserSchema.index({ name: 'text' });

export default mongoose.models.User || mongoose.model('User', UserSchema);
