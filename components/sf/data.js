/* ============================================================
   SmartFix — sample dataset + derived analytics
   Egypt region. Internally consistent so charts/tables agree.
   ============================================================ */
const CATEGORY_CONFIG = {
  plumbing:         { label: 'Plumbing',         icon: 'Wrench',     color: '#3b82f6' },
  electrical:       { label: 'Electrical',       icon: 'Zap',        color: '#f59e0b' },
  carpentry:        { label: 'Carpentry',        icon: 'Hammer',     color: '#10b981' },
  painting:         { label: 'Painting',         icon: 'Paintbrush', color: '#a855f7' },
  hvac:             { label: 'HVAC',             icon: 'Wind',       color: '#06b6d4' },
  cleaning:         { label: 'Cleaning',         icon: 'SprayCan',   color: '#ec4899' },
  appliance_repair: { label: 'Appliance Repair', icon: 'Settings',   color: '#f97316' },
  welding:          { label: 'Welding',          icon: 'Flame',      color: '#ef4444' },
  tiling:           { label: 'Tiling',           icon: 'Grid3x3',    color: '#14b8a6' },
};
const CATEGORIES = Object.keys(CATEGORY_CONFIG);
const CITIES = ['Cairo', 'Giza', 'Alexandria', 'New Cairo', '6th of October', 'Nasr City', 'Heliopolis', 'Maadi', 'Mansoura', 'Zamalek'];

const STATUS_CONFIG = {
  pending:           { label: 'Pending',            color: '#f59e0b' },
  offered:           { label: 'Offered',            color: '#8b5cf6' },
  assigned:          { label: 'Assigned',           color: '#6366f1' },
  inProgress:        { label: 'In Progress',        color: '#22d3ee' },
  awaitingApproval:  { label: 'Awaiting Approval',  color: '#7A5AE0' },
  awaitingPayment:   { label: 'Awaiting Payment',   color: '#0ea5e9' },
  completed:         { label: 'Completed',          color: '#10b981' },
  disputed:          { label: 'Disputed',           color: '#f97316' },
  rejected:          { label: 'Rejected',           color: '#dc2626' },
  cancelled:         { label: 'Cancelled',          color: '#ef4444' },
};
const TICKET_STATUS_CONFIG = {
  open:     { label: 'Open',     color: '#3b82f6' },
  pending:  { label: 'Pending',  color: '#f59e0b' },
  resolved: { label: 'Resolved', color: '#10b981' },
  closed:   { label: 'Closed',   color: '#64748b' },
};
const PAYMENT_STATUS_CONFIG = {
  pending:  { label: 'Pending',  color: '#f59e0b' },
  paid:     { label: 'Paid',     color: '#10b981' },
  failed:   { label: 'Failed',   color: '#ef4444' },
  refunded: { label: 'Refunded', color: '#a855f7' },
};
const TICKET_PRIORITY_CONFIG = {
  low:    { label: 'Low',    color: '#64748b' },
  medium: { label: 'Medium', color: '#3b82f6' },
  high:   { label: 'High',   color: '#ef4444' },
};
const URGENCY_CONFIG = {
  low:       { label: 'Low',       color: '#64748b' },
  medium:    { label: 'Medium',    color: '#3b82f6' },
  high:      { label: 'High',      color: '#f59e0b' },
  emergency: { label: 'Emergency', color: '#ef4444' },
};

