// scripts/train-nlp.mjs
// Trains a Multinomial Naive Bayes Arabic text classifier (9 service categories)
// on data/arabic_issues.jsonl, evaluates it (stratified 80/20 + macro-F1 +
// confusion matrix), and emits:
//   lib/nlp_model.json     — the serialized model (served via lib/nlpModel.js)
//   research/nlp_metrics.md — measured metrics for the thesis
// Pure JS, no Python / sklearn / ONNX. Run: node scripts/train-nlp.mjs
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { extractFeatures } from '../lib/nlpFeatures.js';

const DATA = 'data/arabic_issues.jsonl';
const ALPHA = 0.1;          // Laplace smoothing
const MAX_VOCAB = 7000;     // cap features by total frequency
const MIN_DF = 2;           // drop ultra-rare features
const SEED = 42;

// Deterministic RNG (mulberry32) so the split + results are reproducible.
function rng(seed) {
    let a = seed >>> 0;
    return () => {
        a |= 0; a = (a + 0x6D2B79F5) | 0;
        let t = Math.imul(a ^ (a >>> 15), 1 | a);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}
const rand = rng(SEED);
function shuffle(arr) {
    for (let i = arr.length - 1; i > 0; i -= 1) {
        const j = Math.floor(rand() * (i + 1));
        [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
}

// ── Load + stratified split ──────────────────────────────────────────────────
const rows = readFileSync(DATA, 'utf8').trim().split('\n')
    .map((l) => { try { return JSON.parse(l); } catch { return null; } })
    .filter((r) => r && r.text && r.label);

const byLabel = {};
for (const r of rows) (byLabel[r.label] ||= []).push(r);
const classes = Object.keys(byLabel).sort();

const train = [], test = [];
for (const c of classes) {
    const list = shuffle(byLabel[c].slice());
    const cut = Math.floor(list.length * 0.8);
    train.push(...list.slice(0, cut));
    test.push(...list.slice(cut));
}
console.log(`Loaded ${rows.length} rows · ${classes.length} classes · train ${train.length} / test ${test.length}`);

// ── Vocabulary (document frequency + total frequency, capped) ─────────────────
const df = new Map();      // feature → #docs containing it (train)
const tf = new Map();      // feature → total count (train)
for (const r of train) {
    const feats = extractFeatures(r.text);
    const seen = new Set();
    for (const f of feats) {
        tf.set(f, (tf.get(f) || 0) + 1);
        if (!seen.has(f)) { seen.add(f); df.set(f, (df.get(f) || 0) + 1); }
    }
}
let vocab = [...tf.keys()].filter((f) => (df.get(f) || 0) >= MIN_DF);
vocab.sort((a, b) => (tf.get(b) - tf.get(a)));
vocab = vocab.slice(0, MAX_VOCAB);
const vIndex = new Map(vocab.map((f, i) => [f, i]));
console.log(`Vocabulary: ${vocab.length} features (from ${tf.size} candidates)`);

// ── Train Multinomial NB ──────────────────────────────────────────────────────
const ci = Object.fromEntries(classes.map((c, i) => [c, i]));
const V = vocab.length;
const counts = classes.map(() => new Float64Array(V));
const totalPerClass = new Float64Array(classes.length);
const docsPerClass = new Float64Array(classes.length);

for (const r of train) {
    const c = ci[r.label];
    docsPerClass[c] += 1;
    for (const f of extractFeatures(r.text)) {
        const idx = vIndex.get(f);
        if (idx !== undefined) { counts[c][idx] += 1; totalPerClass[c] += 1; }
    }
}
const logPrior = classes.map((_, c) => Math.log(docsPerClass[c] / train.length));
const logLik = classes.map((_, c) => {
    const denom = totalPerClass[c] + ALPHA * V;
    const row = new Array(V);
    for (let i = 0; i < V; i += 1) row[i] = Math.log((counts[c][i] + ALPHA) / denom);
    return row;
});

function predict(text) {
    const scores = logPrior.slice();
    for (const f of extractFeatures(text)) {
        const idx = vIndex.get(f);
        if (idx !== undefined) for (let c = 0; c < classes.length; c += 1) scores[c] += logLik[c][idx];
    }
    let best = 0;
    for (let c = 1; c < classes.length; c += 1) if (scores[c] > scores[best]) best = c;
    return classes[best];
}

// ── Evaluate ─────────────────────────────────────────────────────────────────
const confusion = classes.map(() => new Array(classes.length).fill(0));
let correct = 0;
for (const r of test) {
    const pred = predict(r.text);
    confusion[ci[r.label]][ci[pred]] += 1;
    if (pred === r.label) correct += 1;
}
const accuracy = correct / test.length;
const perClass = classes.map((c, i) => {
    const tp = confusion[i][i];
    const fp = classes.reduce((s, _, j) => s + (j === i ? 0 : confusion[j][i]), 0);
    const fn = classes.reduce((s, _, j) => s + (j === i ? 0 : confusion[i][j]), 0);
    const precision = tp + fp ? tp / (tp + fp) : 0;
    const recall = tp + fn ? tp / (tp + fn) : 0;
    const f1 = precision + recall ? (2 * precision * recall) / (precision + recall) : 0;
    return { c, precision, recall, f1, support: confusion[i].reduce((a, b) => a + b, 0) };
});
const macroF1 = perClass.reduce((s, p) => s + p.f1, 0) / classes.length;
console.log(`\nAccuracy: ${(accuracy * 100).toFixed(2)}%  ·  Macro-F1: ${(macroF1 * 100).toFixed(2)}%`);
for (const p of perClass) {
    console.log(`  ${p.c.padEnd(18)} P=${(p.precision * 100).toFixed(1)}  R=${(p.recall * 100).toFixed(1)}  F1=${(p.f1 * 100).toFixed(1)}  (n=${p.support})`);
}

// ── Serialize model (round logLik to keep the JSON lean) ──────────────────────
const r4 = (x) => Math.round(x * 10000) / 10000;
const model = {
    id: 'nb-arabic-v1',
    trainedAt: process.env.TRAIN_STAMP || '',
    classes,
    logPrior: logPrior.map(r4),
    vocab,
    logLik: logLik.map((row) => row.map(r4)),
    alpha: ALPHA,
    metrics: { accuracy: r4(accuracy), macroF1: r4(macroF1), test: test.length, train: train.length },
};
writeFileSync('lib/nlp_model.json', JSON.stringify(model));
const sizeKB = (Buffer.byteLength(JSON.stringify(model)) / 1024).toFixed(0);
console.log(`\nWrote lib/nlp_model.json (${sizeKB} KB, ${V} features × ${classes.length} classes)`);

// ── Metrics report (thesis) ───────────────────────────────────────────────────
mkdirSync('research', { recursive: true });
let md = `# SmartFix — Arabic Text Classifier (category detection)\n\n`;
md += `Multinomial Naive Bayes over character n-grams (3–5, word-boundary) + word unigrams, `;
md += `trained on ${rows.length} Arabic service complaints (${classes.length} categories). `;
md += `Pure-JS, served in-process behind \`/api/nlp/classify\` (no Python/ONNX).\n\n`;
md += `- **Accuracy:** ${(accuracy * 100).toFixed(2)}%  ·  **Macro-F1:** ${(macroF1 * 100).toFixed(2)}%\n`;
md += `- Train/test: ${train.length}/${test.length} (stratified 80/20, seed ${SEED}) · Vocabulary: ${V} · Laplace α=${ALPHA}\n\n`;
md += `## Per-class\n\n| category | precision | recall | F1 | support |\n|---|---|---|---|---|\n`;
for (const p of perClass) md += `| ${p.c} | ${(p.precision * 100).toFixed(1)}% | ${(p.recall * 100).toFixed(1)}% | ${(p.f1 * 100).toFixed(1)}% | ${p.support} |\n`;
md += `\n## Confusion matrix (rows = true, cols = predicted)\n\n`;
md += `| | ${classes.map((c) => c.slice(0, 4)).join(' | ')} |\n|${'---|'.repeat(classes.length + 1)}\n`;
for (let i = 0; i < classes.length; i += 1) {
    md += `| **${classes[i].slice(0, 4)}** | ${confusion[i].join(' | ')} |\n`;
}
writeFileSync('research/nlp_metrics.md', md);
console.log('Wrote research/nlp_metrics.md');
