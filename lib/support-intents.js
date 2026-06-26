// Deterministic support engine — the always-on baseline brain (no API key, no
// cost, works offline / on the LAN demo). It classifies the user's last message
// into a support intent, decides what live data to fetch, and composes a
// bilingual (AR/EN) grounded answer. The route (app/api/support-chat) wires this
// to the shared lookups in lib/support-data.js.

import { normalizeArabic } from '@/lib/nlp.js';

// ── Intent keyword lexicons (Arabic + English). Order = tie-break priority:
// more specific intents come first so e.g. "refund" beats generic "payment".
const INTENTS = [
    { intent: 'escalate', kw: ['موظف', 'بشري', 'انسان', 'اتكلم مع حد', 'اكلم حد', 'اكلم الدعم', 'كلم الدعم', 'حد يساعدني', 'محتاج اكلم', 'تحويل', 'خدمة العملاء', 'human', 'agent', 'representative', 'talk to someone', 'support team', 'live agent'] },
    { intent: 'ticket_status', kw: ['تذكرتي', 'تذكره الدعم', 'رقم التذكره', 'حالة التذكره', 'حالة تذكرتي', 'رقم البلاغ', 'رقم الدعم', 'tkt', 'ticket number', 'ticket status', 'my ticket', 'support ticket', 'track ticket'] },
    { intent: 'refund', kw: ['استرداد', 'استرجاع', 'رجعو فلوسي', 'رجع فلوس', 'ارجاع', 'refund', 'money back', 'return my money', 'chargeback'] },
    { intent: 'money_deducted', kw: ['اتخصمت', 'خصمت', 'اتسحبت', 'اتخصم', 'خصم فلوس', 'اتدفع وما', 'deducted', 'charged but', 'took money', 'money gone', 'debited'] },
    { intent: 'fees_vat', kw: ['ضريبه', 'ضريبة', 'رسوم', 'عموله', 'عمولة', 'vat', 'fee', 'fees', 'commission', 'tax'] },
    { intent: 'withdrawal', kw: ['سحب', 'اسحب', 'اسحب ارباحي', 'withdraw', 'withdrawal', 'cash out', 'payout'] },
    { intent: 'wallet', kw: ['محفظه', 'محفظة', 'رصيد', 'رصيدي', 'ارباحي', 'wallet', 'balance', 'earnings'] },
    { intent: 'verification', kw: ['توثيق', 'موثق', 'تحقق', 'حسابي موثق', 'verification', 'verify', 'verified', 'account approval'] },
    { intent: 'booking', kw: ['ازاي احجز', 'كيف احجز', 'احجز', 'اطلب خدمه', 'اطلب فني', 'اعمل طلب', 'ابلغ عن مشكله', 'تقديم بلاغ', 'عايز فني', 'كيف اطلب', 'how to book', 'book a', 'request service', 'new request', 'create request', 'order a technician', 'need a technician'] },
    { intent: 'cancellation', kw: ['الغاء', 'الغي الطلب', 'الغيت', 'الغاء الطلب', 'عايز الغي', 'رسوم الالغاء', 'cancel', 'cancellation', 'cancel request', 'cancel my order'] },
    { intent: 'offers', kw: ['عرض السعر', 'العروض', 'عروض', 'اقبل العرض', 'ارفض العرض', 'سعر العرض', 'كوبون', 'كود خصم', 'بروموكود', 'offer', 'offers', 'accept offer', 'decline offer', 'promo', 'coupon', 'discount code'] },
    { intent: 'worker_assignment', kw: ['مين الفني', 'الفني المسؤول', 'تغيير الفني', 'مفيش فني', 'لسه ماتعينش فني', 'لم يتم تعيين', 'who is my technician', 'which technician', 'change technician', 'no technician', 'assign technician'] },
    { intent: 'tracking', kw: ['وين الفني', 'فين الفني', 'الفني وصل', 'تتبع الفني', 'تتبع طلبي', 'مكان الفني', 'متى يوصل', 'الوقت المتوقع', 'وصول الفني', 'track technician', 'where is the technician', 'eta', 'arrival time'] },
    { intent: 'account', kw: ['حسابي', 'تعديل بياناتي', 'تغيير رقم', 'تغيير كلمه المرور', 'تغيير الايميل', 'تعديل العنوان', 'مشكله تسجيل الدخول', 'نسيت كلمه', 'حذف الحساب', 'account', 'profile', 'change password', 'update profile', 'login problem', 'reset password', 'my address', 'delete account'] },
    { intent: 'how_to_approve', kw: ['اوافق', 'موافقه', 'موافقة', 'اؤكد', 'اكد العمل', 'اعتماد العمل', 'approve', 'confirm', 'accept work', 'how do i confirm'] },
    { intent: 'dispute', kw: ['ارفض', 'رفض', 'مش راضي', 'مش عاجبني', 'شكوى', 'اشتكي', 'شكوي', 'reject', 'dispute', 'complain', 'complaint', 'not satisfied', 'redo'] },
    { intent: 'rating', kw: ['تقييم', 'اقيم', 'نجوم', 'rate', 'rating', 'review', 'stars'] },
    { intent: 'payment_status', kw: ['دفع', 'الدفع', 'فاتوره', 'فاتورة', 'بطاقه', 'بطاقة', 'فيزا', 'payment', 'pay', 'paid', 'pending', 'invoice', 'transaction', 'card', 'fawry', 'meeza'] },
    { intent: 'job_status', kw: ['طلبي', 'حالة الطلب', 'وصل', 'البلاغ', 'الوظيفه', 'الوظيفة', 'الفني', 'order', 'request', 'job', 'status', 'where is', 'track', 'technician'] },
    { intent: 'greeting', kw: ['مرحبا', 'اهلا', 'هاي', 'سلام', 'hi', 'hello', 'hey'] },
];