// ── Technicians ──────────────────────────────────────────
const TECHNICIANS = [
  ['Ahmed Hassan','Cairo','plumbing',4.9,true,142,'Pipe & Leak Repair','2024-08-15'],
  ['Mohamed Ali','Giza','electrical',4.6,true,98,'Industrial Wiring','2024-09-01'],
  ['Khaled Ibrahim','Cairo','carpentry',4.2,false,41,'Door & Cabinet Repair','2025-01-10'],
  ['Omar Mahmoud','Alexandria','painting',4.8,true,87,'Interior Finishing','2024-07-20'],
  ['Youssef Samir','New Cairo','hvac',3.9,true,63,'AC Installation','2025-01-05'],
  ['Mahmoud Tarek','Cairo','cleaning',4.1,false,29,'Deep & Post-Build','2025-02-01'],
  ['Hassan Adel','6th of October','appliance_repair',4.7,true,110,'Washer & Dryer','2024-06-15'],
  ['Amr Nabil','Giza','welding',4.4,true,74,'Gate & Railing','2024-11-01'],
  ['Ibrahim Fathy','Mansoura','tiling',4.3,false,38,'Floor & Wall Tiling','2025-01-20'],
  ['Tarek Mostafa','Nasr City','electrical',4.5,true,81,'Smart Home Wiring','2024-10-12'],
  ['Mostafa Sayed','Heliopolis','plumbing',4.0,true,55,'Drainage Systems','2025-02-18'],
  ['Ali Gamal','Maadi','hvac',4.6,true,92,'Central Cooling','2024-09-22'],
  ['Sherif Fouad','Cairo','painting',3.7,false,22,'Exterior Coating','2025-03-02'],
  ['Nader Wahba','Alexandria','carpentry',4.9,true,131,'Custom Furniture','2024-05-30'],
  ['Hossam Eldin','Giza','appliance_repair',4.2,true,47,'Refrigeration','2025-01-14'],
  ['Walid Saad','New Cairo','welding',4.1,false,33,'Structural Welding','2025-02-25'],
  ['Ramy Naguib','Zamalek','tiling',4.7,true,69,'Marble & Granite','2024-10-05'],
  ['Sameh Lotfy','Cairo','cleaning',4.4,true,58,'Facade Cleaning','2024-12-11'],
  ['Karim Adel','6th of October','electrical',4.8,true,103,'Solar & Backup','2024-08-08'],
  ['Ashraf Zaki','Nasr City','plumbing',3.8,false,26,'Water Heaters','2025-03-09'],
  ['Magdy Sobhy','Maadi','hvac',4.5,true,79,'Ventilation','2024-11-19'],
  ['Tamer Shawky','Giza','carpentry',4.3,true,52,'Flooring & Decks','2025-01-28'],
  ['Yasser Kamal','Alexandria','painting',4.6,true,84,'Decorative Finish','2024-09-14'],
  ['Fady Boutros','Cairo','appliance_repair',4.9,true,121,'Smart Appliances','2024-06-02'],
].map((t, i) => ({
  _id: 'tech_' + (i + 1),
  name: t[0], city: t[1], category: t[2], rating: t[3], isVerified: t[4],
  issuesResolved: t[5], specialization: t[6], createdAt: t[7],
  phone: '+2010' + (10000000 + i * 813241).toString().slice(0, 8),
}));

