const mongoose = require('mongoose');
require('dotenv').config({ path: '.env.local' });

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/smartfix';

// ─── Schemas ───────────────────────────────────────────────
const TechnicianSchema = new mongoose.Schema({
    name: String, city: String, phone: String, category: String,
    rating: Number, isVerified: Boolean, issuesResolved: Number,
    specialization: String, createdAt: Date,
});
const IssueSchema = new mongoose.Schema({
    title: String, description: String, category: String, urgency: String,
    status: String, customerId: String, customerName: String, customerEmail: String,
    customerPhone: String, assignedTechnicianId: mongoose.Schema.Types.ObjectId,
    assignedTechnicianName: String, address: String, city: String,
    latitude: Number, longitude: Number, estimatedCost: Number,
    photoUrls: [String], createdAt: Date, updatedAt: Date,
});
const UserSchema = new mongoose.Schema({
    name: String, email: String, phone: String, role: String,
    skills: [String], city: String, address: String, profileImageUrl: String,
    isVerified: Boolean, isActive: Boolean, issuesReported: Number,
    issuesCompleted: Number, createdAt: Date,
});

const Technician = mongoose.model('Technician', TechnicianSchema);
const Issue = mongoose.model('Issue', IssueSchema);
const User = mongoose.model('User', UserSchema);

// ─── Sample Data ───────────────────────────────────────────

const technicians = [
    { name: 'Ahmed Hassan', city: 'Cairo', phone: '+201012345678', category: 'plumbing', rating: 4.8, isVerified: true, issuesResolved: 12, specialization: 'Pipe Repair', createdAt: new Date('2025-11-15') },
    { name: 'Mohamed Ali', city: 'Giza', phone: '+201123456789', category: 'electrical', rating: 4.5, isVerified: true, issuesResolved: 9, specialization: 'Wiring', createdAt: new Date('2025-12-01') },
    { name: 'Khaled Ibrahim', city: 'Cairo', phone: '+201234567890', category: 'carpentry', rating: 4.2, isVerified: false, issuesResolved: 5, specialization: 'Door Repair', createdAt: new Date('2026-01-10') },
    { name: 'Omar Mahmoud', city: 'Alexandria', phone: '+201098765432', category: 'painting', rating: 4.7, isVerified: true, issuesResolved: 8, specialization: 'Interior Painting', createdAt: new Date('2025-10-20') },
    { name: 'Youssef Samir', city: 'New Cairo', phone: '+201187654321', category: 'hvac', rating: 3.9, isVerified: true, issuesResolved: 6, specialization: 'AC Repair', createdAt: new Date('2026-01-05') },
    { name: 'Mahmoud Tarek', city: 'Cairo', phone: '+201276543210', category: 'cleaning', rating: 4.1, isVerified: false, issuesResolved: 3, specialization: 'Deep Cleaning', createdAt: new Date('2026-02-01') },
    { name: 'Hassan Adel', city: '6th of October', phone: '+201567890123', category: 'appliance_repair', rating: 4.6, isVerified: true, issuesResolved: 10, specialization: 'Washing Machine', createdAt: new Date('2025-09-15') },
    { name: 'Amr Nabil', city: 'Giza', phone: '+201098761234', category: 'welding', rating: 4.3, isVerified: true, issuesResolved: 7, specialization: 'Gate Welding', createdAt: new Date('2025-11-01') },
    { name: 'Ibrahim Fathy', city: 'Mansoura', phone: '+201112345678', category: 'tiling', rating: 4.4, isVerified: false, issuesResolved: 4, specialization: 'Floor Tiling', createdAt: new Date('2026-01-20') },
];