// A support ticket number looks like TKT-XXXXXX. When the user pastes one, we
// treat the turn as a ticket-status lookup regardless of the surrounding words.
const TICKET_RE = /TKT-?[A-Z0-9]{4,}/i;
export function extractTicketNumber(text) {
    const m = String(text || '').toUpperCase().match(TICKET_RE);
    if (!m) return '';
    const raw = m[0].replace(/^TKT-?/, '');
    return `TKT-${raw}`;
}

/**
 * Detect the dominant script of the user's message so the assistant can reply
 * in the language they actually typed — Arabic OR English — regardless of the
 * app's language toggle. Returns 'ar' | 'en' | null (no letters → no signal).
 */
export function detectMessageLang(text) {
    const s = String(text || '');
    const arabic = (s.match(/[؀-ۿ]/g) || []).length;
    const latin = (s.match(/[A-Za-z]/g) || []).length;
    if (arabic === 0 && latin === 0) return null;
    return arabic >= latin ? 'ar' : 'en';
}

/** Classify free text → { intent, score }. Falls back to 'unknown'. */
export function detectSupportIntent(text) {
    const norm = normalizeArabic(text || '');
    const low = String(text || '').toLowerCase();
    let best = { intent: 'unknown', score: 0 };
    for (const { intent, kw } of INTENTS) {
        let hits = 0;
        for (const k of kw) {
            const nk = normalizeArabic(k);
            if ((nk && norm.includes(nk)) || low.includes(k.toLowerCase())) hits++;
        }
        if (hits > best.score) best = { intent, score: hits };
    }
    return best;
}

/** What live data this intent needs the route to fetch. */
export function intentNeeds(intent) {
    switch (intent) {
        case 'job_status':
        case 'how_to_approve':
        case 'dispute':
        case 'rating':
        case 'tracking':
        case 'worker_assignment':
        case 'cancellation':
            return 'job';
        case 'payment_status':
        case 'money_deducted':
        case 'fees_vat':
        case 'refund':
            return 'payment';
        case 'wallet':
        case 'withdrawal':
            return 'wallet';
        case 'verification':
            return 'verification';
        case 'ticket_status':
            return 'ticket';
        default:
            return null;
    }
}

