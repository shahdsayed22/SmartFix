import { NextResponse } from 'next/server';
import { detectCategory, applyKeywordBoost } from '@/lib/nlp';
import { detectUrgency } from '@/lib/urgency';
import trainedModel from '@/lib/nlpModel';

/*
 * NLP triage classifier endpoint.
 *
 * Model-serving scaffold:
 *   - If process.env.NLP_MODEL_PATH is set, we attempt to lazily load a trained
 *     artifact at that path (a CommonJS/ESM module exporting a `classify(text)`
 *     or a default callable). The require/load and the inference call are BOTH
 *     guarded in try/catch — on ANY failure we transparently fall back to the
 *     heuristic. This keeps deploys safe even with a missing/broken artifact.
 *   - Otherwise we use the improved keyword heuristic from '@/lib/nlp'.
 *
 * Response shape is backward-compatible:
 *   { category, confidence, scores, matched, method }
 *   `method` is the model id (or 'heuristic') so callers can attribute results.
 */

// Cache the resolved model across requests within a server instance.
// `undefined` = not attempted yet; `null` = attempted and unavailable.
let _model = undefined;
let _modelId = null;

async function loadModel() {
    if (_model !== undefined) return _model;
    // 1) Preferred: the statically-bundled trained model (reliable on Vercel).
    try {
        if (trainedModel?.available && typeof trainedModel.classify === 'function') {
            _modelId = trainedModel.id || 'nlp-model';
            _model = { classify: trainedModel.classify };
            return _model;
        }
    } catch {
        // fall through to the optional external artifact / heuristic
    }
    // 2) Optional override: an external artifact at NLP_MODEL_PATH.
    const path = process.env.NLP_MODEL_PATH;
    if (!path) {
        _model = null;
        return _model;
    }
    try {
        // Lazy, guarded load. Avoid bundler static analysis on the dynamic path.
        // eslint-disable-next-line no-eval
        const req = eval('require');
        const artifact = req(path);
        const mod = artifact && artifact.default ? artifact.default : artifact;
        const classify =
            typeof mod === 'function' ? mod
            : typeof mod?.classify === 'function' ? mod.classify.bind(mod)
            : null;
        if (!classify) throw new Error('artifact exposes no classify()');
        _modelId = String(mod?.id || mod?.name || process.env.NLP_MODEL_ID || 'nlp-model');
        _model = { classify };
        return _model;
    } catch (err) {
        // Any failure → permanently fall back to the heuristic for this instance.
        console.warn(`[nlp/classify] model load failed for "${path}", using heuristic:`, err?.message || err);
        _model = null;
        return _model;
    }
}

function withMethod(result, method, urg) {
    return {
        category: result.category ?? null,
        confidence: typeof result.confidence === 'number' ? result.confidence : 0,
        scores: result.scores || {},
        matched: Array.isArray(result.matched) ? result.matched : [],
        method,
        // Lexicon-based Arabic urgency detection (independent of the category
        // model). Lets the report screen pre-fill urgency from the description.
        urgency: urg?.urgency ?? 'medium',
        urgencyScore: typeof urg?.score === 'number' ? urg.score : 0.4,
        urgencyMatched: Array.isArray(urg?.matched) ? urg.matched : [],
    };
}

export async function POST(request) {
    let text = '';
    try {
        const body = await request.json();
        text = typeof body?.text === 'string' ? body.text : '';
    } catch {
        return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
    }

    if (!text.trim()) {
        return NextResponse.json({ error: 'Field "text" is required' }, { status: 400 });
    }

    // Urgency is detected by the Arabic severity lexicon regardless of which
    // category path runs below.
    const urg = detectUrgency(text);

    // Try the trained-model path first (guarded). Fall back to the heuristic.
    const model = await loadModel();
    if (model) {
        try {
            const out = await model.classify(text);
            if (out && (out.category !== undefined || out.scores)) {
                // Correct the model on short / low-confidence text using the
                // decisive trade-noun keyword boost.
                const finalOut = applyKeywordBoost(out, text);
                return NextResponse.json(
                    withMethod(finalOut, finalOut.method || _modelId || 'nlp-model', urg),
                );
            }
            throw new Error('model returned an unusable result');
        } catch (err) {
            console.warn('[nlp/classify] model inference failed, using heuristic:', err?.message || err);
            // fall through to heuristic
        }
    }

    try {
        const result = applyKeywordBoost(detectCategory(text), text);
        return NextResponse.json(withMethod(result, result.method || 'heuristic', urg));
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}