const users = [
    { name: 'Seif El-Din', email: 'seif@email.com', phone: '+201011111111', role: 'customer', skills: [], city: 'Cairo', address: '15 El-Tahrir St, Downtown', isVerified: true, isActive: true, issuesReported: 3, issuesCompleted: 0, createdAt: new Date('2026-01-01') },
    { name: 'Waleed Sherif', email: 'waleed@email.com', phone: '+201022222222', role: 'customer', skills: [], city: 'Giza', address: '42 Nile Corniche Road', isVerified: true, isActive: true, issuesReported: 2, issuesCompleted: 0, createdAt: new Date('2026-01-15') },
    { name: 'Tamer Hossam', email: 'tamer@email.com', phone: '+201033333333', role: 'customer', skills: [], city: 'New Cairo', address: '67 New Cairo, 90th Street', isVerified: true, isActive: true, issuesReported: 1, issuesCompleted: 0, createdAt: new Date('2026-02-01') },
    { name: 'Ahmed Hassan', email: 'ahmed.w@email.com', phone: '+201044444444', role: 'worker', skills: ['plumbing', 'hvac'], city: 'Cairo', address: '8 Ahmed Orabi St', isVerified: true, isActive: true, issuesReported: 0, issuesCompleted: 5, createdAt: new Date('2025-11-15') },
    { name: 'Mohamed Ali', email: 'mohamed.w@email.com', phone: '+201055555555', role: 'worker', skills: ['electrical'], city: 'Giza', address: '23 El-Mohandessin, Arab League St', isVerified: true, isActive: true, issuesReported: 0, issuesCompleted: 3, createdAt: new Date('2025-12-01') },
    { name: 'Karim Essam', email: 'karim.w@email.com', phone: '+201066666666', role: 'worker', skills: ['carpentry', 'painting'], city: 'Cairo', address: '44 Dokki, Mesaha Square', isVerified: false, isActive: true, issuesReported: 0, issuesCompleted: 2, createdAt: new Date('2026-01-10') },
];

const now = new Date();

