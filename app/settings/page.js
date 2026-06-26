'use client';

/* ============================================================
   SmartFix — Commission & Tax Settings page
   Source of truth = CommissionSettings singleton (Build Contract §3).
   GET /api/settings/commission  → load form values
   PUT /api/settings/commission  → persist edits
   Live invoice preview computes platformFee / vat / total / payout
   client-side using the exact §3 formulas (no server import in a
   'use client' page); falls back to contract defaults if the API
   isn't reachable so the demo always renders.
   ============================================================ */
import React, { useState, useEffect, useMemo } from 'react';
import { fetchWithTimeout } from '@/lib/fetchWithTimeout';
import { Icon } from '@/components/sf/Icon';
import { StatCard, SectionHead, ChartCard, Loading } from '@/components/sf/ui';
import { useT } from '@/components/sf/i18n';

// Contract §3 defaults — used as the static fallback if the API is offline.
const DEFAULTS = {
  platformFeePercent: 10,
  vatPercent: 14,
  workerCommissionPercent: 15,
  minPlatformFee: 0,
  currency: 'EGP',
};

const numOr = (v, f) => { const n = Number(v); return Number.isFinite(n) ? n : f; };

// computeInvoice (client-facing) — Build Contract §3.
function computeInvoice(base, s) {
  const b = Math.max(0, numOr(base, 0));
  const platformFee = Math.max(numOr(s.minPlatformFee, 0), Math.round((b * numOr(s.platformFeePercent, 0)) / 100));
  const vat = Math.round(((b + platformFee) * numOr(s.vatPercent, 0)) / 100);
  const total = Math.max(0, b + platformFee + vat);
  return { base: b, platformFee, vat, total };
}
// computePayout (worker-facing) — Build Contract §3.
function computePayout(base, s) {
  const b = Math.max(0, numOr(base, 0));
  const workerCommission = Math.round((b * numOr(s.workerCommissionPercent, 0)) / 100);
  return { base: b, workerCommission, payout: b - workerCommission };
}

// Numeric field with a unit suffix, using the existing input/field styling.
function NumField({ label, hint, value, onChange, unit, step = 1, min = 0 }) {
  return React.createElement('div', { className: 'field' },
    React.createElement('label', null, label),
    React.createElement('div', { style: { position: 'relative' } },
      React.createElement('input', {
        className: 'input', type: 'number', step, min,
        value: value === '' ? '' : value,
        onChange: (e) => onChange(e.target.value),
        style: { paddingRight: unit ? 52 : undefined },
      }),
      unit && React.createElement('span', {
        style: { position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-3)', fontSize: 12.5, fontWeight: 700, pointerEvents: 'none' },
      }, unit)),
    hint && React.createElement('div', { className: 'cell-sub', style: { marginTop: 5 } }, hint));
}

