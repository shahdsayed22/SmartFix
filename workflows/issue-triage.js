// SmartFix — Durable Issue-Triage Workflow (Vercel Workflow DevKit)
// -----------------------------------------------------------------------------
// Pipeline (each step is durable + automatically retried; if the server crashes
// mid-pipeline, the run resumes from the last completed step):
//
//   loadIssue  ->  classifyIssue  ->  matchTechnician  ->  persistTriage  ->  notify
//
// Grounded in research/AI_INTEGRATION_PLAN.md:
//   * Tier 1 — Smart issue classification / urgency + anomaly scoring
//   * Tier 3 — Smart technician matching (real MongoDB query)
//
// HONESTY NOTE: classifyIssue() is a transparent HEURISTIC BASELINE, not the
// trained PyTorch model. The real model integration point is marked with TODO.
// Do not describe this as the trained model in the thesis/paper.
// -----------------------------------------------------------------------------

import { FatalError } from 'workflow';
// Relative imports (not the @/ alias) so the workflow bundle resolves reliably.
import dbConnect from '../lib/mongodb.js';
import Issue from '../models/Issue.js';
import Technician from '../models/Technician.js';
import { detectUrgency, maxUrgency } from '../lib/urgency.js';

/**
 * Orchestrates AI triage for a newly-created issue.
 * @param {string} issueId - Mongo _id of the issue to triage.
 */
export async function triageIssue(issueId) {
  'use workflow';

  const issue = await loadIssue(issueId);
  const classification = await classifyIssue(issue);
  // AI still scores urgency/anomaly always. Auto-assignment can be turned off
  // (set TRIAGE_AUTOASSIGN=off) so issues stay "pending" and a technician
  // claims them manually — handy when demoing the worker choosing a job.
  const autoAssign = process.env.TRIAGE_AUTOASSIGN !== 'off';
  const match = autoAssign
    ? await matchTechnician({ ...issue, ...classification })
    : null;
  const updated = await persistTriage(issueId, classification, match);
  await notifyParties(updated, match);

  return {
    issueId,
    aiUrgencyScore: classification.aiUrgencyScore,
    aiAnomalyScore: classification.aiAnomalyScore,
    offeredTo: updated.offeredToName,
    offerCount: updated.offerCount,
    status: updated.status,
  };
}

// --- Steps (full Node.js access; results persisted for replay) ----------------

async function loadIssue(issueId) {
  'use step';
  await dbConnect();
  const doc = await Issue.findById(issueId).lean();
  if (!doc) throw new FatalError(`Issue ${issueId} not found`);
  // Return only serializable, primitive fields (no ObjectId instances).
  return {
    id: String(doc._id),
    title: doc.title || '',
    description: doc.description || '',
    category: doc.category,
    urgency: doc.urgency,
    city: doc.city || 'Cairo',
    latitude: typeof doc.latitude === 'number' ? doc.latitude : 0,
    longitude: typeof doc.longitude === 'number' ? doc.longitude : 0,
    status: doc.status,
  };
}

