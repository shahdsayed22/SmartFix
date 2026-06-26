'use client';

/* ============================================================
   SmartFix — Dashboard Overview page
   ============================================================ */
import React, { useState, useEffect } from 'react';
import { fetchWithTimeout } from '@/lib/fetchWithTimeout';
import { SF } from '@/components/sf/data';
import { Icon } from '@/components/sf/Icon';
import { StatCard, ChartCard, SectionHead } from '@/components/sf/ui';
import { Donut, HBars, VBars, AreaChart } from '@/components/sf/charts';
import { useT } from '@/components/sf/i18n';

// Zeroed analytics — the honest "empty database" state. Used as the initial
// value and the fallback so a fresh/empty DB shows real zeros instead of the
// static SF demo numbers.
const EMPTY_ANALYTICS = {
  totalTechnicians: 0,
  verifiedCount: 0,
  verifiedPercentage: 0,
  avgRating: 0,
  totalIssuesResolved: 0,
  techByCategory: {},
  cityDistribution: [],
  monthlyGrowth: [],
  topTechnicians: [],
  issueStats: {
    total: 0, pending: 0, assigned: 0, inProgress: 0, completed: 0,
    cancelled: 0, active: 0, byCategory: {}, byUrgency: {},
  },
  userStats: { total: 0, customers: 0, workers: 0, verified: 0 },
};

// Normalise the /api/analytics payload into the exact shape the page renders
// from. The API returns `categories` keyed by id with
// {count, avgRating}; the page reads `techByCategory[c].count`. We also
// derive issueStats.active (the API doesn't send it) and fill every key with
// a safe default so a partial/empty DB never crashes the dashboard.
function normalizeAnalytics(d) {
  if (!d || typeof d !== 'object' || d.error) return EMPTY_ANALYTICS;
  const fallback = EMPTY_ANALYTICS;
  const src = d.categories || {};
  const techByCategory = {};
  SF.CATEGORIES.forEach((c) => {
    techByCategory[c] = {
      count: src[c]?.count || 0,
      avgRating: parseFloat(src[c]?.avgRating) || 0,
    };
  });
  const is = d.issueStats || {};
  const pending = is.pending || 0, assigned = is.assigned || 0, inProgress = is.inProgress || 0;
  return {
    totalTechnicians: d.totalTechnicians ?? fallback.totalTechnicians,
    verifiedCount: d.verifiedCount ?? fallback.verifiedCount,
    verifiedPercentage: d.verifiedPercentage ?? fallback.verifiedPercentage,
    avgRating: d.avgRating ?? fallback.avgRating,
    totalIssuesResolved: d.totalIssuesResolved ?? fallback.totalIssuesResolved,
    techByCategory,
    cityDistribution: Array.isArray(d.cityDistribution) && d.cityDistribution.length ? d.cityDistribution : fallback.cityDistribution,
    monthlyGrowth: Array.isArray(d.monthlyGrowth) && d.monthlyGrowth.length ? d.monthlyGrowth : fallback.monthlyGrowth,
    topTechnicians: Array.isArray(d.topTechnicians) && d.topTechnicians.length ? d.topTechnicians : fallback.topTechnicians,
    issueStats: {
      total: is.total || 0,
      pending, assigned, inProgress,
      completed: is.completed || 0,
      cancelled: is.cancelled || 0,
      active: is.active != null ? is.active : (pending + assigned + inProgress),
      byCategory: is.byCategory || {},
      byUrgency: is.byUrgency || {},
    },
    userStats: {
      total: d.userStats?.total ?? fallback.userStats.total,
      customers: d.userStats?.customers ?? fallback.userStats.customers,
      workers: d.userStats?.workers ?? fallback.userStats.workers,
      verified: d.userStats?.verified ?? fallback.userStats.verified,
    },
  };
}

