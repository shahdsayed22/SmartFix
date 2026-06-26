// SmartFix Paymob wrapper (Stage 4).
// Thin client around the Paymob "classic" Accept API with a built-in MOCK MODE
// so the demo runs with no keys. NEVER hardcode a real key — config comes from
// env (see .env.local / Vercel):
//   PAYMOB_ENABLED         ('true' to hit the real API; anything else → mock)
//   PAYMOB_API_KEY         (auth → auth_token)
//   PAYMOB_INTEGRATION_ID  (card integration id for payment_keys)
//   PAYMOB_IFRAME_ID       (hosted checkout iframe id)
//   PAYMOB_HMAC_SECRET     (callback HMAC-SHA512 verification)
//   PAYMOB_BASE_URL        (default https://accept.paymob.com)
//
// Exposes the same surface as lib/myfatoorah.js (createInvoice /
// getPaymentStatus) so app/api/payments/* can swap providers with no change to
// their control flow, plus verifyHmac() for the callback route.

import crypto from 'crypto';

const DEFAULT_BASE_URL = 'https://accept.paymob.com';

function getBaseUrl() {
    return process.env.PAYMOB_BASE_URL || DEFAULT_BASE_URL;
}

/**
 * Live mode requires the toggle ON plus the three values needed to actually
 * reach a hosted checkout. Missing any → mock mode (demo never breaks).
 */
export function isLiveMode() {
    const enabled = String(process.env.PAYMOB_ENABLED || '').toLowerCase();
    const on = enabled === 'true' || enabled === '1' || enabled === 'yes';
    return (
        on &&
        Boolean(process.env.PAYMOB_API_KEY) &&
        Boolean(process.env.PAYMOB_INTEGRATION_ID) &&
        Boolean(process.env.PAYMOB_IFRAME_ID)
    );
}

/** Deterministic fake order id for mock mode (stable per amount + customer). */
function mockInvoiceId({ amount, customer }) {
    const seed = `${amount || 0}-${customer?.email || customer?.phone || customer?.name || 'guest'}`;
    let hash = 0;
    for (let i = 0; i < seed.length; i += 1) {
        hash = (hash * 31 + seed.charCodeAt(i)) >>> 0;
    }
    return `MOCK-${hash.toString(36).toUpperCase()}`;
}

async function postJson(url, body) {
    const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    });
    if (!res.ok) {
        const text = await res.text().catch(() => '');
        throw new Error(`Paymob ${url} failed (${res.status}): ${text}`);
    }
    return res.json();
}

/** Split a full name into Paymob's required first/last (never empty). */
function splitName(name) {
    const parts = String(name || '').trim().split(/\s+/).filter(Boolean);
    const first = parts.shift() || 'SmartFix';
    const last = parts.join(' ') || 'Customer';
    return { first, last };
}

/** Paymob requires a fully-populated billing_data object; "NA" fills blanks. */
function buildBillingData(customer = {}) {
    const { first, last } = splitName(customer.name);
    return {
        first_name: first,
        last_name: last,
        email: customer.email || 'na@smartfix.app',
        phone_number: customer.phone || 'NA',
        apartment: 'NA',
        floor: 'NA',
        street: 'NA',
        building: 'NA',
        shipping_method: 'NA',
        postal_code: 'NA',
        city: 'NA',
        state: 'NA',
        country: 'EG',
    };
}

/**
 * Create a hosted payment "invoice" (Paymob order + payment key + iframe URL).
 * Mirrors lib/myfatoorah.createInvoice so callers are provider-agnostic.
 * @param {{ amount:number, customer?:object, callbackUrl?:string, displayCurrency?:string }} args
 * @returns {Promise<{ invoiceId:string, paymentUrl:string, mock:boolean }>}
 *
 * Mock mode: returns a deterministic order id and a local callback URL with
 * ?mock=1&...&status=paid so the flow completes offline.
 */