// Great-circle distance in km between two lat/lng points.
function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = (d) => (d * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Uber-style upfront fare (EGP). Base + per-km + an urgency surge. Stage 4
// layers platform fee + VAT on top (via lib/pricing.js) at payment time; this
// is the rider-facing quote shown on the offer. Defaults match the spec.
const FARE_BASE = Number(process.env.FARE_BASE || 150);
const FARE_PER_KM = Number(process.env.FARE_PER_KM || 10);
const FARE_URGENCY_SURGE = Number(process.env.FARE_URGENCY_SURGE || 50);
function computeFare(km, urgency) {
  const distance = Number.isFinite(km) ? km : 0;
  const surge = urgency === 'high' || urgency === 'emergency' ? FARE_URGENCY_SURGE : 0;
  return Math.round(FARE_BASE + distance * FARE_PER_KM + surge);
}

// How many candidates to queue up for the cascading offer.
const OFFER_QUEUE_SIZE = Number(process.env.OFFER_QUEUE_SIZE || 5);

// Keyword signals for the heuristic baseline. Replace with model inference.

async function classifyIssue(issue) {
  'use step';

  // TODO(ai): Replace this heuristic with the trained anomaly model.
  // Options (see research/AI_INTEGRATION_PLAN.md, Phase 1-2):
  //   1. POST to a Python (FastAPI) microservice that loads the .pt/.joblib models
  //   2. onnxruntime-node inference on exported ONNX models
  //   3. Pre-computed batch scores read from Mongo
  // Until then this is a deterministic keyword baseline labelled accordingly.
  // Arabic severity-lexicon urgency detection over the title + description.
  const text = `${issue.title || ''} ${issue.description || ''}`;
  const det = detectUrgency(text);

  const baseByUrgency = { low: 0.15, medium: 0.4, high: 0.65, emergency: 0.9 };
  const reportedScore = baseByUrgency[issue.urgency] ?? 0.4;
  // Trust the stronger of the customer's pick vs. the detected severity.
  const aiUrgencyScore = Number(Math.max(reportedScore, det.score).toFixed(3));
  const aiAnomalyScore = Number(Math.min(1, 0.3 + det.matched.length * 0.12).toFixed(3));

  return {
    aiUrgencyScore,
    aiAnomalyScore,
    // Safety upgrade only — never downgrade what the customer reported.
    detectedUrgency: maxUrgency(issue.urgency || 'medium', det.urgency),
    urgencyMatched: det.matched,
    aiSuggestedCategory: issue.category, // baseline trusts the reported category
    method: 'urgency-lexicon-ar-v1',
    confidence: 0.5,
  };
}

async function matchTechnician(issue) {
  'use step';
  await dbConnect();

  // Pool: verified technicians for this category (fall back to any verified).
  let pool = await Technician.find({ category: issue.category, isVerified: true }).lean();
  if (!pool.length) {
    pool = await Technician.find({ isVerified: true }).limit(500).lean();
  }
  if (!pool.length) return null;

  // Uber-style availability: a technician with an active job (assigned /
  // inProgress) or a pending offer elsewhere is BUSY and skipped. We collect
  // every busy technician id (by uid and by _id) in one query.
  const activeIssues = await Issue.find(
    { status: { $in: ['assigned', 'inProgress', 'offered'] } },
    'assignedTechnicianId offeredTo',
  ).lean();
  const busy = new Set();
  for (const i of activeIssues) {
    if (i.assignedTechnicianId) busy.add(String(i.assignedTechnicianId));
    if (i.offeredTo) busy.add(String(i.offeredTo));
  }
  const techIdOf = (t) => (t.uid && t.uid.length ? t.uid : String(t._id));
  const available = pool.filter((t) => !busy.has(techIdOf(t)));
  if (!available.length) return null; // everyone qualified is busy

  const hasFix = (issue.latitude || issue.longitude) && !(issue.latitude === 0 && issue.longitude === 0);
  // Severity from the AI triage scores (passed in via {...issue, ...classification}).
  const severe =
    (issue.aiAnomalyScore || 0) >= 0.7 ||
    (issue.aiUrgencyScore || 0) >= 0.7 ||
    issue.urgency === 'high' ||
    issue.urgency === 'emergency';

  // Annotate each candidate with distance (if we can) and rank them. The result
  // is an ORDERED queue we offer to one-by-one, nearest first.
  let ranked;
  let reason;
  const located = available.filter(
    (t) => (t.latitude || t.longitude) && !(t.latitude === 0 && t.longitude === 0),
  );
  if (hasFix && located.length) {
    ranked = located
      .map((t) => ({ t, km: haversineKm(issue.latitude, issue.longitude, t.latitude, t.longitude) }))
      // Severity-aware: top-rated (>=4) float to the front, then by distance.
      .sort((a, b) => {
        if (severe) {
          const ar = (a.t.rating || 0) >= 4 ? 0 : 1;
          const br = (b.t.rating || 0) >= 4 ? 0 : 1;
          if (ar !== br) return ar - br;
        }
        return a.km - b.km;
      });
    reason = `${severe ? 'Severity-aware: nearest top-rated' : 'Nearest'} available verified ${issue.category} technicians`;
  } else {
    // No usable coordinates: prefer same city, then top-rated.
    const inCity = available.filter((t) => t.city === issue.city);
    ranked = (inCity.length ? inCity : available)
      .slice()
      .sort((a, b) => (b.rating - a.rating) || ((b.issuesResolved || 0) - (a.issuesResolved || 0)))
      .map((t) => ({ t, km: null }));
    reason = `Top-rated available verified ${issue.category} technicians`;
  }

  // Build the offer queue (capped) with an upfront fare per candidate.
  const queue = ranked.slice(0, OFFER_QUEUE_SIZE).map(({ t, km }) => ({
    techId: techIdOf(t),
    name: t.name,
    km: km != null ? Number(km.toFixed(1)) : null,
    fare: computeFare(km, issue.urgency),
    rating: t.rating || 0,
  }));

  return { queue, reason };
}

async function persistTriage(issueId, classification, match) {
  'use step';
  await dbConnect();

  const update = {
    aiUrgencyScore: classification.aiUrgencyScore,
    aiAnomalyScore: classification.aiAnomalyScore,
    aiSuggestedCategory: classification.aiSuggestedCategory,
    aiClassification: classification,
    aiProcessedAt: new Date(),
    updatedAt: new Date(),
  };
  // Apply the detected urgency (safety upgrade — never below what was reported).
  if (classification.detectedUrgency) update.urgency = classification.detectedUrgency;
  // Uber-style OFFER (not a hard assignment): set the ranked queue and offer the
  // job to the first candidate. The worker accepts/declines via the PATCH route;
  // a decline cascades to the next candidate.
  if (match && match.queue && match.queue.length) {
    const first = match.queue[0];
    update.offerQueue = match.queue;
    update.offerIndex = 0;
    update.offeredTo = first.techId;
    update.offeredToName = first.name;
    update.price = first.fare;
    update.status = 'offered';
  }

  const doc = await Issue.findByIdAndUpdate(issueId, update, { new: true }).lean();
  if (!doc) throw new FatalError(`Issue ${issueId} disappeared before triage could be saved`);
  return {
    id: String(doc._id),
    status: doc.status,
    offeredToName: doc.offeredToName || null,
    offerCount: Array.isArray(doc.offerQueue) ? doc.offerQueue.length : 0,
  };
}

async function notifyParties(issue, match) {
  'use step';
  // TODO(notify): integrate FCM push / email here (durable + retried for free).
  const who = issue.offeredToName
    ? `offered to ${issue.offeredToName} (+${Math.max(0, (issue.offerCount || 1) - 1)} backups)`
    : 'awaiting a technician';
  console.log(`[triage] Issue ${issue.id} -> ${issue.status}, ${who}`);
  return true;
}
