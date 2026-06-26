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
    status: String, customerName: String, customerEmail: String,
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

// ─── Data Constants ────────────────────────────────────────
const firstNames = [
    'Ahmed', 'Mohamed', 'Mahmoud', 'Ali', 'Hassan', 'Hussein', 'Omar', 'Khaled',
    'Ibrahim', 'Youssef', 'Mostafa', 'Amr', 'Tamer', 'Hossam', 'Sherif', 'Waleed',
    'Karim', 'Tarek', 'Samir', 'Nabil', 'Adel', 'Gamal', 'Ashraf', 'Essam',
    'Wael', 'Ramy', 'Hatem', 'Fathy', 'Magdy', 'Sayed', 'Hamdy', 'Emad',
    'Ayman', 'Hany', 'Ehab', 'Alaa', 'Reda', 'Sameh', 'Osama', 'Bassem',
    'Nour', 'Hazem', 'Hesham', 'Marwan', 'Ziad', 'Abdallah', 'Seif', 'Yasser',
];

const lastNames = [
    'El-Sayed', 'Hassan', 'Ibrahim', 'Mohamed', 'Ali', 'Mahmoud', 'Ahmed',
    'Abdel-Rahman', 'Abdel-Fattah', 'El-Din', 'El-Masry', 'El-Shamy', 'Badawy',
    'Farouk', 'Saleh', 'Mansour', 'Rizk', 'Hamza', 'Nour', 'El-Husseiny',
    'Gaber', 'Osman', 'Ismail', 'Abou-Zeid', 'El-Naggar', 'Shehata', 'Haroun',
    'Soliman', 'El-Banna', 'Zaki', 'Helal', 'Barakat', 'El-Gohary', 'Fawzy',
];

const cities = [
    'Cairo', 'Giza', 'Alexandria', 'Luxor', 'Aswan', 'Mansoura', 'Tanta',
    'Port Said', 'Suez', 'Ismailia', 'Faiyum', 'Zagazig', 'Damietta',
    'Minya', 'Beni Suef', 'Sohag', 'Hurghada', 'Sharm El Sheikh',
    '6th of October', 'New Cairo',
];

const plumbingSpecs = [
    'Pipe Repair', 'Drain Cleaning', 'Water Heater', 'Toilet Repair',
    'Leak Detection', 'Sewer Line', 'Faucet Installation', 'Bathroom Renovation',
    'Kitchen Plumbing', 'Emergency Plumbing', 'Water Filtration', 'Gas Line Repair',
];
const electricalSpecs = [
    'Wiring', 'Panel Upgrade', 'Lighting Installation', 'Generator Repair',
    'Circuit Breaker', 'Outlet Installation', 'Ceiling Fan', 'Smart Home',
    'Electrical Inspection', 'Emergency Electrical', 'Solar Panel', 'EV Charger',
];
const carpentrySpecs = [
    'Door Repair', 'Window Installation', 'Cabinet Making', 'Furniture Assembly',
    'Wood Flooring', 'Deck Building', 'Shelving', 'Crown Molding',
    'Wood Restoration', 'Custom Carpentry', 'Staircase Repair', 'Fence Building',
];
const paintingSpecs = [
    'Interior Painting', 'Exterior Painting', 'Wall Texturing', 'Wallpaper Installation',
    'Cabinet Refinishing', 'Deck Staining', 'Epoxy Flooring', 'Spray Painting',
    'Mural Art', 'Drywall Patching', 'Trim Painting', 'Ceiling Painting',
];
const hvacSpecs = [
    'AC Repair', 'AC Installation', 'Heating System', 'Duct Cleaning',
    'Thermostat Setup', 'Refrigerant Recharge', 'Heat Pump Repair', 'Ventilation',
    'Central Air Maintenance', 'Mini Split Install', 'Furnace Repair', 'Air Quality',
];
const cleaningSpecs = [
    'Deep Cleaning', 'Move-in Cleaning', 'Post-Construction', 'Carpet Cleaning',
    'Window Washing', 'Pressure Washing', 'Upholstery Cleaning', 'Tile & Grout',
    'Office Cleaning', 'Kitchen Degreasing', 'Bathroom Sanitization', 'Floor Polishing',
];
const applianceRepairSpecs = [
    'Washing Machine', 'Refrigerator Repair', 'Oven Repair', 'Dishwasher Fix',
    'Dryer Repair', 'Microwave Repair', 'AC Unit Service', 'Water Heater',
    'Garbage Disposal', 'Range Hood', 'Ice Maker Repair', 'Freezer Repair',
];
const weldingSpecs = [
    'MIG Welding', 'TIG Welding', 'Arc Welding', 'Pipe Welding',
    'Custom Fabrication', 'Gate Welding', 'Staircase Railing', 'Iron Door',
    'Steel Structure', 'Window Grill', 'Balcony Railing', 'Exhaust Welding',
];
const tilingSpecs = [
    'Floor Tiling', 'Wall Tiling', 'Bathroom Tiling', 'Kitchen Backsplash',
    'Mosaic Installation', 'Marble Flooring', 'Granite Countertop', 'Outdoor Paving',
    'Pool Tiling', 'Staircase Tiling', 'Waterproofing', 'Tile Restoration',
];