export async function createInvoice({ amount, customer = {}, callbackUrl, displayCurrency = 'EGP' } = {}) {
    if (!isLiveMode()) {
        const invoiceId = mockInvoiceId({ amount, customer });
        // Mock always completes through the MyFatoorah/mock callback — it is the
        // only route that understands ?mock=1&status=paid. Callers now pass the
        // LIVE Paymob route as callbackUrl, so rewrite it back to /callback here.
        let base = callbackUrl || '/api/payments/callback';
        base = base.replace('/api/payments/paymob-callback', '/api/payments/callback');
        const sep = base.includes('?') ? '&' : '?';
        const paymentUrl = `${base}${sep}mock=1&invoiceId=${encodeURIComponent(invoiceId)}&status=paid`;
        return { invoiceId, paymentUrl, mock: true };
    }

    const amountCents = Math.round(Number(amount || 0) * 100);

    // 1) Auth → auth_token
    const auth = await postJson(`${getBaseUrl()}/api/auth/tokens`, {
        api_key: process.env.PAYMOB_API_KEY,
    });
    const authToken = auth.token;

    // 2) Order (register the intention to pay)
    const order = await postJson(`${getBaseUrl()}/api/ecommerce/orders`, {
        auth_token: authToken,
        delivery_needed: false,
        amount_cents: amountCents,
        currency: displayCurrency,
        items: [],
    });
    const orderId = order.id;

    // 3) Payment key (scoped to the card integration + billing data)
    const key = await postJson(`${getBaseUrl()}/api/acceptance/payment_keys`, {
        auth_token: authToken,
        amount_cents: amountCents,
        expiration: 3600,
        order_id: orderId,
        billing_data: buildBillingData(customer),
        currency: displayCurrency,
        integration_id: Number(process.env.PAYMOB_INTEGRATION_ID),
    });

    // 4) Hosted checkout iframe URL
    const iframeId = process.env.PAYMOB_IFRAME_ID;
    const paymentUrl = `${getBaseUrl()}/api/acceptance/iframes/${iframeId}?payment_token=${key.token}`;

    return { invoiceId: String(orderId), paymentUrl, mock: false };
}

/**
 * Look up a payment status. Mock mode resolves as 'paid' so the demo completes.
 * Live mode inquires the transaction for an order id.
 * @returns {Promise<{ status:'paid'|'pending'|'failed', mock:boolean, raw?:any }>}
 */
export async function getPaymentStatus(key /*, keyType */) {
    if (!isLiveMode()) {
        return { status: 'paid', mock: true };
    }
    try {
        const auth = await postJson(`${getBaseUrl()}/api/auth/tokens`, {
            api_key: process.env.PAYMOB_API_KEY,
        });
        const data = await postJson(`${getBaseUrl()}/api/ecommerce/orders/transaction_inquiry`, {
            auth_token: auth.token,
            order_id: Number(key),
        });
        const success = data.success === true;
        const pending = data.pending === true;
        const status = success ? 'paid' : pending ? 'pending' : 'failed';
        return { status, mock: false, raw: data, invoiceId: String(data?.order?.id ?? key) };
    } catch (e) {
        return { status: 'pending', mock: false, raw: String(e) };
    }
}

// Ordered keys Paymob concatenates to build the callback HMAC, per their docs.
const HMAC_FIELDS = [
    'amount_cents', 'created_at', 'currency', 'error_occured', 'has_parent_transaction',
    'id', 'integration_id', 'is_3d_secure', 'is_auth', 'is_capture', 'is_refunded',
    'is_standalone_payment', 'is_voided', 'order.id', 'owner', 'pending',
    'source_data.pan', 'source_data.sub_type', 'source_data.type', 'success',
];

function pick(obj, dottedPath) {
    return dottedPath.split('.').reduce((acc, k) => (acc == null ? acc : acc[k]), obj);
}

function normalizeHmacValue(v) {
    if (v === true) return 'true';
    if (v === false) return 'false';
    if (v == null) return '';
    return String(v);
}

/**
 * Verify a Paymob callback's HMAC-SHA512.
 * @param {object} obj - the transaction object (webhook `obj`, or assembled
 *   from the redirect query params).
 * @param {string} receivedHmac - the `hmac` Paymob sent.
 * @returns {boolean} true when the signature matches (or no secret is set,
 *   i.e. mock/dev — so the flow still completes).
 */
export function verifyHmac(obj, receivedHmac) {
    const secret = process.env.PAYMOB_HMAC_SECRET;
    // No secret: allow ONLY in mock/dev (so the demo completes). In live mode a
    // missing secret must FAIL CLOSED — never accept an unsigned webhook that
    // could complete a job and trigger a payout.
    if (!secret) return !isLiveMode();
    if (!receivedHmac) return false;
    const concatenated = HMAC_FIELDS.map((f) => normalizeHmacValue(pick(obj, f))).join('');
    const computed = crypto.createHmac('sha512', secret).update(concatenated).digest('hex');
    try {
        return crypto.timingSafeEqual(
            Buffer.from(computed, 'hex'),
            Buffer.from(String(receivedHmac).toLowerCase(), 'hex'),
        );
    } catch {
        return false;
    }
}

export default { isLiveMode, createInvoice, getPaymentStatus, verifyHmac };
