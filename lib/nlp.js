// SmartFix NLP module (Build Contract §1).
// Reusable Arabic-first category detection. The algorithm here MUST stay
// identical to the Dart mirror in lib/services/category_service.dart.

import { CATEGORIES, CATEGORY_KEYWORDS } from './categories.js';

/**
 * Supplemental keyword coverage layered on top of CATEGORY_KEYWORDS.
 * Kept here (not in categories.js) so the canonical taxonomy file and its
 * Dart mirror stay untouched while the JS heuristic gets broader recall.
 * Both Arabic and English are expanded per category. Merged + de-duped with
 * the base map at match time, so this is purely additive.
 */
const EXTRA_KEYWORDS = {
    plumbing: {
        ar: ['صنبور', 'بيبة', 'سيفون', 'مجاري', 'مجارى', 'انسداد', 'مسدود', 'مسدودة', 'تسليك', 'وصلة مياه', 'عوامة', 'خزان مياه', 'تنك', 'رشاش', 'دش', 'بانيو', 'بالوعه', 'تنقيط ماء', 'رطوبة'],
        en: ['clog', 'clogged', 'blockage', 'blocked', 'overflow', 'shower', 'bathtub', 'hose', 'cistern', 'tank', 'plumb', 'spigot', 'p-trap', 'sump', 'backflow', 'moisture'],
    },
    electrical: {
        ar: ['كهربائيه', 'لوحة كهرباء', 'طبلون', 'فاصل كهرباء', 'بريزة', 'بريزه', 'محول', 'عداد', 'وصلة كهرباء', 'صعق', 'تماس كهربائي', 'حريق كهربائي', 'بطارية', 'ترانس', 'كشاف', 'سخان كهرباء'],
        en: ['electrician', 'electrical', 'panel', 'fuse box', 'breaker box', 'short circuit', 'shock', 'transformer', 'meter', 'cabling', 'plug', 'amp', 'grounding', 'surge', 'flickering', 'dimmer'],
    },
    carpentry: {
        ar: ['نجاره', 'مقبض', 'يد الباب', 'مفصله', 'منجور', 'الواح خشب', 'لوح خشب', 'مكتب', 'وزرة', 'كومدينو', 'تركيب باب', 'صيانة باب', 'تركيب رف', 'بانوهات'],
        en: ['woodwork', 'joinery', 'handle', 'knob', 'plywood', 'desk', 'cupboard', 'closet', 'frame', 'molding', 'sawing', 'assemble furniture', 'sanding wood', 'panel'],
    },
    painting: {
        ar: ['دهانه', 'بوي', 'سقف', 'اسقف', 'معجون', 'سيلر', 'رشة دهان', 'لون الحائط', 'تجديد دهان', 'لاكيه', 'ورنيش', 'تشققات دهان'],
        en: ['painted', 'repainting', 'wall paint', 'ceiling', 'putty', 'sealer', 'varnish', 'lacquer', 'whitewash', 'undercoat', 'emulsion', 'peeling paint'],
    },
    hvac: {
        ar: ['مكيفات', 'تكييفات', 'كمبروسر تكييف', 'وحدة خارجية', 'وحده داخلية', 'فلتر تكييف', 'شحن فريون', 'تنقيط مكيف', 'تكييف لا يبرد', 'دفايه', 'تدفئة', 'سخونة الجو', 'ثرموستات'],
        en: ['air-con', 'aircon', 'climate control', 'thermostat', 'condenser', 'evaporator', 'duct', 'ducting', 'heater', 'furnace', 'chiller', 'coolant', 'not cooling', 'gas charge'],
    },
    cleaning: {
        ar: ['تنظيف منزل', 'تنظيف شقة', 'تلميع', 'كنس', 'مسح', 'إزالة بقع', 'تعقيم', 'تنظيف سجاد', 'تنظيف كنب', 'تنظيف زجاج', 'قمامة', 'وساخة', 'اوساخ'],
        en: ['cleaner', 'tidy', 'mop', 'vacuum', 'scrub', 'polish', 'disinfect', 'sanitise', 'carpet cleaning', 'window cleaning', 'sweep', 'declutter', 'grime', 'dirt'],
    },
    appliance_repair: {
        ar: ['غساله', 'ثلاجه', 'فريزر', 'سخان', 'بوتجاز', 'شفاط', 'مكنسة كهربائية', 'صيانة غسالة', 'صيانة ثلاجة', 'لا تعمل', 'عطل جهاز', 'سخان مياه كهربائي', 'تكييف شباك'],
        en: ['appliance repair', 'fridge repair', 'washer repair', 'cooktop', 'range', 'hood', 'extractor', 'kettle', 'blender', 'not spinning', 'not heating', 'broken appliance', 'water heater'],
    },
    welding: {
        ar: ['لحام حديد', 'تلحيم', 'شبك حديد', 'باب حديد', 'هيكل معدني', 'لحام استانلس', 'قص حديد', 'تكسير حديد', 'حداد', 'حدادة', 'مظلة حديد'],
        en: ['welder', 'soldering', 'brazing', 'fabricate', 'wrought iron', 'stainless', 'metalwork', 'rebar', 'grille', 'frame welding', 'cut metal', 'blacksmith'],
    },
    tiling: {
        ar: ['تركيب بلاط', 'تركيب سيراميك', 'بلاطة', 'بلاطات', 'كسر بلاط', 'فواصل بلاط', 'رخامة', 'ارضيات', 'تبليط', 'موزاييك', 'تجليخ رخام'],
        en: ['tiler', 'retile', 'flooring', 'mosaic', 'paver', 'slab', 'grouting', 'cracked tile', 'wall tile', 'floor tile', 'screed'],
    },
};