// ── Issues ───────────────────────────────────────────────
const ISSUES = [
  ['Leaking kitchen faucet','plumbing','high','completed','Seif El-Din','Ahmed Hassan','Cairo','2026-06-02',350],
  ['Power outage in living room','electrical','emergency','inProgress','Seif El-Din','Mohamed Ali','Cairo','2026-06-10',500],
  ['Broken front door hinge','carpentry','medium','assigned','Waleed Sherif','Khaled Ibrahim','Cairo','2026-06-09',200],
  ['AC not cooling — warm air','hvac','high','assigned','Waleed Sherif','Youssef Samir','Giza','2026-06-08',600],
  ['Living room needs repainting','painting','low','pending','Tamer Hossam','','Giza','2026-06-11',1200],
  ['Washing machine not spinning','appliance_repair','medium','pending','Tamer Hossam','','New Cairo','2026-06-11',450],
  ['Clogged bathroom drain','plumbing','high','completed','Nour Adham','Ahmed Hassan','Giza','2026-05-28',250],
  ['Iron gate hinge broken','welding','medium','inProgress','Seif El-Din','Amr Nabil','Cairo','2026-06-05',400],
  ['Bathroom floor tiles cracked','tiling','low','pending','Yara Sami','','New Cairo','2026-06-07',800],
  ['Deep clean after renovation','cleaning','medium','cancelled','Waleed Sherif','','Giza','2026-05-30',700],
  ['Sparking electrical outlet','electrical','emergency','inProgress','Hana Maged','Karim Adel','6th of October','2026-06-11',300],
  ['Ceiling fan wobbling badly','electrical','medium','assigned','Mostafa Reda','Tarek Mostafa','Nasr City','2026-06-09',180],
  ['Burst pipe under sink','plumbing','emergency','completed','Laila Fawzy','Mostafa Sayed','Heliopolis','2026-06-01',650],
  ['Central AC maintenance','hvac','low','completed','Adham Salah','Ali Gamal','Maadi','2026-05-25',900],
  ['Wardrobe door off track','carpentry','low','pending','Yara Sami','','Alexandria','2026-06-10',150],
  ['Refrigerator not cooling','appliance_repair','high','assigned','Nour Adham','Hossam Eldin','Giza','2026-06-08',550],
  ['Balcony railing rusted','welding','medium','inProgress','Hana Maged','Walid Saad','New Cairo','2026-06-04',420],
  ['Kitchen backsplash retiling','tiling','low','completed','Mostafa Reda','Ramy Naguib','Zamalek','2026-05-22',1100],
  ['Apartment move-out cleaning','cleaning','medium','assigned','Laila Fawzy','Sameh Lotfy','Cairo','2026-06-09',600],
  ['Exterior wall repaint','painting','low','pending','Adham Salah','','Alexandria','2026-06-06',2200],
  ['Water heater no hot water','plumbing','high','assigned','Seif El-Din','Ashraf Zaki','Nasr City','2026-06-10',480],
  ['Bedroom AC drips water','hvac','medium','inProgress','Yara Sami','Magdy Sobhy','Maadi','2026-06-07',340],
  ['Custom bookshelf install','carpentry','low','completed','Nour Adham','Nader Wahba','Alexandria','2026-05-20',1800],
  ['Dishwasher leaking','appliance_repair','high','pending','Hana Maged','','Cairo','2026-06-11',520],
  ['Garden gate fabrication','welding','low','completed','Adham Salah','Amr Nabil','Giza','2026-05-18',1500],
  ['Living room floor tiling','tiling','medium','inProgress','Laila Fawzy','Ibrahim Fathy','Mansoura','2026-06-03',1300],
  ['Office deep cleaning','cleaning','high','completed','Mostafa Reda','Mahmoud Tarek','Cairo','2026-05-27',850],
  ['Smart lighting setup','electrical','low','pending','Tamer Hossam','','6th of October','2026-06-11',700],
].map((s, i) => ({
  _id: 'iss_' + (i + 1),
  title: s[0], category: s[1], urgency: s[2], status: s[3],
  customerName: s[4], assignedTechnicianName: s[5], city: s[6],
  createdAt: s[7], estimatedCost: s[8],
  customerEmail: s[4].toLowerCase().replace(/[^a-z]/g, '.') + '@email.com',
  customerPhone: '+2011' + (20000000 + i * 471829).toString().slice(0, 8),
  address: (10 + i) + ' ' + s[6] + ' District, Egypt',
  description: s[0] + '. Reported by customer; awaiting technician action and on-site assessment.',
}));

