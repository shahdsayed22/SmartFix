import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Dart mirror of the canonical service taxonomy (Build Contract §1).
///
/// This is the single source of truth for the 9 immutable category keys on the
/// Flutter side. It must stay byte-for-byte aligned with `lib/categories.js`,
/// `lib/nlp.js`, the Mongoose enums and `lib/theme/app_colors.dart`.
///
/// Keys (order = display order):
/// plumbing, electrical, carpentry, painting, hvac, cleaning,
/// appliance_repair, welding, tiling

/// Immutable description of one service category.
class CategoryInfo {
  /// Immutable snake_case key shared with the backend/Mongo enums.
  final String key;

  /// Arabic display label.
  final String labelAr;

  /// English display label.
  final String labelEn;

  /// Brand color pulled from [AppColors] (already matches §1 hex values).
  final Color color;

  /// Lucide icon name (informational; mapped to a Flutter icon at the UI layer).
  final String iconName;

  /// Default starting price in EGP.
  final int defaultPrice;

  /// Arabic keyword list used for NLP substring matching.
  final List<String> keywordsAr;

  /// English keyword list used for NLP substring matching.
  final List<String> keywordsEn;

  const CategoryInfo({
    required this.key,
    required this.labelAr,
    required this.labelEn,
    required this.color,
    required this.iconName,
    required this.defaultPrice,
    this.keywordsAr = const [],
    this.keywordsEn = const [],
  });

  /// Locale-aware label.
  String label(bool isEn) => isEn ? labelEn : labelAr;
}

