// SmartFix — Arabic urgency (severity) detector.
//
// Route 1: a lexicon-based NLP severity classifier. Reads the customer's
// free Arabic text (MSA + Egyptian dialect) and maps it to one of
// low | medium | high | emergency, plus a 0..1 score. Drives the triage
// urgency and the live pre-fill on the report screen, so the customer no
// longer has to leave urgency on the "medium" default.
//
// Why a lexicon (not the trained NB model): the research corpus
// (arabic_issues.jsonl) is labelled by CATEGORY only — it has no urgency
// labels — so urgency can't come from that model. This deterministic,
// explainable severity lexicon is the honest "Route 1" detector.
//
// The vocabulary is organised by the app's nine service categories
// (plumbing, electrical, carpentry, painting, hvac, cleaning,
// appliance_repair, welding, tiling) plus cross-cutting signals, so the
// detector behaves sensibly whatever trade the problem belongs to.

// ── Arabic normalisation ────────────────────────────────────────────────
// Strip diacritics/tatweel and unify alef/ya/hamza/ta-marbuta so spelling
// variants ("الكهرباء" / "الكهربا", "مياه" / "ميه", "طارئ" / "طارىء") all match.
export function normalizeAr(input) {
  return String(input || '')
    .replace(/[ً-ْٰـ]/g, '') // harakat + tatweel
    .replace(/[آأإٱ]/g, 'ا') // أ إ آ ٱ → ا
    .replace(/ة/g, 'ه') // ة → ه
    .replace(/ى/g, 'ي') // ى → ي
    .replace(/ؤ/g, 'و') // ؤ → و
    .replace(/ئ/g, 'ي') // ئ → ي
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

// ── EMERGENCY — danger to life/property, act now ────────────────────────
const EMERGENCY_AR = [
  // ── general danger ──
  'خطر', 'خطير جدا', 'خطورة', 'طوارئ', 'طارئ', 'اسعاف', 'نجدة', 'الحقوني',
  'مصيبه', 'كارثه', 'مش امان', 'مهدد', 'تهديد للحياه',
  // ── fire / smoke (any trade) ──
  'حريق', 'حرايق', 'نار', 'لهب', 'دخان', 'دخان كتير', 'بيطلع دخان', 'ريحة حريق',
  'ريحة احتراق', 'ريحه محروق', 'ولعت', 'بتولع', 'اشتعل', 'اشتعال', 'شب حريق',
  'شبه حريق', 'بيحترق', 'احترق',
  // ── electrical danger ──
  'ماس كهربائي', 'ماس كهربا', 'تماس كهربائي', 'تماس', 'شورت', 'شرارة', 'شرر',
  'بيشرر', 'بيطلع شرر', 'صعق', 'صعقه', 'اتصعق', 'بيكهرب', 'بتكهرب', 'فيها كهربا',
  'كهربا في الحديد', 'كهربا في المواسير', 'كهربا في الحيطه', 'لمست كهربا',
  'الكهربا فصلت كلها', 'الكابل بيشرر', 'البريزه بتولع', 'الفيش بيشرر', 'سلك بيشرر',
  // ── gas ──
  'تسريب غاز', 'تسرب غاز', 'ريحة غاز', 'ريحه بوتاجاز', 'شم غاز', 'شمين غاز',
  'الغاز بيخرج', 'اسطوانة غاز بتهرب', 'انبوبة غاز بتهرب', 'البوتاجاز بيطلع غاز',
  // ── explosion / burst ──
  'انفجار', 'انفجر', 'بينفجر', 'فرقعت', 'فرقعه', 'طرقعه', 'ماسورة انفجرت',
  'ماسورة فرقعت', 'المسخن انفجر', 'اسطوانه فرقعت',
  // ── flooding / major water (plumbing) ──
  'فيضان', 'غرق', 'غرقت', 'غرقانه', 'الميه غرقت', 'ميه في كل حته', 'طوفان',
  'مياه بتفور', 'مية بتفور', 'تسرب مياه غزير', 'تهريب مياه كبير', 'الشقه غرقانه',
  'الميه بتنزل من السقف', 'الميه طالعه من كل حته', 'الميه واصله للكهربا',
  // ── structural / falling (carpentry, tiling, welding) ──
  'انهيار', 'السقف بيقع', 'السقف وقع', 'الحيطه بتقع', 'الحيطه وقعت', 'شرخ كبير',
  'شرخ خطير', 'البلاط بيقع من السقف', 'السيراميك بيقع من فوق', 'الدولاب وقع',
  'الرف وقع', 'الباب وقع', 'السور بيقع', 'البوابه وقعت', 'الشرفه بتقع',
  // ── appliance danger ──
  'الجهاز بيطلع دخان', 'الغساله بتكهرب', 'السخان بيشرر', 'التلاجه بتكهرب',
  'الفرن بيطلع غاز', 'البوتاجاز بيشرر', 'الجهاز بيحترق',
  // ── hvac danger ──
  'التكييف بيطلع شرر', 'التكييف بيكهرب', 'ريحة حريق من التكييف', 'دخان من التكييف',
  // ── english fallbacks ──
  'fire', 'spark', 'gas', 'flood', 'smoke', 'shock', 'burst', 'short circuit',
  'electrocut', 'explosion', 'sewage flood', 'collapse',
];

// ── HIGH — needs attention today; service down, security/health, escalating ─
const HIGH_AR = [
  // ── explicit urgency words (cross-cutting) ──
  'عاجل', 'ضروري', 'بسرعه', 'مستعجل', 'مستعجله', 'محتاجه النهارده', 'لازم النهارده',
  'حالا', 'دلوقتي', 'في اسرع وقت', 'مش مستني', 'مش مستنيه', 'مش قادر استنى',
  'مع اطفال', 'مع عيال', 'مع كبار سن', 'مريض في البيت', 'عندي ضيوف',
  // ── no utilities ──
  'مفيش مياه', 'مفيش ميه', 'انقطعت المياه', 'المياه مقطوعه', 'الميه فصلت',
  'مقطوع المياه', 'مفيش كهربا', 'الكهربا فاصله', 'النور قطع', 'مفيش نور',
  'انقطعت الكهرباء', 'الكهرباء مقطوعه', 'مفيش مية سخنه', 'مفيش غاز',
  // ── broken / not working (generic) ──
  'مكسور', 'مكسوره', 'اتكسر', 'اتكسرت', 'بايظ', 'بايظه', 'خربان', 'خربانه',
  'مش شغال', 'مش بيشتغل', 'عاطل', 'واقف', 'وقف', 'مش بيفتح', 'مش بيقفل', 'اتعطل',
  // ── plumbing ──
  'تسريب', 'بيسرب', 'تسرب', 'تهريب', 'بيهرب', 'بيزيد', 'بيكبر', 'بيتفاقم',
  'المجاري طافحه', 'المجاري طلعت', 'ريحة مجاري', 'صرف مسدود', 'البلاعه طافحه',
  'البلاعه مسدوده', 'المرحاض طافح', 'السيفون طافح', 'السيفون مكسور', 'الحنفيه مكسوره',
  'بيقطر بغزاره', 'بيقطر كتير', 'التنقيط زاد', 'ميه بتطلع من تحت', 'رشح مياه',
  'رطوبه في الحيطه', 'عفن من المياه', 'السخان مش بيسخن', 'السخان بيهرب',
  // ── electrical ──
  'سلك مكشوف', 'اسلاك مكشوفه', 'البريزه بتسخن', 'القاطع بيفصل', 'الكهربا بتفصل',
  'الكهربا بتقطع', 'الطبلون بيفصل', 'الفيش بيسخن', 'اللمبه بتنور وتطفي',
  'انقطاع كهرباء متكرر', 'البريزه مش شغاله', 'المفتاح مش شغال',
  // ── carpentry / security ──
  'الباب مش بيقفل', 'القفل خربان', 'القفل باظ', 'القفل اتكسر', 'مش قادر اقفل',
  'الباب مفتوح', 'الباب مخلوع', 'الباب مش بيتفتح', 'الدولاب مايل', 'السرير اتكسر',
  'رجل الدولاب مكسوره', 'الشباك مش بيقفل',
  // ── hvac ──
  // Standalone fragments 'مش بيبرد'/'مش بتبرد' so an inserted trade noun
  // ("تكييف شباك مش بيبرد") doesn't break the contiguous-phrase match.
  'مش بيبرد', 'مش بتبرد', 'التكييف مش بيبرد', 'مفيش تبريد', 'التكييف بيقطر مية', 'الوحده بتسرب',
  'الكمبروسر واقف', 'التكييف بيفصل', 'صوت عالي من التكييف', 'الجو حر والتكييف باظ',
  'التكييف بيطفي لوحده',
  // ── appliance repair ──
  'التلاجه مش ساقعه', 'مش بتبرد', 'الاكل بيبوظ', 'الاكل سايح', 'الفريزر بيسيح',
  'الغساله بتسرب مية', 'الغساله مش بتعصر', 'الغساله مش بتشتغل', 'البوتاجاز مش بيولع',
  'الفرن مش بيسخن', 'الميكروويف واقف', 'الديب فريزر باظ',
  // ── welding / metalwork ──
  'مخلوع', 'مخلوعه', 'الباب الحديد مخلوع', 'الشباك الحديد اتكسر', 'الدرابزين مكسور',
  'البوابه مش بتقفل', 'السور مايل', 'كسر في الحديد', 'اللحام فك',
  // ── tiling ──
  'بلاط متشقق', 'سيراميك مكسور', 'بلاطه مرفوعه', 'البلاط فاضي من تحت', 'تطبيل البلاط',
  'سيراميك واقع', 'الرخامه اتكسرت',
  // ── painting (escalated: damp/mould) ──
  'رطوبه وعفن', 'بقع رطوبه كبيره', 'تساقط الدهان', 'الدهان بيقع', 'عفن منتشر',
  // ── cleaning (escalated: hazard / after-damage cleanups are not routine) ──
  'تنظيف بعد حريق', 'تنظيف بعد غرق', 'تنظيف بعد تسريب', 'ازاله مخلفات خطره',
  'تنظيف صرف صحي', 'نجاسه في كل مكان',
  // ── english fallbacks ──
  'no power', 'no water', 'leak', 'broken', 'not working', 'overflow', 'blocked',
  'exposed wire', 'tripping', 'urgent', 'not cooling',
];

// ── LOW — cosmetic/minor, explicitly can-wait ───────────────────────────
const LOW_AR = [
  // ── explicit "can wait" / negations (also fixes false-high on "مش مستعجل") ──
  'مش مستعجل', 'مش مستعجله', 'مش ضروري', 'مش ضروري دلوقتي', 'مش مهم اوي',
  'يستنى', 'يستنا', 'في وقتك', 'لما تيجي', 'في اي وقت', 'اي وقت يناسبك',
  'لما يتسهل', 'مفيش استعجال', 'براحتك', 'الاسبوع الجاي', 'الشهر الجاي', 'عادي',
  // ── minor / cosmetic (generic) ──
  'بسيط', 'بسيطه', 'حاجه بسيطه', 'شكلي', 'تجميلي', 'ديكور', 'منظر', 'صغير',
  'صغيره', 'خربشه', 'خدش', 'مش مستعجلين',
  // ── painting ──
  'لون باهت', 'تجديد دهان', 'شخبطه على الحيطه', 'خدش في الدهان', 'شويه تقشير',
  'تلوين', 'لمسات دهان', 'تظبيط لون',
  // ── carpentry ──
  'مفصله بتصوت', 'صرير في الباب', 'الدرج بيعلق', 'تلميع خشب', 'شمعه للباب',
  'تظبيط درج', 'خربشه في الخشب',
  // ── plumbing (minor) ──
  'حنفيه بتنقط بسيط', 'تنقيط خفيف', 'صوت في المواسير', 'تغيير شطافه', 'تركيب حنفيه',
  // ── electrical (minor) ──
  'لمبه محروقه', 'تركيب لمبه', 'اركب لمبه', 'تغيير مفتاح', 'بريزه عايزه تتركب',
  'تركيب نجفه',
  // ── installs / routine requests (generally non-urgent) ──
  // NB: only SPECIFIC install phrases live here (e.g. 'تركيب لمبه' above). The
  // bare nouns 'تركيب'/'تجديد'/'تشطيب' were removed — they matched ANY install/
  // renovation request and wrongly forced even an urgent one ("تركيب سخان في
  // اقرب وقت") to LOW. A plain service noun must fall through to medium, not low.
  'تجديد دهان كامل',
  // ── hvac (minor / routine) ──
  'صيانه تكييف', 'تنظيف فلتر', 'شحن فريون دوري', 'صيانه دوريه للتكييف',
  // ── appliance (minor) ──
  'صوت بسيط من الجهاز', 'صيانه دوريه', 'تغيير قطعه بسيطه', 'كشف على الجهاز',
  // ── tiling (minor) ──
  'جراوت متسخ', 'فاصل بسيط', 'بلاطه واحده', 'تلميع رخام', 'شرخ شعري بسيط',
  // ── welding (minor) ──
  'صدا بسيط', 'لحمه بسيطه', 'تعديل مفصله حديد', 'دهان حديد',
  // ── cleaning (mostly low/routine) ──
  'تنظيف عميق', 'نظافه بعد ترميم', 'تلميع', 'غسيل سجاد', 'تنظيف واجهه',
  'نظافه دوريه', 'تنظيف عادي', 'ترتيب', 'نظافه عاديه',
  // ── general routine ──
  // 'كشف'/'معاينه'/'استشاره' removed: an inspection/consult can still be urgent,
  // so a bare inspection noun must not force LOW.
  'تحسين',
  // ── english fallbacks ──
  'not urgent', 'whenever', 'minor', 'cosmetic', 'small', 'can wait', 'routine',
];

const URGENCY_RANK = { low: 0, medium: 1, high: 2, emergency: 3 };

function countHits(normText, list) {
  const matched = [];
  for (const w of list) {
    if (normText.includes(normalizeAr(w))) matched.push(w);
  }
  return matched;
}

/**
 * Detect urgency from free Arabic (or English) text.
 * @param {string} text
 * @returns {{ urgency: 'low'|'medium'|'high'|'emergency', score: number, matched: string[] }}
 */
export function detectUrgency(text) {
  const t = normalizeAr(text);
  if (!t) return { urgency: 'medium', score: 0.4, matched: [] };

  // Emergency wins outright — real danger overrides any "can wait" wording.
  const em = countHits(t, EMERGENCY_AR);
  if (em.length) {
    return { urgency: 'emergency', score: Math.min(1, 0.9 + 0.02 * em.length), matched: em };
  }

  // Negation handling: remove the explicit "can-wait" phrases (e.g. "مش
  // مستعجل") from the text BEFORE scanning for high signals, so the urgent
  // word embedded inside them ("مستعجل") can't trigger a false high.
  const lo = countHits(t, LOW_AR);
  let tHigh = t;
  for (const w of lo) tHigh = tHigh.split(normalizeAr(w)).join(' ');

  const hi = countHits(tHigh, HIGH_AR);
  if (hi.length) {
    return { urgency: 'high', score: Math.min(0.85, 0.65 + 0.04 * hi.length), matched: hi };
  }
  if (lo.length) {
    return { urgency: 'low', score: Math.max(0.1, 0.25 - 0.02 * lo.length), matched: lo };
  }
  return { urgency: 'medium', score: 0.4, matched: [] };
}

/** Return the more severe of two urgency labels (used as a safety upgrade). */
export function maxUrgency(a, b) {
  return (URGENCY_RANK[b] ?? 1) > (URGENCY_RANK[a] ?? 1) ? b : a;
}

export const URGENCY_LEVELS = ['low', 'medium', 'high', 'emergency'];

export default { detectUrgency, normalizeAr, maxUrgency, URGENCY_LEVELS };
