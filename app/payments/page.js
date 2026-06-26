'use client';

/* ============================================================
   SmartFix — Payments & Invoices page
   Reads GET /api/payments (Mongo-backed, same model the mobile
   app & MyFatoorah callback write to). Falls back to invoices
   derived from the seed issues so the demo always renders.
   ============================================================ */
import React, { useState, useEffect, useMemo } from 'react';
import { fetchWithTimeout } from '@/lib/fetchWithTimeout';
import { SF } from '@/components/sf/data';
import { useT } from '@/components/sf/i18n';
import { Icon } from '@/components/sf/Icon';
import {
  StatCard, SectionHead, DataTable, SearchBox, Select, Modal, Avatar,
} from '@/components/sf/ui';

const fmtDate = (s) => s ? new Date(s).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';
const fmtMoney = (n, c = 'EGP') => `${c} ${Number(n || 0).toLocaleString()}`;

const METHOD_CONFIG = {
  card:   { label: 'Card',   icon: 'CreditCard' },
  meeza:  { label: 'Meeza',  icon: 'CreditCard' },
  fawry:  { label: 'Fawry',  icon: 'Receipt' },
  wallet: { label: 'Wallet', icon: 'Wallet' },
};

// ── Static fallback ─────────────────────────────────────────
// Derive plausible invoices from the seed issues using the §3
// financial model defaults (platform 10%, VAT 14%, worker 15%).
function buildFallbackPayments() {
  const PLATFORM = 0.10, VAT = 0.14, COMMISSION = 0.15;
  return SF.ISSUES
    .filter(i => i.estimatedCost > 0 && ['completed', 'awaitingPayment', 'inProgress'].includes(i.status))
    .map((i, idx) => {
      const base = i.estimatedCost;
      const platformFee = Math.round(base * PLATFORM);
      const vat = Math.round((base + platformFee) * VAT);
      const discount = 0;
      const total = base + platformFee + vat - discount;
      const workerCommission = Math.round(base * COMMISSION);
      const payoutAmount = base - workerCommission;
      const status = i.status === 'completed' ? 'paid' : (i.status === 'awaitingPayment' ? 'pending' : (idx % 7 === 0 ? 'failed' : 'pending'));
      const methods = ['card', 'meeza', 'fawry', 'wallet'];
      return {
        _id: 'pay_' + (idx + 1),
        issueId: i._id,
        issueTitle: i.title,
        customerName: i.customerName,
        technicianName: i.assignedTechnicianName || '',
        method: methods[idx % methods.length],
        status,
        base, platformFee, vat, discount, total,
        workerCommission, payoutAmount,
        currency: 'EGP',
        createdAt: i.createdAt,
        paidAt: status === 'paid' ? i.createdAt : null,
      };
    });
}

const METHOD_AR = {
  card: 'بطاقة',
  meeza: 'ميزة',
  fawry: 'فوري',
  wallet: 'المحفظة',
};
const methodLabel = (t, key) => {
  const m = METHOD_CONFIG[key];
  return m ? t(m.label, METHOD_AR[key] || m.label) : key;
};

// Which status transitions are allowed from a given current status.
const STATUS_ACTIONS = {
  pending: ['paid', 'failed'],
  failed: ['paid'],
  paid: ['refunded'],
  refunded: [],
};