const issues = [
    { title: 'Leaking kitchen faucet', description: 'The kitchen faucet has been leaking for two days. Water dripping constantly.', category: 'plumbing', urgency: 'high', status: 'completed', customerName: 'Seif El-Din', customerEmail: 'seif@email.com', customerPhone: '+201011111111', assignedTechnicianName: 'Ahmed Hassan', address: '15 El-Tahrir St, Downtown', city: 'Cairo', latitude: 30.0444, longitude: 31.2357, estimatedCost: 350, createdAt: new Date('2026-02-10'), updatedAt: new Date('2026-02-12') },
    { title: 'Power outage in living room', description: 'No electricity in the living room. All other rooms have power.', category: 'electrical', urgency: 'emergency', status: 'completed', customerName: 'Seif El-Din', customerEmail: 'seif@email.com', customerPhone: '+201011111111', assignedTechnicianName: 'Mohamed Ali', address: '15 El-Tahrir St, Downtown', city: 'Cairo', latitude: 30.0444, longitude: 31.2357, estimatedCost: 500, createdAt: new Date('2026-02-15'), updatedAt: new Date('2026-02-16') },
    { title: 'Broken front door hinge', description: 'The front door hinge snapped. Door cannot close properly.', category: 'carpentry', urgency: 'medium', status: 'inProgress', customerName: 'Seif El-Din', customerEmail: 'seif@email.com', customerPhone: '+201011111111', assignedTechnicianName: 'Khaled Ibrahim', address: '15 El-Tahrir St, Downtown', city: 'Cairo', latitude: 30.0444, longitude: 31.2357, estimatedCost: 200, createdAt: new Date('2026-02-20'), updatedAt: new Date('2026-02-22') },
    { title: 'AC not cooling properly', description: 'The air conditioner runs but blows warm air. Needs inspection.', category: 'hvac', urgency: 'high', status: 'assigned', customerName: 'Waleed Sherif', customerEmail: 'waleed@email.com', customerPhone: '+201022222222', assignedTechnicianName: 'Youssef Samir', address: '42 Nile Corniche Road', city: 'Giza', latitude: 30.0131, longitude: 31.2089, estimatedCost: 600, createdAt: new Date('2026-02-21'), updatedAt: new Date('2026-02-22') },
    { title: 'Living room needs repainting', description: 'Paint peeling off walls in the living room. Full repaint needed.', category: 'painting', urgency: 'low', status: 'pending', customerName: 'Waleed Sherif', customerEmail: 'waleed@email.com', customerPhone: '+201022222222', assignedTechnicianName: '', address: '42 Nile Corniche Road', city: 'Giza', latitude: 30.0131, longitude: 31.2089, estimatedCost: 1200, createdAt: new Date('2026-02-23'), updatedAt: new Date('2026-02-23') },
    { title: 'Washing machine not spinning', description: 'The washing machine fills with water but the drum doesn\'t spin.', category: 'appliance_repair', urgency: 'medium', status: 'pending', customerName: 'Tamer Hossam', customerEmail: 'tamer@email.com', customerPhone: '+201033333333', assignedTechnicianName: '', address: '67 New Cairo, 90th Street', city: 'New Cairo', latitude: 30.0300, longitude: 31.4700, estimatedCost: 450, createdAt: new Date('2026-02-24'), updatedAt: new Date('2026-02-24') },
    { title: 'Clogged bathroom drain', description: 'Bathroom drain is completely clogged. Water not draining at all.', category: 'plumbing', urgency: 'high', status: 'completed', customerName: 'Waleed Sherif', customerEmail: 'waleed@email.com', customerPhone: '+201022222222', assignedTechnicianName: 'Ahmed Hassan', address: '42 Nile Corniche Road', city: 'Giza', latitude: 30.0131, longitude: 31.2089, estimatedCost: 250, createdAt: new Date('2026-02-05'), updatedAt: new Date('2026-02-06') },
    { title: 'Iron gate hinge broken', description: 'The main iron gate hinge is cracked and the gate won\'t close.', category: 'welding', urgency: 'medium', status: 'inProgress', customerName: 'Seif El-Din', customerEmail: 'seif@email.com', customerPhone: '+201011111111', assignedTechnicianName: 'Amr Nabil', address: '15 El-Tahrir St, Downtown', city: 'Cairo', latitude: 30.0444, longitude: 31.2357, estimatedCost: 400, createdAt: new Date('2026-02-18'), updatedAt: new Date('2026-02-20') },
    { title: 'Bathroom floor tiles cracked', description: 'Several tiles in the bathroom are cracked and need replacement.', category: 'tiling', urgency: 'low', status: 'pending', customerName: 'Tamer Hossam', customerEmail: 'tamer@email.com', customerPhone: '+201033333333', assignedTechnicianName: '', address: '67 New Cairo, 90th Street', city: 'New Cairo', latitude: 30.0300, longitude: 31.4700, estimatedCost: 800, createdAt: new Date('2026-02-22'), updatedAt: new Date('2026-02-22') },
    { title: 'Deep clean after renovation', description: 'Full apartment deep cleaning needed after construction work.', category: 'cleaning', urgency: 'medium', status: 'cancelled', customerName: 'Waleed Sherif', customerEmail: 'waleed@email.com', customerPhone: '+201022222222', assignedTechnicianName: '', address: '42 Nile Corniche Road', city: 'Giza', latitude: 30.0131, longitude: 31.2089, estimatedCost: 700, createdAt: new Date('2026-02-08'), updatedAt: new Date('2026-02-09') },
];

// ─── Seed ──────────────────────────────────────────────────
async function seed() {
    console.log('🔌 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected to MongoDB');

    console.log('🗑️  Clearing all existing data...');
    await Technician.deleteMany({});
    await Issue.deleteMany({});
    await User.deleteMany({});

    console.log('📦 Inserting sample technicians...');
    await Technician.insertMany(technicians);

    console.log('📦 Inserting sample users...');
    await User.insertMany(users);

    console.log('📦 Inserting sample issues...');
    await Issue.insertMany(issues);

    console.log('\n📊 Sample data loaded:');
    console.log(`   Technicians: ${technicians.length}`);
    console.log(`   Users: ${users.length}`);
    console.log(`   Issues: ${issues.length}`);
    console.log('\n✅ Done! Dashboard ready with sample data.');

    await mongoose.disconnect();
}

seed().catch((err) => { console.error('❌ Error:', err); process.exit(1); });
