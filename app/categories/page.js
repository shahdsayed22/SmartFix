'use client';

/* ============================================================
   SmartFix — Service Categories management page
   GET/POST/PUT /api/categories. Keys are immutable per §1 taxonomy.
   Falls back to SF.CATEGORY_CONFIG-derived rows when the API is empty.
   ============================================================ */
import React, { useState, useEffect, useMemo } from 'react';
import { fetchWithTimeout } from '@/lib/fetchWithTimeout';
import { SF } from '@/components/sf/data';
import { Icon } from '@/components/sf/Icon';
import { useT } from '@/components/sf/i18n';
import {
  StatCard, SectionHead, DataTable, SearchBox, Modal, Toggle, Loading,
} from '@/components/sf/ui';

// Canonical §1 default prices + Arabic labels (the SF display config only carries
// English label/icon/color, so the contract values fill the rest of the fallback).
const SEED_META = {
  plumbing:         { labelAr: 'السباكة',           icon: 'wrench',          defaultPrice: 180, order: 0 },
  electrical:       { labelAr: 'الكهرباء',          icon: 'zap',             defaultPrice: 200, order: 1 },
  carpentry:        { labelAr: 'النجارة',           icon: 'hammer',          defaultPrice: 250, order: 2 },
  painting:         { labelAr: 'الدهانات',          icon: 'paint-roller',    defaultPrice: 1200, order: 3 },
  hvac:             { labelAr: 'التكييف والتبريد',  icon: 'wind',            defaultPrice: 350, order: 4 },
  cleaning:         { labelAr: 'التنظيف',           icon: 'spray-can',       defaultPrice: 300, order: 5 },
  appliance_repair: { labelAr: 'صيانة الأجهزة',     icon: 'washing-machine', defaultPrice: 220, order: 6 },
  welding:          { labelAr: 'اللحام',            icon: 'flame',           defaultPrice: 280, order: 7 },
  tiling:           { labelAr: 'السيراميك والبلاط',  icon: 'grid-3x3',        defaultPrice: 900, order: 8 },
};

// Derive the static fallback rows from the SF display config + §1 contract meta.
const staticRows = () => SF.CATEGORIES.map((key) => {
  const cfg = SF.CATEGORY_CONFIG[key] || {};
  const meta = SEED_META[key] || {};
  return {
    key,
    labelEn: cfg.label || key,
    labelAr: meta.labelAr || '',
    icon: meta.icon || '',
    color: cfg.color || '#6366f1',
    defaultPrice: meta.defaultPrice ?? 0,
    order: meta.order ?? 0,
    active: true,
  };
});

const fmtEGP = (n) => 'EGP ' + (Number(n) || 0).toLocaleString();

// Lucide icon for display, keyed by category key (SF config) — resilient regardless
// of the slug-style icon string stored on the row.
const lucideFor = (key) => (SF.CATEGORY_CONFIG[key] && SF.CATEGORY_CONFIG[key].icon) || 'Layers';

function ColorSwatch({ color }) {
  return React.createElement('span', { style: { display: 'inline-flex', alignItems: 'center', gap: 7 } },
    React.createElement('span', { style: { width: 16, height: 16, borderRadius: 5, background: color || '#6366f1', border: '1px solid rgba(0,0,0,0.15)', display: 'inline-block' } }),
    React.createElement('span', { className: 'cell-sub', style: { fontFamily: 'monospace', fontSize: 12 } }, (color || '').toUpperCase()));
}