function InvoiceModal({ payment, onClose, onStatus, busy }) {
  const t = useT();
  const c = payment.currency || 'EGP';
  const st = SF.PAYMENT_STATUS_CONFIG[payment.status] || { label: payment.status, color: '#64748b' };
  const m = METHOD_CONFIG[payment.method] || { label: payment.method, icon: 'CreditCard' };
  const mLabel = methodLabel(t, payment.method);
  const allowed = STATUS_ACTIONS[payment.status] || [];

  const Row = (label, value, opts = {}) => React.createElement('div', {
    style: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '9px 0', borderBottom: opts.last ? 'none' : '1px solid var(--border)', ...(opts.style || {}) },
  },
    React.createElement('span', { style: { color: opts.strong ? 'var(--text-1)' : 'var(--text-2)', fontSize: opts.strong ? 14.5 : 13.5, fontWeight: opts.strong ? 700 : 500 } }, label),
    React.createElement('span', { className: 'tnum', style: { color: opts.color || (opts.strong ? 'var(--text-1)' : 'var(--text-1)'), fontSize: opts.strong ? 15.5 : 14, fontWeight: opts.strong ? 800 : 600 } }, value));

  return React.createElement(Modal, {
    title: t('Invoice Breakdown', 'تفاصيل الفاتورة'),
    sub: `${payment.issueTitle || payment.issueId || t('Service', 'خدمة')} · ${mLabel}`,
    onClose, wide: true,
    footer: React.createElement(React.Fragment, null,
      allowed.includes('paid') && React.createElement('button', { className: 'btn btn-ghost', disabled: busy, onClick: () => onStatus(payment, 'paid'), style: { color: '#10b981' } },
        React.createElement(Icon, { name: 'CircleCheck', size: 16 }), t('Mark Paid', 'وضع كمدفوعة')),
      allowed.includes('failed') && React.createElement('button', { className: 'btn btn-ghost', disabled: busy, onClick: () => onStatus(payment, 'failed'), style: { color: '#ef4444' } },
        React.createElement(Icon, { name: 'CircleX', size: 16 }), t('Mark Failed', 'وضع كفاشلة')),
      allowed.includes('refunded') && React.createElement('button', { className: 'btn btn-ghost', disabled: busy, onClick: () => onStatus(payment, 'refunded'), style: { color: '#a855f7' } },
        React.createElement(Icon, { name: 'RotateCcw', size: 16 }), t('Refund', 'استرداد')),
      React.createElement('button', { className: 'btn btn-primary', onClick: onClose },
        React.createElement(Icon, { name: 'Check', size: 16 }), t('Close', 'إغلاق'))),
  },
    // Header: status + parties
    React.createElement('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginBottom: 18, flexWrap: 'wrap' } },
      React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 10 } },
        React.createElement(Avatar, { name: payment.customerName || 'Customer' }),
        React.createElement('div', null,
          React.createElement('div', { className: 'cell-primary' }, payment.customerName || '—'),
          React.createElement('div', { className: 'cell-sub' }, payment.technicianName ? `${t('Technician', 'الفني')}: ${payment.technicianName}` : t('Unassigned', 'غير مُسند'))),
      React.createElement('span', { className: 'badge badge-soft', style: { background: `${st.color}1f`, color: st.color, border: `1px solid ${st.color}40` } },
        React.createElement('span', { className: 'bdot', style: { background: st.color } }), st.label)),

    // Client invoice
    React.createElement('div', { style: { fontSize: 11.5, fontWeight: 700, letterSpacing: 0.6, color: 'var(--text-3)', textTransform: 'uppercase', marginBottom: 4 } }, t('Client Invoice', 'فاتورة العميل')),
    React.createElement('div', { className: 'card', style: { padding: '4px 16px', marginBottom: 16 } },
      Row(t('Base service', 'سعر الخدمة الأساسي'), fmtMoney(payment.base, c)),
      Row(t('Platform fee', 'رسوم المنصة'), fmtMoney(payment.platformFee, c)),
      Row(t('VAT', 'ضريبة القيمة المضافة'), fmtMoney(payment.vat, c)),
      payment.discount > 0 && Row(t('Discount', 'الخصم'), `− ${fmtMoney(payment.discount, c)}`, { color: 'var(--success, #10b981)' }),
      Row(t('Total charged', 'إجمالي المبلغ المحصّل'), fmtMoney(payment.total, c), { strong: true, last: true, color: 'var(--accent)' })),

    // Worker payout
    React.createElement('div', { style: { fontSize: 11.5, fontWeight: 700, letterSpacing: 0.6, color: 'var(--text-3)', textTransform: 'uppercase', marginBottom: 4 } }, t('Worker Payout', 'مستحقات الفني')),
    React.createElement('div', { className: 'card', style: { padding: '4px 16px', marginBottom: 16 } },
      Row(t('Base service', 'سعر الخدمة الأساسي'), fmtMoney(payment.base, c)),
      Row(t('Worker commission', 'عمولة الفني'), `− ${fmtMoney(payment.workerCommission, c)}`),
      Row(t('Net payout', 'صافي المستحقات'), fmtMoney(payment.payoutAmount, c), { strong: true, last: true, color: 'var(--accent-2)' })),

    // Meta
    React.createElement('div', { style: { display: 'grid', gridTemplateColumns: 'repeat(2,1fr)', gap: 10 } },
      React.createElement('div', { className: 'card', style: { padding: 12 } },
        React.createElement('div', { className: 'cell-sub' }, t('Created', 'تاريخ الإنشاء')),
        React.createElement('div', { className: 'cell-muted' }, fmtDate(payment.createdAt))),
      React.createElement('div', { className: 'card', style: { padding: 12 } },
        React.createElement('div', { className: 'cell-sub' }, t('Paid At', 'تاريخ الدفع')),
        React.createElement('div', { className: 'cell-muted' }, fmtDate(payment.paidAt)))),

    // Payment link (when the provider returned a hosted checkout URL)
    payment.paymentUrl && React.createElement('div', { className: 'card', style: { padding: 12, marginTop: 10, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' } },
      React.createElement('div', { className: 'cell-sub' }, t('Payment Link', 'رابط الدفع')),
      React.createElement('a', { href: payment.paymentUrl, target: '_blank', rel: 'noopener noreferrer', className: 'cell-muted', style: { color: 'var(--accent)', display: 'inline-flex', alignItems: 'center', gap: 6, fontWeight: 600, wordBreak: 'break-all' } },
        React.createElement(Icon, { name: 'ExternalLink', size: 14 }), t('Open checkout', 'فتح صفحة الدفع')))));
}

