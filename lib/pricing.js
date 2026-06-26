// SmartFix financial model (Build Contract §3).
// Source of truth = CommissionSettings singleton (admin-editable). These
// defaults reproduce the design's invoice exactly: base 320 → platform 32 →
// vat 49 → total 401.

export const DEFAULT_COMMISSION_SETTINGS = {
    key: 'default',
    platformFeePercent: 10,
    vatPercent: 14,
    workerCommissionPercent: 15,
    minPlatformFee: 0,
    currency: 'EGP',
};

/**
 * Resolve the active commission settings.
 * Prefers the CommissionSettings singleton (via its static getSettings()).
 * Falls back to DEFAULT_COMMISSION_SETTINGS if the model/collection is not
 * available yet, so callers can always compute deterministically.
 */
export async function getCommissionSettings() {
    try {
        const mod = await import('../models/CommissionSettings.js');
        const CommissionSettings = mod.default;
        if (CommissionSettings && typeof CommissionSettings.getSettings === 'function') {
            const doc = await CommissionSettings.getSettings();
            if (doc) {
                return {
                    key: doc.key ?? 'default',
                    platformFeePercent: numOr(doc.platformFeePercent, DEFAULT_COMMISSION_SETTINGS.platformFeePercent),
                    vatPercent: numOr(doc.vatPercent, DEFAULT_COMMISSION_SETTINGS.vatPercent),
                    workerCommissionPercent: numOr(doc.workerCommissionPercent, DEFAULT_COMMISSION_SETTINGS.workerCommissionPercent),
                    minPlatformFee: numOr(doc.minPlatformFee, DEFAULT_COMMISSION_SETTINGS.minPlatformFee),
                    currency: doc.currency || DEFAULT_COMMISSION_SETTINGS.currency,
                };
            }
        }
    } catch {
        // Model not present yet (other agent) — fall through to defaults.
    }
    return { ...DEFAULT_COMMISSION_SETTINGS };
}

function numOr(value, fallback) {
    const n = Number(value);
    return Number.isFinite(n) ? n : fallback;
}

/**
 * Compute the client-facing invoice.
 * @param {{ base:number, settings?:object, discount?:number }} args
 * @returns {{ base, platformFee, vat, discount, total, currency }}
 *
 * platformFee = max(minPlatformFee, round(base * platformFeePercent/100))
 * vat         = round((base + platformFee) * vatPercent/100)
 * total       = max(0, base + platformFee + vat - discount)
 */
export function computeInvoice({ base, settings, discount } = {}) {
    const s = { ...DEFAULT_COMMISSION_SETTINGS, ...(settings || {}) };
    const safeBase = Math.max(0, numOr(base, 0));

    const platformFee = Math.max(
        s.minPlatformFee,
        Math.round((safeBase * s.platformFeePercent) / 100),
    );
    const vat = Math.round(((safeBase + platformFee) * s.vatPercent) / 100);
    const gross = safeBase + platformFee + vat;
    // A discount can never exceed the gross (no negative totals) and can never
    // dip below the worker's payout — the platform absorbs at most its own
    // margin (fee + commission), never the worker's pay or the VAT to remit.
    const workerCommission = Math.round((safeBase * s.workerCommissionPercent) / 100);
    const maxDiscount = Math.max(0, gross - Math.max(0, safeBase - workerCommission));
    const appliedDiscount = Math.min(Math.max(0, numOr(discount, 0)), maxDiscount);
    const total = Math.max(0, gross - appliedDiscount);

    return {
        base: safeBase,
        platformFee,
        vat,
        discount: appliedDiscount,
        total,
        currency: s.currency,
    };
}

/**
 * Compute the worker-facing payout.
 * @param {{ base:number, settings?:object }} args
 * @returns {{ base, workerCommission, payout, currency }}
 *
 * workerCommission = round(base * workerCommissionPercent/100)
 * payout           = base - workerCommission
 */
export function computePayout({ base, settings } = {}) {
    const s = { ...DEFAULT_COMMISSION_SETTINGS, ...(settings || {}) };
    const safeBase = Math.max(0, numOr(base, 0));

    const workerCommission = Math.round((safeBase * s.workerCommissionPercent) / 100);
    const payout = Math.max(0, safeBase - workerCommission);

    return {
        base: safeBase,
        workerCommission,
        payout,
        currency: s.currency,
    };
}

export default { getCommissionSettings, computeInvoice, computePayout, DEFAULT_COMMISSION_SETTINGS };
