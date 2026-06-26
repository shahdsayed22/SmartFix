// SmartFix notifications module (Build Contract §6 / §7).
// Maps event keys to Arabic title/body/icon/tone (icon names + tone enum match
// the design's SEED_NOTIFICATIONS in ar/data-extra.jsx) and writes a Notification.

import dbConnect from './mongodb.js';

const TONES = ['info', 'success', 'warning', 'danger'];

/**
 * Event-key → presentation map (§7). `body` may be a string or a function of
 * the notification context, so dynamic details (names, amounts) can be woven in.
 * lucide icon names + tone match the design's notification seed style.
 */
export const NOTIFICATION_EVENTS = {
    ticket_created: {
        icon: 'ticket',
        tone: 'info',
        title: 'تم إنشاء تذكرة',
        body: (ctx) => ctx?.subject
            ? `تم فتح تذكرة دعم جديدة: ${ctx.subject}`
            : 'تم فتح تذكرة دعم جديدة',
    },
    ticket_reply: {
        icon: 'message-circle',
        tone: 'info',
        title: 'رد جديد على تذكرتك',
        body: (ctx) => ctx?.senderName
            ? `${ctx.senderName}: وصلك رد جديد على تذكرتك`
            : 'وصلك رد جديد على تذكرتك',
    },
    // A customer raised a support ticket about a job assigned to this worker.
    // The worker is asked to explain what happened so support can follow up.
    ticket_worker_query: {
        icon: 'ticket',
        tone: 'warning',
        title: 'استفسار بخصوص مهمتك',
        body: (ctx) => ctx?.issueNumber
            ? `لدى العميل استفسار بخصوص الطلب ${ctx.issueNumber} — يرجى توضيح ما حدث`
            : 'لدى العميل استفسار بخصوص إحدى مهامك — يرجى توضيح ما حدث',
    },
    issue_created: {
        icon: 'clipboard-check',
        tone: 'success',
        title: 'تم استلام بلاغك',
        body: (ctx) => ctx?.title
            ? `تم استلام بلاغك: ${ctx.title}، وجارٍ مراجعته`
            : 'تم استلام بلاغك وجارٍ مراجعته',
    },
    job_accepted: {
        icon: 'user-check',
        tone: 'success',
        title: 'تم قبول طلبك',
        body: (ctx) => ctx?.technicianName
            ? `قبِل ${ctx.technicianName} المهمة وهو في طريقه إليك`
            : 'قبِل الفني المهمة وهو في طريقه إليك',
    },
    offer_accepted: {
        icon: 'user-check',
        tone: 'success',
        title: 'قبِل الفني العرض',
        body: (ctx) => ctx?.technicianName
            ? `قبِل ${ctx.technicianName} المهمة وهو في طريقه إليك`
            : 'قبِل الفني المهمة وهو في طريقه إليك',
    },
    offer_declined: {
        icon: 'bell',
        tone: 'info',
        title: 'لديك عرض مهمة جديد',
        body: (ctx) => ctx?.issueTitle
            ? `عرض جديد: ${ctx.issueTitle} — راجع التفاصيل وقرّر القبول`
            : 'لديك عرض مهمة جديد — راجع التفاصيل وقرّر القبول',
    },
    completion_requested: {
        icon: 'check-circle',
        tone: 'warning',
        title: 'أبلغ الفني عن إتمام العمل',
        body: (ctx) => ctx?.technicianName
            ? `أبلغ ${ctx.technicianName} عن إتمام العمل — يرجى المراجعة والموافقة`
            : 'أبلغ الفني عن إتمام العمل — يرجى المراجعة والموافقة',
    },
    completion_approved: {
        icon: 'badge-check',
        tone: 'success',
        title: 'تمت الموافقة على العمل',
        body: 'وافق العميل على إتمام العمل، ويمكنك متابعة الدفع',
    },
    completion_rejected: {
        icon: 'rotate-ccw',
        tone: 'warning',
        title: 'طلب العميل تعديلًا على العمل',
        body: (ctx) => ctx?.rejectionReason
            ? `طلب العميل تعديلًا: ${ctx.rejectionReason}`
            : 'طلب العميل تعديلًا على العمل قبل الإغلاق',
    },
    rating_submitted: {
        icon: 'star',
        tone: 'warning',
        title: 'تقييم جديد',
        body: (ctx) => (ctx?.rating != null)
            ? `حصلت على تقييم جديد بمعدل ${ctx.rating} نجوم`
            : 'حصلت على تقييم جديد',
    },
    payment_completed: {
        icon: 'wallet',
        tone: 'success',
        title: 'تم الدفع بنجاح',
        body: (ctx) => (ctx?.amount != null)
            ? `تم الدفع بنجاح بمبلغ ${ctx.amount} ${ctx?.currency || 'ج.م'}`
            : 'تم الدفع بنجاح',
    },
    payment_failed: {
        icon: 'x-circle',
        tone: 'danger',
        title: 'فشل الدفع',
        body: 'تعذّر إتمام عملية الدفع، يرجى المحاولة مرة أخرى',
    },
    worker_verified: {
        icon: 'shield-check',
        tone: 'success',
        title: 'تم توثيق حسابك',
        body: 'تهانينا! تم توثيق حسابك ويمكنك الآن استقبال المهام',
    },
};

function resolveBody(value, ctx) {
    return typeof value === 'function' ? value(ctx || {}) : value;
}

/**
 * Low-level: persist a single Notification document.
 * @param {{ userId, role, type, title, body, icon, tone, relatedId }} args
 * @returns {Promise<object|null>} the created doc, or null if the model is unavailable.
 */
export async function createNotification({
    userId,
    role,
    type,
    title = '',
    body = '',
    icon = 'bell',
    tone = 'info',
    relatedId = '',
} = {}) {
    if (!userId) return null;
    const safeTone = TONES.includes(tone) ? tone : 'info';

    await dbConnect();
    const mod = await import('../models/Notification.js');
    const Notification = mod.default;

    return Notification.create({
        userId,
        role,
        type,
        title,
        body,
        icon,
        tone: safeTone,
        relatedId,
        read: false,
        createdAt: new Date(),
    });
}

/**
 * High-level: create a notification for a known event key (§7).
 * Looks up Arabic title/body/icon/tone, weaves in `ctx`, and persists it.
 * @param {string} type one of NOTIFICATION_EVENTS keys
 * @param {{ userId, role, relatedId, title?, body?, ...details }} ctx
 */
export async function notifyEvent(type, ctx = {}) {
    const def = NOTIFICATION_EVENTS[type];
    if (!def) {
        // Unknown event key — still create a minimal notification so nothing is lost.
        return createNotification({
            userId: ctx.userId,
            role: ctx.role,
            type,
            title: ctx.title || type,
            body: ctx.body || '',
            icon: ctx.icon || 'bell',
            tone: ctx.tone || 'info',
            relatedId: ctx.relatedId || '',
        });
    }

    return createNotification({
        userId: ctx.userId,
        role: ctx.role,
        type,
        title: ctx.title || def.title,
        body: ctx.body || resolveBody(def.body, ctx),
        icon: ctx.icon || def.icon,
        tone: ctx.tone || def.tone,
        relatedId: ctx.relatedId || '',
    });
}

export default { NOTIFICATION_EVENTS, createNotification, notifyEvent };
