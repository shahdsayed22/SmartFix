// scripts/verify-e2e.mjs
// -----------------------------------------------------------------------------
// End-to-end verification of SmartFix Stage 3 (Uber-style offer / accept / cascade
// dispatch) + Stage 4 (Uber-style fare + Paymob payment in MOCK mode — no real
// money). Drives the REAL Next.js HTTP API exactly as the Flutter app does.
//
// Isolation trick: locally NO existing technician has coordinates, and
// matchTechnician() only distance-ranks technicians that HAVE coordinates. So
// the verified techs this script seeds (with coords) become the ENTIRE offer
// queue — existing data cannot interfere. Everything seeded is tagged with a
// unique run id and deleted at the end.
//
// Prereq: dev server running in mock mode, e.g.
//   PAYMOB_ENABLED=false TRIAGE_AUTOASSIGN=on npm run dev
// Then:
//   node scripts/verify-e2e.mjs
// -----------------------------------------------------------------------------
import { MongoClient } from 'mongodb';
import { readFileSync } from 'fs';

const BASE = process.env.E2E_BASE || 'http://localhost:3000';
const URI = (readFileSync('.env.local', 'utf8').match(/MONGODB_URI=(.*)/) || [])[1].trim();
const RUN = 'e2e-' + Date.now().toString(36);

// Commission settings are read LIVE from the admin singleton (not hardcoded),
// then we replicate lib/pricing.js exactly to predict the figures.
let CS = { platformFeePercent: 13, vatPercent: 15, workerCommissionPercent: 15, minPlatformFee: 0 };
const expInvoice = (base, discount = 0) => {
  const platformFee = Math.max(CS.minPlatformFee, Math.round((base * CS.platformFeePercent) / 100));
  const vat = Math.round(((base + platformFee) * CS.vatPercent) / 100);
  const total = Math.max(0, base + platformFee + vat - discount);
  return { platformFee, vat, total };
};
const expPayout = (base) => {
  const workerCommission = Math.round((base * CS.workerCommissionPercent) / 100);
  return { workerCommission, payout: base - workerCommission };
};
// fare knobs (workflows/issue-triage.js): base 150, perKm 10, surge 50 (high/emergency)
const FARE_BASE = 150, FARE_PER_KM = 10, FARE_SURGE = 50;

let PASS = 0, FAIL = 0;
const summary = {};
const log = (...a) => console.log(...a);
function check(name, cond, extra = '') {
  if (cond) { PASS++; log(`  ✓ ${name}`); }
  else { FAIL++; log(`  ✗ ${name}   ${extra}`); }
  return cond;
}
const round = (n) => Math.round(n);
function haversineKm(a, b, c, d) {
  const R = 6371, toRad = (x) => (x * Math.PI) / 180;
  const dLat = toRad(c - a), dLon = toRad(d - b);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a)) * Math.cos(toRad(c)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}
async function api(method, path, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json; try { json = JSON.parse(text); } catch { json = { _raw: text.slice(0, 300) }; }
  return { status: res.status, json };
}
async function waitForStatus(id, want, timeoutMs = 45000) {
  const t0 = Date.now();
  let last = null;
  while (Date.now() - t0 < timeoutMs) {
    const { json } = await api('GET', `/api/issues/${id}`);
    last = json;
    if (json && json.status === want) return json;
    await new Promise((r) => setTimeout(r, 1000));
  }
  return last; // return last seen for diagnostics
}

const client = new MongoClient(URI, { serverSelectionTimeoutMS: 8000 });
await client.connect();
const db = client.db();
const Tech = db.collection('technicians');

async function seedTech({ uid, name, category, lat, lng, rating }) {
  await Tech.insertOne({
    uid, name, category, categories: [category], city: 'E2ETown',
    latitude: lat, longitude: lng, rating, isVerified: true,
    verificationStatus: 'verified', issuesResolved: 0,
    createdAt: new Date(), updatedAt: new Date(),
  });
}

// Base location for all scenarios (remote desert coords → zero collision).
const LAT0 = 23.5, LNG0 = 32.0;