// ── New invoice modal: collects the invoice inputs and POSTs /api/payments ──
function NewInvoiceModal({ onClose, onCreate, busy, result }) {
  const t = useT();
  const blank = { issueId: '', base: '', customerName: '', customerEmail: '', customerPhone: '', method: 'card' };
  const [form, setForm] = useState(blank);
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));
  const valid = Number(form.base) > 0;
  return React.createElement(Modal, {
    title: t('New Invoice', 'فاتورة جديدة'),
    sub: t('Create a payment invoice and share the checkout link', 'أنشئ فاتورة دفع وشارك رابط السداد'),
    onClose, wide: true,
    footer: React.createElement(React.Fragment, null,
      React.createElement('button', { className: 'btn btn-ghost', onClick: onClose }, result ? t('Close', 'إغلاق') : t('Cancel', 'إلغاء')),
      !result && React.createElement('button', { className: 'btn btn-primary', disabled: !valid || busy, onClick: () => onCreate(form) },
        React.createElement(Icon, { name: 'Plus', size: 16 }), busy ? t('Creating…', 'جارٍ الإنشاء…') : t('Create Invoice', 'إنشاء الفاتورة'))),
  },
    result
      ? React.createElement('div', null,
          React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 } },
            React.createElement('span', { style: { width: 34, height: 34, borderRadius: 9, background: 'rgba(16,185,129,0.14)', color: '#10b981', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' } }, React.createElement(Icon, { name: 'CircleCheck', size: 18 })),
            React.createElement('div', null,
              React.createElement('div', { className: 'cell-primary' }, t('Invoice created', 'تم إنشاء الفاتورة')),
              React.createElement('div', { className: 'cell-sub' }, `${t('Total', 'الإجمالي')}: ${fmtMoney(result.total, result.currency)}`))),
          result.paymentUrl
            ? React.createElement('div', { className: 'card', style: { padding: 14 } },
                React.createElement('div', { className: 'cell-sub', style: { marginBottom: 6 } }, t('Payment Link', 'رابط الدفع')),
                React.createElement('a', { href: result.paymentUrl, target: '_blank', rel: 'noopener noreferrer', style: { color: 'var(--accent)', display: 'inline-flex', alignItems: 'center', gap: 6, fontWeight: 600, wordBreak: 'break-all' } },
                  React.createElement(Icon, { name: 'ExternalLink', size: 14 }), result.paymentUrl))
            : React.createElement('div', { className: 'cell-sub' }, t('No payment link was returned by the provider.', 'لم يُرجِع مزوّد الدفع رابطًا للسداد.')))
      : React.createElement('div', { className: 'form-grid' },
          React.createElement('div', { className: 'field' },
            React.createElement('label', null, t('Base Amount (EGP)', 'المبلغ الأساسي (ج.م)'), React.createElement('span', { className: 'req' }, ' *')),
            React.createElement('input', { className: 'input', type: 'number', min: 0, value: form.base, onChange: (e) => set('base', e.target.value), placeholder: '0' })),
          React.createElement('div', { className: 'field' },
            React.createElement('label', null, t('Payment Method', 'طريقة الدفع')),
            React.createElement(Select, { value: form.method, onChange: (v) => set('method', v), icon: 'Wallet', options: Object.keys(METHOD_CONFIG).map(m => ({ value: m, label: methodLabel(t, m) })) })),
          React.createElement('div', { className: 'field' },
            React.createElement('label', null, t('Issue ID', 'معرّف البلاغ')),
            React.createElement('input', { className: 'input', value: form.issueId, onChange: (e) => set('issueId', e.target.value), placeholder: t('Optional', 'اختياري') })),
          React.createElement('div', { className: 'field' },
            React.createElement('label', null, t('Customer Name', 'اسم العميل')),
            React.createElement('input', { className: 'input', value: form.customerName, onChange: (e) => set('customerName', e.target.value), placeholder: t('e.g. Ahmed Ali', 'مثال: أحمد علي') })),
          React.createElement('div', { className: 'field' },
            React.createElement('label', null, t('Customer Email', 'البريد الإلكتروني للعميل')),
            React.createElement('input', { className: 'input', type: 'email', value: form.customerEmail, onChange: (e) => set('customerEmail', e.target.value), placeholder: 'name@example.com' })),
          React.createElement('div', { className: 'field' },
            React.createElement('label', null, t('Customer Phone', 'هاتف العميل')),
            React.createElement('input', { className: 'input', value: form.customerPhone, onChange: (e) => set('customerPhone', e.target.value), placeholder: '+20…' }))));
}

