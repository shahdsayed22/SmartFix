// Shared, server-only data lookups + escalation for the support assistant.
// Both the deterministic engine (lib/support-intents.js, via the route) and the
// optional AI Gateway layer call these, so answers are grounded in the SAME
// live data regardless of which brain is active.
//
// Every lookup enforces ownership (a customer only ever sees their own
// jobs/payments; a worker only their own) — ids arriving from the client are
// untrusted. Guests (no/blank uid) get no DB access at all.

import Issue from '@/models/Issue';
import Payment from '@/models/Payment';
import Technician from '@/models/Technician';
import WalletTransaction from '@/models/WalletTransaction';
import Ticket from '@/models/Ticket';
import { notifyEvent } from '@/lib/notifications';

/** A guest / no-login demo session — empty uid or the `guest-*` sentinel. */
export function isGuestUser(userId) {
    return !userId || String(userId).startsWith('guest-');
}

// Bilingual labels for the issue lifecycle — the single source of truth reused
// by both engines so status wording stays consistent across the app.
export const STATUS_LABELS = {
    pending: { ar: 'قيد الانتظار', en: 'Pending' },
    offered: { ar: 'عرض مُرسَل لفني', en: 'Offer sent to a technician' },
    assigned: { ar: 'تم تعيين فني', en: 'Technician assigned' },
    inProgress: { ar: 'قيد التنفيذ', en: 'In progress' },
    awaitingApproval: { ar: 'بانتظار موافقتك على إتمام العمل', en: 'Awaiting your approval' },
    awaitingPayment: { ar: 'بانتظار الدفع', en: 'Awaiting payment' },
    completed: { ar: 'مكتمل', en: 'Completed' },
    cancelled: { ar: 'ملغى', en: 'Cancelled' },
    disputed: { ar: 'متنازع عليه', en: 'Disputed' },
    rejected: { ar: 'مرفوض', en: 'Rejected' },
};

export const PAYMENT_STATUS_LABELS = {
    pending: { ar: 'قيد التأكيد', en: 'Pending confirmation' },
    paid: { ar: 'مدفوع', en: 'Paid' },
    failed: { ar: 'فشل', en: 'Failed' },
    refunded: { ar: 'مُسترَد', en: 'Refunded' },
};

export const TICKET_STATUS_LABELS = {
    open: { ar: 'مفتوحة', en: 'Open' },
    pending: { ar: 'قيد المراجعة', en: 'Pending' },
    resolved: { ar: 'تم الحل', en: 'Resolved' },
    closed: { ar: 'مغلقة', en: 'Closed' },
};

/**
 * Look up a support ticket by its human number (TKT-XXXX) for a status reply.
 * Ownership: a ticket that belongs to a signed-in user is only visible to that
 * same user; a guest-created ticket (no customerId) can be referenced by its
 * number. Never leaks another customer's ticket.
 */
export async function getTicketStatusFor({ userId, role, ticketNumber }) {
    if (!ticketNumber) return { found: false };
    const ticket = await Ticket.findOne({ ticketId: String(ticketNumber).toUpperCase() }).lean();
    if (!ticket) return { found: false };
    if (ticket.customerId) {
        // Owned ticket → require the same signed-in user (IDOR guard).
        if (isGuestUser(userId) || ticket.customerId !== userId) return { found: false };
    }
    const lastAdmin = [...(ticket.messages || [])]
        .reverse()
        .find((m) => m.senderRole === 'admin');
    return {
        found: true,
        ticketId: ticket.ticketId,
        status: ticket.status,
        statusLabel: TICKET_STATUS_LABELS[ticket.status] || { ar: ticket.status, en: ticket.status },
        subject: ticket.subject || '',
        category: ticket.category || 'general',
        relatedIssueNumber: ticket.relatedIssueNumber || '',
        technicianName: ticket.technicianName || '',
        lastAdminReply: lastAdmin ? (lastAdmin.text || '') : '',
        createdAt: ticket.createdAt || null,
    };
}

function ownsIssue(issue, userId, role) {
    if (!issue) return false;
    return role === 'worker'
        ? issue.assignedTechnicianId === userId
        : issue.customerId === userId;
}

/** Latest relevant job for this user (or the one identified by issueId). */
export async function getJobStatusFor({ userId, role, issueId }) {
    if (isGuestUser(userId)) return { found: false, guest: true };

    let issue = null;
    if (issueId) {
        issue = await Issue.findById(issueId).lean().catch(() => null);
        if (!ownsIssue(issue, userId, role)) issue = null; // IDOR guard
    }
    if (!issue) {
        const filter = role === 'worker'
            ? { assignedTechnicianId: userId }
            : { customerId: userId };
        issue = await Issue.findOne(filter).sort({ updatedAt: -1 }).lean();
    }
    if (!issue) return { found: false };

    return {
        found: true,
        issueId: issue._id.toString(),
        title: issue.title || '',
        status: issue.status,
        statusLabel: STATUS_LABELS[issue.status] || { ar: issue.status, en: issue.status },
        technicianName: issue.assignedTechnicianName || '',
        customerName: issue.customerName || '',
        completionRequestedAt: issue.completionRequestedAt || null,
        rejectionReason: issue.rejectionReason || '',
        paymentId: issue.paymentId || '',
        price: issue.price || 0,
    };
}