// ── Users ────────────────────────────────────────────────
const USERS = [
  ['Seif El-Din','customer','Cairo',true,[]],
  ['Waleed Sherif','customer','Giza',true,[]],
  ['Tamer Hossam','customer','New Cairo',false,[]],
  ['Nour Adham','customer','Giza',true,[]],
  ['Yara Sami','customer','Alexandria',true,[]],
  ['Hana Maged','customer','6th of October',false,[]],
  ['Mostafa Reda','customer','Nasr City',true,[]],
  ['Laila Fawzy','customer','Heliopolis',true,[]],
  ['Adham Salah','customer','Maadi',false,[]],
  ['Ahmed Hassan','worker','Cairo',true,['plumbing','hvac']],
  ['Mohamed Ali','worker','Giza',true,['electrical']],
  ['Karim Adel','worker','6th of October',true,['electrical','appliance_repair']],
  ['Nader Wahba','worker','Alexandria',true,['carpentry','painting']],
  ['Ali Gamal','worker','Maadi',true,['hvac']],
  ['Ramy Naguib','worker','Zamalek',false,['tiling']],
  ['Sameh Lotfy','worker','Cairo',true,['cleaning']],
  ['Ashraf Zaki','worker','Nasr City',false,['plumbing']],
  ['Fady Boutros','worker','Cairo',true,['appliance_repair']],
].map((u, i) => ({
  _id: 'usr_' + (i + 1),
  name: u[0], role: u[1], city: u[2], isVerified: u[3], skills: u[4],
  email: u[0].toLowerCase().replace(/[^a-z]/g, '.') + '@email.com',
  phone: '+2012' + (30000000 + i * 392817).toString().slice(0, 8),
  isActive: true,
  createdAt: ['2026-01-04','2026-01-15','2026-02-01','2026-02-09','2026-02-20','2026-03-03','2026-03-14','2026-03-25','2026-04-05','2025-08-15','2025-09-01','2024-08-08','2024-05-30','2024-09-22','2024-10-05','2024-12-11','2025-03-09','2024-06-02'][i],
}));

// ── Derived analytics ────────────────────────────────────
const count = (arr, fn) => arr.filter(fn).length;
const sum = (arr, fn) => arr.reduce((a, x) => a + fn(x), 0);

const verifiedCount = count(TECHNICIANS, t => t.isVerified);
const avgRating = (sum(TECHNICIANS, t => t.rating) / TECHNICIANS.length);

const issueStatus = {};
Object.keys(STATUS_CONFIG).forEach(s => { issueStatus[s] = count(ISSUES, i => i.status === s); });

const issuesByCategory = {};
CATEGORIES.forEach(c => { issuesByCategory[c] = count(ISSUES, i => i.category === c); });

const techByCategory = {};
CATEGORIES.forEach(c => {
  const list = TECHNICIANS.filter(t => t.category === c);
  techByCategory[c] = {
    count: list.length,
    avgRating: list.length ? (sum(list, t => t.rating) / list.length) : 0,
  };
});

const cityDistribution = CITIES.map(city => ({
  city, count: count(TECHNICIANS, t => t.city === city),
})).filter(c => c.count > 0).sort((a, b) => b.count - a.count);

const urgencyDist = {};
Object.keys(URGENCY_CONFIG).forEach(u => { urgencyDist[u] = count(ISSUES, i => i.urgency === u); });

// rating distribution buckets
const ratingBuckets = [
  { range: '4.5 – 5.0', min: 4.5, max: 5.01 },
  { range: '4.0 – 4.5', min: 4.0, max: 4.5 },
  { range: '3.5 – 4.0', min: 3.5, max: 4.0 },
  { range: '3.0 – 3.5', min: 3.0, max: 3.5 },
  { range: '< 3.0',     min: 0,   max: 3.0 },
].map(b => ({ range: b.range, count: count(TECHNICIANS, t => t.rating >= b.min && t.rating < b.max) }));

const monthlyGrowth = [
  { month: 'Jan', technicians: 11, issues: 64, users: 8 },
  { month: 'Feb', technicians: 14, issues: 89, users: 14 },
  { month: 'Mar', technicians: 17, issues: 121, users: 21 },
  { month: 'Apr', technicians: 19, issues: 158, users: 27 },
  { month: 'May', technicians: 22, issues: 203, users: 33 },
  { month: 'Jun', technicians: 24, issues: 247, users: 41 },
];

