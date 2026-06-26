// SmartFix MyFatoorah wrapper (Build Contract §6).
// Thin client around the MyFatoorah REST API with a built-in MOCK MODE so the
// demo runs with no keys. NEVER hardcode a real key — config comes from env:
//   MYFATOORAH_ENABLED  ('true' to hit the real API; anything else → mock)
//   MYFATOORAH_API_KEY  (required for live mode)
//   MYFATOORAH_BASE_URL (default https://apitest.myfatoorah.com)

const DEFAULT_BASE_URL = 'https://apitest.myfatoorah.com';

function isLiveMode() {
    const enabled = String(process.env.MYFATOORAH_ENABLED || '').toLowerCase();
    const on = enabled === 'true' || enabled === '1' || enabled === 'yes';
    return on && Boolean(process.env.MYFATOORAH_API_KEY);
}

function getBaseUrl() {
    return process.env.MYFATOORAH_BASE_URL || DEFAULT_BASE_URL;
}

/**
 * Deterministic fake invoice id for mock mode (stable per amount + customer).
 */
function mockInvoiceId({ amount, customer }) {
    const seed = `${amount || 0}-${customer?.email || customer?.phone || customer?.name || 'guest'}`;
    let hash = 0;
    for (let i = 0; i < seed.length; i += 1) {
        hash = (hash * 31 + seed.charCodeAt(i)) >>> 0;
    }
    return `MOCK-${hash.toString(36).toUpperCase()}`;
}

/**
 * Create a hosted payment invoice.
 * @param {{ amount:number, customer?:{name?,email?,phone?}, callbackUrl?:string, displayCurrency?:string }} args
 * @returns {Promise<{ invoiceId:string, paymentUrl:string, mock:boolean }>}
 *
 * Mock mode (no key / not enabled): returns a deterministic invoiceId and a
 * local callback URL so the flow can complete offline.
 */
export async function createInvoice({ amount, customer = {}, callbackUrl, errorUrl, customerReference, displayCurrency = 'EGP' } = {}) {
    if (!isLiveMode()) {
        const invoiceId = mockInvoiceId({ amount, customer });
        const base = callbackUrl || '/api/payments/callback';
        const sep = base.includes('?') ? '&' : '?';
        const paymentUrl = `${base}${sep}mock=1&invoiceId=${encodeURIComponent(invoiceId)}&status=paid`;
        return { invoiceId, paymentUrl, mock: true };
    }

    const res = await fetch(`${getBaseUrl()}/v2/SendPayment`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${process.env.MYFATOORAH_API_KEY}`,
        },
        body: JSON.stringify({
            InvoiceValue: amount,
            CustomerName: customer.name || 'SmartFix Customer',
            CustomerEmail: customer.email || undefined,
            CustomerMobile: customer.phone || undefined,
            DisplayCurrencyIso: displayCurrency,
            CallBackUrl: callbackUrl || undefined,
            ErrorUrl: errorUrl || callbackUrl || undefined,
            CustomerReference: customerReference || undefined,
            NotificationOption: 'LNK',
        }),
    });

    if (!res.ok) {
        const text = await res.text().catch(() => '');
        throw new Error(`MyFatoorah createInvoice failed (${res.status}): ${text}`);
    }

    const json = await res.json();
    const data = json?.Data || {};
    return {
        invoiceId: String(data.InvoiceId ?? ''),
        paymentUrl: data.InvoiceURL || '',
        mock: false,
    };
}

/**
 * Look up the payment status for an invoice.
 * @param {string} invoiceId
 * @returns {Promise<{ status:'paid'|'pending'|'failed', mock:boolean, raw?:any }>}
 *
 * Mock mode: always resolves as 'paid' so the demo completes.
 */
export async function getPaymentStatus(key, keyType = 'InvoiceId') {
    if (!isLiveMode()) {
        return { status: 'paid', mock: true };
    }

    const res = await fetch(`${getBaseUrl()}/v2/GetPaymentStatus`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${process.env.MYFATOORAH_API_KEY}`,
        },
        // keyType is 'InvoiceId' (our stored providerInvoiceId) or 'PaymentId'
        // (what MyFatoorah appends to the CallBackUrl after the hosted payment).
        body: JSON.stringify({ Key: String(key), KeyType: keyType }),
    });

    if (!res.ok) {
        const text = await res.text().catch(() => '');
        throw new Error(`MyFatoorah getPaymentStatus failed (${res.status}): ${text}`);
    }

    const json = await res.json();
    const data = json?.Data || {};
    const raw = String(data.InvoiceStatus || '').toLowerCase();
    let status = 'pending';
    if (raw === 'paid') status = 'paid';
    else if (raw === 'failed' || raw === 'expired') status = 'failed';

    return {
        status,
        mock: false,
        raw: data.InvoiceStatus,
        invoiceId: String(data.InvoiceId ?? ''),
    };
}

export default { createInvoice, getPaymentStatus };
