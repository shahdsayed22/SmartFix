/**
 * Light reseed — inserts a SMALL, realistic dataset into MongoDB so the
 * dashboard looks alive for a demo/defense without the heavy 3k-doc seed.
 * Safe to run after scripts/wipe-demo.mjs. Re-running clears these first
 * (matched by the `seed: 'light'` marker) so it stays idempotent.
 *
 * Usage:
 *   node --env-file=.env.local scripts/seed-light.mjs
 */
import { MongoClient } from 'mongodb';

const uri = process.env.MONGODB_URI;
if (!uri) {
  console.error('✖ MONGODB_URI not set. Run with: node --env-file=.env.local scripts/seed-light.mjs');
  process.exit(1);
}

const now = new Date();
const daysAgo = (n) => new Date(now.getTime() - n * 86400000);

const users = [
  { name: 'Mariam Hassan', email: 'mariam.hassan@example.com', phone: '+201001234567', role: 'customer', city: 'Cairo', isVerified: true, isActive: true, skills: [], seed: 'light', createdAt: daysAgo(20) },
  { name: 'Omar Khaled', email: 'omar.khaled@example.com', phone: '+201112223344', role: 'customer', city: 'Giza', isVerified: true, isActive: true, skills: [], seed: 'light', createdAt: daysAgo(12) },
  { name: 'Youssef Adel', email: 'youssef.adel@example.com', phone: '+201224445566', role: 'worker', city: 'Cairo', isVerified: true, isActive: true, skills: ['plumbing', 'hvac'], seed: 'light', createdAt: daysAgo(30) },
  { name: 'Karim Nabil', email: 'karim.nabil@example.com', phone: '+201229998877', role: 'worker', city: 'Giza', isVerified: false, isActive: true, skills: ['electrical'], seed: 'light', createdAt: daysAgo(4) },
];

const technicians = [
  { name: 'Youssef Adel', email: 'youssef.adel@example.com', phone: '+201224445566', city: 'Cairo', category: 'plumbing', categories: ['plumbing', 'hvac'], rating: 4.8, isVerified: true, verificationStatus: 'verified', issuesResolved: 37, specialization: 'Pipe & Leak Repair', seed: 'light', createdAt: daysAgo(30) },
  { name: 'Karim Nabil', email: 'karim.nabil@example.com', phone: '+201229998877', city: 'Giza', category: 'electrical', categories: ['electrical'], rating: 0, isVerified: false, verificationStatus: 'pending', issuesResolved: 0, specialization: 'Smart Home Wiring', seed: 'light', createdAt: daysAgo(4) },
];

const issues = [
  { title: 'Leaking kitchen faucet', category: 'plumbing', urgency: 'high', status: 'completed', customerName: 'Mariam Hassan', customerEmail: 'mariam.hassan@example.com', assignedTechnicianName: 'Youssef Adel', city: 'Cairo', estimatedCost: 350, address: 'Nasr City, Cairo', description: 'Kitchen faucet leaking at the base.', seed: 'light', createdAt: daysAgo(8) },
  { title: 'Power outage in living room', category: 'electrical', urgency: 'emergency', status: 'pending', customerName: 'Omar Khaled', customerEmail: 'omar.khaled@example.com', assignedTechnicianName: '', city: 'Giza', estimatedCost: 500, address: 'Dokki, Giza', description: 'No power in the living room circuit.', seed: 'light', createdAt: daysAgo(1) },
  { title: 'AC not cooling', category: 'hvac', urgency: 'medium', status: 'assigned', customerName: 'Mariam Hassan', customerEmail: 'mariam.hassan@example.com', assignedTechnicianName: 'Youssef Adel', city: 'Cairo', estimatedCost: 600, address: 'Nasr City, Cairo', description: 'Split AC blowing warm air.', seed: 'light', createdAt: daysAgo(2) },
];

const client = new MongoClient(uri);
try {
  await client.connect();
  const db = client.db();
  for (const [coll, docs] of [['users', users], ['technicians', technicians], ['issues', issues]]) {
    await db.collection(coll).deleteMany({ seed: 'light' });
    if (docs.length) await db.collection(coll).insertMany(docs);
    console.log(`  + ${coll}: inserted ${docs.length}`);
  }
  console.log('\n✅ Light seed done. Dashboard now shows a small realistic dataset.\n');
} finally {
  await client.close();
}
