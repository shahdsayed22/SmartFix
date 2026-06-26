// Shared feature extraction for the trained Arabic text classifier.
// Used by BOTH the offline trainer (scripts/train-nlp.mjs) and the runtime
// classifier (lib/nlpModel.js) so features are produced identically — the same
// "must stay in sync" guarantee, but from a single source of truth.
//
// Reuses the project's canonical Arabic normalization (lib/nlp.js) so the
// classifier sees the same normalized text as the keyword heuristic.
import { normalizeArabic } from './nlp.js';

/**
 * Turn raw text into a bag of features:
 *   - word unigrams           → "w:كهرباء"
 *   - character n-grams (3-5) over the normalized string, word-boundary aware
 *     (spaces kept) → robust to Arabic morphology, prefixes/suffixes, and typos.
 * @param {string} text
 * @returns {string[]} feature tokens (with duplicates = term frequency)
 */
export function extractFeatures(text) {
    const norm = normalizeArabic(String(text || ''));
    const feats = [];

    // Word unigrams (>= 2 chars).
    for (const w of norm.split(/\s+/)) {
        if (w.length >= 2) feats.push('w:' + w);
    }

    // Character n-grams with word boundaries (' ' padding, single-spaced).
    const s = ' ' + norm.replace(/\s+/g, ' ').trim() + ' ';
    for (const n of [3, 4, 5]) {
        for (let i = 0; i + n <= s.length; i += 1) {
            feats.push('c:' + s.slice(i, i + n));
        }
    }
    return feats;
}

export default { extractFeatures };