const ARABIC_DIACRITICS = /[ً-ْ]/g; // tashkeel: fathatan..sukun
const TATWEEL = /ـ/g; // ـ

/**
 * Normalize Arabic (and mixed) text before keyword matching.
 * Steps (must match the Dart implementation exactly):
 *  - lowercase
 *  - remove Arabic diacritics (tashkeel)
 *  - strip tatweel (ـ)
 *  - normalize alef forms: أ إ آ ٱ → ا
 *  - ى → ي, ة → ه, ؤ → و, ئ → ي
 *  - collapse whitespace
 */
export function normalizeArabic(str) {
    if (str == null) return '';
    let s = String(str).toLowerCase();
    s = s.replace(ARABIC_DIACRITICS, '');
    s = s.replace(TATWEEL, '');
    s = s.replace(/[أإآٱ]/g, 'ا'); // أ إ آ ٱ → ا
    s = s.replace(/ى/g, 'ي'); // ى → ي
    s = s.replace(/ة/g, 'ه'); // ة → ه
    s = s.replace(/ؤ/g, 'و'); // ؤ → و
    s = s.replace(/ئ/g, 'ي'); // ئ → ي
    s = s.replace(/\s+/g, ' ').trim();
    return s;
}

/**
 * Merge the canonical CATEGORY_KEYWORDS with the supplemental EXTRA_KEYWORDS,
 * de-duplicating by normalized form so a term added to both maps is counted once.
 * @returns {string[]} unique keyword surface forms for the category.
 */
function keywordsFor(key) {
    const base = CATEGORY_KEYWORDS[key] || { ar: [], en: [] };
    const extra = EXTRA_KEYWORDS[key] || { ar: [], en: [] };
    const all = [
        ...(base.ar || []), ...(base.en || []),
        ...(extra.ar || []), ...(extra.en || []),
    ];
    const seen = new Set();
    const out = [];
    for (const kw of all) {
        const needle = normalizeArabic(kw);
        if (!needle || seen.has(needle)) continue;
        seen.add(needle);
        out.push(kw);
    }
    return out;
}

/**
 * Detect a service category from free text.
 * @returns {{ category: string|null, confidence: number, scores: Object<string,number>, matched: string[] }}
 *
 * Algorithm: normalize text; for each category count keyword substring hits
 * (ar + en, base + supplemental, de-duped); category = argmax.
 * Confidence is a normalized softmax-style margin in [0,1] that rewards both
 * absolute evidence (more hits) and separation from the runner-up, instead of
 * the old min(1, topHits/3) which saturated abruptly and ignored competitors.
 * If topHits === 0 → category null, confidence 0. Ties → earlier in CATEGORIES order.
 */
export function detectCategory(text) {
    const normalized = normalizeArabic(text);
    const scores = {};
    const matched = [];

    let topCategory = null;
    let topHits = 0;
    let secondHits = 0;

    for (const key of CATEGORIES) {
        let hits = 0;
        for (const kw of keywordsFor(key)) {
            const needle = normalizeArabic(kw);
            if (needle && normalized.includes(needle)) {
                hits += 1;
                matched.push(kw);
            }
        }
        scores[key] = hits;
        // strict `>` keeps the earlier-in-order category on ties
        if (hits > topHits) {
            secondHits = topHits;
            topHits = hits;
            topCategory = key;
        } else if (hits > secondHits) {
            secondHits = hits;
        }
    }

    if (topHits === 0) {
        return { category: null, confidence: 0, scores, matched };
    }

    // Evidence term: saturates smoothly toward 1 as hits accumulate (1 hit≈0.5,
    // 2≈0.67, 3≈0.75, 4≈0.8…) rather than the old hard cap at 3 hits.
    const evidence = topHits / (topHits + 1);
    // Separation term: how dominant the winner is over the runner-up in [0,1].
    const separation = (topHits - secondHits) / topHits;
    // Blend, keeping a confidence floor so any clear single match reads as plausible.
    let confidence = evidence * (0.65 + 0.35 * separation);
    confidence = Math.max(0, Math.min(1, confidence));
    // Round to 4 dp for a stable, JSON-friendly value.
    confidence = Math.round(confidence * 1e4) / 1e4;

    return { category: topCategory, confidence, scores, matched };
}