function CategoryModal({ category, onClose, onSave }) {
  const t = useT();
  const blank = { key: '', labelEn: '', labelAr: '', icon: '', color: '#6366f1', defaultPrice: '', order: 0, active: true };
  const [form, setForm] = useState(category || blank);
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));
  const isEdit = !!category;
  const valid = (form.key || '').trim() && (form.labelEn || '').trim();
  return React.createElement(Modal, {
    title: isEdit ? t('Edit Category', 'تعديل الفئة') : t('New Category', 'فئة جديدة'),
    sub: isEdit ? `${t('Editing', 'تعديل')} ${form.labelEn || form.key}` : t('Add a service category to the taxonomy', 'إضافة فئة خدمة إلى التصنيف'),
    onClose, wide: true,
    footer: React.createElement(React.Fragment, null,
      React.createElement('button', { className: 'btn btn-ghost', onClick: onClose }, t('Cancel', 'إلغاء')),
      React.createElement('button', { className: 'btn btn-primary', disabled: !valid, onClick: () => onSave(form) },
        React.createElement(Icon, { name: 'Check', size: 16 }), isEdit ? t('Save Changes', 'حفظ التغييرات') : t('Create Category', 'إنشاء فئة'))),
  },
    React.createElement('div', { className: 'form-grid' },
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Key ', 'المعرّف '), React.createElement('span', { className: 'req' }, '*')),
        React.createElement('input', {
          className: 'input', value: form.key, readOnly: isEdit, disabled: isEdit,
          onChange: (e) => set('key', e.target.value.trim().toLowerCase().replace(/\s+/g, '_')),
          placeholder: t('e.g. plumbing', 'مثال: plumbing'),
          style: isEdit ? { opacity: 0.65, cursor: 'not-allowed' } : undefined,
        }),
        React.createElement('div', { className: 'cell-sub', style: { marginTop: 4, fontSize: 11.5 } }, isEdit ? t('Keys are immutable (§1 taxonomy).', 'المعرّفات ثابتة لا تتغيّر (التصنيف §1).') : t('Lowercase, immutable once created.', 'أحرف صغيرة، ثابتة بعد الإنشاء.'))),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Default Price (EGP)', 'السعر الافتراضي (ج.م)')),
        React.createElement('input', { className: 'input', type: 'number', value: form.defaultPrice, onChange: (e) => set('defaultPrice', e.target.value), placeholder: '0' })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Label (English) ', 'الاسم (بالإنجليزية) '), React.createElement('span', { className: 'req' }, '*')),
        React.createElement('input', { className: 'input', value: form.labelEn, onChange: (e) => set('labelEn', e.target.value), placeholder: t('e.g. Plumbing', 'مثال: Plumbing') })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Label (Arabic)', 'الاسم (بالعربية)')),
        React.createElement('input', { className: 'input', value: form.labelAr, onChange: (e) => set('labelAr', e.target.value), placeholder: 'مثال: السباكة', style: { textAlign: 'right', direction: 'rtl' } })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Icon (slug)', 'الأيقونة (الرمز)')),
        React.createElement('input', { className: 'input', value: form.icon, onChange: (e) => set('icon', e.target.value), placeholder: t('e.g. wrench', 'مثال: wrench') })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Display Order', 'ترتيب العرض')),
        React.createElement('input', { className: 'input', type: 'number', value: form.order, onChange: (e) => set('order', e.target.value), placeholder: '0' })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Color', 'اللون')),
        React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 10 } },
          React.createElement('input', { type: 'color', value: form.color || '#6366f1', onChange: (e) => set('color', e.target.value), style: { width: 46, height: 38, padding: 2, borderRadius: 8, border: '1px solid var(--border)', background: 'transparent', cursor: 'pointer' } }),
          React.createElement('input', { className: 'input', value: form.color, onChange: (e) => set('color', e.target.value), placeholder: '#6366f1', style: { flex: 1 } }))),
      React.createElement('div', { className: 'field', style: { display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' } },
        React.createElement('label', null, t('Active', 'نشط')),
        React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 10, height: 38 } },
          React.createElement(Toggle, { on: !!form.active, onChange: (v) => set('active', v) }),
          React.createElement('span', { className: 'cell-sub' }, form.active ? t('Visible in the app', 'ظاهرة في التطبيق') : t('Hidden from the app', 'مخفية عن التطبيق'))))
    ));
}