/// Ordered list of categories (display order == §1 order).
const List<CategoryInfo> kCategories = [
  CategoryInfo(
    key: 'plumbing',
    labelAr: 'السباكة',
    labelEn: 'Plumbing',
    color: AppColors.plumbing,
    iconName: 'wrench',
    defaultPrice: 180,
    keywordsAr: [
      'حنفية', 'خلاط', 'ماسورة', 'مواسير', 'حوض', 'تسريب', 'تسرب', 'تنقيط',
      'تنقط', 'مياه', 'ميه', 'حمام', 'صرف', 'بالوعة', 'سباكة', 'سباك', 'محبس',
      'سخان مياه', 'مرحاض', 'شطاف',
    ],
    keywordsEn: [
      'faucet', 'tap', 'pipe', 'sink', 'leak', 'leaking', 'water', 'toilet',
      'drain', 'valve', 'plumber', 'plumbing', 'basin', 'flush', 'sewage',
      'dripping',
    ],
  ),
  CategoryInfo(
    key: 'electrical',
    labelAr: 'الكهرباء',
    labelEn: 'Electrical',
    color: AppColors.electrical,
    iconName: 'zap',
    defaultPrice: 200,
    keywordsAr: [
      'نور', 'لمبة', 'لمبه', 'مفتاح', 'فيشة', 'فيشه', 'مقبس', 'كهرباء', 'كهربا',
      'كهربائي', 'سلك', 'أسلاك', 'اسلاك', 'قاطع', 'شرر', 'شرارة', 'دائرة',
      'تماس', 'انقطاع التيار', 'نجفة', 'ماس كهربائي',
    ],
    keywordsEn: [
      'light', 'switch', 'socket', 'outlet', 'power', 'electricity', 'electric',
      'wire', 'wiring', 'breaker', 'fuse', 'spark', 'circuit', 'bulb', 'lamp',
      'voltage', 'outage',
    ],
  ),
  CategoryInfo(
    key: 'carpentry',
    labelAr: 'النجارة',
    labelEn: 'Carpentry',
    color: AppColors.carpentry,
    iconName: 'hammer',
    defaultPrice: 250,
    keywordsAr: [
      'باب', 'خشب', 'دولاب', 'خزانة', 'أثاث', 'اثاث', 'مفصلة', 'مفصلات', 'درج',
      'رف', 'طاولة', 'نجار', 'نجارة', 'ضلفة', 'قفل', 'كرسي', 'سرير',
    ],
    keywordsEn: [
      'door', 'wood', 'cabinet', 'furniture', 'hinge', 'drawer', 'shelf',
      'table', 'carpenter', 'carpentry', 'wardrobe', 'lock', 'chair', 'bed',
    ],
  ),
  CategoryInfo(
    key: 'painting',
    labelAr: 'الدهانات',
    labelEn: 'Painting',
    color: AppColors.painting,
    iconName: 'paint-roller',
    defaultPrice: 1200,
    keywordsAr: [
      'دهان', 'دهانات', 'حائط', 'جدار', 'جدران', 'لون', 'طلاء', 'نقاشة', 'نقاش',
      'بوية', 'تقشير', 'دهن',
    ],
    keywordsEn: [
      'paint', 'painting', 'wall', 'color', 'colour', 'repaint', 'primer',
      'coat', 'painter',
    ],
  ),
  CategoryInfo(
    key: 'hvac',
    labelAr: 'التكييف والتبريد',
    labelEn: 'HVAC',
    color: AppColors.hvac,
    iconName: 'wind',
    defaultPrice: 350,
    keywordsAr: [
      'تكييف', 'مكيف', 'تكيف', 'تبريد', 'فريون', 'تهوية', 'مروحة', 'سبليت',
      // bigram (window-AC) — bare 'شباك' leaked plain windows into HVAC.
      'تكييف شباك', 'شباك تكييف', 'كمبروسر', 'يبرد', 'لا يبرد', 'ثلاجة الهواء',
    ],
    keywordsEn: [
      'ac', 'air condition', 'air conditioner', 'air-conditioning', 'cooling',
      'hvac', 'freon', 'refrigerant', 'ventilation', 'fan', 'split',
      'compressor', 'heating',
    ],
  ),
  CategoryInfo(
    key: 'cleaning',
    labelAr: 'التنظيف',
    labelEn: 'Cleaning',
    color: AppColors.cleaning,
    iconName: 'spray-can',
    defaultPrice: 300,
    keywordsAr: [
      'تنظيف', 'نظافة', 'نظف', 'تنظيف عميق', 'غسيل', 'تطهير', 'أتربة', 'اتربة',
      'بقع', 'جلي',
    ],
    keywordsEn: [
      'clean', 'cleaning', 'deep cleaning', 'house cleaning', 'dust', 'wash',
      'sanitize', 'stain',
    ],
  ),
  CategoryInfo(
    key: 'appliance_repair',
    labelAr: 'صيانة الأجهزة',
    labelEn: 'Appliances',
    color: AppColors.applianceRepair,
    iconName: 'washing-machine',
    defaultPrice: 220,
    keywordsAr: [
      'غسالة', 'نشافة', 'غسالة أطباق', 'فرن', 'ثلاجة', 'ميكروويف', 'أجهزة',
      'اجهزة', 'صيانة أجهزة', 'بوتاجاز', 'سخان كهربائي', 'تعصر', 'لا تعصر',
      'ديب فريزر',
    ],
    keywordsEn: [
      'washing machine', 'washer', 'dryer', 'dishwasher', 'oven',
      'refrigerator', 'fridge', 'microwave', 'appliance', 'stove', 'freezer',
      'spin',
    ],
  ),
  CategoryInfo(
    key: 'welding',
    labelAr: 'اللحام',
    labelEn: 'Welding',
    color: AppColors.welding,
    iconName: 'flame',
    defaultPrice: 280,
    keywordsAr: [
      'لحام', 'حديد', 'بوابة', 'درابزين', 'معدن', 'صاج', 'سور', 'كسر معدن',
    ],
    keywordsEn: [
      'weld', 'welding', 'metal', 'gate', 'railing', 'steel', 'iron',
      'fabrication',
    ],
  ),
  CategoryInfo(
    key: 'tiling',
    labelAr: 'السيراميك والبلاط',
    labelEn: 'Tiling',
    color: AppColors.tiling,
    iconName: 'grid-3x3',
    defaultPrice: 900,
    keywordsAr: [
      'بلاط', 'سيراميك', 'أرضية', 'رخام', 'جرانيت', 'تجليط', 'بورسلين',
      'فاصل سيراميك', 'قيشاني',
    ],
    keywordsEn: [
      'tile', 'tiles', 'tiling', 'ceramic', 'floor', 'grout', 'marble',
      'granite', 'porcelain',
    ],
  ),
];

