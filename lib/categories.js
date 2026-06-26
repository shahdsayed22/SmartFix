import {
    Wrench, Zap, Hammer, Paintbrush, Wind, SprayCan,
    Settings, Flame, Grid3X3,
} from 'lucide-react';

export const CATEGORIES = [
    'plumbing', 'electrical', 'carpentry', 'painting',
    'hvac', 'cleaning', 'appliance_repair', 'welding', 'tiling',
];

export const CATEGORY_CONFIG = {
    plumbing: { label: 'Plumbing', icon: Wrench, color: '#3b82f6' },
    electrical: { label: 'Electrical', icon: Zap, color: '#f59e0b' },
    carpentry: { label: 'Carpentry', icon: Hammer, color: '#10b981' },
    painting: { label: 'Painting', icon: Paintbrush, color: '#a855f7' },
    hvac: { label: 'HVAC', icon: Wind, color: '#06b6d4' },
    cleaning: { label: 'Cleaning', icon: SprayCan, color: '#ec4899' },
    appliance_repair: { label: 'Appliance Repair', icon: Settings, color: '#f97316' },
    welding: { label: 'Welding', icon: Flame, color: '#ef4444' },
    tiling: { label: 'Tiling', icon: Grid3X3, color: '#14b8a6' },
};

export function getCategoryIcon(category) {
    return CATEGORY_CONFIG[category]?.icon || Wrench;
}

export function getCategoryLabel(category) {
    return CATEGORY_CONFIG[category]?.label || category;
}

export function getCategoryColor(category) {
    return CATEGORY_CONFIG[category]?.color || '#6366f1';
}

// --- Arabic-first taxonomy additions (Build Contract §1) ---

// Arabic display labels, keyed by canonical category key.
export const CATEGORY_LABELS_AR = {
    plumbing: 'السباكة',
    electrical: 'الكهرباء',
    carpentry: 'النجارة',
    painting: 'الدهانات',
    hvac: 'التكييف والتبريد',
    cleaning: 'التنظيف',
    appliance_repair: 'صيانة الأجهزة',
    welding: 'اللحام',
    tiling: 'السيراميك والبلاط',
};

// Default starting price (EGP) per category.
export const CATEGORY_DEFAULT_PRICE = {
    plumbing: 180,
    electrical: 200,
    carpentry: 250,
    painting: 1200,
    hvac: 350,
    cleaning: 300,
    appliance_repair: 220,
    welding: 280,
    tiling: 900,
};

// Keyword maps for NLP category detection (expandable — add more freely).
// Each category has Arabic (`ar`) + English (`en`) substring keywords.
export const CATEGORY_KEYWORDS = {
    plumbing: {
        ar: ['حنفية', 'خلاط', 'ماسورة', 'مواسير', 'حوض', 'تسريب', 'تسرب', 'تنقيط', 'تنقط', 'مياه', 'ميه', 'حمام', 'صرف', 'بالوعة', 'سباكة', 'سباك', 'محبس', 'سخان مياه', 'مرحاض', 'شطاف'],
        en: ['faucet', 'tap', 'pipe', 'sink', 'leak', 'leaking', 'water', 'toilet', 'drain', 'valve', 'plumber', 'plumbing', 'basin', 'flush', 'sewage', 'dripping'],
    },
    electrical: {
        ar: ['نور', 'لمبة', 'لمبه', 'مفتاح', 'فيشة', 'فيشه', 'مقبس', 'كهرباء', 'كهربا', 'كهربائي', 'سلك', 'أسلاك', 'اسلاك', 'قاطع', 'شرر', 'شرارة', 'دائرة', 'تماس', 'انقطاع التيار', 'نجفة', 'ماس كهربائي'],
        en: ['light', 'switch', 'socket', 'outlet', 'power', 'electricity', 'electric', 'wire', 'wiring', 'breaker', 'fuse', 'spark', 'circuit', 'bulb', 'lamp', 'voltage', 'outage'],
    },
    carpentry: {
        ar: ['باب', 'خشب', 'دولاب', 'خزانة', 'أثاث', 'اثاث', 'مفصلة', 'مفصلات', 'درج', 'رف', 'طاولة', 'نجار', 'نجارة', 'ضلفة', 'قفل', 'كرسي', 'سرير'],
        en: ['door', 'wood', 'cabinet', 'furniture', 'hinge', 'drawer', 'shelf', 'table', 'carpenter', 'carpentry', 'wardrobe', 'lock', 'chair', 'bed'],
    },
    painting: {
        ar: ['دهان', 'دهانات', 'حائط', 'جدار', 'جدران', 'لون', 'طلاء', 'نقاشة', 'نقاش', 'بوية', 'تقشير', 'دهن'],
        en: ['paint', 'painting', 'wall', 'color', 'colour', 'repaint', 'primer', 'coat', 'painter'],
    },
    hvac: {
        // 'شباك' alone (window) leaked carpentry/window jobs into HVAC; require
        // the bigram 'تكييف شباك' / 'شباك تكييف' (window-AC) instead.
        ar: ['تكييف', 'مكيف', 'تكيف', 'تبريد', 'فريون', 'تهوية', 'مروحة', 'سبليت', 'تكييف شباك', 'شباك تكييف', 'كمبروسر', 'يبرد', 'لا يبرد', 'ثلاجة الهواء'],
        en: ['ac', 'air condition', 'air conditioner', 'air-conditioning', 'cooling', 'hvac', 'freon', 'refrigerant', 'ventilation', 'fan', 'split', 'compressor', 'heating'],
    },
    cleaning: {
        ar: ['تنظيف', 'نظافة', 'نظف', 'تنظيف عميق', 'غسيل', 'تطهير', 'أتربة', 'اتربة', 'بقع', 'جلي'],
        en: ['clean', 'cleaning', 'deep cleaning', 'house cleaning', 'dust', 'wash', 'sanitize', 'stain'],
    },
    appliance_repair: {
        ar: ['غسالة', 'نشافة', 'غسالة أطباق', 'فرن', 'ثلاجة', 'ميكروويف', 'أجهزة', 'اجهزة', 'صيانة أجهزة', 'بوتاجاز', 'سخان كهربائي', 'تعصر', 'لا تعصر', 'ديب فريزر'],
        en: ['washing machine', 'washer', 'dryer', 'dishwasher', 'oven', 'refrigerator', 'fridge', 'microwave', 'appliance', 'stove', 'freezer', 'spin'],
    },
    welding: {
        ar: ['لحام', 'حديد', 'بوابة', 'درابزين', 'معدن', 'صاج', 'سور', 'كسر معدن'],
        en: ['weld', 'welding', 'metal', 'gate', 'railing', 'steel', 'iron', 'fabrication'],
    },
    tiling: {
        ar: ['بلاط', 'سيراميك', 'أرضية', 'رخام', 'جرانيت', 'تجليط', 'بورسلين', 'فاصل سيراميك', 'قيشاني'],
        en: ['tile', 'tiles', 'tiling', 'ceramic', 'floor', 'grout', 'marble', 'granite', 'porcelain'],
    },
};

export function getCategoryLabelAr(category) {
    return CATEGORY_LABELS_AR[category] || category;
}

export function getCategoryDefaultPrice(category) {
    return CATEGORY_DEFAULT_PRICE[category] ?? 0;
}
