import mongoose from 'mongoose';

const CommissionSettingsSchema = new mongoose.Schema({
    key: {
        type: String,
        unique: true,
        default: 'default',
    },
    platformFeePercent: {
        type: Number,
        default: 10,
        min: [0, 'platformFeePercent cannot be negative'],
        max: [100, 'platformFeePercent cannot exceed 100'],
    },
    vatPercent: {
        type: Number,
        default: 14,
        min: [0, 'vatPercent cannot be negative'],
        max: [100, 'vatPercent cannot exceed 100'],
    },
    workerCommissionPercent: {
        type: Number,
        default: 15,
        min: [0, 'workerCommissionPercent cannot be negative'],
        max: [100, 'workerCommissionPercent cannot exceed 100'],
    },
    minPlatformFee: {
        type: Number,
        default: 0,
        min: [0, 'minPlatformFee cannot be negative'],
    },
    currency: {
        type: String,
        default: 'EGP',
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

// Returns the singleton 'default' settings doc, creating it atomically if absent.
// Atomic upsert avoids the find-then-create race (two cold requests both
// creating, or the E11000 loser silently falling back to defaults).
CommissionSettingsSchema.statics.getSettings = async function getSettings() {
    return this.findOneAndUpdate(
        { key: 'default' },
        { $setOnInsert: { key: 'default' } },
        { new: true, upsert: true, setDefaultsOnInsert: true },
    );
};

export default mongoose.models.CommissionSettings || mongoose.model('CommissionSettings', CommissionSettingsSchema);