/// Ordered list of immutable category keys (== §1 order).
final List<String> kCategoryKeys = kCategories.map((c) => c.key).toList();

/// Key → [CategoryInfo] lookup.
final Map<String, CategoryInfo> kCategoryByKey = {
  for (final c in kCategories) c.key: c,
};

/// Returns the [CategoryInfo] for [key], or null if unknown.
CategoryInfo? categoryInfo(String? key) =>
    key == null ? null : kCategoryByKey[key];

/// Arabic label for a category key (falls back to the key itself).
String categoryLabelAr(String? key) => kCategoryByKey[key]?.labelAr ?? key ?? '';

/// English label for a category key (falls back to the key itself).
String categoryLabelEn(String? key) => kCategoryByKey[key]?.labelEn ?? key ?? '';

/// Default price (EGP) for a category key (0 if unknown).
int categoryDefaultPrice(String? key) => kCategoryByKey[key]?.defaultPrice ?? 0;

/// Brand color for a category key (falls back to [AppColors.primary]).
Color categoryColor(String? key) => kCategoryByKey[key]?.color ?? AppColors.primary;

// ── Arabic normalization (must be identical in JS `lib/nlp.js`) ──────────────

final RegExp _tashkeel = RegExp('[ً-ْ]'); // ً ٌ ٍ َ ُ ِ ّ ْ
final RegExp _tatweel = RegExp('ـ'); // ـ
final RegExp _whitespace = RegExp(r'\s+');

/// Normalize Arabic text before matching (Build Contract §1):
/// lowercase; remove diacritics (tashkeel); normalize
/// أ إ آ ٱ → ا, ى → ي, ة → ه, ؤ → و, ئ → ي; strip tatweel; collapse whitespace.
String normalizeArabic(String input) {
  var s = input.toLowerCase();
  s = s.replaceAll(_tashkeel, '');
  s = s.replaceAll(_tatweel, '');
  s = s
      .replaceAll('أ', 'ا') // أ → ا
      .replaceAll('إ', 'ا') // إ → ا
      .replaceAll('آ', 'ا') // آ → ا
      .replaceAll('ٱ', 'ا') // ٱ → ا
      .replaceAll('ى', 'ي') // ى → ي
      .replaceAll('ة', 'ه') // ة → ه
      .replaceAll('ؤ', 'و') // ؤ → و
      .replaceAll('ئ', 'ي'); // ئ → ي
  s = s.replaceAll(_whitespace, ' ').trim();
  return s;
}

/// Result of [detectCategory] — same shape as the JS `detectCategory` return.
class CategoryDetection {
  /// The argmax category key, or null when no keyword matched.
  final String? category;

  /// Confidence in 0..1 = min(1, topHits / 3).
  final double confidence;

  /// Per-category hit counts (only non-zero categories included to mirror JS,
  /// but all keys are present for convenience).
  final Map<String, int> scores;

  /// The list of matched keywords (across categories).
  final List<String> matched;

  const CategoryDetection({
    required this.category,
    required this.confidence,
    required this.scores,
    required this.matched,
  });

  /// Convenience: `key` alias used in some callers per the contract shape.
  String? get key => category;

  Map<String, dynamic> toJson() => {
        'category': category,
        'confidence': confidence,
        'scores': scores,
        'matched': matched,
      };
}