const pick = (lang, ar, en) => (lang === 'en' ? en : ar);
const money = (n, cur, lang) => `${Number(n || 0).toLocaleString(lang === 'en' ? 'en-US' : 'ar-EG')} ${cur || 'EGP'}`;

// Suggested starter prompts (bilingual) per role — shown as quick-reply pills.
// Cover the whole system (booking, tracking, payments, offers, account…) and
// the user-requested starters ("how can we help", "send your ticket number").
export function suggestionsFor(role, lang) {
    const C = [
        { ar: 'كيف نساعدك؟', en: 'How can we help you?' },
        { ar: 'أرسل رقم تذكرة الدعم', en: 'Send your support ticket number' },
        { ar: 'وين وصل طلبي؟', en: 'Where is my request?' },
        { ar: 'كيف أحجز فنيًّا؟', en: 'How do I book a technician?' },
        { ar: 'أين الفني الآن؟', en: 'Where is the technician now?' },
        { ar: 'اتخصمت فلوس وما تحدّث الطلب', en: 'Money deducted but job not updated' },
        { ar: 'الدفع معلّق', en: 'Payment is pending' },
        { ar: 'أريد استرداد المبلغ', en: 'I want a refund' },
        { ar: 'كيف ألغي الطلب؟', en: 'How do I cancel my request?' },
        { ar: 'تفاصيل الرسوم والضريبة', en: 'Fees & VAT breakdown' },
    ];
    const W = [
        { ar: 'كيف نساعدك؟', en: 'How can we help you?' },
        { ar: 'أرسل رقم تذكرة الدعم', en: 'Send your support ticket number' },
        { ar: 'كم رصيد محفظتي؟', en: "What's my wallet balance?" },
        { ar: 'كيف أسحب أرباحي؟', en: 'How do I withdraw earnings?' },
        { ar: 'حالة توثيق حسابي', en: 'My verification status' },
        { ar: 'لم أستلم مستحقات عمل مكتمل', en: "I wasn't paid for a completed job" },
        { ar: 'كيف أقبل أو أرفض عرضًا؟', en: 'How do I accept or decline an offer?' },
        { ar: 'العميل لم يؤكّد إتمام العمل', en: "Customer hasn't confirmed completion" },
        { ar: 'تفاصيل الرسوم والعمولة', en: 'Fees & commission breakdown' },
    ];
    return (role === 'worker' ? W : C).map((s) => pick(lang, s.ar, s.en));
}

// The explicit human-handoff line appended to EVERY escalation reply, so the
// customer always sees that a real person will follow up (user goal #3).
export const HANDOFF_LINE = (lang) => pick(
    lang,
    ' سيتواصل معك أحد أعضاء فريق الدعم قريبًا.',
    ' A member of our team will answer your request soon.',
);

const GREETING = (role, lang) => pick(
    lang,
    'مرحبًا! أنا مساعد دعم سمارت فيكس. أقدر أساعدك في حالة طلباتك، مشاكل الدفع، '
    + (role === 'worker' ? 'محفظتك وأرباحك، وتوثيق حسابك. ' : 'والفواتير. ')
    + 'كيف أقدر أساعدك؟',
    "Hi! I'm the SmartFix support assistant. I can help with your requests, payment issues, "
    + (role === 'worker' ? 'your wallet & earnings, and account verification. ' : 'and invoices. ')
    + 'How can I help?',
);

const SIGN_IN = (lang) => pick(
    lang,
    'لعرض تفاصيل طلبك أو دفعتك، الرجاء تسجيل الدخول بحسابك. أقدر كمان أحوّلك لفريق الدعم البشري.',
    'To see your order or payment details, please sign in to your account. I can also connect you to the human support team.',
);

