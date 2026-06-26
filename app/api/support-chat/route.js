import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import {
    detectSupportIntent,
    intentNeeds,
    composeAnswer,
    suggestionsFor,
    extractTicketNumber,
    detectMessageLang,
} from '@/lib/support-intents.js';
import {
    getJobStatusFor,
    getPaymentStatusFor,
    getWalletFor,
    getVerificationFor,
    getTicketStatusFor,
    escalateToTicket,
} from '@/lib/support-data.js';

// Hybrid support assistant.
//   • Always-on: a deterministic intent engine (free, no key, offline-capable).
//   • Optional: an AI Gateway (LLM) brain that activates only when
//     AI_GATEWAY_API_KEY is set, with transparent fallback to deterministic.
// Mirrors the model-or-heuristic pattern used by app/api/nlp/classify.

const MAX_TURNS = 12; // bound payload/cost — only the last N turns matter.

function lastUserText(messages) {
    if (!Array.isArray(messages)) return '';
    for (let i = messages.length - 1; i >= 0; i--) {
        const m = messages[i];
        if (m && m.role === 'user' && typeof m.text === 'string') return m.text;
    }
    return '';
}

export async function POST(request) {
    let body;
    try {
        body = await request.json();
    } catch {
        return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
    }

    const baseLang = body.lang === 'en' ? 'en' : 'ar';
    const role = body.role === 'worker' ? 'worker' : 'customer';
    const userId = typeof body.userId === 'string' ? body.userId : '';
    const userName = typeof body.userName === 'string' ? body.userName : '';
    const ctx = body.context || {};
    const issueId = ctx.issueId || null;
    const paymentId = ctx.paymentId || null;
    const messages = Array.isArray(body.messages) ? body.messages.slice(-MAX_TURNS) : [];
    // Reply in the language the user actually typed (Arabic OR English), falling
    // back to the app's language toggle when the message has no letters.
    const lang = detectMessageLang(lastUserText(messages)) || baseLang;
    const params = { messages, lang, role, userId, userName, issueId, paymentId };

    try {
        await dbConnect();

        // Phase 2: LLM brain via Vercel AI Gateway when a key is configured.
        if (process.env.AI_GATEWAY_API_KEY) {
            try {
                const { runAiGateway } = await import('@/lib/support-ai.js');
                return NextResponse.json(await runAiGateway(params));
            } catch (err) {
                console.warn('[support-chat] AI gateway failed, falling back:', err?.message || err);
            }
        }

        return NextResponse.json(await runDeterministic(params));
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}

async function runDeterministic({ messages, lang, role, userId, userName, issueId, paymentId }) {
    const text = lastUserText(messages);
    const ticketRef = extractTicketNumber(text);
    let intent = text ? detectSupportIntent(text).intent : 'greeting';
    // A pasted TKT- number always means "what's the status of this ticket".
    if (ticketRef) intent = 'ticket_status';

    // Fetch only the live data this intent needs (ownership-checked in helpers).
    const need = intentNeeds(intent);
    let data = null;
    if (need === 'job') data = await getJobStatusFor({ userId, role, issueId });
    else if (need === 'payment') data = await getPaymentStatusFor({ userId, role, paymentId, issueId });
    else if (need === 'wallet') data = await getWalletFor({ userId, role });
    else if (need === 'verification') data = await getVerificationFor({ userId, role });
    else if (need === 'ticket') data = await getTicketStatusFor({ userId, role, ticketNumber: ticketRef });

    const ans = composeAnswer({ intent, lang, role, data, lastText: text });

    let escalation = null;
    if (ans.escalate) {
        escalation = await escalateToTicket({
            userId, userName, role,
            subject: ans.subject, category: ans.category, priority: ans.priority,
            summary: text, transcript: messages,
            issueId: issueId || (data && data.issueId) || '',
            lang,
        });
    }

    // Speak the created ticket number back so the customer can reference it later.
    let reply = ans.reply;
    if (escalation && escalation.ticketId) {
        reply += lang === 'en'
            ? ` Your ticket number is ${escalation.ticketId}.`
            : ` رقم تذكرتك هو ${escalation.ticketId}.`;
    }

    return {
        reply,
        intent,
        data: data && data.found ? data : null,
        suggestions: suggestionsFor(role, lang),
        escalation,
        method: 'deterministic',
    };
}