/// Detect the most likely category for free-text [text] (Build Contract §1).
///
/// Algorithm (identical to `lib/nlp.js`):
// ── Decisive keyword boost (mirror of lib/nlp.js DECISIVE_KEYWORDS) ──────
// High-precision trade nouns. When present, the category is near-certain —
// used to correct the on-device argmax on short text, so the instant offline
// guess matches the server's model+keyword layer.
const Map<String, List<String>> _kDecisiveKeywords = {
  'plumbing': ['ماسوره', 'مواسير', 'حنفيه', 'صنبور', 'مجاري', 'بلاعه', 'سيفون',
      'مرحاض', 'تسريب مياه', 'شطافه', 'سباك', 'سباكه', 'محبس', 'خزان مياه',
      'مية بتنقط'],
  'electrical': ['لمبه', 'بريزه', 'فيشه', 'كهربا', 'كهرباء', 'كهربائي', 'سلك',
      'اسلاك', 'مفتاح نور', 'قاطع', 'طبلون', 'عداد كهربا', 'نجفه'],
  'carpentry': ['دولاب', 'خشب', 'نجار', 'نجاره', 'مفصله', 'سرير', 'كومدينو',
      'باب خشب', 'رف خشب', 'درج خشب'],
  'painting': ['دهان', 'بويه', 'طلاء', 'نقاش', 'محاره', 'معجون', 'رش دهان'],
  'hvac': ['تكييف', 'مكيف', 'تبريد', 'فريون', 'كمبروسر', 'سبليت', 'شباك تكييف',
      'دكت'],
  'cleaning': ['تنظيف', 'نظافه', 'جلي', 'غسيل سجاد', 'تلميع ارضيات'],
  'appliance_repair': ['غساله', 'تلاجه', 'ثلاجه', 'بوتاجاز', 'فرن', 'ميكروويف',
      'سخان', 'ديب فريزر', 'مكنسه', 'غساله اطباق'],
  'welding': ['لحام', 'حداد', 'حداده', 'حديد', 'بوابه', 'سور', 'درابزين',
      'شبك حديد', 'استيل', 'مظله حديد'],
  'tiling': ['بلاط', 'سيراميك', 'رخام', 'قيشاني', 'بورسلين', 'جرانيت', 'مبلط',
      'فواصل بلاط'],
};

class _DecisiveMatch {
  final String key;
  final int hits;
  final List<String> matched;
  const _DecisiveMatch(this.key, this.hits, this.matched);
}

/// Best decisive trade-noun match over already-normalized text, or null.
_DecisiveMatch? _boostCategory(String normalized) {
  if (normalized.isEmpty) return null;
  _DecisiveMatch? best;
  _kDecisiveKeywords.forEach((key, words) {
    final matched = <String>[];
    for (final w in words) {
      if (normalized.contains(normalizeArabic(w))) matched.add(w);
    }
    if (matched.isNotEmpty && (best == null || matched.length > best!.hits)) {
      best = _DecisiveMatch(key, matched.length, matched);
    }
  });
  return best;
}

/// 1. normalize text;
/// 2. for each category count keyword substring hits (ar + en);
/// 3. category = argmax; confidence = min(1, topHits / 3);
/// 4. decisive keyword boost corrects the argmax on short / weak text;
/// 5. if topHits == 0 and no boost → category null, confidence 0;
/// 6. ties → earlier in CATEGORY order.
CategoryDetection detectCategory(String text) {
  final normalized = normalizeArabic(text);
  final scores = <String, int>{};
  final matched = <String>[];

  for (final c in kCategories) {
    var hits = 0;
    for (final kw in c.keywordsAr) {
      if (normalized.contains(normalizeArabic(kw))) {
        hits++;
        matched.add(kw);
      }
    }
    for (final kw in c.keywordsEn) {
      if (normalized.contains(kw.toLowerCase())) {
        hits++;
        matched.add(kw);
      }
    }
    scores[c.key] = hits;
  }

  // argmax with stable order (kCategories is already in §1 order).
  String? best;
  var topHits = 0;
  var secondHits = 0;
  for (final c in kCategories) {
    final h = scores[c.key] ?? 0;
    if (h > topHits) {
      secondHits = topHits;
      topHits = h;
      best = c.key;
    } else if (h > secondHits) {
      secondHits = h;
    }
  }

  // Decisive keyword boost: a high-precision trade noun corrects the argmax on
  // short / weak text, and rescues the case where no category keyword matched.
  final boost = _boostCategory(normalized);
  final wordCount = normalized.split(' ').where((w) => w.isNotEmpty).length;
  final isShort = wordCount <= 4;
  if (boost != null &&
      boost.key != best &&
      (boost.hits >= 2 || isShort || topHits <= 1)) {
    return CategoryDetection(
      category: boost.key,
      confidence: 0.7,
      scores: scores,
      matched: boost.matched,
    );
  }

  if (topHits == 0) {
    return CategoryDetection(
      category: null,
      confidence: 0,
      scores: scores,
      matched: matched,
    );
  }

  // Mirror lib/nlp.js: a smoothed evidence × separation blend (rewards both
  // absolute evidence and dominance over the runner-up), not the old min(1,
  // topHits/3) which saturated abruptly and ignored competitors.
  final evidence = topHits / (topHits + 1);
  final separation = (topHits - secondHits) / topHits;
  var confidence = evidence * (0.65 + 0.35 * separation);
  confidence = confidence.clamp(0.0, 1.0);
  confidence = (confidence * 10000).round() / 10000;
  return CategoryDetection(
    category: best,
    confidence: confidence,
    scores: scores,
    matched: matched,
  );
}

