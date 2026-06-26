'use client';

/* ============================================================
   SmartFix — Verified Profiles page (verification queue)
   ============================================================ */
import React, { useState, useEffect, useMemo } from 'react';
import { fetchWithTimeout } from '@/lib/fetchWithTimeout';
import { Icon } from '@/components/sf/Icon';
import { StatCard, SectionHead, DataTable, SearchBox, CatChip, Avatar } from '@/components/sf/ui';
import { useT } from '@/components/sf/i18n';

// Normalize a technician record into a consistent shape with an explicit
// verificationStatus. The DB carries the field directly; the static seed only
// has isVerified, so we derive (verified ⇒ 'verified', otherwise 'pending').
const normTech = (t) => {
  const status = t.verificationStatus
    || (t.isVerified ? 'verified' : 'pending');
  return {
    ...t,
    verificationStatus: status,
    isVerified: status === 'verified',
    rating: typeof t.rating === 'number' ? t.rating : 0,
    issuesResolved: t.issuesResolved || 0,
    specialization: t.specialization || '',
    city: t.city || '—',
  };
};

const STATUS_META = {
  verified: { color: 'var(--success)', icon: 'ShieldCheck', label: 'Verified', labelAr: 'موثّق' },
  pending: { color: 'var(--warning)', icon: 'ShieldAlert', label: 'Pending', labelAr: 'قيد الانتظار' },
  rejected: { color: 'var(--danger)', icon: 'ShieldX', label: 'Rejected', labelAr: 'مرفوض' },
};

