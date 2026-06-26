import mongoose from 'mongoose';

const ServiceCategorySchema = new mongoose.Schema({
    key: {
        type: String,
        required: true,
        unique: true,
        trim: true,
        lowercase: true,
        // Lowercase slug: must start with a letter, then letters/digits/underscore.
        // Replaces the old fixed enum so genuinely-new categories can be created.
        match: [/^[a-z][a-z0-9_]*$/, 'Key must be a lowercase slug (a-z, 0-9, _) starting with a letter.'],
    },
    labelEn: {
        type: String,
        default: '',
    },
    labelAr: {
        type: String,
        default: '',
    },
    icon: {
        type: String,
        default: '',
    },
    color: {
        type: String,
        default: '',
    },
    defaultPrice: {
        type: Number,
        default: 0,
    },
    order: {
        type: Number,
        default: 0,
    },
    active: {
        type: Boolean,
        default: true,
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

ServiceCategorySchema.index({ order: 1 });
ServiceCategorySchema.index({ active: 1 });

// Canonical taxonomy from build contract §1 (keys are immutable; order = display order).
export const SERVICE_CATEGORY_SEED = [
    { key: 'plumbing', labelAr: 'السباكة', labelEn: 'Plumbing', icon: 'wrench', color: '#1E6FD9', defaultPrice: 180, order: 0, active: true },
    { key: 'electrical', labelAr: 'الكهرباء', labelEn: 'Electrical', icon: 'zap', color: '#EBA110', defaultPrice: 200, order: 1, active: true },
    { key: 'carpentry', labelAr: 'النجارة', labelEn: 'Carpentry', icon: 'hammer', color: '#8A5A3B', defaultPrice: 250, order: 2, active: true },
    { key: 'painting', labelAr: 'الدهانات', labelEn: 'Painting', icon: 'paint-roller', color: '#8E44C4', defaultPrice: 1200, order: 3, active: true },
    { key: 'hvac', labelAr: 'التكييف والتبريد', labelEn: 'HVAC', icon: 'wind', color: '#189FB6', defaultPrice: 350, order: 4, active: true },
    { key: 'cleaning', labelAr: 'التنظيف', labelEn: 'Cleaning', icon: 'spray-can', color: '#DE3F7C', defaultPrice: 300, order: 5, active: true },
    { key: 'appliance_repair', labelAr: 'صيانة الأجهزة', labelEn: 'Appliances', icon: 'washing-machine', color: '#F2700B', defaultPrice: 220, order: 6, active: true },
    { key: 'welding', labelAr: 'اللحام', labelEn: 'Welding', icon: 'flame', color: '#D23A2A', defaultPrice: 280, order: 7, active: true },
    { key: 'tiling', labelAr: 'السيراميك والبلاط', labelEn: 'Tiling', icon: 'grid-3x3', color: '#0E9C8C', defaultPrice: 900, order: 8, active: true },
];

// Seeds the canonical §1 taxonomy if the collection is empty; returns the active, ordered list.
ServiceCategorySchema.statics.seedDefaults = async function seedDefaults() {
    const count = await this.estimatedDocumentCount();
    if (count === 0) {
        await this.insertMany(SERVICE_CATEGORY_SEED);
    }
    return this.find({ active: true }).sort({ order: 1 });
};

export default mongoose.models.ServiceCategory || mongoose.model('ServiceCategory', ServiceCategorySchema);