/// Per-category suggested description placeholder (AR/EN), shown as the hint in
/// the issue-writing field so each trade gets a relevant, concrete example
/// instead of one generic plumbing-flavoured prompt.
const Map<String, List<String>> _kCategoryHints = {
  // key: [arabic, english]
  'plumbing': [
    'مثال: تسريب من ماسورة تحت حوض المطبخ بدأ من يومين ويبلّل الأرضية…',
    'e.g. A pipe under the kitchen sink has been leaking for two days and wetting the floor…',
  ],
  'electrical': [
    'مثال: انقطاع الكهرباء في غرفة النوم، البريزة لا تعمل والقاطع يفصل باستمرار…',
    'e.g. No power in the bedroom, the socket is dead and the breaker keeps tripping…',
  ],
  'carpentry': [
    'مثال: باب الدولاب مخلوع من المفصلة ولا يغلق جيدًا…',
    'e.g. The cabinet door is off its hinge and won’t close properly…',
  ],
  'painting': [
    'مثال: تقشير دهان وبقع رطوبة في سقف الصالة بمساحة حوالي مترين…',
    'e.g. Peeling paint and damp patches on the living-room ceiling, about 2 m²…',
  ],
  'hvac': [
    'مثال: التكييف لا يبرّد جيدًا ويصدر صوتًا ويسرّب مياه من الوحدة الداخلية…',
    'e.g. The AC isn’t cooling well, makes noise and leaks water from the indoor unit…',
  ],
  'cleaning': [
    'مثال: تنظيف شامل لشقة ٣ غرف بعد التشطيب، يشمل الزجاج والأرضيات…',
    'e.g. Full cleaning of a 3-room flat after renovation, including windows and floors…',
  ],
  'appliance_repair': [
    'مثال: الغسالة لا تدور ولا تصرّف المياه وتصدر صوتًا عاليًا…',
    'e.g. The washing machine won’t spin or drain and makes a loud noise…',
  ],
  'welding': [
    'مثال: بوابة حديد مكسورة عند المفصلة وتحتاج لحام وتثبيت…',
    'e.g. A steel gate is broken at the hinge and needs welding and refitting…',
  ],
  'tiling': [
    'مثال: عدد من بلاطات السيراميك مرتفعة وفارغة من تحت في المطبخ…',
    'e.g. Several ceramic tiles in the kitchen are lifting and hollow underneath…',
  ],
};

/// Suggested description placeholder for [key] in the active locale; falls back
/// to a generic prompt when the category is unknown/unselected.
String categoryDescriptionHint(String? key, bool isEn) {
  final h = key == null ? null : _kCategoryHints[key];
  if (h == null) {
    return isEn
        ? 'Describe the problem in detail — when it started and what you noticed…'
        : 'اشرح المشكلة بالتفصيل — متى بدأت وما الذي لاحظته…';
  }
  return isEn ? h[1] : h[0];
}