export default function VerifiedPage() {
  const t = useT();
  const [techs, setTechs] = useState([]);
  const [live, setLive] = useState(false);
  const [q, setQ] = useState('');
  const [filter, setFilter] = useState('all'); // all | pending | verified | rejected

  // Live sync: read technicians from the same Mongo-backed API the mobile app
  // writes to on worker sign-up, so real applicants surface in the queue. Falls
  // back to the seed data if the backend isn't reachable (page never empties).
  useEffect(() => {
    let active = true;
    const load = async () => {
      try {
        const res = await fetchWithTimeout('/api/technicians?limit=200', { cache: 'no-store' });
        if (!res.ok) return;
        const data = await res.json();
        const arr = (Array.isArray(data) ? data : (data.technicians || [])).map(normTech);
        if (active) { setTechs(arr); setLive(true); }
      } catch { /* keep the seed-data fallback */ }
    };
    load();
    const t = setInterval(load, 6000);
    return () => { active = false; clearInterval(t); };
  }, []);

  const stats = useMemo(() => {
    const verified = techs.filter(t => t.verificationStatus === 'verified').length;
    const pending = techs.filter(t => t.verificationStatus === 'pending').length;
    const total = techs.length || 1;
    return { verified, pending, pct: ((verified / total) * 100).toFixed(0) };
  }, [techs]);

  const filtered = useMemo(() => techs.filter(t =>
    (q === '' || (t.name || '').toLowerCase().includes(q.toLowerCase())) &&
    (filter === 'all' || t.verificationStatus === filter)
  ), [techs, q, filter]);

  // A row is persistable only when it came from the live backend and carries a
  // real Mongo ObjectId. Seed/demo rows must never trigger a PATCH (the route
  // would 404/400 and the optimistic UI would falsely "confirm").
  const isObjectId = (id) => typeof id === 'string' && /^[a-f0-9]{24}$/i.test(id);
  const canPersist = (id) => live && isObjectId(id);

  // Optimistic review action; PATCH /api/technicians/[id] with { action }.
  // The 6s poll reconciles with Mongo afterwards. On non-live/seed rows the
  // mutation is skipped entirely (no false confirmation). On a failed request
  // the optimistic change is reverted and a message surfaces.
  const review = async (id, action) => {
    const next = action === 'verify' ? 'verified' : 'rejected';

    // Snapshot the previous status so we can revert on failure.
    const prev = techs.find(t => t._id === id);
    const prevStatus = prev ? prev.verificationStatus : 'pending';

    if (!canPersist(id)) {
      // Demo/seed data: do not pretend to persist.
      if (typeof window !== 'undefined') {
        window.alert(t(
          'Demo data — this profile is not persisted. Connect the backend to verify.',
          'بيانات تجريبية — لا يتم حفظ هذا الملف. اربط الخادم للتوثيق.'
        ));
      }
      return;
    }

    const apply = (status) => setTechs(list => list.map(t => t._id === id
      ? { ...t, verificationStatus: status, isVerified: status === 'verified' }
      : t));

    apply(next); // optimistic
    try {
      const res = await fetch(`/api/technicians/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
    } catch {
      apply(prevStatus); // revert the optimistic change
      if (typeof window !== 'undefined') {
        window.alert(t(
          'Could not update verification status. Please try again.',
          'تعذّر تحديث حالة التوثيق. يرجى المحاولة مرة أخرى.'
        ));
      }
    }
  };

  const StatusPill = (status) => {
    const m = STATUS_META[status] || STATUS_META.pending;
    return React.createElement('span', { className: 'badge badge-soft', style: { background: `color-mix(in srgb, ${m.color} 14%, transparent)`, color: m.color, border: `1px solid color-mix(in srgb, ${m.color} 38%, transparent)` } },
      React.createElement(Icon, { name: m.icon, size: 13 }), t(m.label, m.labelAr));
  };

  const columns = [
    { key: 'name', label: t('Technician', 'الفني'), width: 240, render: (r) => React.createElement('div', { className: 'name-cell' },
      React.createElement('div', { style: { position: 'relative' } },
        React.createElement(Avatar, { name: r.name }),
        r.verificationStatus === 'verified' && React.createElement('span', { style: { position: 'absolute', right: -3, bottom: -3, background: 'var(--bg-elevated)', borderRadius: '50%', display: 'grid', placeItems: 'center', width: 16, height: 16 } },
          React.createElement(Icon, { name: 'BadgeCheck', size: 15, color: 'var(--success)' }))),
      React.createElement('div', null,
        React.createElement('div', { className: 'cell-primary' }, r.name),
        React.createElement('div', { className: 'cell-sub' }, r.specialization))) },
    { key: 'category', label: t('Category', 'الفئة'), render: (r) => React.createElement(CatChip, { cat: r.category, small: true }) },
    { key: 'city', label: t('City', 'المدينة'), hideSm: true, render: (r) => React.createElement('span', { className: 'cell-muted' }, r.city) },
    { key: 'rating', label: t('Rating', 'التقييم'), render: (r) => React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 6 } }, React.createElement(Icon, { name: 'Star', size: 14, color: '#f59e0b', style: { fill: '#f59e0b' } }), React.createElement('span', { className: 'rating-num tnum' }, r.rating.toFixed(1))) },
    { key: 'issuesResolved', label: t('Resolved', 'تم الحل'), align: 'right', hideSm: true, render: (r) => React.createElement('span', { className: 'tnum', style: { fontWeight: 700 } }, r.issuesResolved) },
    { key: 'verificationStatus', label: t('Status', 'الحالة'), sortAccessor: (r) => ({ verified: 2, pending: 1, rejected: 0 }[r.verificationStatus] ?? 1), render: (r) => StatusPill(r.verificationStatus) },
    { key: 'actions', label: '', sortable: false, align: 'right', render: (r) => {
      if (r.verificationStatus === 'pending') {
        return React.createElement('div', { className: 'row-actions', style: { justifyContent: 'flex-end' } },
          React.createElement('button', { className: 'btn btn-primary btn-sm', onClick: () => review(r._id, 'verify') }, React.createElement(Icon, { name: 'ShieldCheck', size: 14 }), t('Approve', 'اعتماد')),
          React.createElement('button', { className: 'btn btn-ghost btn-sm', onClick: () => review(r._id, 'reject') }, React.createElement(Icon, { name: 'ShieldX', size: 14 }), t('Reject', 'رفض')));
      }
      if (r.verificationStatus === 'verified') {
        return React.createElement('button', { className: 'btn btn-ghost btn-sm', onClick: () => review(r._id, 'reject') }, React.createElement(Icon, { name: 'ShieldOff', size: 14 }), t('Revoke', 'إلغاء التوثيق'));
      }
      // rejected → allow re-approval
      return React.createElement('button', { className: 'btn btn-primary btn-sm', onClick: () => review(r._id, 'verify') }, React.createElement(Icon, { name: 'ShieldCheck', size: 14 }), t('Approve', 'اعتماد'));
    } },
  ];

  const seg = (val, label, icon) => React.createElement('button', { className: `seg ${filter === val ? 'on' : ''}`, onClick: () => setFilter(val) }, React.createElement(Icon, { name: icon, size: 14 }), label);

  return React.createElement('div', { className: 'page-anim' },
    React.createElement('div', { className: 'stat-grid grid-3' },
      React.createElement(StatCard, { icon: 'ShieldCheck', label: t('Verified Profiles', 'الملفات الموثّقة'), value: stats.verified, tone: 'success', trend: stats.pct + '%', trendDir: 'up', foot: t('of all technicians', 'من إجمالي الفنيين'), delay: 0 }),
      React.createElement(StatCard, { icon: 'ShieldAlert', label: t('Awaiting Verification', 'في انتظار التوثيق'), value: stats.pending, tone: 'warning', foot: t('pending review', 'قيد المراجعة'), delay: 60 }),
      React.createElement(StatCard, { icon: 'Percent', label: t('Verification Rate', 'معدل التوثيق'), value: parseFloat(stats.pct), suffix: '%', tone: 'primary', foot: t('platform trust score', 'درجة ثقة المنصة'), delay: 120 })
    ),

    React.createElement(SectionHead, { icon: 'ShieldCheck', title: t('Verification Queue', 'قائمة التوثيق'), sub: `· ${filtered.length} ${t('profiles', 'ملف')}`,
      right: live
        ? React.createElement('span', { title: t('Reading live data from the app backend', 'قراءة بيانات مباشرة من خادم التطبيق'), style: { display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, fontWeight: 700, letterSpacing: 0.4, color: '#0e9f6e', background: 'rgba(16,185,129,0.12)', padding: '4px 10px', borderRadius: 999 } },
            React.createElement('span', { style: { width: 7, height: 7, borderRadius: 999, background: '#10b981', display: 'inline-block' } }), t('LIVE', 'مباشر'))
        : React.createElement('span', { title: t('Showing sample data — verification actions are disabled until the backend is connected', 'عرض بيانات تجريبية — إجراءات التوثيق معطّلة حتى يتم ربط الخادم'), style: { display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, fontWeight: 700, letterSpacing: 0.4, color: 'var(--warning)', background: 'color-mix(in srgb, var(--warning) 12%, transparent)', padding: '4px 10px', borderRadius: 999 } },
            React.createElement(Icon, { name: 'FlaskConical', size: 13 }), t('demo data — not persisted', 'بيانات تجريبية — غير محفوظة')) }),

    React.createElement('div', { className: 'toolbar' },
      React.createElement(SearchBox, { value: q, onChange: setQ, placeholder: t('Search technician…', 'ابحث عن فني…') }),
      React.createElement('div', { className: 'toolbar-spacer' }),
      React.createElement('div', { className: 'segmented' },
        seg('all', t('All', 'الكل'), 'List'),
        seg('pending', t('Pending', 'قيد الانتظار'), 'ShieldAlert'),
        seg('verified', t('Verified', 'موثّق'), 'ShieldCheck'),
        seg('rejected', t('Rejected', 'مرفوض'), 'ShieldX'))
    ),

    React.createElement(DataTable, { columns, rows: filtered, pageSize: 8, initialSort: { key: 'verificationStatus', dir: 'asc' }, emptyTitle: t('Nothing here', 'لا يوجد شيء هنا'), emptySub: filter === 'pending' ? t('No applicants awaiting review. 🎉', 'لا يوجد متقدمون في انتظار المراجعة. 🎉') : t('No profiles match.', 'لا توجد ملفات مطابقة.') })
  );
}