const issueTitles = {
    plumbing: [
        'Leaking kitchen faucet', 'Clogged bathroom drain', 'Broken water heater',
        'Toilet not flushing properly', 'Burst pipe in wall', 'Low water pressure',
        'Sewage backup in basement', 'Dripping shower head', 'Water tank overflow',
        'Frozen pipes emergency', 'Garbage disposal jammed', 'Running toilet',
        'Washing machine leak', 'Sump pump failure', 'Bathtub won\'t drain',
        'Water softener malfunction', 'Backflow preventer broken', 'Slab leak detected',
        'Replace corroded pipes', 'Water meter running constantly',
    ],
    electrical: [
        'Power outage in living room', 'Sparking outlet', 'Faulty circuit breaker',
        'Flickering lights throughout house', 'No power to kitchen appliances',
        'Ceiling fan not working', 'Electrical panel buzzing', 'Outdoor lights dead',
        'AC unit tripping breaker', 'Smart home system malfunction',
        'GFCI outlet won\'t reset', 'Burning smell from outlet', 'Doorbell not working',
        'Recessed lighting installation', 'Surge protector needed', 'Home theatre wiring',
        'Electric stove not heating', 'Outlet has no ground', 'Main breaker keeps tripping',
        'Emergency generator installation',
    ],
    carpentry: [
        'Broken front door hinge', 'Kitchen cabinet door fell off', 'Cracked window frame',
        'Warped wooden floor', 'Damaged staircase railing', 'Built-in shelf collapsed',
        'Bathroom door won\'t close', 'Fence panel blown over', 'Deck boards rotting',
        'Custom bookshelf installation', 'Wardrobe door misaligned', 'Pergola construction',
    ],
    painting: [
        'Living room needs repainting', 'Exterior paint peeling', 'Water stains on ceiling',
        'Wallpaper removal needed', 'Kitchen cabinets need refinishing', 'Deck needs staining',
        'Garage floor epoxy coating', 'Mold damage on walls', 'Bathroom paint chipping',
        'New apartment full painting job', 'Fence needs painting', 'Balcony railing touch-up',
    ],
    hvac: [
        'AC not cooling properly', 'Heater making loud noise', 'Thermostat not responding',
        'AC leaking water inside', 'Central air not turning on', 'Ductwork needs cleaning',
        'Heat pump frozen over', 'Bad smell from AC vents', 'Mini split installation',
        'AC compressor failure', 'Furnace pilot light out', 'Ventilation fan broken',
    ],
    cleaning: [
        'Deep clean after renovation', 'Move-out cleaning needed', 'Kitchen grease buildup',
        'Mold in bathroom needs treatment', 'Carpet stains won\'t come out', 'Window cleaning 5th floor',
        'Office space weekly cleaning', 'Post-party cleanup needed', 'Tiles need scrubbing',
        'Pressure wash driveway', 'Upholstery cleaning sofa set', 'Dust and allergen removal',
    ],
    appliance_repair: [
        'Washing machine not spinning', 'Refrigerator not cooling', 'Oven temperature wrong',
        'Dishwasher leaking from bottom', 'Dryer takes too long', 'Microwave sparking inside',
        'Water heater no hot water', 'Ice maker stopped working', 'Range hood fan broken',
        'Freezer icing up excessively', 'Garbage disposal jammed', 'Coffee machine broken',
    ],
    welding: [
        'Iron gate hinge broken', 'Staircase railing detached', 'Metal door frame cracked',
        'Balcony railing needs welding', 'Window grill came off', 'Custom metal shelf needed',
        'Car exhaust pipe broken', 'Metal fence panel repair', 'Steel door installation',
        'Overhead metal structure', 'Custom window frame', 'Security bar installation',
    ],
    tiling: [
        'Bathroom floor tiles cracked', 'Kitchen backsplash falling off', 'Loose floor tiles',
        'Marble countertop chipped', 'Outdoor patio tiling needed', 'Pool tiles peeling',
        'Shower wall tiles broken', 'Staircase tiling upgrade', 'Mosaic accent wall install',
        'Waterproofing under tiles failed', 'Grout between tiles crumbling', 'New apartment floor tiling',
    ],
};