/** Payment for this user — by paymentId, else by issueId, else most recent. */
export async function getPaymentStatusFor({ userId, role, paymentId, issueId }) {
    if (isGuestUser(userId)) return { found: false, guest: true };

    let payment = null;
    if (paymentId) payment = await Payment.findById(paymentId).lean().catch(() => null);
    if (!payment && issueId) {
        payment = await Payment.findOne({ issueId }).sort({ createdAt: -1 }).lean();
    }
    if (!payment) {
        const filter = role === 'worker' ? { technicianId: userId } : { customerId: userId };
        payment = await Payment.findOne(filter).sort({ createdAt: -1 }).lean();
    }
    if (payment) {
        const owns = role === 'worker'
            ? payment.technicianId === userId
            : payment.customerId === userId;
        if (!owns) payment = null; // IDOR guard
    }
    if (!payment) return { found: false };

    return {
        found: true,
        paymentId: payment._id.toString(),
        issueId: payment.issueId || '',
        status: payment.status,
        statusLabel: PAYMENT_STATUS_LABELS[payment.status] || { ar: payment.status, en: payment.status },
        method: payment.method || '',
        base: payment.base || 0,
        platformFee: payment.platformFee || 0,
        vat: payment.vat || 0,
        discount: payment.discount || 0,
        total: payment.total || 0,
        currency: payment.currency || 'EGP',
        paidAt: payment.paidAt || null,
    };
}

/** Worker wallet balance + recent payout/withdrawal history. */
export async function getWalletFor({ userId, role }) {
    if (isGuestUser(userId)) return { found: false, guest: true };
    if (role !== 'worker') return { found: false, notWorker: true };

    const tech = (await Technician.findOne({ uid: userId }).lean())
        || (await Technician.findById(userId).lean().catch(() => null));
    const transactions = await WalletTransaction.find({
        technicianId: userId,
        type: { $in: ['payout', 'withdrawal'] },
    }).sort({ createdAt: -1 }).limit(10).lean();

    return {
        found: true,
        balance: tech ? (tech.walletBalance || 0) : 0,
        totalEarned: tech ? (tech.totalEarned || 0) : 0,
        currency: 'EGP',
        transactions: transactions.map((t) => ({
            type: t.type, amount: t.amount, status: t.status, at: t.createdAt,
        })),
    };
}

/** Worker verification status. */
export async function getVerificationFor({ userId, role }) {
    if (isGuestUser(userId)) return { found: false, guest: true };
    if (role !== 'worker') return { found: false, notWorker: true };

    const tech = (await Technician.findOne({ uid: userId }).lean())
        || (await Technician.findById(userId).lean().catch(() => null));
    if (!tech) return { found: false };
    return {
        found: true,
        verificationStatus: tech.verificationStatus || 'pending',
        isVerified: !!tech.isVerified,
    };
}

function generateTicketId() {
    const rand = Math.random().toString(36).slice(2, 8).toUpperCase();
    return `TKT-${rand}`;
}

/**
 * Escalate the conversation to a human by creating a support Ticket
 * (source 'chatbot'). Reuses the same Ticket schema + admin notification as the
 * tickets API. Works for guests too (empty customerId) so the team still sees it.
 */
export async function escalateToTicket({
    userId, userName, role, subject, category, priority,
    summary, transcript = [], issueId = '', lang = 'ar',
}) {
    const now = new Date();
    const botName = lang === 'en' ? 'Support Assistant' : 'مساعد الدعم';
    const messages = [
        {
            senderId: 'bot',
            senderRole: 'bot',
            senderName: botName,
            text: (lang === 'en'
                ? 'Escalated from the support assistant. Summary: '
                : 'تحويل من مساعد الدعم. الملخص: ') + (summary || ''),
            at: now,
        },
        ...transcript.slice(-12).map((m) => ({
            senderId: m.role === 'user' ? (userId || '') : 'bot',
            // Ticket schema senderRole is customer|admin|bot — worker maps to customer.
            senderRole: m.role === 'user' ? 'customer' : 'bot',
            senderName: m.role === 'user' ? (userName || '') : botName,
            text: m.text || '',
            at: now,
        })),
    ];

    // Denormalize the related issue's human number + assigned worker so the
    // dashboard can show ticket# + issue# + worker together (goal #4).
    let relatedIssueNumber = '';
    let technicianId = '';
    let technicianName = '';
    if (issueId) {
        const issue = await Issue.findById(issueId)
            .select('issueNumber assignedTechnicianId assignedTechnicianName')
            .lean()
            .catch(() => null);
        if (issue) {
            relatedIssueNumber = issue.issueNumber || '';
            technicianId = issue.assignedTechnicianId || '';
            technicianName = issue.assignedTechnicianName || '';
        }
    }

    const ticket = await Ticket.create({
        ticketId: generateTicketId(),
        customerId: isGuestUser(userId) ? '' : userId,
        customerName: userName || (role === 'worker' ? 'Technician' : 'Customer'),
        subject: subject || (lang === 'en' ? 'Support request' : 'طلب دعم'),
        category: category || 'general',
        status: 'open',
        priority: priority || 'medium',
        relatedIssueId: issueId || '',
        relatedIssueNumber,
        technicianId,
        technicianName,
        requesterRole: role === 'worker' ? 'worker' : 'customer',
        source: 'chatbot',
        messages,
    });

    try {
        await notifyEvent('ticket_created', {
            userId: 'admin',
            role: 'admin',
            relatedId: ticket._id.toString(),
            ticketId: ticket.ticketId,
            subject: ticket.subject,
            customerName: ticket.customerName,
        });
    } catch (e) {
        console.error('support escalate: notify failed', e?.message || e);
    }

    return { created: true, ticketId: ticket.ticketId, _id: ticket._id.toString() };
}
