/* ============================================================
   SmartFix — AI Research view-model
   Derives display structures from the REAL experiment output
   (research/results/all_results.json, copied to ai_results.json).
   210 experiments = 7 datasets × 3 models × 10-fold CV.
   ============================================================ */
import RAW from './ai_results.json';

/* ── Models ───────────────────────────────────────────────── */
export const AI_MODELS = ['IF', 'LSTM-AE', 'Trans-D'];

export const AI_MODEL_META = {
  'IF':      { name: 'Isolation Forest',      kind: 'Tree-ensemble',          color: '#22d3ee' },
  'LSTM-AE': { name: 'LSTM Autoencoder',      kind: 'Recurrent reconstruction', color: '#a855f7' },
  'Trans-D': { name: 'Transformer Detector',  kind: 'Attention-based',        color: '#6366f1' },
};

/* ── Datasets (ordered best→weakest, with SmartFix domain mapping) ── */
export const AI_DATASETS = [
  { key: 'Elec. Fault',  short: 'Electrical',  domain: 'Electrical fault detection',  icon: 'Zap',       color: '#f59e0b', sensor: 'Line voltage & current signatures',      maps: 'Electrical issues' },
  { key: 'NASA C-MAPSS', short: 'Degradation', domain: 'Equipment degradation (RUL)', icon: 'Gauge',     color: '#6366f1', sensor: 'Turbofan multivariate sensor cycles',    maps: 'Predictive maintenance' },
  { key: 'CASAS',        short: 'Activity',    domain: 'Activity monitoring',         icon: 'Activity',  color: '#10b981', sensor: 'Ambient smart-home activity sensors',    maps: 'Occupancy / usage' },
  { key: 'Smart Home',   short: 'Appliance',   domain: 'Appliance / smart home',      icon: 'Plug',      color: '#22d3ee', sensor: 'Household power & device telemetry',     maps: 'Appliance repair' },
  { key: 'HVAC Power',   short: 'HVAC',        domain: 'HVAC power anomalies',        icon: 'Snowflake', color: '#3b82f6', sensor: 'HVAC power-draw time-series',            maps: 'HVAC issues' },
  { key: 'Smoke Det.',   short: 'Fire/Gas',    domain: 'Fire / gas detection',        icon: 'Flame',     color: '#ef4444', sensor: 'Smoke, gas & particulate sensors',       maps: 'Safety alerts' },
  { key: 'Water Leak',   short: 'Plumbing',    domain: 'Water-leak detection',        icon: 'Droplets',  color: '#14b8a6', sensor: 'Flow & moisture sensors',               maps: 'Plumbing issues' },
];

/* ── Accessors ────────────────────────────────────────────── */
export const stat = (datasetKey, model) => RAW[datasetKey]?.[model] || null;

export const STAT_TESTS = RAW._statistical_tests || {};
export const ABLATION = RAW._ablation || {};

/** Best model (by F1) for a dataset. */
export function bestModel(datasetKey) {
  let best = null;
  for (const m of AI_MODELS) {
    const s = stat(datasetKey, m);
    if (s && (!best || s.f1 > best.f1)) best = { model: m, ...s };
  }
  return best;
}

/** Per-dataset summary rows for the leaderboard table. */
export const LEADERBOARD = AI_DATASETS.map((d) => {
  const b = bestModel(d.key);
  const tests = STAT_TESTS[d.key] || {};
  const allSig = Object.values(tests).every((t) => String(t.significant) === 'True');
  return {
    _id: d.key,
    dataset: d.key,
    short: d.short,
    domain: d.domain,
    icon: d.icon,
    color: d.color,
    sensor: d.sensor,
    maps: d.maps,
    bestModelKey: b.model,
    f1: b.f1,
    f1_std: b.f1_std,
    auc: b.auc_roc,
    precision: b.precision,
    recall: b.recall,
    inferMs: b.infer_ms,
    cm: b.cm,
    sigCount: Object.keys(tests).length,
    allSig,
  };
});

/* ── Headline numbers (computed, not hard-coded) ──────────── */
const _best = LEADERBOARD.reduce((a, r) => (r.f1 > a.f1 ? r : a), LEADERBOARD[0]);
const _bestAuc = LEADERBOARD.reduce((a, r) => (r.auc > a.auc ? r : a), LEADERBOARD[0]);
const _pairwise = Object.values(STAT_TESTS).reduce((n, ds) => n + Object.keys(ds).length, 0);
const _sigPairwise = Object.values(STAT_TESTS).reduce(
  (n, ds) => n + Object.values(ds).filter((t) => String(t.significant) === 'True').length, 0,
);
const _fastest = Math.min(...LEADERBOARD.map((r) => r.inferMs));

export const AI_SUMMARY = {
  datasets: AI_DATASETS.length,
  models: AI_MODELS.length,
  folds: 10,
  experiments: AI_DATASETS.length * AI_MODELS.length * 10,
  bestF1: _best.f1,
  bestF1Domain: _best.short,
  bestAuc: _bestAuc.auc,
  bestAucDomain: _bestAuc.short,
  pairwise: _pairwise,
  sigPairwise: _sigPairwise,
  fastestMs: _fastest,
};

/* ── Publication figures (real paper artifacts, staged to /public) ── */
export const AI_FIGURES = [
  { src: '/research/figures/f1_comparison.png',     title: 'F1-Score Comparison',     sub: 'Per-dataset F1 across all three models' },
  { src: '/research/figures/auc_comparison.png',    title: 'AUC-ROC Comparison',      sub: 'Discrimination power by model & domain' },
  { src: '/research/figures/roc_curves.png',        title: 'ROC Curves',              sub: 'True vs false positive rates' },
  { src: '/research/figures/confusion_matrices.png',title: 'Confusion Matrices',      sub: 'Per best-model classification breakdown' },
  { src: '/research/figures/radar_chart.png',       title: 'Multi-Metric Radar',      sub: 'Accuracy · precision · recall · F1 · AUC' },
  { src: '/research/figures/latency_tradeoff.png',  title: 'Latency vs Accuracy',     sub: 'Inference cost trade-off' },
  { src: '/research/figures/ablation.png',          title: 'Ensemble Ablation',       sub: 'Ensemble vs single best model' },
  { src: '/research/figures/architecture.png',      title: 'System Architecture',     sub: 'Research → production pipeline' },
];

/* ── Research → product mapping (honest about live status) ── */
export const AI_BRIDGE = [
  { icon: 'Gauge',     title: 'Urgency & anomaly scoring', text: 'Anomaly scores map to an issue’s urgency, replacing keyword guessing with model-driven severity.', status: 'Baseline live · trained-model next' },
  { icon: 'Radar',     title: 'Predictive auto-issues',    text: 'A flagged sensor anomaly auto-creates a maintenance issue before a human reports it.', status: 'Roadmap' },
  { icon: 'Route',     title: 'Severity-aware routing',    text: 'High-anomaly issues route to the highest-rated verified technicians automatically.', status: 'Partially live' },
];