export default function CommissionSettingsPage() {
  const t = useT();
  const [form, setForm] = useState(DEFAULTS);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);   // inline confirmation toast
  const [error, setError] = useState('');
  const [sampleBase, setSampleBase] = useState(320); // design sample: 320 → 32 → 49 → 401

  const set = (k, v) => { setForm(f => ({ ...f, [k]: v })); setSaved(false); };

  // ── Load settings ────────────────────────────────────────────────
  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const res = await fetchWithTimeout('/api/settings/commission', { cache: 'no-store' });
        if (!res.ok) throw new Error('bad status');
        const data = await res.json();
        if (active && data && !data.error) {
          setForm({
            platformFeePercent: numOr(data.platformFeePercent, DEFAULTS.platformFeePercent),
            vatPercent: numOr(data.vatPercent, DEFAULTS.vatPercent),
            workerCommissionPercent: numOr(data.workerCommissionPercent, DEFAULTS.workerCommissionPercent),
            minPlatformFee: numOr(data.minPlatformFee, DEFAULTS.minPlatformFee),
            currency: data.currency || DEFAULTS.currency,
          });
        }
      } catch {
        if (active) setForm(DEFAULTS); // contract-default fallback — page never blank
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => { active = false; };
  }, []);

  // ── Save settings ────────────────────────────────────────────────
  const save = async () => {
    setSaving(true); setError(''); setSaved(false);
    const payload = {
      platformFeePercent: numOr(form.platformFeePercent, DEFAULTS.platformFeePercent),
      vatPercent: numOr(form.vatPercent, DEFAULTS.vatPercent),
      workerCommissionPercent: numOr(form.workerCommissionPercent, DEFAULTS.workerCommissionPercent),
      minPlatformFee: numOr(form.minPlatformFee, DEFAULTS.minPlatformFee),
      currency: (form.currency || DEFAULTS.currency).trim() || DEFAULTS.currency,
    };
    try {
      const res = await fetch('/api/settings/commission', {
        method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || (data && data.error)) throw new Error((data && data.error) || 'Save failed');
      setSaved(true);
      setTimeout(() => setSaved(false), 3200);
    } catch (e) {
      // Optimistic: keep the edited values locally; surface a soft error.
      setError(t('Could not reach the server — changes kept locally for this session.', 'تعذّر الوصول إلى الخادم — تم حفظ التغييرات محليًا لهذه الجلسة.'));
      setSaved(true);
      setTimeout(() => setSaved(false), 3200);
    } finally {
      setSaving(false);
    }
  };

  const cur = form.currency || DEFAULTS.currency;
  const fmt = (n) => `${cur} ${Number(n || 0).toLocaleString()}`;

  const invoice = useMemo(() => computeInvoice(sampleBase, form), [sampleBase, form]);
  const payout = useMemo(() => computePayout(sampleBase, form), [sampleBase, form]);

  if (loading) return React.createElement(Loading, { text: t('Loading commission settings…', 'جارٍ تحميل إعدادات العمولة…') });

  // ── Invoice preview line ──────────────────────────────────────────
  const line = (label, value, opts = {}) => React.createElement('div', {
    style: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '11px 0', borderBottom: opts.last ? 'none' : '1px solid var(--border)' },
  },
    React.createElement('span', { style: { color: opts.strong ? 'var(--text-1)' : 'var(--text-2)', fontWeight: opts.strong ? 800 : 500, fontSize: opts.strong ? 15 : 13.5 } }, label),
    React.createElement('span', {
      className: 'tnum',
      style: { color: opts.tone || (opts.strong ? 'var(--text-1)' : 'var(--text-2)'), fontWeight: opts.strong ? 900 : 700, fontSize: opts.strong ? 17 : 14 },
    }, value));

  return React.createElement('div', { className: 'page-anim' },

    // KPI strip — current configured rates
    React.createElement('div', { className: 'stat-grid grid-4' },
      React.createElement(StatCard, { icon: 'Percent', label: t('Platform Fee', 'رسوم المنصة'), value: numOr(form.platformFeePercent, 0), suffix: '%', tone: 'primary', foot: t('On service base', 'على أساس قيمة الخدمة'), delay: 0 }),
      React.createElement(StatCard, { icon: 'ReceiptText', label: t('VAT', 'ضريبة القيمة المضافة'), value: numOr(form.vatPercent, 0), suffix: '%', tone: 'cyan', foot: t('On base + fee', 'على الأساس + الرسوم'), delay: 50 }),
      React.createElement(StatCard, { icon: 'HandCoins', label: t('Worker Commission', 'عمولة الفني'), value: numOr(form.workerCommissionPercent, 0), suffix: '%', tone: 'warning', foot: t('Deducted from payout', 'تُخصم من المستحقات'), delay: 100 }),
      React.createElement(StatCard, { icon: 'Coins', label: t('Min Platform Fee', 'الحد الأدنى لرسوم المنصة'), value: numOr(form.minPlatformFee, 0), suffix: ' ' + cur, tone: 'success', foot: t('Floor per job', 'الحد الأدنى لكل مهمة'), delay: 150 })
    ),

    React.createElement(SectionHead, {
      icon: 'Settings', title: t('Commission & Tax Settings', 'إعدادات العمولة والضرائب'), sub: t('· source of truth for all invoices', '· المرجع الأساسي لجميع الفواتير'),
      right: React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 10 } },
        saved && !error && React.createElement('span', {
          style: { display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12, fontWeight: 700, color: '#0e9f6e', background: 'rgba(16,185,129,0.12)', padding: '5px 11px', borderRadius: 999 },
        }, React.createElement(Icon, { name: 'Check', size: 14 }), t('Saved', 'تم الحفظ')),
        React.createElement('button', { className: 'btn btn-primary', disabled: saving, onClick: save },
          React.createElement(Icon, { name: saving ? 'Loader' : 'Save', size: 16 }), saving ? t('Saving…', 'جارٍ الحفظ…') : t('Save Changes', 'حفظ التغييرات'))),
    }),

    // Two-column layout: editor (left) + live preview (right)
    React.createElement('div', { className: 'settings-grid', style: { display: 'grid', gridTemplateColumns: 'minmax(0,1.15fr) minmax(0,1fr)', gap: 18, alignItems: 'start' } },

      // ── Editor card ──
      React.createElement('div', { className: 'card', style: { padding: 22 } },
        React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 9, marginBottom: 18 } },
          React.createElement('span', { className: 'stat-icon bg-primary-soft', style: { width: 36, height: 36 } }, React.createElement(Icon, { name: 'SlidersHorizontal', size: 18 })),
          React.createElement('div', null,
            React.createElement('h3', { style: { margin: 0, fontSize: 15.5, fontWeight: 800 } }, t('Rate Configuration', 'إعداد النسب')),
            React.createElement('div', { className: 'chart-sub' }, t('Applied to every new invoice & payout', 'تُطبَّق على كل فاتورة ومستحقات جديدة')))),

        error && React.createElement('div', {
          style: { display: 'flex', alignItems: 'center', gap: 8, background: 'rgba(245,158,11,0.12)', color: 'var(--warning,#b45309)', border: '1px solid rgba(245,158,11,0.3)', borderRadius: 10, padding: '9px 12px', fontSize: 12.5, marginBottom: 16 },
        }, React.createElement(Icon, { name: 'TriangleAlert', size: 15 }), error),

        React.createElement('div', { className: 'form-grid' },
          React.createElement(NumField, { label: t('Platform Fee', 'رسوم المنصة'), hint: t('Percent of the service base charged to the customer.', 'نسبة مئوية من قيمة الخدمة تُحصّل من العميل.'), value: form.platformFeePercent, onChange: (v) => set('platformFeePercent', v), unit: '%', step: 0.5 }),
          React.createElement(NumField, { label: t('VAT', 'ضريبة القيمة المضافة'), hint: t('Tax on (base + platform fee).', 'ضريبة على (الأساس + رسوم المنصة).'), value: form.vatPercent, onChange: (v) => set('vatPercent', v), unit: '%', step: 0.5 }),
          React.createElement(NumField, { label: t('Worker Commission', 'عمولة الفني'), hint: t('Deducted from the worker payout.', 'تُخصم من مستحقات الفني.'), value: form.workerCommissionPercent, onChange: (v) => set('workerCommissionPercent', v), unit: '%', step: 0.5 }),
          React.createElement(NumField, { label: t('Minimum Platform Fee', 'الحد الأدنى لرسوم المنصة'), hint: t('Floor applied per job, in ' + cur + '.', 'الحد الأدنى المطبَّق لكل مهمة، بـ ' + cur + '.'), value: form.minPlatformFee, onChange: (v) => set('minPlatformFee', v), unit: cur, step: 1 }),
          React.createElement('div', { className: 'field col-2' },
            React.createElement('label', null, t('Currency', 'العملة')),
            React.createElement('input', { className: 'input', value: form.currency || '', onChange: (e) => set('currency', e.target.value), placeholder: 'EGP', maxLength: 6, style: { textTransform: 'uppercase', maxWidth: 160 } }),
            React.createElement('div', { className: 'cell-sub', style: { marginTop: 5 } }, t('ISO currency code shown on invoices.', 'رمز العملة (ISO) الظاهر على الفواتير.'))))),

      // ── Live invoice preview card ──
      React.createElement(ChartCard, { title: t('Live Invoice Preview', 'معاينة الفاتورة المباشرة'), sub: t('Recomputes instantly as you edit the rates', 'تُحسب فورًا أثناء تعديلك للنسب') },
        React.createElement('div', { className: 'field', style: { marginBottom: 14 } },
          React.createElement('label', null, t('Sample Base Amount', 'مبلغ الأساس التجريبي'), ' (', cur, ')'),
          React.createElement('input', {
            className: 'input', type: 'number', min: 0, step: 10, value: sampleBase === '' ? '' : sampleBase,
            onChange: (e) => setSampleBase(e.target.value === '' ? '' : Number(e.target.value)),
            placeholder: '320',
          })),

        // Customer invoice breakdown
        React.createElement('div', { style: { background: 'var(--surface-2, rgba(127,127,127,0.05))', border: '1px solid var(--border)', borderRadius: 12, padding: '6px 16px', marginBottom: 16 } },
          React.createElement('div', { style: { fontSize: 11, fontWeight: 800, letterSpacing: 0.5, color: 'var(--text-3)', textTransform: 'uppercase', padding: '12px 0 4px' } }, t('Customer Invoice', 'فاتورة العميل')),
          line(t('Service Base', 'قيمة الخدمة'), fmt(invoice.base)),
          line(`${t('Platform Fee', 'رسوم المنصة')} (${numOr(form.platformFeePercent, 0)}%)`, '+ ' + fmt(invoice.platformFee), { tone: 'var(--accent)' }),
          line(`${t('VAT', 'ضريبة القيمة المضافة')} (${numOr(form.vatPercent, 0)}%)`, '+ ' + fmt(invoice.vat), { tone: 'var(--accent-2)' }),
          line(t('Total Charged', 'إجمالي المطلوب'), fmt(invoice.total), { strong: true, tone: 'var(--accent)', last: true })),

        // Worker payout breakdown
        React.createElement('div', { style: { background: 'var(--surface-2, rgba(127,127,127,0.05))', border: '1px solid var(--border)', borderRadius: 12, padding: '6px 16px' } },
          React.createElement('div', { style: { fontSize: 11, fontWeight: 800, letterSpacing: 0.5, color: 'var(--text-3)', textTransform: 'uppercase', padding: '12px 0 4px' } }, t('Worker Payout', 'مستحقات الفني')),
          line(t('Service Base', 'قيمة الخدمة'), fmt(payout.base)),
          line(`${t('Commission', 'العمولة')} (${numOr(form.workerCommissionPercent, 0)}%)`, '− ' + fmt(payout.workerCommission), { tone: 'var(--warning,#b45309)' }),
          line(t('Net Payout', 'صافي المستحقات'), fmt(payout.payout), { strong: true, tone: '#0e9f6e', last: true })),

        React.createElement('div', { className: 'cell-sub', style: { marginTop: 14, display: 'flex', alignItems: 'center', gap: 6 } },
          React.createElement(Icon, { name: 'Info', size: 13 }),
          t('Formulas per financial model §3 — fee, VAT and commission are rounded to whole ', 'الصيغ وفق النموذج المالي §3 — تُقرَّب الرسوم والضريبة والعمولة إلى أعداد صحيحة بـ '), cur, '.'))
    )
  );
}