const issueDescriptions = [
    'This has been an ongoing issue for the past week. Needs urgent attention.',
    'The problem started suddenly and is getting worse every day.',
    'We noticed this issue after the recent renovation work.',
    'This is affecting our daily routine and needs to be fixed ASAP.',
    'We\'ve tried temporary fixes but need a professional solution.',
    'The issue is intermittent but increasingly frequent.',
    'Safety concern - please prioritize this repair.',
    'This was reported by the tenant and needs immediate resolution.',
];

const addresses = [
    '15 El-Tahrir St, Downtown', '42 Nile Corniche Road', '8 Ahmed Orabi St',
    '23 El-Mohandessin, Arab League St', '56 Nasr City, Abbas El-Akkad St',
    '31 Heliopolis, El-Mirghani St', '72 Maadi, Road 9', '19 Zamalek, 26th July St',
    '44 Dokki, Mesaha Square', '67 New Cairo, 90th Street',
];

function randomItem(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function generatePhone() {
    const prefix = ['010', '011', '012', '015'][Math.floor(Math.random() * 4)];
    return `+2${prefix}${Math.floor(10000000 + Math.random() * 90000000).toString().substring(0, 8)}`;
}

// ─── Generators ────────────────────────────────────────────
function generateTechnician() {
    const categories = ['plumbing', 'electrical', 'carpentry', 'painting', 'hvac', 'cleaning', 'appliance_repair', 'welding', 'tiling'];
    const category = randomItem(categories);
    const specMap = {
        plumbing: plumbingSpecs, electrical: electricalSpecs, carpentry: carpentrySpecs,
        painting: paintingSpecs, hvac: hvacSpecs, cleaning: cleaningSpecs,
        appliance_repair: applianceRepairSpecs, welding: weldingSpecs, tiling: tilingSpecs,
    };
    const specs = specMap[category];
    const now = new Date();
    const monthsAgo = Math.floor(Math.random() * 24);
    const day = Math.floor(1 + Math.random() * 28);
    return {
        name: `${randomItem(firstNames)} ${randomItem(lastNames)}`,
        city: randomItem(cities),
        phone: generatePhone(),
        category,
        rating: parseFloat((1 + Math.random() * 4).toFixed(1)),
        isVerified: Math.random() > 0.35,
        issuesResolved: Math.floor(Math.random() * 500),
        specialization: randomItem(specs),
        createdAt: new Date(now.getFullYear(), now.getMonth() - monthsAgo, day),
    };
}

function generateIssue() {
    const categories = ['plumbing', 'electrical', 'carpentry', 'painting', 'hvac', 'cleaning', 'appliance_repair', 'welding', 'tiling'];
    const category = randomItem(categories);
    const urgencies = ['low', 'medium', 'high', 'emergency'];
    const urgencyWeights = [0.2, 0.4, 0.3, 0.1];
    const urgRand = Math.random();
    let urgency = 'medium';
    let cumulative = 0;
    for (let i = 0; i < urgencies.length; i++) {
        cumulative += urgencyWeights[i];
        if (urgRand < cumulative) { urgency = urgencies[i]; break; }
    }
    const statuses = ['pending', 'assigned', 'inProgress', 'completed', 'cancelled'];
    const statusWeights = [0.25, 0.15, 0.2, 0.3, 0.1];
    const stRand = Math.random();
    let status = 'pending';
    cumulative = 0;
    for (let i = 0; i < statuses.length; i++) {
        cumulative += statusWeights[i];
        if (stRand < cumulative) { status = statuses[i]; break; }
    }

    const customerFirst = randomItem(firstNames);
    const customerLast = randomItem(lastNames);
    const now = new Date();
    const daysAgo = Math.floor(Math.random() * 90);
    const created = new Date(now - daysAgo * 86400000);
    const techName = `${randomItem(firstNames)} ${randomItem(lastNames)}`;

    return {
        title: randomItem(issueTitles[category]),
        description: randomItem(issueDescriptions),
        category,
        urgency,
        status,
        customerName: `${customerFirst} ${customerLast}`,
        customerEmail: `${customerFirst.toLowerCase()}.${customerLast.toLowerCase().replace(/[^a-z]/g, '')}@email.com`,
        customerPhone: generatePhone(),
        assignedTechnicianName: ['assigned', 'inProgress', 'completed'].includes(status) ? techName : '',
        address: randomItem(addresses),
        city: randomItem(cities),
        latitude: 29.9 + Math.random() * 1.2,
        longitude: 31.1 + Math.random() * 0.8,
        estimatedCost: Math.floor(100 + Math.random() * 2000),
        createdAt: created,
        updatedAt: new Date(created.getTime() + Math.random() * daysAgo * 86400000),
    };
}

function generateUser() {
    const firstName = randomItem(firstNames);
    const lastName = randomItem(lastNames);
    const role = Math.random() > 0.4 ? 'customer' : 'worker';
    const skills = role === 'worker'
        ? (() => {
            const allSkills = ['plumbing', 'electrical', 'carpentry', 'painting', 'hvac', 'cleaning', 'appliance_repair', 'welding', 'tiling'];
            const n = 1 + Math.floor(Math.random() * 2);
            const shuffled = allSkills.sort(() => 0.5 - Math.random());
            return shuffled.slice(0, n);
        })()
        : [];
    const now = new Date();
    const daysAgo = Math.floor(Math.random() * 365);
    return {
        name: `${firstName} ${lastName}`,
        email: `${firstName.toLowerCase()}.${lastName.toLowerCase().replace(/[^a-z]/g, '')}${Math.floor(Math.random() * 999)}@email.com`,
        phone: generatePhone(),
        role,
        skills,
        city: randomItem(cities),
        address: randomItem(addresses),
        isVerified: Math.random() > 0.3,
        isActive: Math.random() > 0.1,
        issuesReported: role === 'customer' ? Math.floor(Math.random() * 20) : 0,
        issuesCompleted: role === 'worker' ? Math.floor(Math.random() * 50) : 0,
        createdAt: new Date(now - daysAgo * 86400000),
    };
}

// ─── Seed ──────────────────────────────────────────────────
async function seed() {
    console.log('🔌 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected to MongoDB');

    // Technicians
    console.log('🗑️  Clearing technicians...');
    await Technician.deleteMany({});
    const TECH_COUNT = 500;
    console.log(`📦 Seeding ${TECH_COUNT} technicians...`);
    await Technician.insertMany(Array.from({ length: TECH_COUNT }, generateTechnician));
    console.log('✅ Technicians seeded!');

    // Issues
    console.log('🗑️  Clearing issues...');
    await Issue.deleteMany({});
    const ISSUE_COUNT = 2000;
    console.log(`📦 Seeding ${ISSUE_COUNT} issues...`);
    await Issue.insertMany(Array.from({ length: ISSUE_COUNT }, generateIssue));
    console.log('✅ Issues seeded!');

    // Users
    console.log('🗑️  Clearing users...');
    await User.deleteMany({});
    const USER_COUNT = 500;
    console.log(`📦 Seeding ${USER_COUNT} users...`);
    await User.insertMany(Array.from({ length: USER_COUNT }, generateUser));
    console.log('✅ Users seeded!');

    // Summary
    const [techCount, issueCount, userCount] = await Promise.all([
        Technician.countDocuments(), Issue.countDocuments(), User.countDocuments(),
    ]);
    console.log(`\n📊 Final counts:`);
    console.log(`   Technicians: ${techCount.toLocaleString()}`);
    console.log(`   Issues: ${issueCount.toLocaleString()}`);
    console.log(`   Users: ${userCount.toLocaleString()}`);

    await mongoose.disconnect();
    console.log('🔌 Disconnected from MongoDB');
}

seed().catch((err) => { console.error('❌ Seed error:', err); process.exit(1); });