try {
  log(`\n=== SmartFix E2E verification (run ${RUN}, base ${BASE}) ===`);
  log(`Paymob mode under test: MOCK (no real money)`);
  // Pull live commission settings so invoice assertions match the admin config.
  const cs = await api('GET', '/api/settings/commission');
  if (cs.json && cs.json.platformFeePercent != null) {
    CS = cs.json;
    log(`Commission settings (live): platform ${CS.platformFeePercent}% · VAT ${CS.vatPercent}% · worker ${CS.workerCommissionPercent}% · minFee ${CS.minPlatformFee}`);
  }
  log('');

  // ───────────────────────────────────────────────────────────────────────
  // SCENARIO 1 — Happy path: report → AI triage builds offer queue → worker
  // ACCEPTS at quoted fare → completion approval → MOCK Paymob payment →
  // issue completed. Verifies fare formula + invoice/payout math.
  // ───────────────────────────────────────────────────────────────────────
  log('SCENARIO 1 — happy path (plumbing, medium urgency): offer → accept → fare → pay');
  const p = [
    { uid: `${RUN}-p1`, name: 'Plumber Near', category: 'plumbing', lat: LAT0, lng: LNG0, rating: 4.5 },
    { uid: `${RUN}-p2`, name: 'Plumber Mid', category: 'plumbing', lat: LAT0 + 0.02, lng: LNG0, rating: 4.6 },
    { uid: `${RUN}-p3`, name: 'Plumber Far', category: 'plumbing', lat: LAT0 + 0.05, lng: LNG0, rating: 4.7 },
  ];
  for (const t of p) await seedTech(t);
  let r = await api('POST', '/api/issues', {
    title: 'تسريب مياه', description: 'الحنفية بتنقط في المطبخ',
    category: 'plumbing', urgency: 'medium',
    customerName: 'E2E Customer', customerId: `${RUN}-cust1`,
    city: 'E2ETown', latitude: LAT0, longitude: LNG0,
  });
  check('issue created (201)', r.status === 201, `got ${r.status} ${JSON.stringify(r.json).slice(0,160)}`);
  const id1 = r.json._id;
  let iss = await waitForStatus(id1, 'offered');
  const triageRan = check('AI triage ran in dev → status "offered"', iss && iss.status === 'offered',
    `last status: ${iss && iss.status}`);
  if (triageRan) {
    const q = iss.offerQueue || [];
    check('offer queue built with all 3 seeded techs', q.length === 3, `len=${q.length}`);
    check('offer queue sorted nearest-first', q.length === 3 && q[0].km <= q[1].km && q[1].km <= q[2].km,
      `km=[${q.map(x => x.km).join(', ')}]`);
    check('offeredTo = nearest tech (p1)', iss.offeredTo === `${RUN}-p1`, `offeredTo=${iss.offeredTo}`);
    check('offerIndex = 0', iss.offerIndex === 0, `idx=${iss.offerIndex}`);
    const km0 = q[0] ? q[0].km : null;
    const expKm = round(haversineKm(LAT0, LNG0, p[0].lat, p[0].lng) * 10) / 10;
    check('server distance matches haversine (~0 km)', km0 != null && Math.abs(km0 - expKm) < 0.2,
      `server=${km0} expected~${expKm}`);
    const expFare = round(FARE_BASE + km0 * FARE_PER_KM + 0); // medium → no surge
    check(`fare = base+km*perKm (no surge) = ${expFare}`, q[0].fare === expFare, `fare=${q[0].fare}`);
    summary.s1_fare = q[0].fare;

    // Accept the offer
    r = await api('PATCH', `/api/issues/${id1}`, { action: 'accept-offer', technicianId: `${RUN}-p1`, by: 'worker' });
    check('accept-offer → assigned', r.json.status === 'assigned', `status=${r.json.status}`);
    check('assigned to accepting worker', r.json.assignedTechnicianId === `${RUN}-p1`, `tech=${r.json.assignedTechnicianId}`);
    check('price locked to quoted fare', r.json.price === q[0].fare, `price=${r.json.price}`);
    check('offer cleared after accept', !r.json.offeredTo, `offeredTo=${r.json.offeredTo}`);
    const base = r.json.price;

    // Completion approval handshake
    r = await api('PATCH', `/api/issues/${id1}`, { action: 'request-completion', by: 'worker', completionSummary: 'done' });
    check('request-completion → awaitingApproval', r.json.status === 'awaitingApproval', `status=${r.json.status}`);
    r = await api('PATCH', `/api/issues/${id1}`, { action: 'approve-completion', by: 'customer' });
    check('approve-completion → awaitingPayment', r.json.status === 'awaitingPayment', `status=${r.json.status}`);

    // Payment (mock Paymob)
    r = await api('POST', '/api/payments', {
      issueId: id1, customerId: `${RUN}-cust1`, technicianId: `${RUN}-p1`,
      base, customerName: 'E2E Customer', method: 'card',
    });
    const pay = r.json;
    check('payment created (201)', r.status === 201, `status=${r.status}`);
    const { platformFee: expFee, vat: expVat, total: expTotal } = expInvoice(base);
    const { workerCommission: expComm, payout: expPay } = expPayout(base);
    check(`invoice base = ${base}`, pay.base === base, `base=${pay.base}`);
    check(`platformFee ${CS.platformFeePercent}% = ${expFee}`, pay.platformFee === expFee, `fee=${pay.platformFee}`);
    check(`VAT ${CS.vatPercent}% of (base+fee) = ${expVat}`, pay.vat === expVat, `vat=${pay.vat}`);
    check(`client total = ${expTotal}`, pay.total === expTotal, `total=${pay.total}`);
    check(`worker commission ${CS.workerCommissionPercent}% = ${expComm}`, pay.workerCommission === expComm, `comm=${pay.workerCommission}`);
    check(`worker payout = base-comm = ${expPay}`, pay.payoutAmount === expPay, `payout=${pay.payoutAmount}`);
    check('payment provider = paymob', pay.provider === 'paymob', `provider=${pay.provider}`);
    check('payment status starts pending', pay.status === 'pending', `status=${pay.status}`);
    check('mock checkout URL issued', /mock=1/.test(pay.paymentUrl) && /status=paid/.test(pay.paymentUrl), pay.paymentUrl);
    summary.s1_invoice = { base, platformFee: pay.platformFee, vat: pay.vat, total: pay.total, workerCommission: pay.workerCommission, payout: pay.payoutAmount };

    // Hit the mock callback (what the in-app browser would land on). paymentUrl
    // is already absolute (origin baked in), so don't re-prefix BASE.
    const cbUrl = /^https?:\/\//.test(pay.paymentUrl) ? pay.paymentUrl : BASE + pay.paymentUrl;
    const cb = await fetch(cbUrl);
    check('mock callback page 200', cb.status === 200, `status=${cb.status}`);
    // Poll payment → paid
    let paid = null;
    for (let i = 0; i < 10; i++) {
      const g = await api('GET', `/api/payments/${pay._id}`);
      if (g.json.status === 'paid') { paid = g.json; break; }
      await new Promise((r) => setTimeout(r, 500));
    }
    check('payment flips to paid', paid && paid.status === 'paid', `status=${paid && paid.status}`);
    check('paidAt timestamp set', !!(paid && paid.paidAt), '');
    // Issue completed
    const done = (await api('GET', `/api/issues/${id1}`)).json;
    check('issue auto-completed after payment', done.status === 'completed', `status=${done.status}`);
    check('issue links paymentId', done.paymentId === String(pay._id), `paymentId=${done.paymentId}`);

    // ── Stage 5: the money MOVED as a process (wallet ledger) ──────────────
    const w = (await api('GET', `/api/wallet?technicianId=${RUN}-p1`)).json;
    check(`worker wallet credited with payout (${expPay})`, w.balance === expPay, `balance=${w.balance}`);
    check('wallet history shows the payout entry',
      (w.transactions || []).some((t) => t.type === 'payout' && t.amount === expPay), '');
    const plat = (await api('GET', '/api/wallet?scope=platform')).json;
    check('platform ledger recorded revenue (fee+commission)',
      typeof plat.revenue === 'number' && plat.revenue >= (pay.platformFee + pay.workerCommission), `revenue=${plat.revenue}`);
    // Idempotency: re-hitting the mock callback must NOT double-credit.
    await fetch(cbUrl);
    const w2 = (await api('GET', `/api/wallet?technicianId=${RUN}-p1`)).json;
    check('ledger is idempotent (no double-credit on repeat callback)', w2.balance === expPay, `balance=${w2.balance}`);
    // Withdraw (simulated cash-out) empties the wallet.
    const wd = (await api('POST', '/api/wallet/withdraw', { technicianId: `${RUN}-p1` })).json;
    check('withdraw debits wallet to 0', wd.balance === 0, `balance=${wd.balance}`);
    summary.s1_walletPayout = expPay;
  }

  // ───────────────────────────────────────────────────────────────────────
  // SCENARIO 2 — Decline cascade: each decline advances to the next candidate;
  // exhausting the queue re-opens the job as 'pending'.
  // ───────────────────────────────────────────────────────────────────────
  log('\nSCENARIO 2 — decline cascade (electrical): decline → next → next → pending');
  const e = [
    { uid: `${RUN}-e1`, name: 'Elec A', category: 'electrical', lat: LAT0, lng: LNG0, rating: 4.2 },
    { uid: `${RUN}-e2`, name: 'Elec B', category: 'electrical', lat: LAT0 + 0.02, lng: LNG0, rating: 4.3 },
    { uid: `${RUN}-e3`, name: 'Elec C', category: 'electrical', lat: LAT0 + 0.05, lng: LNG0, rating: 4.4 },
  ];
  for (const t of e) await seedTech(t);
  r = await api('POST', '/api/issues', {
    title: 'مشكلة كهرباء', description: 'النور مش بيشتغل في الأوضة',
    category: 'electrical', urgency: 'medium',
    customerName: 'E2E Customer', customerId: `${RUN}-cust2`,
    city: 'E2ETown', latitude: LAT0, longitude: LNG0,
  });
  const id2 = r.json._id;
  iss = await waitForStatus(id2, 'offered');
  if (check('triage offered to e1', iss && iss.offeredTo === `${RUN}-e1`, `offeredTo=${iss && iss.offeredTo}`)) {
    r = await api('PATCH', `/api/issues/${id2}`, { action: 'decline-offer', technicianId: `${RUN}-e1`, by: 'worker' });
    check('decline #1 → cascades to e2', r.json.offeredTo === `${RUN}-e2` && r.json.status === 'offered', `offeredTo=${r.json.offeredTo} idx=${r.json.offerIndex}`);
    check('offerIndex advanced to 1', r.json.offerIndex === 1, `idx=${r.json.offerIndex}`);
    r = await api('PATCH', `/api/issues/${id2}`, { action: 'decline-offer', technicianId: `${RUN}-e2`, by: 'worker' });
    check('decline #2 → cascades to e3', r.json.offeredTo === `${RUN}-e3` && r.json.status === 'offered', `offeredTo=${r.json.offeredTo}`);
    r = await api('PATCH', `/api/issues/${id2}`, { action: 'decline-offer', technicianId: `${RUN}-e3`, by: 'worker' });
    check('decline #3 (queue exhausted) → pending', r.json.status === 'pending', `status=${r.json.status}`);
    check('offer cleared on exhaustion', !r.json.offeredTo, `offeredTo=${r.json.offeredTo}`);
  }

  // ───────────────────────────────────────────────────────────────────────
  // SCENARIO 3 — Severity-aware ranking + urgency surge: an EMERGENCY job
  // floats the top-rated (>=4) tech ahead of a nearer low-rated one, and adds
  // the +50 surge to the fare.
  // ───────────────────────────────────────────────────────────────────────
  log('\nSCENARIO 3 — emergency (hvac): severity-aware top-rated first + surge fare');
  const h = [
    { uid: `${RUN}-h1`, name: 'HVAC Near LowRated', category: 'hvac', lat: LAT0, lng: LNG0, rating: 3.0 },
    { uid: `${RUN}-h2`, name: 'HVAC Far TopRated', category: 'hvac', lat: LAT0 + 0.03, lng: LNG0, rating: 4.8 },
  ];
  for (const t of h) await seedTech(t);
  r = await api('POST', '/api/issues', {
    title: 'تكييف خطر', description: 'التكييف بيطلع ريحة حريق ودخان',
    category: 'hvac', urgency: 'emergency',
    customerName: 'E2E Customer', customerId: `${RUN}-cust3`,
    city: 'E2ETown', latitude: LAT0, longitude: LNG0,
  });
  const id3 = r.json._id;
  iss = await waitForStatus(id3, 'offered');
  if (check('triage offered (emergency)', iss && iss.status === 'offered', `status=${iss && iss.status}`)) {
    const q = iss.offerQueue || [];
    check('severity-aware: top-rated (h2) offered FIRST despite being farther', iss.offeredTo === `${RUN}-h2`,
      `offeredTo=${iss.offeredTo} (km=[${q.map(x => x.km).join(', ')}], ratings=[${q.map(x => x.rating).join(', ')}])`);
    check('nearer low-rated (h1) ranked second', q[1] && q[1].techId === `${RUN}-h1`, `q1=${q[1] && q[1].techId}`);
    const surgeFare = round(FARE_BASE + (q[0] ? q[0].km : 0) * FARE_PER_KM + FARE_SURGE);
    check(`emergency fare includes +${FARE_SURGE} surge = ${surgeFare}`, q[0] && q[0].fare === surgeFare, `fare=${q[0] && q[0].fare}`);
    summary.s3_surgeFare = q[0] && q[0].fare;
  }
} catch (err) {
  FAIL++;
  log('\n!!! ERROR during verification:', err && err.message);
} finally {
  // Cleanup everything tagged with this run id.
  const dt = await Tech.deleteMany({ uid: { $regex: '^' + RUN } });
  const di = await db.collection('issues').deleteMany({ customerId: { $regex: '^' + RUN } });
  const dp = await db.collection('payments').deleteMany({ customerId: { $regex: '^' + RUN } });
  const dw = await db.collection('wallettransactions').deleteMany({
    $or: [{ technicianId: { $regex: '^' + RUN } }, { customerId: { $regex: '^' + RUN } }],
  });
  log(`\nCleanup: removed ${dt.deletedCount} techs, ${di.deletedCount} issues, ${dp.deletedCount} payments, ${dw.deletedCount} ledger rows.`);
  await client.close();
  log(`\n=== RESULT: ${PASS} passed, ${FAIL} failed ===`);
  if (Object.keys(summary).length) log('Captured figures:', JSON.stringify(summary));
  process.exit(FAIL > 0 ? 1 : 0);
}
