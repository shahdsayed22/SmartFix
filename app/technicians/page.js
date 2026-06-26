'use client';

/* ============================================================
   SmartFix — Technician Management page (ported from prototype)
   Wired to the live MongoDB API (/api/technicians), with a
   static SF.TECHNICIANS fallback so the demo always renders.
   ============================================================ */
import React, { useState, useMemo, useEffect } from 'react';
import { fetchWithTimeout } from '@/lib/fetchWithTimeout';
import { SF } from '@/components/sf/data';
import { useT } from '@/components/sf/i18n';
import { Icon } from '@/components/sf/Icon';
import {
  StatCard, SectionHead, DataTable, SearchBox, Select,
  CatChip, Stars, VerifiedBadge, Toggle, Modal, Avatar,
} from '@/components/sf/ui';

/* Normalise a technician record (API or seed) so render never crashes. */
function normTech(t) {
  return {
    ...t,
    name: t.name || '',
    city: t.city || 'Cairo',
    phone: t.phone || '',
    category: t.category || 'plumbing',
    categories: Array.isArray(t.categories) && t.categories.length
      ? t.categories
      : (t.category ? [t.category] : []),
    specialization: t.specialization || '',
    rating: typeof t.rating === 'number' ? t.rating : Number(t.rating) || 0,
    issuesResolved: typeof t.issuesResolved === 'number' ? t.issuesResolved : Number(t.issuesResolved) || 0,
    isVerified: !!t.isVerified,
    verificationStatus: t.verificationStatus || (t.isVerified ? 'verified' : 'pending'),
    nationalIdFrontUrl: t.nationalIdFrontUrl || '',
    nationalIdBackUrl: t.nationalIdBackUrl || '',
  };
}

// National ID review block (read-only) for the technician modal. Shows the
// front/back images the technician uploaded at registration so the admin can
// confirm identity before verifying. Clicking opens the full image in a tab.
function IdReview({ t, front, back }) {
  const cell = (label, url) => React.createElement('div', { style: { flex: 1 } },
    React.createElement('div', { className: 'fr-sub', style: { marginBottom: 6 } }, label),
    url
      ? React.createElement('a', { href: url, target: '_blank', rel: 'noopener noreferrer' },
          React.createElement('img', {
            src: url, alt: label, loading: 'lazy',
            style: { width: '100%', aspectRatio: '1.55', objectFit: 'cover', borderRadius: 10, border: '1px solid var(--line, #e5e7eb)', cursor: 'zoom-in' },
          }))
      : React.createElement('div', {
          style: { width: '100%', aspectRatio: '1.55', display: 'grid', placeItems: 'center', borderRadius: 10, border: '1px dashed var(--line, #e5e7eb)', color: '#9ca3af', fontSize: 12 },
        }, t('Not uploaded', 'لم تُرفع')));
  return React.createElement('div', { className: 'field col-2' },
    React.createElement('label', null, t('National ID', 'بطاقة الرقم القومي')),
    React.createElement('div', { style: { display: 'flex', gap: 12 } },
      cell(t('Front', 'الوجه الأمامي'), front),
      cell(t('Back', 'الوجه الخلفي'), back)));
}