export default function DashboardPage() {
  const t = useT();
  // Start from the static SF.ANALYTICS so the page always renders, then
  // hydrate from the live /api/analytics endpoint (falls back on error/empty).
  const [a, setA] = useState(EMPTY_ANALYTICS);
  const [growthTab, setGrowthTab] = useState('technicians');

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const res = await fetchWithTimeout('/api/analytics', { cache: 'no-store' });
        if (!res.ok) return;
        const data = await res.json();
        if (!active || !data || data.error) return;
        setA(normalizeAnalytics(data));
      } catch { /* keep the SF.ANALYTICS fallback */ }
    })();
    return () => { active = false; };
  }, []);

  const catData = SF.CATEGORIES.map(c => ({
    name: SF.CATEGORY_CONFIG[c].label, value: a.techByCategory?.[c]?.count || 0, color: SF.CATEGORY_CONFIG[c].color,
  })).filter(d => d.value > 0).sort((x, y) => y.value - x.value);

  const statusData = ['pending', 'assigned', 'inProgress', 'completed', 'cancelled'].map(s => ({
    name: SF.STATUS_CONFIG[s]?.label || s, value: a.issueStats?.[s] || 0, color: SF.STATUS_CONFIG[s]?.color,
  })).filter(d => d.value > 0);

  const cityData = (a.cityDistribution || []).slice(0, 7).map(c => ({ name: c.city, value: c.count }));

  const issueCatData = SF.CATEGORIES.map(c => ({
    name: SF.CATEGORY_CONFIG[c].label, short: SF.CATEGORY_CONFIG[c].label.split(' ')[0], value: a.issueStats?.byCategory?.[c] || 0, color: SF.CATEGORY_CONFIG[c].color,
  })).filter(d => d.value > 0);

  // Derive sparkline series + a first-vs-last trend % from the monthly growth
  // data so the KPI cards reflect live data instead of hardcoded arrays.
  const mg = Array.isArray(a.monthlyGrowth) && a.monthlyGrowth.length ? a.monthlyGrowth : EMPTY_ANALYTICS.monthlyGrowth;
  const sparkOf = (key) => mg.map(m => Number(m[key]) || 0);
  const trendOf = (key, { decimals = 1, sign = true } = {}) => {
    const s = sparkOf(key);
    const first = s[0], last = s[s.length - 1];
    if (!first) return sign ? '+0%' : '0%';
    const pct = ((last - first) / first) * 100;
    const v = pct.toFixed(decimals);
    return `${sign && pct >= 0 ? '+' : ''}${v}%`;
  };
  const techSpark = sparkOf('technicians');
  const issuesSpark = sparkOf('issues');
  const usersSpark = sparkOf('users');
  const techTrend = trendOf('technicians');
  const issuesTrend = trendOf('issues');
  const usersTrend = trendOf('users');
  const urgentCount = (a.issueStats?.byUrgency?.high || 0) + (a.issueStats?.byUrgency?.emergency || 0);

  const growthSeries = growthTab === 'technicians'
    ? [{ key: 'technicians', name: t('Technicians', 'الفنيون'), color: '#6366f1' }, { key: 'users', name: t('Users', 'المستخدمون'), color: '#22d3ee' }]
    : [{ key: 'issues', name: t('Issues Resolved', 'البلاغات المُنجزة'), color: '#10b981' }];

  return React.createElement('div', { className: 'page-anim' },
    // KPI row 1
    React.createElement(SectionHead, { icon: 'LayoutDashboard', title: t('Platform Overview', 'نظرة عامة على المنصة'), sub: t('· live across Egypt region', '· مباشر عبر منطقة مصر') }),
    React.createElement('div', { className: 'stat-grid grid-4' },
      React.createElement(StatCard, { icon: 'Users', label: t('Total Technicians', 'إجمالي الفنيين'), value: a.totalTechnicians, tone: 'primary', trend: techTrend, trendDir: 'up', foot: t('vs last month', 'مقارنة بالشهر الماضي'), spark: techSpark, delay: 0 }),
      React.createElement(StatCard, { icon: 'BadgeCheck', label: t('Verified Rate', 'نسبة التوثيق'), value: parseFloat(a.verifiedPercentage), suffix: '%', decimals: 1, tone: 'success', trend: '+4.2%', trendDir: 'up', foot: `${a.verifiedCount} ${t('of', 'من')} ${a.totalTechnicians}`, spark: [58, 62, 65, 67, 70, parseFloat(a.verifiedPercentage)], delay: 60 }),
      React.createElement(StatCard, { icon: 'Star', label: t('Average Rating', 'متوسط التقييم'), value: parseFloat(a.avgRating), decimals: 2, tone: 'warning', trend: '+0.1', trendDir: 'up', foot: t('across all techs', 'عبر جميع الفنيين'), spark: [4.2, 4.3, 4.3, 4.4, 4.4, parseFloat(a.avgRating)], delay: 120 }),
      React.createElement(StatCard, { icon: 'Wrench', label: t('Issues Resolved', 'البلاغات المُنجزة'), value: a.totalIssuesResolved, tone: 'cyan', trend: issuesTrend, trendDir: 'up', foot: t('all-time', 'إجمالي كلي'), spark: issuesSpark, delay: 180 })
    ),
    // KPI row 2
    React.createElement('div', { className: 'stat-grid grid-4', style: { marginTop: 16 } },
      React.createElement(StatCard, { icon: 'TriangleAlert', label: t('Active Issues', 'البلاغات النشطة'), value: a.issueStats.active, tone: 'danger', trend: `${urgentCount} ${t('urgent', 'عاجلة')}`, trendDir: 'flat', foot: `${t('of', 'من')} ${a.issueStats.total} ${t('total', 'الإجمالي')}`, spark: [9, 11, 8, 12, 10, a.issueStats.active], sparkColor: 'var(--danger)', delay: 0 }),
      React.createElement(StatCard, { icon: 'Clock', label: t('Pending', 'قيد الانتظار'), value: a.issueStats.pending, tone: 'warning', foot: t('awaiting assignment', 'في انتظار الإسناد'), spark: [4, 6, 5, 7, 6, a.issueStats.pending], delay: 60 }),
      React.createElement(StatCard, { icon: 'CircleCheck', label: t('Completed', 'مكتمل'), value: a.issueStats.completed, tone: 'success', trend: '+12%', trendDir: 'up', foot: t('this cycle', 'هذه الدورة'), spark: [3, 5, 6, 6, 8, a.issueStats.completed], delay: 120 }),
      React.createElement(StatCard, { icon: 'UserRound', label: t('Total Users', 'إجمالي المستخدمين'), value: a.userStats.total, tone: 'primary', trend: usersTrend, trendDir: 'up', foot: `${a.userStats.customers} ${t('customers', 'عملاء')} · ${a.userStats.workers} ${t('workers', 'عمال')}`, spark: usersSpark, delay: 180 })
    ),

    // Charts row 1: donuts
    React.createElement(SectionHead, { icon: 'ChartPie', title: t('Distribution', 'التوزيع') }),
    React.createElement('div', { className: 'charts-grid grid-2' },
      React.createElement(ChartCard, { title: t('Technician Categories', 'فئات الفنيين'), sub: `${a.totalTechnicians} ${t('technicians across', 'فني عبر')} ${catData.length} ${t('trades', 'مهنة')}` },
        React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 18, flexWrap: 'wrap' } },
          React.createElement(Donut, { data: catData, size: 200, thickness: 24, centerVal: a.totalTechnicians, centerLabel: t('Techs', 'فنيون') }),
          React.createElement('div', { style: { flex: 1, minWidth: 160, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px 14px' } },
            catData.map((d, i) => React.createElement('div', { key: i, className: 'legend-item' },
              React.createElement('span', { className: 'legend-dot', style: { background: d.color } }), d.name,
              React.createElement('span', { className: 'lv tnum' }, d.value)))))),
      React.createElement(ChartCard, { title: t('Issue Status Breakdown', 'توزيع حالات البلاغات'), sub: `${a.issueStats.total} ${t('issues tracked', 'بلاغ متابَع')}` },
        React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 18, flexWrap: 'wrap' } },
          React.createElement(Donut, { data: statusData, size: 200, thickness: 24, centerVal: a.issueStats.total, centerLabel: t('Issues', 'البلاغات') }),
          React.createElement('div', { style: { flex: 1, minWidth: 160, display: 'flex', flexDirection: 'column', gap: 9 } },
            statusData.map((d, i) => React.createElement('div', { key: i, className: 'legend-item', style: { justifyContent: 'space-between' } },
              React.createElement('span', { style: { display: 'flex', alignItems: 'center', gap: 7 } }, React.createElement('span', { className: 'legend-dot', style: { background: d.color } }), d.name),
              React.createElement('span', { className: 'lv tnum' }, d.value))))))
    ),

    // Charts row 2: bars
    React.createElement('div', { className: 'charts-grid grid-2', style: { marginTop: 16 } },
      React.createElement(ChartCard, { title: t('Top Cities', 'أبرز المدن'), sub: t('Technician coverage by city', 'تغطية الفنيين حسب المدينة') },
        React.createElement(HBars, { data: cityData, unit: t(' techs', ' فني') })),
      React.createElement(ChartCard, { title: t('Issues by Category', 'البلاغات حسب الفئة'), sub: t('Open + resolved this period', 'المفتوحة + المُنجزة هذه الفترة') },
        React.createElement(VBars, { data: issueCatData, height: 220 }))
    ),

    // Charts row 3: growth + ranking
    React.createElement('div', { className: 'charts-grid grid-2-1', style: { marginTop: 16 } },
      React.createElement(ChartCard, { title: t('Monthly Growth', 'النمو الشهري'), sub: t('Trailing 6 months', 'آخر 6 أشهر'),
        tools: React.createElement('div', { className: 'chart-tools' },
          React.createElement('button', { className: `chip-tab ${growthTab === 'technicians' ? 'on' : ''}`, onClick: () => setGrowthTab('technicians') }, t('Network', 'الشبكة')),
          React.createElement('button', { className: `chip-tab ${growthTab === 'issues' ? 'on' : ''}`, onClick: () => setGrowthTab('issues') }, t('Resolved', 'المُنجزة'))) },
        React.createElement(AreaChart, { data: a.monthlyGrowth, series: growthSeries, height: 256 }),
        React.createElement('div', { className: 'legend' }, growthSeries.map((s, i) => React.createElement('div', { className: 'legend-item', key: i },
          React.createElement('span', { className: 'legend-dot', style: { background: s.color } }), s.name)))),
      React.createElement(ChartCard, { title: t('Top Rated Technicians', 'الأعلى تقييماً من الفنيين'), sub: t('By rating & throughput', 'حسب التقييم والإنتاجية') },
        React.createElement('div', { className: 'rank-list' },
          (a.topTechnicians || []).map((tech, i) => React.createElement('div', { className: 'rank-item', key: tech._id || i },
            React.createElement('div', { className: `rank-badge ${i === 0 ? 'gold' : i === 1 ? 'silver' : i === 2 ? 'bronze' : 'plain'}` }, i + 1),
            React.createElement('div', { className: 'rank-info' },
              React.createElement('div', { className: 'rank-name' }, tech.name),
              React.createElement('div', { className: 'rank-meta' },
                React.createElement(Icon, { name: SF.CATEGORY_CONFIG[tech.category]?.icon || 'Wrench', size: 11, color: SF.CATEGORY_CONFIG[tech.category]?.color }),
                `${tech.city || '—'} · ${tech.issuesResolved || 0} ${t('resolved', 'مُنجز')}`)),
            React.createElement('div', { className: 'rank-score' },
              React.createElement(Icon, { name: 'Star', size: 14, color: '#f59e0b', style: { fill: '#f59e0b' } }), (tech.rating != null ? Number(tech.rating) : 0).toFixed(1))))))
    )
  );
}
