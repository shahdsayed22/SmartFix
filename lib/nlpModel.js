// Runtime serving for the trained Arabic category classifier (Multinomial NB).
// Statically imports the model JSON so Next/Vercel bundles it with the function
// (reliable, unlike a dynamic require). Exposes classify(text) matching the
// /api/nlp/classify contract, with the SAME feature extraction used in training.
import MODEL from './nlp_model.json';
import { extractFeatures } from './nlpFeatures.js';

const classes = Array.isArray(MODEL?.classes) ? MODEL.classes : [];
const available = classes.length > 0 && Array.isArray(MODEL?.logLik) && Array.isArray(MODEL?.logPrior);
const vIndex = new Map((MODEL?.vocab || []).map((f, i) => [f, i]));

/**
 * Classify free text into one of the 9 service categories.
 * @returns {{category:string, confidence:number, scores:object, matched:string[]}}
 */
export function classify(text) {
    if (!available) throw new Error('nlp model unavailable');
    const scores = MODEL.logPrior.slice();
    const matched = [];
    const seen = new Set();
    for (const f of extractFeatures(text)) {
        const idx = vIndex.get(f);
        if (idx === undefined) continue;
        for (let c = 0; c < classes.length; c += 1) scores[c] += MODEL.logLik[c][idx];
        if (f.startsWith('w:') && !seen.has(f)) { seen.add(f); matched.push(f.slice(2)); }
    }
    // argmax + softmax → a stable confidence in [0,1].
    let best = 0;
    for (let c = 1; c < classes.length; c += 1) if (scores[c] > scores[best]) best = c;
    const max = scores[best];
    let z = 0;
    const exps = scores.map((s) => { const e = Math.exp(s - max); z += e; return e; });
    const probs = {};
    classes.forEach((c, i) => { probs[c] = Math.round((exps[i] / z) * 1000) / 1000; });
    return {
        category: classes[best],
        confidence: Math.round((exps[best] / z) * 1000) / 1000,
        scores: probs,
        matched: matched.slice(0, 8),
    };
}

export const id = MODEL?.id || 'nb-arabic-v1';
export const metrics = MODEL?.metrics || null;
export default { id, classify, available, metrics };
