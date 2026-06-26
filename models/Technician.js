import mongoose from 'mongoose';

const TechnicianSchema = new mongoose.Schema({
    // Firebase uid of the registered worker (links the app account to this
    // technician record; lets us upsert instead of duplicating on re-sync).
    uid: {
        type: String,
        default: '',
        index: true,
    },
    email: {
        type: String,
        default: '',
    },
    name: {
        type: String,
        required: [true, 'Please provide a name'],
        maxlength: [100, 'Name cannot be more than 100 characters'],
    },
    city: {
        type: String,
        default: 'Cairo',
        enum: ['Cairo', 'Giza', 'Alexandria', 'Luxor', 'Aswan', 'Mansoura', 'Tanta', 'Port Said', 'Suez', 'Ismailia', 'Faiyum', 'Zagazig', 'Damietta', 'Minya', 'Beni Suef', 'Sohag', 'Hurghada', 'Sharm El Sheikh', '6th of October', 'New Cairo'],
    },
    phone: {
        type: String,
        default: '',
    },
    category: {
        type: String,
        default: 'plumbing',
        enum: ['plumbing', 'electrical', 'carpentry', 'painting', 'hvac', 'cleaning', 'appliance_repair', 'welding', 'tiling'],
    },
    // Approximate technician location, used for nearest-technician matching.
    latitude: {
        type: Number,
        default: 0,
    },
    longitude: {
        type: Number,
        default: 0,
    },
    categories: {
        type: [String],
        default: [],
    },
    verificationStatus: {
        type: String,
        enum: ['pending', 'verified', 'rejected'],
        default: 'pending',
    },
    rating: {
        type: Number,
        min: 0,
        max: 5,
        default: 0,
    },
    isVerified: {
        type: Boolean,
        default: false,
    },
    issuesResolved: {
        type: Number,
        default: 0,
    },
    // In-app wallet (Stage 5). Credited with the worker payout when a job's
    // payment settles; debited on withdrawal. No real money — an internal
    // ledger that makes the money flow visible end-to-end. See lib/ledger.js.
    walletBalance: {
        type: Number,
        default: 0,
    },
    totalEarned: {
        type: Number,
        default: 0,
    },
    specialization: {
        type: String,
        default: '',
    },
    // National ID images uploaded at registration (Firebase Storage URLs).
    // The admin reviews these before flipping verificationStatus to 'verified'.
    nationalIdFrontUrl: {
        type: String,
        default: '',
    },
    nationalIdBackUrl: {
        type: String,
        default: '',
    },
    createdAt: {
        type: Date,
        default: Date.now,
    },
});

TechnicianSchema.index({ city: 1 });
TechnicianSchema.index({ category: 1 });
TechnicianSchema.index({ isVerified: 1 });
TechnicianSchema.index({ rating: -1 });
TechnicianSchema.index({ name: 'text' });

export default mongoose.models.Technician || mongoose.model('Technician', TechnicianSchema);