export default function CategoriesPage() {
  const t = useT();
  const [rows, setRows] = useState(staticRows());
  const [loading, setLoading] = useState(true);
  const [source, setSource] = useState('static');
  const [q, setQ] = useState('');
  const [modal, setModal] = useState(null); // null | 'new' | categoryObj

  // ── Load from the live API; fall back to the §1 static rows on error/empty. ──
  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const res = await fetchWithTimeout('/api/categories', { cache: 'no-store' });
        if (!res.ok) throw new Error('bad status');
        const data = await res.json();
        const arr = Array.isArray(data) ? data : (data.categories || []);
        if (active && arr.length) {
          setRows(arr.slice().sort((a, b) => (a.order ?? 0) - (b.order ?? 0)));
          setSource(data.source || 'db');
        }
      } catch { /* keep the static fallback so the page always renders */ }
      finally { if (active) setLoading(false); }
    })();
    return () => { active = false; };
  }, []);

  const stats = useMemo(() => {
    const activeCount = rows.filter(r => r.active).length;
    const prices = rows.map(r => Number(r.defaultPrice) || 0).filter(p => p > 0);
    const avg = prices.length ? Math.round(prices.reduce((a, b) => a + b, 0) / prices.length) : 0;
    return { total: rows.length, active: activeCount, inactive: rows.length - activeCount, avg };
  }, [rows]);

  const filtered = useMemo(() => rows.filter(r =>
    q === '' ||
    (r.labelEn || '').toLowerCase().includes(q.toLowerCase()) ||
    (r.labelAr || '').includes(q) ||
    (r.key || '').toLowerCase().includes(q.toLowerCase())
  ), [rows, q]);

  const notify = (msg) => { if (typeof window !== 'undefined') window.alert(msg); };

  // Persist a category (optimistic local update, then upsert via the API).
  // On failure the optimistic change is reverted and an error surfaces; on
  // success the row is reconciled with the doc returned by the API.
  const saveCategory = async (form) => {
    setModal(null);
    const payload = {
      key: form.key,
      labelEn: form.labelEn,
      labelAr: form.labelAr,
      icon: form.icon,
      color: form.color,
      defaultPrice: Number(form.defaultPrice) || 0,
      order: Number(form.order) || 0,
      active: !!form.active,
    };
    const exists = rows.some(r => r.key === payload.key);
    const prevRows = rows; // snapshot for revert
    setRows(list => {
      const next = exists
        ? list.map(r => r.key === payload.key ? { ...r, ...payload } : r)
        : [...list, payload];
      return next.slice().sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
    });
    const method = exists ? 'PUT' : 'POST';
    try {
      const res = await fetch('/api/categories', { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
      // Reconcile with the returned doc (server defaults/normalisation).
      const doc = Array.isArray(data.categories) ? data.categories.find(c => c && c.key === payload.key) : null;
      if (doc) {
        setRows(list => list.map(r => r.key === payload.key ? { ...r, ...doc } : r)
          .slice().sort((a, b) => (a.order ?? 0) - (b.order ?? 0)));
      }
    } catch (err) {
      setRows(prevRows); // revert the optimistic change
      notify(t('Could not save the category. ', 'تعذّر حفظ الفئة. ') + (err.message || ''));
    }
  };

  // Toggle active — upsert just the active flag (key included so the API can match).
  const toggleActive = async (key, active) => {
    const prevRows = rows; // snapshot for revert
    setRows(list => list.map(r => r.key === key ? { ...r, active } : r));
    const row = rows.find(r => r.key === key);
    const payload = { ...(row || {}), key, active };
    try {
      const res = await fetch('/api/categories', { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
      const doc = Array.isArray(data.categories) ? data.categories.find(c => c && c.key === key) : null;
      if (doc) setRows(list => list.map(r => r.key === key ? { ...r, ...doc } : r));
    } catch (err) {
      setRows(prevRows); // revert the optimistic toggle
      notify(t('Could not update the category. ', 'تعذّر تحديث الفئة. ') + (err.message || ''));
    }
  };

  // Delete a category (after confirm). Optimistic removal, reverted on failure.
  const deleteCategory = async (row) => {
    if (typeof window !== 'undefined') {
      const ok = window.confirm(t(
        `Delete the category "${row.labelEn || row.key}"? This cannot be undone.`,
        `حذف الفئة "${row.labelEn || row.key}"؟ لا يمكن التراجع عن هذا الإجراء.`
      ));
      if (!ok) return;
    }
    const prevRows = rows; // snapshot for revert
    setRows(list => list.filter(r => r.key !== row.key));
    try {
      const res = await fetch(`/api/categories?key=${encodeURIComponent(row.key)}`, { method: 'DELETE' });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
    } catch (err) {
      setRows(prevRows); // revert the optimistic removal
      notify(t('Could not delete the category. ', 'تعذّر حذف الفئة. ') + (err.message || ''));
    }
  };

  const columns = [
    { key: 'labelEn', label: t('Category', 'الفئة'), width: 240, render: (r) => React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 11 } },
      React.createElement('span', { style: { width: 34, height: 34, borderRadius: 9, background: `${r.color || '#6366f1'}1f`, color: r.color || '#6366f1', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 } },
        React.createElement(Icon, { name: lucideFor(r.key), size: 17 })),
      React.createElement('div', null,
        React.createElement('div', { className: 'cell-primary' }, r.labelEn || r.key),
        React.createElement('div', { className: 'cell-sub', style: { direction: 'rtl', textAlign: 'left' } }, r.labelAr || '—'))) },
    { key: 'key', label: t('Key', 'المعرّف'), hideSm: true, render: (r) => React.createElement('span', { className: 'badge badge-soft', style: { fontFamily: 'monospace', fontSize: 11.5 } }, r.key) },
    { key: 'icon', label: t('Icon', 'الأيقونة'), hideSm: true, render: (r) => React.createElement('span', { className: 'cell-sub', style: { fontFamily: 'monospace', fontSize: 12 } }, r.icon || '—') },
    { key: 'color', label: t('Color', 'اللون'), hideSm: true, sortable: false, render: (r) => React.createElement(ColorSwatch, { color: r.color }) },
    { key: 'defaultPrice', label: t('Default Price', 'السعر الافتراضي'), align: 'right', sortAccessor: (r) => Number(r.defaultPrice) || 0, render: (r) => React.createElement('span', { className: 'cell-muted tnum' }, fmtEGP(r.defaultPrice)) },
    { key: 'order', label: t('Order', 'الترتيب'), align: 'center', hideSm: true, sortAccessor: (r) => Number(r.order) || 0, render: (r) => React.createElement('span', { className: 'cell-muted tnum' }, r.order ?? 0) },
    { key: 'active', label: t('Active', 'نشط'), align: 'center', sortAccessor: (r) => (r.active ? 1 : 0), render: (r) => React.createElement('div', { style: { display: 'flex', justifyContent: 'center' } }, React.createElement(Toggle, { on: !!r.active, onChange: (v) => toggleActive(r.key, v) })) },
    { key: 'actions', label: '', sortable: false, align: 'right', render: (r) => React.createElement('div', { className: 'row-actions', style: { justifyContent: 'flex-end' } },
      React.createElement('button', { className: 'act-btn', title: t('Edit', 'تعديل'), onClick: () => setModal(r) }, React.createElement(Icon, { name: 'Pencil', size: 15 })),
      React.createElement('button', { className: 'act-btn danger', title: t('Delete', 'حذف'), onClick: () => deleteCategory(r) }, React.createElement(Icon, { name: 'Trash2', size: 15 }))) },
  ];

  if (loading) return React.createElement(Loading, { text: t('Loading service categories…', 'جارٍ تحميل فئات الخدمات…') });

  return React.createElement('div', { className: 'page-anim' },
    React.createElement('div', { className: 'stat-grid grid-4' },
      React.createElement(StatCard, { icon: 'LayoutGrid', label: t('Total Categories', 'إجمالي الفئات'), value: stats.total, tone: 'primary', delay: 0 }),
      React.createElement(StatCard, { icon: 'CircleCheck', label: t('Active', 'النشطة'), value: stats.active, tone: 'success', delay: 50 }),
      React.createElement(StatCard, { icon: 'EyeOff', label: t('Inactive', 'غير النشطة'), value: stats.inactive, tone: 'warning', delay: 100 }),
      React.createElement(StatCard, { icon: 'Banknote', label: t('Avg. Default Price', 'متوسط السعر الافتراضي'), value: stats.avg, suffix: ' EGP', tone: 'cyan', delay: 150 })
    ),

    React.createElement(SectionHead, { icon: 'LayoutGrid', title: t('Service Categories', 'فئات الخدمات'), sub: `· ${filtered.length} ${t('shown', 'معروضة')}`,
      right: React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 10 } },
        source === 'db' && React.createElement('span', { title: t('Reading live data from the database', 'قراءة بيانات حيّة من قاعدة البيانات'), style: { display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, fontWeight: 700, letterSpacing: 0.4, color: '#0e9f6e', background: 'rgba(16,185,129,0.12)', padding: '4px 10px', borderRadius: 999 } },
          React.createElement('span', { style: { width: 7, height: 7, borderRadius: 999, background: '#10b981', display: 'inline-block' } }), t('LIVE', 'مباشر')),
        React.createElement('button', { className: 'btn btn-primary', onClick: () => setModal('new') }, React.createElement(Icon, { name: 'Plus', size: 16 }), t('New Category', 'فئة جديدة'))) }),

    React.createElement('div', { className: 'toolbar' },
      React.createElement(SearchBox, { value: q, onChange: setQ, placeholder: t('Search by name or key…', 'ابحث بالاسم أو المعرّف…') }),
      q && React.createElement('button', { className: 'btn btn-ghost btn-sm', onClick: () => setQ('') }, React.createElement(Icon, { name: 'X', size: 14 }), t('Clear', 'مسح'))
    ),

    React.createElement(DataTable, { columns, rows: filtered, pageSize: 10, initialSort: { key: 'order', dir: 'asc' }, emptyTitle: t('No categories match', 'لا توجد فئات مطابقة'), emptySub: t('Try a different search term.', 'جرّب كلمة بحث مختلفة.') }),

    modal && React.createElement(CategoryModal, { category: modal === 'new' ? null : modal, onClose: () => setModal(null), onSave: saveCategory })
  );
}