export default function PaymentsPage() {
  const t = useT();
  const [payments, setPayments] = useState([]);
  const [live, setLive] = useState(false);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState('');
  const [status, setStatus] = useState('all');
  const [method, setMethod] = useState('all');
  const [selected, setSelected] = useState(null);
  const [newOpen, setNewOpen] = useState(false);   // New Invoice modal
  const [newResult, setNewResult] = useState(null); // created payment (with paymentUrl)
  const [busy, setBusy] = useState(false);           // mutation in flight
  const [finance, setFinance] = useState(null);      // platform ledger summary

  // ── Load from the live API; keep the derived fallback on error/empty ──
  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const res = await fetchWithTimeout('/api/payments?limit=500', { cache: 'no-store' });
        if (!res.ok) return;
        const data = await res.json();
        const arr = Array.isArray(data) ? data : (data.payments || []);
        if (active) { setPayments(arr); setLive(true); }
      } catch { /* keep fallback */ }
      finally { if (active) setLoading(false); }
    })();
    return () => { active = false; };
  }, []);

  // ── Platform money ledger (Stage 5): revenue / payouts / VAT / owed ──
  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const res = await fetchWithTimeout('/api/wallet?scope=platform', { cache: 'no-store' });
        if (!res.ok) return;
        const data = await res.json();
        if (active && data && typeof data.revenue === 'number') setFinance(data);
      } catch { /* ledger unavailable — section stays hidden */ }
    })();
    return () => { active = false; };
  }, []);

  const stats = useMemo(() => {
    let revenue = 0, fees = 0, pending = 0;
    payments.forEach(p => {
      if (p.status === 'paid') { revenue += Number(p.total) || 0; fees += Number(p.platformFee) || 0; }
      if (p.status === 'pending') pending++;
    });
    return { revenue, fees, pending };
  }, [payments]);

  const currency = (payments[0] && payments[0].currency) || 'EGP';

  const filtered = useMemo(() => payments.filter(p =>
    (q === '' || (p.issueTitle || p.issueId || '').toLowerCase().includes(q.toLowerCase()) || (p.customerName || '').toLowerCase().includes(q.toLowerCase())) &&
    (status === 'all' || p.status === status) &&
    (method === 'all' || p.method === method)
  ), [payments, q, status, method]);

  // ── Change an invoice status (paid / failed / refunded). Optimistic with
  //    server reconcile; revert + surface the error on failure. ──
  const changeStatus = async (payment, status) => {
    const allowed = STATUS_ACTIONS[payment.status] || [];
    if (!allowed.includes(status) || busy) return;
    const prev = payment;
    const optimistic = {
      ...payment, status,
      ...(status === 'paid' ? { paidAt: new Date().toISOString() } : {}),
      ...(status === 'refunded' ? { refundedAt: new Date().toISOString() } : {}),
    };
    setBusy(true);
    setPayments(list => list.map(p => p._id === payment._id ? optimistic : p));
    setSelected(s => (s && s._id === payment._id ? optimistic : s));
    try {
      const res = await fetch(`/api/payments/${payment._id}`, {
        method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ status }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
      setPayments(list => list.map(p => p._id === payment._id ? { ...p, ...data } : p));
      setSelected(s => (s && s._id === payment._id ? { ...s, ...data } : s));
    } catch (err) {
      // Revert optimistic state and tell the user.
      setPayments(list => list.map(p => p._id === payment._id ? prev : p));
      setSelected(s => (s && s._id === payment._id ? prev : s));
      window.alert(t(`Could not update the invoice: ${err.message}`, `تعذّر تحديث الفاتورة: ${err.message}`));
    } finally {
      setBusy(false);
    }
  };

  // ── Create a new invoice via POST /api/payments. Prepends it to the list and
  //    surfaces the returned payment link. ──
  const createInvoice = async (form) => {
    if (busy) return;
    setBusy(true);
    try {
      const res = await fetch('/api/payments', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          issueId: form.issueId || '',
          base: Number(form.base) || 0,
          customerName: form.customerName || '',
          customerEmail: form.customerEmail || '',
          customerPhone: form.customerPhone || '',
          method: form.method || 'card',
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
      setPayments(list => [data, ...list]);
      setNewResult(data);
    } catch (err) {
      window.alert(t(`Could not create the invoice: ${err.message}`, `تعذّر إنشاء الفاتورة: ${err.message}`));
    } finally {
      setBusy(false);
    }
  };

  const closeNew = () => { setNewOpen(false); setNewResult(null); };

  const allOpt = (label) => ({ value: 'all', label });
  const columns = [
    { key: 'issueTitle', label: t('Service / Issue', 'الخدمة / البلاغ'), width: 220, sortAccessor: (r) => r.issueTitle || r.issueId || '', render: (r) => React.createElement('div', null,
      React.createElement('div', { className: 'cell-primary' }, r.issueTitle || r.issueId || '—'),
      React.createElement('div', { className: 'cell-sub' }, `${t('Invoice', 'فاتورة')} #${(r._id || '').toString().slice(-6).toUpperCase() || '—'}`)) },
    { key: 'customerName', label: t('Customer', 'العميل'), hideSm: true, render: (r) => React.createElement('span', { className: 'cell-muted' }, r.customerName || '—') },
    { key: 'technicianName', label: t('Technician', 'الفني'), hideSm: true, render: (r) => r.technicianName ? React.createElement('span', { className: 'cell-muted' }, r.technicianName) : React.createElement('span', { className: 'unassigned' }, t('Unassigned', 'غير مُسند')) },
    { key: 'method', label: t('Method', 'طريقة الدفع'), render: (r) => {
      const m = METHOD_CONFIG[r.method] || { label: r.method, icon: 'CreditCard' };
      return React.createElement('span', { className: 'cell-muted', style: { display: 'flex', alignItems: 'center', gap: 6 } }, React.createElement(Icon, { name: m.icon, size: 14, color: 'var(--text-3)' }), methodLabel(t, r.method));
    } },
    { key: 'total', label: t('Total', 'الإجمالي'), align: 'right', sortAccessor: (r) => Number(r.total) || 0, render: (r) => React.createElement('span', { className: 'tnum cell-primary' }, fmtMoney(r.total, r.currency)) },
    { key: 'status', label: t('Status', 'الحالة'), render: (r) => {
      const s = SF.PAYMENT_STATUS_CONFIG[r.status] || { label: r.status, color: '#64748b' };
      return React.createElement('span', { className: 'badge badge-soft', style: { background: `${s.color}1f`, color: s.color, border: `1px solid ${s.color}40` } },
        React.createElement('span', { className: 'bdot', style: { background: s.color } }), s.label);
    } },
    { key: 'paidAt', label: t('Paid', 'تاريخ الدفع'), hideSm: true, sortAccessor: (r) => r.paidAt ? new Date(r.paidAt).getTime() : 0, render: (r) => React.createElement('span', { className: 'cell-sub', style: { fontSize: 12.5 } }, fmtDate(r.paidAt)) },
    { key: 'actions', label: '', sortable: false, align: 'right', render: (r) => {
      const allowed = STATUS_ACTIONS[r.status] || [];
      return React.createElement('div', { className: 'row-actions', style: { justifyContent: 'flex-end' } },
        allowed.includes('paid') && React.createElement('button', { className: 'act-btn', disabled: busy, title: t('Mark paid', 'وضع كمدفوعة'), onClick: () => changeStatus(r, 'paid'), style: { color: '#10b981' } }, React.createElement(Icon, { name: 'CircleCheck', size: 15 })),
        allowed.includes('failed') && React.createElement('button', { className: 'act-btn', disabled: busy, title: t('Mark failed', 'وضع كفاشلة'), onClick: () => changeStatus(r, 'failed'), style: { color: '#ef4444' } }, React.createElement(Icon, { name: 'CircleX', size: 15 })),
        allowed.includes('refunded') && React.createElement('button', { className: 'act-btn', disabled: busy, title: t('Refund', 'استرداد'), onClick: () => changeStatus(r, 'refunded'), style: { color: '#a855f7' } }, React.createElement(Icon, { name: 'RotateCcw', size: 15 })),
        React.createElement('button', { className: 'act-btn', title: t('View invoice', 'عرض الفاتورة'), onClick: () => setSelected(r) }, React.createElement(Icon, { name: 'Eye', size: 15 })));
    } },
  ];

  return React.createElement('div', { className: 'page-anim' },
    React.createElement('div', { className: 'stat-grid grid-4', style: { gridTemplateColumns: 'repeat(3,1fr)' } },
      React.createElement(StatCard, { icon: 'DollarSign', label: t('Total Revenue', 'إجمالي الإيرادات'), value: stats.revenue, suffix: ' ' + currency, tone: 'success', foot: t('From paid invoices', 'من الفواتير المدفوعة'), delay: 0 }),
      React.createElement(StatCard, { icon: 'Landmark', label: t('Platform Fees', 'رسوم المنصة'), value: stats.fees, suffix: ' ' + currency, tone: 'primary', foot: t('Collected commission', 'العمولة المُحصّلة'), delay: 50 }),
      React.createElement(StatCard, { icon: 'Clock', label: t('Pending Payments', 'المدفوعات المعلّقة'), value: stats.pending, tone: 'warning', foot: t('Awaiting settlement', 'في انتظار التسوية'), delay: 100 })
    ),

    // ── Money ledger (Stage 5): where the customer's money actually went ──
    finance && React.createElement('div', { style: { marginTop: 16 } },
      React.createElement(SectionHead, { icon: 'Wallet', title: t('Money Ledger', 'دفتر الحركة المالية'), sub: `· ${finance.jobsSettled || 0} ${t('settled jobs', 'وظيفة مُسوّاة')}` }),
      React.createElement('div', { className: 'stat-grid grid-4' },
        React.createElement(StatCard, { icon: 'Wallet', label: t('Worker Payouts', 'مستحقات الفنيين'), value: finance.totalPayouts, suffix: ' ' + (finance.currency || 'EGP'), tone: 'success', foot: t('Credited to wallets', 'مُضافة لمحافظ الفنيين'), delay: 0 }),
        React.createElement(StatCard, { icon: 'Landmark', label: t('Commission', 'العمولة'), value: finance.commission, suffix: ' ' + (finance.currency || 'EGP'), tone: 'primary', foot: t('Platform commission', 'عمولة المنصّة'), delay: 50 }),
        React.createElement(StatCard, { icon: 'DollarSign', label: t('VAT Collected', 'ضريبة القيمة المضافة'), value: finance.vatCollected, suffix: ' ' + (finance.currency || 'EGP'), tone: 'warning', foot: t('To remit', 'للتوريد للضرائب'), delay: 100 }),
        React.createElement(StatCard, { icon: 'Clock', label: t('Owed to Workers', 'مستحقّ غير مسحوب'), value: finance.owedToWorkers, suffix: ' ' + (finance.currency || 'EGP'), tone: 'primary', foot: t('Credited, not withdrawn', 'مُضاف ولم يُسحب'), delay: 150 })
      )
    ),

    React.createElement(SectionHead, { icon: 'CreditCard', title: t('Payments & Invoices', 'المدفوعات والفواتير'), sub: `· ${filtered.length} ${t('shown', 'معروضة')}`,
      right: React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 10 } },
        live
          ? React.createElement('span', { title: t('Reading live data from the payments backend', 'يتم عرض بيانات مباشرة من خادم المدفوعات'), style: { display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, fontWeight: 700, letterSpacing: 0.4, color: '#0e9f6e', background: 'rgba(16,185,129,0.12)', padding: '4px 10px', borderRadius: 999 } },
              React.createElement('span', { style: { width: 7, height: 7, borderRadius: 999, background: '#10b981', display: 'inline-block' } }), t('LIVE', 'مباشر'))
          : React.createElement('span', { title: t('Showing derived sample data — the payments backend is unavailable', 'يتم عرض بيانات تجريبية مشتقّة — خادم المدفوعات غير متاح'), style: { display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, fontWeight: 700, letterSpacing: 0.4, color: '#b45309', background: 'rgba(245,158,11,0.14)', padding: '4px 10px', borderRadius: 999 } },
              React.createElement(Icon, { name: 'FlaskConical', size: 13 }), t('SAMPLE DATA', 'بيانات تجريبية')),
        React.createElement('button', { className: 'btn btn-primary', onClick: () => { setNewResult(null); setNewOpen(true); } }, React.createElement(Icon, { name: 'Plus', size: 16 }), t('New Invoice', 'فاتورة جديدة'))) }),

    React.createElement('div', { className: 'toolbar' },
      React.createElement(SearchBox, { value: q, onChange: setQ, placeholder: t('Search service or customer…', 'ابحث عن خدمة أو عميل…') }),
      React.createElement(Select, { value: status, onChange: setStatus, icon: 'Activity', options: [allOpt(t('All Statuses', 'كل الحالات')), ...Object.keys(SF.PAYMENT_STATUS_CONFIG).map(s => ({ value: s, label: SF.PAYMENT_STATUS_CONFIG[s].label }))] }),
      React.createElement(Select, { value: method, onChange: setMethod, icon: 'Wallet', options: [allOpt(t('All Methods', 'كل طرق الدفع')), ...Object.keys(METHOD_CONFIG).map(m => ({ value: m, label: methodLabel(t, m) }))] }),
      (q || status !== 'all' || method !== 'all') && React.createElement('button', { className: 'btn btn-ghost btn-sm', onClick: () => { setQ(''); setStatus('all'); setMethod('all'); } }, React.createElement(Icon, { name: 'X', size: 14 }), t('Clear', 'مسح'))
    ),

    React.createElement(DataTable, {
      columns, rows: filtered, pageSize: 8, initialSort: { key: 'paidAt', dir: 'desc' },
      emptyTitle: loading ? t('Loading payments…', 'جارٍ تحميل المدفوعات…') : t('No payments yet', 'لا توجد مدفوعات بعد'),
      emptySub: loading ? t('Fetching invoices from the backend.', 'يتم جلب الفواتير من الخادم.') : t('Invoices will appear here once customers are charged.', 'ستظهر الفواتير هنا بمجرد تحصيل المدفوعات من العملاء.'),
    }),

    selected && React.createElement(InvoiceModal, { payment: selected, onClose: () => setSelected(null), onStatus: changeStatus, busy }),

    newOpen && React.createElement(NewInvoiceModal, { onClose: closeNew, onCreate: createInvoice, busy, result: newResult })
  );
}