const topTechnicians = [...TECHNICIANS]
  .sort((a, b) => b.rating - a.rating || b.issuesResolved - a.issuesResolved)
  .slice(0, 6);

const totalIssuesResolved = sum(TECHNICIANS, t => t.issuesResolved);

const ANALYTICS = {
  totalTechnicians: TECHNICIANS.length,
  verifiedCount,
  verifiedPercentage: ((verifiedCount / TECHNICIANS.length) * 100).toFixed(1),
  avgRating: avgRating.toFixed(2),
  totalIssuesResolved,
  techByCategory,
  cityDistribution,
  ratingDistribution: ratingBuckets,
  monthlyGrowth,
  topTechnicians,
  issueStats: {
    total: ISSUES.length,
    ...issueStatus,
    active: issueStatus.pending + issueStatus.assigned + issueStatus.inProgress,
    byCategory: issuesByCategory,
    byUrgency: urgencyDist,
  },
  userStats: {
    total: USERS.length,
    customers: count(USERS, u => u.role === 'customer'),
    workers: count(USERS, u => u.role === 'worker'),
    verified: count(USERS, u => u.isVerified),
  },
};

// ── System health (mock live metrics) ────────────────────
const HEALTH = {
  services: [
    {
      id: 'api', name: 'API Gateway', status: 'operational', icon: 'Server',
      uptime: 99.98, latency: 42, rpm: 1840, errorRate: 0.02,
      metrics: [
        { label: 'Active Connections', value: '312', pct: 41, unit: '' },
        { label: 'Requests / min', value: '1,840', pct: 62, unit: '' },
        { label: 'Error Rate', value: '0.02%', pct: 2, unit: '', tone: 'success' },
        { label: 'Avg Latency', value: '42 ms', pct: 28, unit: '', tone: 'success' },
      ],
    },
    {
      id: 'llm', name: 'LLM Engine', status: 'degraded', icon: 'BrainCircuit',
      uptime: 99.71, latency: 880, rpm: 420, errorRate: 0.4,
      metrics: [
        { label: 'Token Usage (24h)', value: '8.4M', pct: 71, unit: '', tone: 'warning' },
        { label: 'Queue Length', value: '17', pct: 34, unit: '' },
        { label: 'Inference Latency', value: '880 ms', pct: 68, unit: '', tone: 'warning' },
        { label: 'Error Rate', value: '0.40%', pct: 8, unit: '' },
      ],
    },
    {
      id: 'db', name: 'MongoDB Atlas', status: 'operational', icon: 'Database',
      uptime: 99.99, latency: 11, rpm: 3120, errorRate: 0.01,
      metrics: [
        { label: 'DB Connections', value: '88 / 200', pct: 44, unit: '' },
        { label: 'Avg Query Time', value: '11 ms', pct: 18, unit: '', tone: 'success' },
        { label: 'Documents', value: '1.27M', pct: 53, unit: '' },
        { label: 'Storage Used', value: '6.2 / 10 GB', pct: 62, unit: '' },
      ],
    },
  ],
  incidents: [
    { time: '14:32', service: 'LLM Engine', text: 'Elevated inference latency on triage model', level: 'warning' },
    { time: '09:11', service: 'API Gateway', text: 'Auto-scaled to 4 instances under load', level: 'info' },
    { time: 'Yesterday', service: 'MongoDB Atlas', text: 'Nightly backup completed (6.2 GB)', level: 'success' },
  ],
};

export const SF = {
  CATEGORY_CONFIG, CATEGORIES, CITIES, STATUS_CONFIG, URGENCY_CONFIG,
  TICKET_STATUS_CONFIG, PAYMENT_STATUS_CONFIG, TICKET_PRIORITY_CONFIG,
  TECHNICIANS, ISSUES, USERS, ANALYTICS, HEALTH,
};
