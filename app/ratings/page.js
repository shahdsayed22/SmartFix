'use client';
/* ============================================================
   SmartFix — Ratings Management page
   ============================================================ */
import React, { useState, useMemo, useEffect, useRef } from 'react';
import { fetchWithTimeout } from '@/lib/fetchWithTimeout';
import { SF } from '@/components/sf/data';
import { useT } from '@/components/sf/i18n';
import { Icon } from '@/components/sf/Icon';
import { StatCard, ChartCard, SectionHead, DataTable, SearchBox, CatChip, Stars, Avatar } from '@/components/sf/ui';
import { RatingBars } from '@/components/sf/charts';

const fmtDate = (s) => { try { return new Date(s).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }); } catch { return '—'; } };

export default function RatingsPage() {
  const t = useT();
  const [techs, setTechs] = useState([]);
  const [reviews, setReviews] = useState([]);
  const [live, setLive] = useState(false);
  const [q, setQ] = useState('');
  // Guard the background poll so it never clobbers a rating the admin is
  // actively dragging or that is mid-save. `dirty` holds technician ids with
  // unsaved/in-flight local edits; their rows are preserved across refetches.
  const dirtyRef = useRef(new Set());
  const loadRef = useRef(() => {});
  const [saveError, setSaveError] = useState('');

  // ── Live sync ──────────────────────────────────────────────────────
  // Read real reviews + technicians from the Mongo-backed API. Per-technician
  // averages and the reviews list are computed from the reviews collection;
  // technician names/cities/categories come from /api/technicians. Falls back
  // to the SF static technician data so the page always renders for the demo.
  useEffect(() => {
    let active = true;
    const load = async () => {
      try {
        const [tRes, rRes] = await Promise.all([
          fetchWithTimeout('/api/technicians', { cache: 'no-store' }),
          fetchWithTimeout('/api/reviews?limit=500', { cache: 'no-store' }),
        ]);
        const tData = tRes.ok ? await tRes.json() : null;
        const rData = rRes.ok ? await rRes.json() : null;
        const techArr = tData ? (Array.isArray(tData) ? tData : (tData.technicians || [])) : [];
        const revArr = rData ? (Array.isArray(rData) ? rData : (rData.reviews || [])) : [];

        if (!active) return;

        // Keep any rating the admin is currently editing (dragging or saving)
        // so a background refetch can't overwrite their in-flight change.
        const dirty = dirtyRef.current;
        const keepDirty = (next) => setTechs(prev => {
          if (!dirty.size) return next;
          const prevById = {};
          prev.forEach(t => { prevById[t._id] = t; });
          return next.map(t => (dirty.has(t._id) && prevById[t._id])
            ? { ...t, rating: prevById[t._id].rating }
            : t);
        });

        if (revArr.length) {
          // Average each technician's score from their real reviews.
          const byTech = {};
          revArr.forEach(r => {
            const id = r.technicianId || '';
            if (!id) return;
            (byTech[id] = byTech[id] || []).push(r);
          });
          const base = techArr;
          const merged = base.map(t => {
            const list = byTech[t._id] || [];
            return list.length
              ? { ...t, rating: Number((list.reduce((a, x) => a + (x.rating || 0), 0) / list.length).toFixed(2)), issuesResolved: list.length }
              : { ...t };
          });
          keepDirty(merged);
          setReviews(revArr);
          setLive(true);
        } else if (techArr.length) {
          // No reviews yet, but real technicians exist — use their stored ratings.
          keepDirty(techArr.map(t => ({ ...t, rating: t.rating || 0, issuesResolved: t.issuesResolved || 0 })));
          setReviews([]);
          setLive(true);
        }
      } catch { /* keep SF static fallback */ }
    };
    loadRef.current = load;
    load();
    const t = setInterval(load, 6000);
    return () => { active = false; clearInterval(t); };
  }, []);

  const avg = techs.length ? (techs.reduce((a, t) => a + (t.rating || 0), 0) / techs.length) : 0;

  // Honest platform-average trend: compare the average score of the newer
  // half of real reviews against the older half. Only shown when there are
  // enough reviews to make a meaningful comparison; otherwise hidden.
  const avgTrend = useMemo(() => {
    if (reviews.length < 4) return null;
    const sorted = [...reviews].sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
    const mid = Math.floor(sorted.length / 2);
    const older = sorted.slice(0, mid);
    const newer = sorted.slice(mid);
    const mean = (l) => l.reduce((a, x) => a + (x.rating || 0), 0) / l.length;
    if (!older.length || !newer.length) return null;
    const delta = mean(newer) - mean(older);
    if (Math.abs(delta) < 0.05) return null;
    return delta;
  }, [reviews]);

  const catAverages = useMemo(() => SF.CATEGORIES.map(c => {
    const list = techs.filter(t => t.category === c);
    return { cat: c, avg: list.length ? list.reduce((a, t) => a + (t.rating || 0), 0) / list.length : 0, count: list.length };
  }).filter(c => c.count > 0).sort((a, b) => b.avg - a.avg), [techs]);

  const ratingDist = useMemo(() => {
    const buckets = [
      { range: '4.5 – 5.0', min: 4.5, max: 5.01 },
      { range: '4.0 – 4.5', min: 4.0, max: 4.5 },
      { range: '3.5 – 4.0', min: 3.5, max: 4.0 },
      { range: '3.0 – 3.5', min: 3.0, max: 3.5 },
      { range: '< 3.0', min: 0, max: 3.0 },
    ];
    return buckets.map(b => ({ range: b.range, count: techs.filter(t => (t.rating || 0) >= b.min && (t.rating || 0) < b.max).length }));
  }, [techs]);

  const recentReviews = useMemo(() => [...reviews].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt)).slice(0, 8), [reviews]);

  const topRated = useMemo(() => [...techs].sort((a, b) => (b.rating || 0) - (a.rating || 0)).slice(0, 6), [techs]);
  const filtered = useMemo(() => techs.filter(t => q === '' || t.name.toLowerCase().includes(q.toLowerCase())), [techs, q]);
  // Local (optimistic) slider movement — marks the row dirty so the poll
  // won't overwrite it, but does not hit the network on every tick.
  const setRating = (id, v) => {
    dirtyRef.current.add(id);
    setTechs(list => list.map(t => t._id === id ? { ...t, rating: v } : t));
  };

  // Commit on slider release: persist via PATCH, then refetch. On failure,
  // surface a message and revert the optimistic value from the server copy.
  const commitRating = async (id, v) => {
    const prev = techs.find(t => t._id === id);
    const rating = Math.round(parseFloat(v) * 100) / 100;
    try {
      const res = await fetch(`/api/technicians/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'set-rating', rating }),
      });
      if (!res.ok) {
        let msg = `Failed to save rating (${res.status})`;
        try { const j = await res.json(); if (j?.error) msg = j.error; } catch { /* ignore */ }
        // Revert optimistic state to the previous server-backed value.
        const fallback = prev ? (prev.rating || 0) : 0;
        setTechs(list => list.map(t => t._id === id ? { ...t, rating: fallback } : t));
        setSaveError(msg);
        return;
      }
      setSaveError('');
      // Re-pull authoritative data; only drop the dirty flag after the
      // refetch finished so the poll can't briefly resurrect an old value.
      await loadRef.current();
    } catch (err) {
      const fallback = prev ? (prev.rating || 0) : 0;
      setTechs(list => list.map(t => t._id === id ? { ...t, rating: fallback } : t));
      setSaveError(err?.message || 'Network error while saving rating');
    } finally {
      dirtyRef.current.delete(id);
    }
  };

  const columns = [
    { key: 'name', label: t('Technician', 'الفني'), width: 230, render: (r) => React.createElement('div', { className: 'name-cell' },
      React.createElement(Avatar, { name: r.name }),
      React.createElement('div', null,
        React.createElement('div', { className: 'cell-primary' }, r.name),
        React.createElement('div', { className: 'cell-sub' }, r.city))) },
    { key: 'category', label: t('Category', 'الفئة'), render: (r) => React.createElement(CatChip, { cat: r.category, small: true }) },
    { key: 'rating', label: t('Current', 'الحالي'), render: (r) => React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 7 } }, React.createElement(Stars, { value: r.rating || 0, size: 13 }), React.createElement('span', { className: 'rating-num tnum', style: { color: 'var(--warning)' } }, (r.rating || 0).toFixed(1))) },
    { key: 'adjust', label: t('Adjust Rating', 'تعديل التقييم'), sortable: false, width: 230, render: (r) => React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 12 } },
      React.createElement('input', { className: 'range', type: 'range', min: 0, max: 5, step: 0.1, value: r.rating || 0, onChange: (e) => setRating(r._id, parseFloat(e.target.value)), onMouseUp: (e) => commitRating(r._id, e.target.value), onTouchEnd: (e) => commitRating(r._id, e.target.value), onKeyUp: (e) => commitRating(r._id, e.target.value), style: { width: 150 } }),
      React.createElement('span', { className: 'tnum', style: { fontWeight: 700, width: 30 } }, (r.rating || 0).toFixed(1))) },
    { key: 'issuesResolved', label: t('Jobs', 'المهام'), align: 'right', hideSm: true, render: (r) => React.createElement('span', { className: 'tnum', style: { fontWeight: 700 } }, r.issuesResolved || 0) },
  ];

  return React.createElement('div', { className: 'page-anim' },
    React.createElement('div', { className: 'charts-grid grid-1-2' },
      // Average rating hero card
      React.createElement('div', { className: 'card rise', style: { padding: 24, display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center', textAlign: 'center', gap: 10 } },
        React.createElement('div', { className: 'stat-label' }, t('Platform Average Rating', 'متوسط تقييم المنصة')),
        React.createElement('div', { style: { fontSize: 56, fontWeight: 800, letterSpacing: '-0.04em', lineHeight: 1, color: 'var(--warning)' } }, avg.toFixed(2)),
        React.createElement(Stars, { value: avg, size: 22 }),
        React.createElement('div', { className: 'stat-foot', style: { justifyContent: 'center' } },
          avgTrend !== null && React.createElement('span', { className: `trend ${avgTrend >= 0 ? 'up' : 'down'}` },
            React.createElement(Icon, { name: avgTrend >= 0 ? 'TrendingUp' : 'TrendingDown', size: 12 }),
            `${avgTrend >= 0 ? '+' : ''}${avgTrend.toFixed(1)}`),
          React.createElement('span', null, t(`across ${techs.length} technicians`, `عبر ${techs.length} فنيًا`))),
        live && React.createElement('span', { title: t('Computed from live reviews in the app backend', 'محسوب من التقييمات المباشرة في الواجهة الخلفية للتطبيق'), style: { display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, fontWeight: 700, letterSpacing: 0.4, color: '#0e9f6e', background: 'rgba(16,185,129,0.12)', padding: '4px 10px', borderRadius: 999 } },
          React.createElement('span', { style: { width: 7, height: 7, borderRadius: 999, background: '#10b981', display: 'inline-block' } }), t('LIVE', 'مباشر'))),
      // Distribution
      React.createElement(ChartCard, { title: t('Rating Distribution', 'توزيع التقييمات'), sub: t('Technicians grouped by score band', 'الفنيون مجمّعون حسب نطاق الدرجة') },
        React.createElement(RatingBars, { data: ratingDist }))
    ),

    React.createElement(SectionHead, { icon: 'ChartColumn', title: t('Average Rating by Category', 'متوسط التقييم حسب الفئة') }),
    React.createElement('div', { className: 'stat-grid', style: { gridTemplateColumns: 'repeat(auto-fill, minmax(190px, 1fr))' } },
      catAverages.map((c, i) => React.createElement('div', { key: c.cat, className: 'card rise', style: { padding: 16, animationDelay: i * 40 + 'ms' } },
        React.createElement('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 } },
          React.createElement(CatChip, { cat: c.cat, small: true }),
          React.createElement('span', { className: 'cell-sub' }, t(`${c.count} techs`, `${c.count} فني`))),
        React.createElement('div', { style: { display: 'flex', alignItems: 'baseline', gap: 8 } },
          React.createElement('span', { style: { fontSize: 26, fontWeight: 800, letterSpacing: '-0.03em', color: 'var(--warning)' } }, c.avg.toFixed(2)),
          React.createElement(Stars, { value: c.avg, size: 13 })),
        React.createElement('div', { className: 'progress warning', style: { marginTop: 10 } }, React.createElement('span', { style: { width: `${(c.avg / 5) * 100}%` } }))))
    ),

    React.createElement('div', { className: 'charts-grid grid-2-1', style: { marginTop: 22 } },
      React.createElement('div', { className: 'card table-card rise', style: { overflow: 'hidden' } },
        React.createElement('div', { className: 'chart-head', style: { padding: '18px 20px 0' } },
          React.createElement('div', null, React.createElement('h3', null, t('Technician Ratings', 'تقييمات الفنيين')), React.createElement('div', { className: 'chart-sub' }, t('Drag a slider to adjust a rating', 'اسحب الشريط لتعديل التقييم')))),
        saveError && React.createElement('div', { role: 'alert', style: { margin: '10px 20px 0', padding: '8px 12px', borderRadius: 8, fontSize: 13, fontWeight: 600, color: 'var(--danger, #dc2626)', background: 'rgba(220,38,38,0.1)', border: '1px solid rgba(220,38,38,0.25)' } }, t(`Could not save rating: ${saveError}`, `تعذّر حفظ التقييم: ${saveError}`)),
        React.createElement('div', { style: { padding: '12px 8px 0' } },
          React.createElement(SearchBox, { value: q, onChange: setQ, placeholder: t('Search technician…', 'ابحث عن فني…') })),
        React.createElement('div', { style: { padding: 8 } },
          React.createElement(DataTable, { columns, rows: filtered, pageSize: 6, initialSort: { key: 'rating', dir: 'desc' }, emptyTitle: t('No technicians', 'لا يوجد فنيون'), emptySub: t('Adjust your search.', 'عدّل بحثك.') }))),
      React.createElement(ChartCard, { title: t('Top Rated', 'الأعلى تقييمًا'), sub: t('Highest scoring technicians', 'الفنيون الأعلى درجة') },
        React.createElement('div', { className: 'rank-list' },
          topRated.map((t, i) => React.createElement('div', { className: 'rank-item', key: t._id },
            React.createElement('div', { className: `rank-badge ${i === 0 ? 'gold' : i === 1 ? 'silver' : i === 2 ? 'bronze' : 'plain'}` }, i + 1),
            React.createElement('div', { className: 'rank-info' },
              React.createElement('div', { className: 'rank-name' }, t.name),
              React.createElement('div', { className: 'rank-meta' }, React.createElement(Icon, { name: SF.CATEGORY_CONFIG[t.category]?.icon || 'Wrench', size: 11, color: SF.CATEGORY_CONFIG[t.category]?.color || 'var(--text-3)' }), t.city)),
            React.createElement('div', { className: 'rank-score' }, React.createElement(Icon, { name: 'Star', size: 14, color: '#f59e0b', style: { fill: '#f59e0b' } }), (t.rating || 0).toFixed(1))))))
    ),

    // ── Recent customer reviews (live) ───────────────────────────────
    recentReviews.length > 0 && React.createElement('div', { style: { marginTop: 22 } },
      React.createElement(SectionHead, { icon: 'MessageSquare', title: t('Recent Reviews', 'أحدث التقييمات'), sub: t(`· ${reviews.length} total`, `· ${reviews.length} إجمالًا`) }),
      React.createElement('div', { className: 'stat-grid', style: { gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))' } },
        recentReviews.map((r, i) => React.createElement('div', { key: r._id || i, className: 'card rise', style: { padding: 16, animationDelay: i * 40 + 'ms', display: 'flex', flexDirection: 'column', gap: 10 } },
          React.createElement('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 } },
            React.createElement('div', { className: 'name-cell' },
              React.createElement(Avatar, { name: r.customerName || t('Customer', 'العميل') }),
              React.createElement('div', null,
                React.createElement('div', { className: 'cell-primary' }, r.customerName || t('Customer', 'العميل')),
                React.createElement('div', { className: 'cell-sub' }, r.technicianName ? t(`for ${r.technicianName}`, `لـ ${r.technicianName}`) : '—'))),
            React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 5 } }, React.createElement(Stars, { value: r.rating || 0, size: 13 }))),
          r.comment && React.createElement('div', { style: { color: 'var(--text-2)', fontSize: 13.5, lineHeight: 1.55 } }, r.comment),
          React.createElement('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginTop: 'auto' } },
            r.category ? React.createElement(CatChip, { cat: r.category, small: true }) : React.createElement('span', null),
            React.createElement('span', { className: 'cell-sub', style: { fontSize: 12 } }, fmtDate(r.createdAt))))))
    )
  );
}
