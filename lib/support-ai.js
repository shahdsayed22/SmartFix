// Optional AI brain for the support assistant — Vercel AI SDK v6 through the
// AI Gateway. Loaded ONLY when AI_GATEWAY_API_KEY is set (the route dynamically
// imports this); otherwise the deterministic engine handles everything.
//
// The model gets read-only tools to look up the user's live job/payment/wallet/
// verification data, plus ONE write tool (createSupportTicket) for escalation.
// It can never mutate jobs, payments, or wallets. Grounding + payment-safety
// rules live in the system prompt.

import { generateText, tool, stepCountIs } from 'ai';
import { z } from 'zod';
import {
    getJobStatusFor,
    getPaymentStatusFor,
    getWalletFor,
    getVerificationFor,
    getTicketStatusFor,
    escalateToTicket,
} from '@/lib/support-data.js';
import { suggestionsFor, HANDOFF_LINE } from '@/lib/support-intents.js';

// Cost-appropriate, fast model for short grounded support Q&A. Routed via the
// gateway with a plain "provider/model" string. Set SUPPORT_MODEL in the
// environment to the model you want to use (e.g. "<provider>/<model>").
const SUPPORT_MODEL = process.env.SUPPORT_MODEL || '<provider>/<model>';

function systemPrompt({ lang, role, userId }) {
    const langName = lang === 'en' ? 'English' : 'Arabic';
    const isGuest = !userId || String(userId).startsWith('guest-');
    return [
        "You are SmartFix's in-app support assistant. SmartFix is a home-services marketplace (plumbing, electrical, etc.) with a job lifecycle and Paymob payments.",
        `Always reply in ${langName}. Keep answers short (1–4 sentences) with a concrete next step.`,
        'Scope: booking/creating a request, tracking a technician (location/ETA), job status, technician assignment, offers & promo codes, cancellation, payments & invoices, refunds, ratings, account/profile/login help, support-ticket status by number, and for workers: wallet/earnings, withdrawals, and verification. For anything else, or anything you cannot verify, escalate.',
        'If the user gives a ticket number like TKT-XXXXXX, call getTicketStatus to report its status, related issue, and assigned worker.',
        'GROUNDING: base every factual claim about a job, payment, wallet, or verification on a tool result. Never guess statuses, amounts, dates, or outcomes. Call a tool before stating specifics.',
        'PAYMENT SAFETY (critical): NEVER confirm a refund, payout, or that money was returned/sent. NEVER say a payment succeeded, failed, or was refunded unless getPaymentStatus returned that exact status. If a payment is pending, say it is still being confirmed (gateway webhooks can lag) and offer to open a support ticket — do not promise resolution.',
        'MONEY DEDUCTED BUT JOB NOT UPDATED: reassure that webhooks can lag, check getPaymentStatus, and if still unresolved (pending/failed) call createSupportTicket with category "payment" and priority "high".',
        'ESCALATE (createSupportTicket) when: the user asks for a human; a refund/dispute/chargeback is requested; a payment is stuck pending; or you cannot answer from tools.',
        role === 'worker'
            ? 'This user is a TECHNICIAN (worker). Use the worker-side tools.'
            : 'This user is a CUSTOMER.',
        isGuest
            ? 'This is a GUEST with no account — you cannot look up personal data. Give general guidance and invite them to sign in or share an issue/payment id. You may still open a ticket if they ask.'
            : `The signed-in user id is "${userId}". Tools already scope to this user; do not ask them for their own id.`,
    ].join('\n');
}

export async function runAiGateway({ messages, lang, role, userId, userName, issueId, paymentId }) {
    let escalation = null;

    const tools = {
        getJobStatus: tool({
            description: "Look up the user's current/most-recent job (or a specific issueId) and its lifecycle status.",
            inputSchema: z.object({
                issueId: z.string().optional().describe('Specific issue id, if known'),
            }),
            execute: async ({ issueId: id }) =>
                getJobStatusFor({ userId, role, issueId: id || issueId }),
        }),
        getPaymentStatus: tool({
            description: "Look up the user's payment by paymentId, issueId, or most recent. Returns the exact status (pending|paid|failed|refunded) and amounts.",
            inputSchema: z.object({
                paymentId: z.string().optional(),
                issueId: z.string().optional(),
            }),
            execute: async ({ paymentId: pid, issueId: iid }) =>
                getPaymentStatusFor({ userId, role, paymentId: pid || paymentId, issueId: iid || issueId }),
        }),
        getWallet: tool({
            description: 'Worker only: the technician wallet balance, total earnings, and recent payout/withdrawal history.',
            inputSchema: z.object({}),
            execute: async () => getWalletFor({ userId, role }),
        }),
        getVerification: tool({
            description: 'Worker only: the technician account verification status.',
            inputSchema: z.object({}),
            execute: async () => getVerificationFor({ userId, role }),
        }),
        getTicketStatus: tool({
            description: "Look up an existing support ticket by its number (TKT-XXXXXX) — returns its status, subject, related issue number, and assigned worker.",
            inputSchema: z.object({
                ticketNumber: z.string().describe('The TKT- ticket number the user provided'),
            }),
            execute: async ({ ticketNumber }) =>
                getTicketStatusFor({ userId, role, ticketNumber }),
        }),
        createSupportTicket: tool({
            description: 'Escalate to a human by opening a support ticket. Use for refunds, disputes, stuck payments, or when you cannot resolve.',
            inputSchema: z.object({
                subject: z.string().describe('Short subject line'),
                category: z.enum(['general', 'payment', 'service_quality', 'technician', 'account', 'complaint', 'other']).default('general'),
                priority: z.enum(['low', 'medium', 'high']).default('medium'),
                summary: z.string().describe("Brief summary of the user's problem"),
            }),
            execute: async ({ subject, category, priority, summary }) => {
                escalation = await escalateToTicket({
                    userId, userName, role, subject, category, priority,
                    summary, transcript: messages, issueId: issueId || '', lang,
                });
                return escalation;
            },
        }),
    };

    const modelMessages = (messages || [])
        .filter((m) => m && typeof m.text === 'string' && m.text.trim())
        .map((m) => ({ role: m.role === 'assistant' ? 'assistant' : 'user', content: m.text }));
    if (modelMessages.length === 0) {
        // Bootstrap greeting turn.
        modelMessages.push({ role: 'user', content: lang === 'en' ? '(greet me briefly)' : '(رحّب بي باختصار)' });
    }

    const { text } = await generateText({
        model: SUPPORT_MODEL,
        system: systemPrompt({ lang, role, userId }),
        messages: modelMessages,
        tools,
        stopWhen: stepCountIs(5),
        temperature: 0.2,
    });

    // Guard: a model that ends on a tool step can return empty text. Fall back
    // to a localized line (mentioning the ticket if one was opened) so the user
    // is never left with a blank reply.
    let reply = (text || '').trim();
    if (!reply) {
        reply = lang === 'en'
            ? 'I’ve noted your request.'
            : 'سجّلت طلبك.';
        if (escalation && escalation.ticketId) reply += HANDOFF_LINE(lang);
    }
    // Always surface the created ticket number on escalation.
    if (escalation && escalation.ticketId && !reply.includes(escalation.ticketId)) {
        reply += lang === 'en'
            ? ` Your ticket number is ${escalation.ticketId}.`
            : ` رقم تذكرتك هو ${escalation.ticketId}.`;
    }

    return {
        reply,
        intent: 'ai',
        data: null,
        suggestions: suggestionsFor(role, lang),
        escalation,
        method: `ai-gateway:${SUPPORT_MODEL}`,
    };
}
