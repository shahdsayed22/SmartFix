/**
 * Export collected NLP training samples → JSONL, ready to append to
 * data/arabic_issues.jsonl and retrain the Arabic classifier.
 *
 * Usage:
 *   node --env-file=.env.local scripts/export-nlp-samples.mjs            # all
 *   node --env-file=.env.local scripts/export-nlp-samples.mjs --corrected # only user-corrected (high value)
 *
 * Then:
 *   cat data/collected_samples.jsonl >> data/arabic_issues.jsonl
 *   node scripts/train-nlp.mjs
 */
import { MongoClient } from 'mongodb';
import { writeFileSync } from 'node:fs';

const ONLY_CORRECTED = process.argv.includes('--corrected');

const uri = process.env.MONGODB_URI;
if (!uri) {
  console.error('✖ MONGODB_URI not set. Run with: node --env-file=.env.local scripts/export-nlp-samples.mjs');
  process.exit(1);
}

const client = new MongoClient(uri);
try {
  await client.connect();
  const db = client.db();
  const filter = ONLY_CORRECTED ? { corrected: true } : {};
  const samples = await db.collection('trainingsamples')
    .find(filter)
    .sort({ createdAt: 1 })
    .toArray();

  const seen = new Set();
  const lines = [];
  for (const s of samples) {
    if (!s.text || !s.category) continue;
    const key = `${s.text}${s.category}`;
    if (seen.has(key)) continue; // de-dup identical (text,label)
    seen.add(key);
    lines.push(JSON.stringify({ text: s.text, label: s.category }));
  }

  const out = 'data/collected_samples.jsonl';
  writeFileSync(out, lines.length ? lines.join('\n') + '\n' : '');
  console.log(`Exported ${lines.length} unique sample(s)${ONLY_CORRECTED ? ' (corrected only)' : ''} → ${out}`);
  console.log('Next: cat data/collected_samples.jsonl >> data/arabic_issues.jsonl && node scripts/train-nlp.mjs');
} finally {
  await client.close();
}