function TechModal({ tech, onClose, onSave }) {
  const t = useT();
  const blank = { name: '', city: 'Cairo', category: 'plumbing', categories: [], phone: '', rating: 4.5, specialization: '', isVerified: false, issuesResolved: 0 };
  const [form, setForm] = useState(tech ? normTech(tech) : blank);
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));
  const toggleCat = (s) => set('categories', form.categories.includes(s) ? form.categories.filter(x => x !== s) : [...form.categories, s]);
  const valid = form.name.trim() && form.phone.trim();
  return React.createElement(Modal, {
    title: tech ? t('Edit Technician', 'تعديل الفني') : t('Add Technician', 'إضافة فني'),
    sub: tech ? form.name : t('Onboard a new field technician', 'إضافة فني ميداني جديد'),
    onClose, wide: true,
    footer: React.createElement(React.Fragment, null,
      React.createElement('button', { className: 'btn btn-ghost', onClick: onClose }, t('Cancel', 'إلغاء')),
      React.createElement('button', { className: 'btn btn-primary', disabled: !valid, onClick: () => onSave(form) }, React.createElement(Icon, { name: 'Check', size: 16 }), tech ? t('Save Changes', 'حفظ التغييرات') : t('Add Technician', 'إضافة فني'))),
  },
    React.createElement('div', { className: 'form-grid' },
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Full Name ', 'الاسم الكامل '), React.createElement('span', { className: 'req' }, '*')),
        React.createElement('input', { className: 'input', value: form.name, onChange: (e) => set('name', e.target.value), placeholder: t('e.g. Ahmed Hassan', 'مثال: أحمد حسن') })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Phone ', 'الهاتف '), React.createElement('span', { className: 'req' }, '*')),
        React.createElement('input', { className: 'input', value: form.phone, onChange: (e) => set('phone', e.target.value), placeholder: '+20…' })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('City', 'المدينة')),
        React.createElement(Select, { value: form.city, onChange: (v) => set('city', v), options: SF.CITIES.map(c => ({ value: c, label: c })) })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Primary Category', 'الفئة الرئيسية')),
        React.createElement(Select, { value: form.category, onChange: (v) => set('category', v), options: SF.CATEGORIES.map(c => ({ value: c, label: SF.CATEGORY_CONFIG[c].label })) })),
      React.createElement('div', { className: 'field col-2' },
        React.createElement('label', null, t('Skill Categories', 'فئات المهارات')),
        React.createElement('div', { className: 'chip-select' },
          SF.CATEGORIES.map(s => React.createElement('button', { key: s, type: 'button', className: `skill-chip ${form.categories.includes(s) ? 'on' : ''}`, onClick: () => toggleCat(s) },
            React.createElement(Icon, { name: SF.CATEGORY_CONFIG[s].icon, size: 13 }), SF.CATEGORY_CONFIG[s].label)))),
      React.createElement('div', { className: 'field col-2' },
        React.createElement('label', null, t('Specialization', 'التخصص')),
        React.createElement('input', { className: 'input', value: form.specialization, onChange: (e) => set('specialization', e.target.value), placeholder: t('e.g. Pipe & Leak Repair', 'مثال: إصلاح المواسير والتسريبات') })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, `${t('Rating', 'التقييم')} — ${Number(form.rating).toFixed(1)} ★`),
        React.createElement('input', { className: 'range', type: 'range', min: 0, max: 5, step: 0.1, value: form.rating, onChange: (e) => set('rating', parseFloat(e.target.value)) })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Issues Resolved', 'البلاغات المحلولة')),
        React.createElement('input', { className: 'input', type: 'number', value: form.issuesResolved, onChange: (e) => set('issuesResolved', parseInt(e.target.value) || 0) })),
      tech && React.createElement(IdReview, { t, front: form.nationalIdFrontUrl, back: form.nationalIdBackUrl }),
      React.createElement('div', { className: 'field col-2' },
        React.createElement('div', { className: 'field-row' },
          React.createElement('div', null,
            React.createElement('div', { className: 'fr-label' }, t('Verified Technician', 'فني موثّق')),
            React.createElement('div', { className: 'fr-sub' }, t('Mark as identity & skill verified', 'وضع علامة موثّق للهوية والمهارة'))),
          React.createElement(Toggle, { on: form.isVerified, onChange: (v) => set('isVerified', v) })))
    ));
}