/**
 * Compose the deterministic answer for an intent given the (already fetched)
 * live `data`. Returns { reply, escalate, category, priority, subject }.
 * NEVER fabricates a payment outcome — it reflects exactly what `data` holds.
 */
export function composeAnswer(args) {
    const out = _composeAnswer(args);
    // Always tell the user a human will follow up whenever we escalate.
    if (out.escalate) out.reply = `${out.reply || ''}${HANDOFF_LINE(args.lang)}`;
    return out;
}

function _composeAnswer({ intent, lang, role, data, lastText }) {
    const out = { reply: '', escalate: false, category: 'general', priority: 'medium', subject: '' };
    const guest = data && data.guest;

    switch (intent) {
        case 'greeting':
            out.reply = GREETING(role, lang);
            return out;

        case 'job_status': {
            if (guest) { out.reply = SIGN_IN(lang); return out; }
            if (!data || !data.found) {
                out.reply = pick(lang, 'لا أجد طلبًا نشطًا على حسابك حاليًا. لو عندك رقم بلاغ معيّن أخبرني به.',
                    "I can't find an active request on your account. If you have a specific request, tell me its number.");
                return out;
            }
            const sl = pick(lang, data.statusLabel.ar, data.statusLabel.en);
            let extra = '';
            if (data.status === 'awaitingApproval') {
                extra = role === 'worker'
                    ? pick(lang, ' أبلغتَ عن إتمام العمل — بانتظار تأكيد العميل.', ' You reported completion — waiting for the customer to confirm.')
                    : pick(lang, ' افتح الطلب ثم اضغط «الموافقة على إتمام العمل» للتأكيد.', ' Open the request and tap “Approve work completion” to confirm.');
            } else if (data.status === 'awaitingPayment') {
                extra = pick(lang, ' الخطوة التالية هي إتمام الدفع.', ' The next step is to complete the payment.');
            } else if (data.status === 'inProgress') {
                extra = pick(lang, ' الفني يعمل على طلبك الآن.', ' The technician is working on it now.');
            }
            out.reply = pick(lang, `طلبك «${data.title}» حالته الآن: ${sl}.${extra}`,
                `Your request “${data.title}” is currently: ${sl}.${extra}`);
            return out;
        }

        case 'how_to_approve':
            out.reply = pick(lang,
                'بعد ما الفني يبلّغ عن إتمام العمل، افتح الطلب من «طلباتي» → راجع العمل المُنجَز → اضغط «الموافقة على إتمام العمل». بعدها تنتقل لخطوة الدفع. لو فيه مشكلة بالعمل تقدر ترفضه وتطلب إعادته.',
                'After the technician reports completion, open the request from “My requests” → review the finished work → tap “Approve work completion”. You then move to payment. If something is wrong, you can reject it and ask for a redo.');
            return out;

        case 'dispute':
            out.reply = pick(lang,
                'لو العمل غير مكتمل أو غير مُرضٍ، تقدر تفتح الطلب وتضغط «رفض وإعادة العمل» مع ذكر السبب — يرجع الطلب للفني. وسجّلت لك شكوى لدى فريق الدعم لمتابعة الموضوع معك.',
                'If the work is incomplete or unsatisfactory, you can open the request and tap “Reject & redo” with a reason — it goes back to the technician. I’ve also logged a complaint with our support team to follow up with you.');
            out.escalate = true;
            out.category = role === 'worker' ? 'service_quality' : 'complaint';
            out.priority = 'high';
            out.subject = pick(lang, 'شكوى بخصوص جودة العمل', 'Complaint about work quality');
            return out;

        case 'rating':
            out.reply = pick(lang,
                'بعد الموافقة على إتمام العمل والدفع، تظهر لك شاشة التقييم لتقييم الفني بالنجوم وكتابة ملاحظة.',
                'After you approve completion and pay, a rating screen appears so you can rate the technician with stars and leave a note.');
            return out;

        case 'payment_status': {
            if (guest) { out.reply = SIGN_IN(lang); return out; }
            if (!data || !data.found) {
                out.reply = pick(lang, 'لا أجد عملية دفع على حسابك حاليًا.', "I can't find a payment on your account yet.");
                return out;
            }
            const sl = pick(lang, data.statusLabel.ar, data.statusLabel.en);
            const amt = money(data.total, data.currency, lang);
            if (data.status === 'pending') {
                out.reply = pick(lang,
                    `دفعتك بمبلغ ${amt} ${sl}. أحيانًا يتأخر تأكيد البوابة دقائق — أكمل الدفع في الصفحة المفتوحة أو اضغط «تحقّق من الحالة». لو فضلت معلّقة، أقدر أحوّلك للدعم.`,
                    `Your payment of ${amt} is ${sl}. The gateway can take a few minutes to confirm — complete it in the open page or tap “Check status”. If it stays pending, I can escalate to support.`);
            } else if (data.status === 'failed') {
                out.reply = pick(lang,
                    `دفعتك بمبلغ ${amt} ${sl}. لم يُخصم منك شيء عادةً — جرّب مرة أخرى أو بطريقة دفع مختلفة (بطاقة / فوري / محفظة).`,
                    `Your payment of ${amt} ${sl}. You are usually not charged — try again or use a different method (card / Fawry / wallet).`);
            } else if (data.status === 'paid') {
                out.reply = pick(lang, `تم تأكيد دفعتك بمبلغ ${amt} ✅ (${sl}).`, `Your payment of ${amt} is confirmed ✅ (${sl}).`);
            } else {
                out.reply = pick(lang, `حالة دفعتك بمبلغ ${amt}: ${sl}.`, `Your payment of ${amt}: ${sl}.`);
            }
            return out;
        }

        case 'money_deducted': {
            if (guest) { out.reply = SIGN_IN(lang); return out; }
            const found = data && data.found;
            const status = found ? data.status : null;
            if (status === 'paid') {
                out.reply = pick(lang,
                    'دفعتك مؤكدة ومسجّلة ✅. لو الطلب ما اتحدّثش عندك، حدّث الشاشة — ولو استمر، أقدر أحوّلك للدعم.',
                    'Your payment is confirmed ✅. If the request didn’t update, refresh the screen — if it persists I can escalate.');
                return out;
            }
            // Pending/failed/unknown + money-deducted claim → escalate (payment, high).
            out.reply = pick(lang,
                'أتفهّم قلقك. أحيانًا يتأخر إشعار البوابة (Paymob) فيظهر الخصم قبل تحديث الطلب. سجّلت لك طلب دعم بأولوية عالية وسيراجع الفريق العملية ويتأكد من أي خصم. لا يتم تأكيد أي استرداد إلا بعد المراجعة.',
                'I understand. Sometimes the Paymob notification lags, so a charge can show before the request updates. I’ve opened a high-priority support ticket; the team will review the transaction and any charge. No refund is confirmed until reviewed.');
            out.escalate = true;
            out.category = 'payment';
            out.priority = 'high';
            out.subject = pick(lang, 'خصم مبلغ دون تحديث الطلب', 'Money deducted but job not updated');
            return out;
        }

        case 'fees_vat': {
            let detail = '';
            if (data && data.found) {
                detail = pick(lang,
                    ` في فاتورتك: الخدمة ${money(data.base, data.currency, lang)} + رسوم المنصة ${money(data.platformFee, data.currency, lang)} + ضريبة ${money(data.vat, data.currency, lang)} = الإجمالي ${money(data.total, data.currency, lang)}.`,
                    ` On your invoice: service ${money(data.base, data.currency, lang)} + platform fee ${money(data.platformFee, data.currency, lang)} + VAT ${money(data.vat, data.currency, lang)} = total ${money(data.total, data.currency, lang)}.`);
            }
            out.reply = pick(lang,
                `الإجمالي يتكوّن من سعر الخدمة + رسوم منصة (١٠٪) + ضريبة قيمة مضافة (١٤٪).${detail}`,
                `The total is the service price + a platform fee (10%) + VAT (14%).${detail}`);
            return out;
        }

        case 'refund':
            out.reply = pick(lang,
                'لا أستطيع تنفيذ الاسترداد بنفسي، لكني سجّلت لك طلب استرداد لدى فريق الدعم وسيتواصلون معك بعد مراجعة العملية. لن يتم تأكيد أي مبلغ مُسترَد إلا بعد المراجعة.',
                "I can't process a refund myself, but I've opened a refund request with the support team; they'll review the transaction and follow up. No refund is confirmed until reviewed.");
            out.escalate = true;
            out.category = 'payment';
            out.priority = 'high';
            out.subject = pick(lang, 'طلب استرداد مبلغ', 'Refund request');
            return out;

        case 'wallet': {
            if (guest) { out.reply = SIGN_IN(lang); return out; }
            if (data && data.notWorker) {
                out.reply = pick(lang, 'المحفظة والأرباح خاصة بحسابات الفنيين.', 'The wallet & earnings are for technician accounts.');
                return out;
            }
            if (!data || !data.found) { out.reply = SIGN_IN(lang); return out; }
            out.reply = pick(lang,
                `رصيد محفظتك الحالي ${money(data.balance, data.currency, lang)}، وإجمالي أرباحك ${money(data.totalEarned, data.currency, lang)}. يُضاف رصيدك بعد تأكيد دفع العميل وموافقته على إتمام العمل. تقدر تسحب من شاشة «الأرباح».`,
                `Your current wallet balance is ${money(data.balance, data.currency, lang)}, and total earnings ${money(data.totalEarned, data.currency, lang)}. Your balance is credited after the customer's payment is confirmed and completion approved. You can withdraw from the “Earnings” screen.`);
            return out;
        }

        case 'withdrawal': {
            if (guest) { out.reply = SIGN_IN(lang); return out; }
            const bal = (data && data.found) ? `(${pick(lang, 'رصيدك الحالي', 'current balance')}: ${money(data.balance, data.currency, lang)}) ` : '';
            out.reply = pick(lang,
                `لسحب أرباحك: افتح شاشة «الأرباح» ${bal}→ اضغط «سحب» → أدخل المبلغ. يُسجّل الطلب بحالة «قيد التنفيذ» حتى يعتمده الفريق.`,
                `To withdraw: open the “Earnings” screen ${bal}→ tap “Withdraw” → enter the amount. The request is recorded as “pending” until the team processes it.`);
            return out;
        }

        case 'verification': {
            if (guest) { out.reply = SIGN_IN(lang); return out; }
            if (data && data.notWorker) {
                out.reply = pick(lang, 'التوثيق خاص بحسابات الفنيين.', 'Verification applies to technician accounts.');
                return out;
            }
            if (!data || !data.found) { out.reply = SIGN_IN(lang); return out; }
            const st = data.verificationStatus;
            const m = {
                verified: pick(lang, 'حسابك موثّق ✅ ويمكنك استقبال الطلبات.', 'Your account is verified ✅ and can receive jobs.'),
                pending: pick(lang, 'حسابك قيد المراجعة. يراجع المشرف بطاقة الهوية التي رفعتها ثم يفعّل التوثيق.', 'Your account is under review. An admin checks your uploaded ID, then enables verification.'),
                rejected: pick(lang, 'تم رفض التوثيق. يرجى إعادة رفع صور هوية واضحة، أو تواصل مع الدعم.', 'Verification was rejected. Please re-upload clear ID images, or contact support.'),
            };
            out.reply = m[st] || pick(lang, `حالة التوثيق: ${st}.`, `Verification status: ${st}.`);
            return out;
        }

        case 'escalate':
            out.reply = pick(lang,
                'تمام، حوّلتك لفريق الدعم البشري وفتحت لك تذكرة — سيردّون عليك قريبًا.',
                "Sure — I've connected you to the human support team and opened a ticket; they'll reply soon.");
            out.escalate = true;
            out.category = role === 'worker' ? 'technician' : 'general';
            out.subject = pick(lang, 'طلب تحدث مع الدعم', 'Request to talk to support');
            return out;

        case 'booking':
            out.reply = pick(lang,
                'لحجز فني: من الشاشة الرئيسية اضغط «اطلب خدمة» أو «تقديم بلاغ» → اختر التصنيف (سباكة، كهرباء، تكييف…) → اكتب وصف المشكلة وحدّد موقعك → أرسل الطلب. هنطابقك مع أقرب فني موثّق ويوصلك عرض سعر.',
                'To book a technician: from the home screen tap “Request service” / “New request” → pick a category (plumbing, electrical, HVAC…) → describe the problem and set your location → submit. We match you with the nearest verified technician who sends a price offer.');
            return out;

        case 'tracking': {
            if (guest) { out.reply = SIGN_IN(lang); return out; }
            if (!data || !data.found) {
                out.reply = pick(lang, 'لا أجد طلبًا نشطًا لتتبّعه حاليًا.', "I can't find an active request to track right now.");
                return out;
            }
            const sl = pick(lang, data.statusLabel.ar, data.statusLabel.en);
            const who = data.technicianName ? ` (${data.technicianName})` : '';
            const extra = (data.status === 'assigned' || data.status === 'inProgress')
                ? pick(lang, ' افتح «تتبّع الطلب» داخل الطلب لرؤية موقع الفني والوقت المتوقّع.', ' Open “Track request” inside the order to see the technician’s location and ETA.')
                : '';
            out.reply = pick(lang, `طلبك «${data.title}» حالته: ${sl}${who}.${extra}`, `Your request “${data.title}” is: ${sl}${who}.${extra}`);
            return out;
        }

        case 'worker_assignment': {
            if (guest) { out.reply = SIGN_IN(lang); return out; }
            if (!data || !data.found) {
                out.reply = pick(lang, 'لا أجد طلبًا نشطًا على حسابك حاليًا.', "I can't find an active request on your account.");
                return out;
            }
            if (data.technicianName) {
                out.reply = pick(lang, `الفني المسؤول عن طلبك «${data.title}» هو ${data.technicianName}. تقدر تراسله من شاشة الطلب.`, `The technician handling “${data.title}” is ${data.technicianName}. You can message them from the request screen.`);
            } else {
                out.reply = pick(lang, 'لسه ما اتعيّنش فني لطلبك — إحنا بنطابقك مع أقرب فني متاح، وهيوصلك إشعار أول ما يتم القبول. لو طال الوقت أقدر أحوّلك للدعم.', "No technician is assigned yet — we’re matching you with the nearest available one and you’ll be notified once accepted. If it takes too long I can escalate to support.");
            }
            return out;
        }

        case 'offers':
            out.reply = role === 'worker'
                ? pick(lang, 'لما يوصلك عرض شغل: افتحه من «العروض» → راجع التفاصيل والمسافة والأجر → اضغط «قبول» أو «رفض». الرفض يمرّر العرض للفني التالي.', 'When a job offer arrives: open it from “Offers” → review the details, distance and fare → tap Accept or Decline. Declining passes it to the next technician.')
                : pick(lang, 'بعد إرسال طلبك يوصلك عرض سعر من الفني المطابق — تقدر تقبله للمتابعة. لو عندك كود خصم/كوبون تقدر تطبّقه في شاشة الدفع.', 'After you submit a request, the matched technician sends a price offer — accept it to proceed. If you have a promo/coupon code, apply it on the payment screen.');
            return out;

        case 'cancellation': {
            const can = data && data.found && ['pending', 'offered', 'assigned'].includes(data.status);
            out.reply = pick(lang,
                'لإلغاء طلب: افتح الطلب من «طلباتي» ثم اضغط «إلغاء الطلب». الإلغاء قبل بدء الفني عادةً بدون رسوم؛ بعد بدء العمل قد تُطبّق رسوم. ' + (can ? 'طلبك الحالي ما زال قابلاً للإلغاء.' : ''),
                'To cancel a request: open it from “My requests” then tap “Cancel request”. Cancelling before the technician starts is usually free; once work has started a fee may apply. ' + (can ? 'Your current request can still be cancelled.' : ''));
            return out;
        }

        case 'account':
            out.reply = role === 'worker'
                ? pick(lang, 'لإدارة حسابك: من «الملف الشخصي» تقدر تعدّل بياناتك ومهاراتك وحالة الإتاحة، ومن «الإعدادات» تغيّر كلمة المرور أو اللغة. لو فيه مشكلة دخول قول لي وأفتحلك تذكرة.', 'To manage your account: from “Profile” you can edit your details, skills and availability; from “Settings” change your password or language. If you have a login problem, tell me and I’ll open a ticket.')
                : pick(lang, 'لإدارة حسابك: من «الملف الشخصي» تقدر تعدّل الاسم والهاتف والعناوين، ومن «الإعدادات» تغيّر كلمة المرور أو اللغة أو الإشعارات. لو فيه مشكلة دخول قول لي وأفتحلك تذكرة.', 'To manage your account: from “Profile” edit your name, phone and addresses; from “Settings” change your password, language or notifications. If you have a login problem, tell me and I’ll open a ticket.');
            return out;

        case 'ticket_status': {
            if (!data || !data.found) {
                out.reply = pick(lang,
                    'ما لقيتش تذكرة بالرقم ده على حسابك. ابعت رقم التذكرة بالشكل TKT-XXXXXX، أو أقدر أفتحلك تذكرة جديدة لو حابب.',
                    "I couldn't find a ticket with that number on your account. Send the ticket number as TKT-XXXXXX, or I can open a new ticket for you.");
                return out;
            }
            const sl = pick(lang, data.statusLabel.ar, data.statusLabel.en);
            const parts = [];
            if (data.subject) parts.push(pick(lang, `الموضوع: ${data.subject}`, `Subject: ${data.subject}`));
            if (data.relatedIssueNumber) parts.push(pick(lang, `الطلب المرتبط: ${data.relatedIssueNumber}`, `Related issue: ${data.relatedIssueNumber}`));
            if (data.technicianName) parts.push(pick(lang, `الفني: ${data.technicianName}`, `Technician: ${data.technicianName}`));
            const meta = parts.length ? ` — ${parts.join('، ')}` : '';
            const pendingNote = (data.status === 'open' || data.status === 'pending');
            out.reply = pick(lang,
                `تذكرتك ${data.ticketId} حالتها: ${sl}${meta}.` + (pendingNote ? ' فريق الدعم بيراجعها وهيتواصل معك قريبًا.' : ''),
                `Your ticket ${data.ticketId} is: ${sl}${meta}.` + (pendingNote ? ' Our support team is reviewing it and will contact you soon.' : ''));
            return out;
        }

        default:
            out.reply = pick(lang,
                'أقدر أساعدك في كل خدمات سمارت فيكس: حجز فني وتتبّع الطلب، حالة الطلبات، مشاكل الدفع والفواتير والاسترداد، العروض والإلغاء، التقييم، وإدارة الحساب'
                + (role === 'worker' ? '، بالإضافة للمحفظة والأرباح والسحب وتوثيق الحساب' : '')
                + '. اكتب سؤالك، أو ابعت رقم تذكرة الدعم (TKT-)، أو اختر من الاقتراحات بالأسفل، أو اطلب «التحدث مع الدعم».',
                'I can help with everything in SmartFix: booking a technician and tracking, request status, payments/invoices/refunds, offers and cancellation, ratings, and account management'
                + (role === 'worker' ? ', plus wallet, earnings, withdrawals and verification' : '')
                + '. Type your question, send your support ticket number (TKT-), pick a suggestion below, or ask to “talk to support”.');
            return out;
    }
}