// ── Decisive keyword boost (for short text) ─────────────────────────────
// High-PRECISION trade nouns: when one of these appears, the category is
// near-certain. The trained NB model struggles on 2-4 word inputs, so these
// override it on short / low-confidence text (e.g. «اركب لمبة» → electrical,
// «البلاط بيقع» → tiling). Kept deliberately unambiguous to avoid harming
// the model on longer, descriptive text.
const DECISIVE_KEYWORDS = {
    plumbing: ['ماسوره', 'مواسير', 'حنفيه', 'صنبور', 'مجاري', 'بلاعه', 'سيفون', 'مرحاض', 'تسريب مياه', 'شطافه', 'سباك', 'سباكه', 'محبس', 'خزان مياه', 'مية بتنقط'],
    electrical: ['لمبه', 'بريزه', 'فيشه', 'كهربا', 'كهرباء', 'كهربائي', 'سلك', 'اسلاك', 'مفتاح نور', 'قاطع', 'طبلون', 'عداد كهربا', 'نجفه'],
    carpentry: ['دولاب', 'خشب', 'نجار', 'نجاره', 'مفصله', 'سرير', 'كومدينو', 'باب خشب', 'رف خشب', 'درج خشب'],
    painting: ['دهان', 'بويه', 'طلاء', 'نقاش', 'محاره', 'معجون', 'رش دهان'],
    hvac: ['تكييف', 'مكيف', 'تبريد', 'فريون', 'كمبروسر', 'سبليت', 'شباك تكييف', 'دكت'],
    cleaning: ['تنظيف', 'نظافه', 'جلي', 'غسيل سجاد', 'تلميع ارضيات'],
    appliance_repair: ['غساله', 'تلاجه', 'ثلاجه', 'بوتاجاز', 'فرن', 'ميكروويف', 'سخان', 'ديب فريزر', 'مكنسه', 'غساله اطباق'],
    welding: ['لحام', 'حداد', 'حداده', 'حديد', 'بوابه', 'سور', 'درابزين', 'شبك حديد', 'استيل', 'مظله حديد'],
    tiling: ['بلاط', 'سيراميك', 'رخام', 'قيشاني', 'بورسلين', 'جرانيت', 'مبلط', 'فواصل بلاط'],
};

/**
 * Decisive trade-noun match for short-text correction.
 * @returns {{category:string, hits:number, matched:string[]}|null}
 */
export function boostCategory(text) {
    const t = normalizeArabic(text);
    if (!t) return null;
    let best = null;
    for (const [cat, words] of Object.entries(DECISIVE_KEYWORDS)) {
        const matched = [];
        for (const w of words) {
            if (t.includes(normalizeArabic(w))) matched.push(w);
        }
        if (matched.length && (!best || matched.length > best.hits)) {
            best = { category: cat, hits: matched.length, matched };
        }
    }
    return best;
}

/**
 * Blend a model prediction with the decisive keyword boost. Overrides the
 * model only when the boost disagrees AND the text is short, the model is
 * unsure, or the keyword signal is strong (>=2 hits).
 * @returns {{category, confidence, scores, matched, method}}
 */
export function applyKeywordBoost(modelOut, text) {
    const b = boostCategory(text);
    if (!b || b.category === modelOut.category) return modelOut;
    const words = normalizeArabic(text).split(' ').filter(Boolean).length;
    const isShort = words <= 4;
    const conf = typeof modelOut.confidence === 'number' ? modelOut.confidence : 0;
    if (b.hits >= 2 || isShort || conf < 0.6) {
        return {
            category: b.category,
            confidence: Math.max(conf, 0.7),
            scores: modelOut.scores || {},
            matched: b.matched,
            method: 'model+keyword',
        };
    }
    return modelOut;
}

export default { normalizeArabic, detectCategory, boostCategory, applyKeywordBoost };