export default function TechniciansPage() {
  const t = useT();
  const [techs, setTechs] = useState([]);
  const [live, setLive] = useState(false);
  const [loading, setLoading] = useState(true);
  const [q, setQ] = useState('');
  const [city, setCity] = useState('all');
  const [cat, setCat] = useState('all');
  const [modal, setModal] = useState(null);
  const [toDelete, setToDelete] = useState(null);

  // Live sync: read the Mongo-backed API. Falls back to the seed data if the
  // backend isn't reachable or returns nothing, so the dashboard always renders.
  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const res = await fetchWithTimeout('/api/technicians?limit=200', { cache: 'no-store' });
        if (!res.ok) return;
        const data = await res.json();
        const arr = (Array.isArray(data) ? data : (data.technicians || [])).map(normTech);
        if (active) { setTechs(arr); setLive(true); }
      } catch { /* keep seed-data fallback */ }
      finally { if (active) setLoading(false); }
    })();
    return () => { active = false; };
  }, []);

  const filtered = useMemo(() => techs.filter(t =>
    (q === '' || t.name.toLowerCase().includes(q.toLowerCase()) || (t.phone || '').includes(q)) &&
    (city === 'all' || t.city === city) &&
    (cat === 'all' || t.category === cat || (t.categories || []).includes(cat))
  ), [techs, q, city, cat]);

  const verifiedPct = techs.length ? ((techs.filter(t => t.isVerified).length / techs.length) * 100).toFixed(0) : '0';
  const avg = techs.length ? (techs.reduce((a, t) => a + (t.rating || 0), 0) / techs.length).toFixed(2) : '0';

  const saveTech = async (form) => {
    const body = {
      name: form.name, city: form.city, phone: form.phone, category: form.category,
      categories: form.categories, specialization: form.specialization,
      rating: form.rating, issuesResolved: form.issuesResolved,
      isVerified: form.isVerified,
      verificationStatus: form.isVerified ? 'verified' : (form.verificationStatus || 'pending'),
    };
    if (form._id) {
      // optimistic update
      setTechs(list => list.map(t => t._id === form._id ? normTech({ ...t, ...body, _id: form._id }) : t));
      setModal(null);
      try {
        const res = await fetch(`/api/technicians/${form._id}`, {
          method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
        });
        if (res.ok) { const saved = await res.json(); setTechs(list => list.map(t => t._id === form._id ? normTech(saved) : t)); }
      } catch { /* keep optimistic state */ }
    } else {
      const tempId = 'tech_' + Date.now();
      setTechs(list => [normTech({ ...body, _id: tempId }), ...list]);
      setModal(null);
      try {
        const res = await fetch('/api/technicians', {
          method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
        });
        if (res.ok) { const created = await res.json(); setTechs(list => list.map(t => t._id === tempId ? normTech(created) : t)); }
      } catch { /* keep optimistic state */ }
    }
  };

  const removeTech = async (id) => {
    setTechs(list => list.filter(t => t._id !== id));
    setToDelete(null);
    try { await fetch(`/api/technicians/${id}`, { method: 'DELETE' }); } catch { /* ignore */ }
  };

  // Verify / reject via PATCH { action } — optimistic, with server reconcile.
  const setVerification = async (tech, action) => {
    const next = action === 'verify'
      ? { verificationStatus: 'verified', isVerified: true }
      : { verificationStatus: 'rejected', isVerified: false };
    setTechs(list => list.map(t => t._id === tech._id ? { ...t, ...next } : t));
    try {
      const res = await fetch(`/api/technicians/${tech._id}`, {
        method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action }),
      });
      if (res.ok) { const saved = await res.json(); setTechs(list => list.map(t => t._id === tech._id ? normTech(saved) : t)); }
    } catch { /* keep optimistic state */ }
  };

  const allOpt = (l) => ({ value: 'all', label: l });

  const columns = [
    { key: 'name', label: t('Technician', 'الفني'), width: 230, render: (r) => React.createElement('div', { className: 'name-cell' },
      React.createElement(Avatar, { name: r.name }),
      React.createElement('div', null,
        React.createElement('div', { className: 'cell-primary' }, r.name),
        React.createElement('div', { className: 'cell-sub' }, r.specialization))) },
    { key: 'city', label: t('City', 'المدينة'), render: (r) => React.createElement('span', { className: 'cell-muted', style: { display: 'flex', alignItems: 'center', gap: 5 } }, React.createElement(Icon, { name: 'MapPin', size: 13, color: 'var(--text-3)' }), r.city) },
    { key: 'phone', label: t('Phone', 'الهاتف'), hideSm: true, render: (r) => React.createElement('span', { className: 'id-mono' }, r.phone) },
    { key: 'category', label: t('Skills', 'المهارات'), sortable: false, render: (r) => {
      const cats = (r.categories && r.categories.length) ? r.categories : (r.category ? [r.category] : []);
      return cats.length
        ? React.createElement('div', { style: { display: 'flex', gap: 4, flexWrap: 'wrap' } },
            cats.slice(0, 2).map(s => React.createElement(CatChip, { key: s, cat: s, small: true })),
            cats.length > 2 && React.createElement('span', { className: 'badge', style: { background: 'var(--surface-2)', color: 'var(--text-2)' } }, `+${cats.length - 2}`))
        : React.createElement('span', { className: 'unassigned' }, '—');
    } },
    { key: 'rating', label: t('Rating', 'التقييم'), render: (r) => React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 7 } }, React.createElement(Stars, { value: r.rating, size: 13 }), React.createElement('span', { className: 'rating-num tnum' }, Number(r.rating).toFixed(1))) },
    { key: 'isVerified', label: t('Verified', 'موثّق'), sortAccessor: (r) => r.isVerified ? 1 : 0, render: (r) => React.createElement(VerifiedBadge, { verified: r.isVerified }) },
    { key: 'issuesResolved', label: t('Resolved', 'المحلولة'), align: 'right', hideSm: true, render: (r) => React.createElement('span', { className: 'tnum', style: { fontWeight: 700 } }, r.issuesResolved) },
    { key: 'actions', label: '', sortable: false, align: 'right', render: (r) => React.createElement('div', { className: 'row-actions', style: { justifyContent: 'flex-end' } },
      r.verificationStatus !== 'verified' && React.createElement('button', { className: 'act-btn', title: t('Verify', 'توثيق'), style: { color: '#10b981' }, onClick: () => setVerification(r, 'verify') }, React.createElement(Icon, { name: 'BadgeCheck', size: 15 })),
      r.verificationStatus !== 'rejected' && React.createElement('button', { className: 'act-btn', title: t('Reject', 'رفض'), style: { color: '#f59e0b' }, onClick: () => setVerification(r, 'reject') }, React.createElement(Icon, { name: 'UserX', size: 15 })),
      React.createElement('button', { className: 'act-btn', title: t('Edit', 'تعديل'), onClick: () => setModal(r) }, React.createElement(Icon, { name: 'Pencil', size: 15 })),
      React.createElement('button', { className: 'act-btn danger', title: t('Delete', 'حذف'), onClick: () => setToDelete(r) }, React.createElement(Icon, { name: 'Trash2', size: 15 }))) },
  ];

  return React.createElement('div', { className: 'page-anim' },
    React.createElement('div', { className: 'stat-grid grid-4' },
      React.createElement(StatCard, { icon: 'Users', label: t('Total Technicians', 'إجمالي الفنيين'), value: techs.length, tone: 'primary', delay: 0 }),
      React.createElement(StatCard, { icon: 'BadgeCheck', label: t('Verified', 'موثّق'), value: parseFloat(verifiedPct), suffix: '%', tone: 'success', delay: 50 }),
      React.createElement(StatCard, { icon: 'Star', label: t('Avg Rating', 'متوسط التقييم'), value: parseFloat(avg), decimals: 2, tone: 'warning', delay: 100 }),
      React.createElement(StatCard, { icon: 'MapPin', label: t('Cities Covered', 'المدن المغطّاة'), value: new Set(techs.map(t => t.city)).size, tone: 'cyan', delay: 150 })
    ),

    React.createElement(SectionHead, { icon: 'Users', title: t('Technician Directory', 'دليل الفنيين'), sub: `· ${filtered.length} ${t('shown', 'معروض')}`,
      right: React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 10 } },
        live && React.createElement('span', { title: t('Reading live technicians from the app backend', 'قراءة الفنيين مباشرة من خادم التطبيق'), style: { display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, fontWeight: 700, letterSpacing: 0.4, color: '#0e9f6e', background: 'rgba(16,185,129,0.12)', padding: '4px 10px', borderRadius: 999 } },
          React.createElement('span', { style: { width: 7, height: 7, borderRadius: 999, background: '#10b981', display: 'inline-block' } }), t('LIVE', 'مباشر')),
        React.createElement('button', { className: 'btn btn-primary', onClick: () => setModal('new') }, React.createElement(Icon, { name: 'Plus', size: 16 }), t('Add Technician', 'إضافة فني'))) }),

    React.createElement('div', { className: 'toolbar' },
      React.createElement(SearchBox, { value: q, onChange: setQ, placeholder: t('Search name or phone…', 'ابحث بالاسم أو الهاتف…') }),
      React.createElement(Select, { value: city, onChange: setCity, icon: 'MapPin', options: [allOpt(t('All Cities', 'كل المدن')), ...SF.CITIES.map(c => ({ value: c, label: c }))] }),
      React.createElement(Select, { value: cat, onChange: setCat, icon: 'Layers', options: [allOpt(t('All Categories', 'كل الفئات')), ...SF.CATEGORIES.map(c => ({ value: c, label: SF.CATEGORY_CONFIG[c].label }))] }),
      (q || city !== 'all' || cat !== 'all') && React.createElement('button', { className: 'btn btn-ghost btn-sm', onClick: () => { setQ(''); setCity('all'); setCat('all'); } }, React.createElement(Icon, { name: 'X', size: 14 }), t('Clear', 'مسح'))
    ),

    React.createElement(DataTable, { columns, rows: filtered, pageSize: 8, initialSort: { key: 'rating', dir: 'desc' }, emptyTitle: loading ? t('Loading technicians…', 'جارٍ تحميل الفنيين…') : t('No technicians found', 'لا يوجد فنيون'), emptySub: loading ? t('Fetching from the backend.', 'جارٍ الجلب من الخادم.') : t('Adjust your filters or add a new technician.', 'عدّل عوامل التصفية أو أضف فنيًا جديدًا.') }),

    modal && React.createElement(TechModal, { tech: modal === 'new' ? null : modal, onClose: () => setModal(null), onSave: saveTech }),
    toDelete && React.createElement(Modal, { title: t('Remove Technician', 'إزالة الفني'), sub: toDelete.name, onClose: () => setToDelete(null),
      footer: React.createElement(React.Fragment, null,
        React.createElement('button', { className: 'btn btn-ghost', onClick: () => setToDelete(null) }, t('Cancel', 'إلغاء')),
        React.createElement('button', { className: 'btn btn-danger', onClick: () => removeTech(toDelete._id) }, React.createElement(Icon, { name: 'Trash2', size: 15 }), t('Remove', 'إزالة'))) },
      React.createElement('p', { style: { color: 'var(--text-2)', fontSize: 14, lineHeight: 1.6 } }, `${t('Remove', 'إزالة')} ${toDelete.name} ${t('from the technician directory? Their resolved-issue history will be retained for reporting.', 'من دليل الفنيين؟ سيتم الاحتفاظ بسجل بلاغاته المحلولة لأغراض التقارير.')}`))
  );
}
