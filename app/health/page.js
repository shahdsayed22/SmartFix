'use client';
/* ============================================================
   SmartFix — System Health page (ported from prototype)
   Real metrics from /api/health; SF.HEALTH is offline fallback.
   ============================================================ */
import React, { useState, useEffect, useRef, useCallback } from 'react';
import { fetchWithTimeout } from '@/lib/fetchWithTimeout';
import { SF } from '@/components/sf/data';
import { Icon } from '@/components/sf/Icon';
import { SectionHead, Toggle, Progress } from '@/components/sf/ui';
import { useT } from '@/components/sf/i18n';

const STATUS = {
  operational: { label: 'Operational', ar: 'تعمل', color: 'var(--success)', icon: 'CircleCheck' },
  degraded: { label: 'Degraded', ar: 'متدهورة', color: 'var(--warning)', icon: 'TriangleAlert' },
  down: { label: 'Down', ar: 'متوقفة', color: 'var(--danger)', icon: 'CircleX' },
  unknown: { label: 'Unknown', ar: 'غير معروف', color: 'var(--text-3)', icon: 'CircleHelp' },
};
const LEVEL = { info: 'var(--info)', warning: 'var(--warning)', success: 'var(--success)', danger: 'var(--danger)' };

// Map raw API status strings onto the UI status keys above.
function mapStatus(raw) {
  if (raw === 'healthy') return 'operational';
  if (raw === 'degraded') return 'degraded';
  if (raw === 'down') return 'down';
  return 'unknown';
}

const NA = 'N/A';
const fmtNum = (n) => (n === null || n === undefined ? NA : Number(n).toLocaleString('en-US'));
const fmtPct = (n) => (n === null || n === undefined ? NA : n + '%');

// Build the services[] array the UI renders from a real /api/health payload.
function buildServices(data, t) {
  const api = data.api || {};
  const db = data.database || {};
  const llm = data.llm || {};
  const mem = api.memory || {};
  const counts = db.counts || {};

  const uptimeMin = api.uptimeSeconds != null ? Math.round(api.uptimeSeconds / 60) : null;

  return [
    {
      id: 'api',
      name: t('API Gateway', 'بوابة الواجهة البرمجية'),
      status: mapStatus(api.status),
      icon: 'Server',
      uptimeLabel: uptimeMin != null ? t(`${uptimeMin} min`, `${uptimeMin} دقيقة`) : NA,
      metrics: [
        { label: t('Heap Used', 'الذاكرة المستخدمة'), value: mem.heapUsedMB != null ? `${mem.heapUsedMB} MB` : NA, pct: mem.heapPct ?? 0, tone: (mem.heapPct ?? 0) > 80 ? 'warning' : 'success' },
        { label: t('RSS Memory', 'ذاكرة العملية'), value: mem.rssMB != null ? `${mem.rssMB} MB` : NA, pct: mem.heapPct ?? 0 },
        { label: t('Node Version', 'إصدار Node'), value: api.nodeVersion || NA, pct: 0, tone: 'success' },
        { label: t('Process Uptime', 'مدة تشغيل العملية'), value: uptimeMin != null ? `${uptimeMin} min` : NA, pct: 0, tone: 'success' },
      ],
    },
    {
      id: 'llm',
      name: t('LLM Engine', 'محرك النماذج اللغوية'),
      status: mapStatus(llm.status),
      icon: 'BrainCircuit',
      uptimeLabel: NA,
      metrics: [
        { label: t('Token Usage (24h)', 'استهلاك الرموز 24 ساعة'), value: fmtNum(llm.tokenUsage24h), pct: 0 },
        { label: t('Queue Length', 'طول الطابور'), value: llm.queueLength == null ? NA : fmtNum(llm.queueLength), pct: 0 },
        { label: t('Inference Latency', 'زمن الاستدلال'), value: llm.inferenceLatencyMs == null ? NA : `${llm.inferenceLatencyMs} ms`, pct: 0 },
        { label: t('Model', 'النموذج'), value: llm.model || NA, pct: 0 },
      ],
    },
    {
      id: 'db',
      name: t('MongoDB', 'قاعدة بيانات MongoDB'),
      status: mapStatus(db.status),
      icon: 'Database',
      uptimeLabel: db.readyLabel ? t(db.readyLabel, db.readyLabel) : NA,
      metrics: [
        { label: t('Connection State', 'حالة الاتصال'), value: db.readyLabel || NA, pct: 0, tone: db.status === 'healthy' ? 'success' : 'warning' },
        { label: t('Ping', 'زمن الاستجابة'), value: db.pingMs == null ? NA : `${db.pingMs} ms`, pct: 0, tone: 'success' },
        { label: t('Documents', 'المستندات'), value: fmtNum(counts.total), pct: 0 },
        { label: t('Issues / Users / Techs', 'بلاغات / مستخدمون / فنيون'), value: `${fmtNum(counts.issues)} / ${fmtNum(counts.users)} / ${fmtNum(counts.technicians)}`, pct: 0 },
      ],
    },
  ];
}

// Cluster snapshot tiles built from real values, N/A where unmeasurable.
function buildCluster(data, t) {
  const api = data.api || {};
  const db = data.database || {};
  const llm = data.llm || {};
  const mem = api.memory || {};
  const counts = db.counts || {};
  const uptimeMin = api.uptimeSeconds != null ? Math.round(api.uptimeSeconds / 60) : null;

  return [
    { label: t('Process Uptime', 'مدة التشغيل'), value: uptimeMin != null ? `${uptimeMin} min` : NA, icon: 'Clock', tone: 'cyan' },
    { label: t('DB Ping', 'زمن استجابة القاعدة'), value: db.pingMs == null ? NA : `${db.pingMs} ms`, icon: 'Gauge', tone: 'success' },
    { label: t('Heap Used', 'الذاكرة المستخدمة'), value: mem.heapUsedMB != null ? `${mem.heapUsedMB} MB` : NA, icon: 'Cpu', tone: 'primary' },
    { label: t('RSS Memory', 'ذاكرة العملية'), value: mem.rssMB != null ? `${mem.rssMB} MB` : NA, icon: 'MemoryStick', tone: 'primary' },
    { label: t('Documents', 'المستندات'), value: fmtNum(counts.total), icon: 'Database', tone: 'primary' },
    { label: t('Token Usage 24h', 'استهلاك الرموز 24 ساعة'), value: fmtNum(llm.tokenUsage24h), icon: 'Cpu', tone: 'warning' },
  ];
}

// Offline fallback: derive the same UI shape from SF.HEALTH sample data.
function fallbackServices() {
  return SF.HEALTH.services.map(s => ({
    id: s.id,
    name: s.name,
    status: s.status,
    icon: s.icon,
    uptimeLabel: s.uptime + '%',
    metrics: s.metrics.map(m => ({ label: m.label, value: m.value, pct: m.pct, tone: m.tone })),
  }));
}

export default function HealthPage() {
  const t = useT();
  const [services, setServices] = useState(fallbackServices);
  const [cluster, setCluster] = useState(null);
  const [live, setLive] = useState(false);
  const [auto, setAuto] = useState(true);
  const [updated, setUpdated] = useState(null);
  const [spin, setSpin] = useState(false);
  const timer = useRef();

  const refresh = useCallback(async () => {
    setSpin(true);
    try {
      const res = await fetchWithTimeout('/api/health', { cache: 'no-store' });
      if (!res.ok) throw new Error('health ' + res.status);
      const data = await res.json();
      setServices(buildServices(data, t));
      setCluster(buildCluster(data, t));
      setLive(true);
      setUpdated(data.lastChecked ? new Date(data.lastChecked) : new Date());
    } catch (e) {
      // Keep the last good data; fall back to SF.HEALTH only if we never went live.
      setLive(false);
      setServices(prev => (prev && prev.length ? prev : fallbackServices()));
      setUpdated(new Date());
    } finally {
      setTimeout(() => setSpin(false), 400);
    }
  }, [t]);

  // Initial fetch on mount.
  useEffect(() => { refresh(); }, [refresh]);

  // Auto-refresh interval.
  useEffect(() => {
    if (auto) { timer.current = setInterval(refresh, 5000); }
    return () => clearInterval(timer.current);
  }, [auto, refresh]);

  const fmtTime = (d) => d ? d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', second: '2-digit' }) : '—';
  const tone = (m) => m.tone === 'success' ? 'success' : m.tone === 'warning' ? 'warning' : m.tone === 'danger' ? 'danger' : (m.pct > 80 ? 'warning' : 'cyan');

  const allUp = services.every(s => s.status === 'operational');
  const headLabel = !live
    ? t('Offline — Sample Data', 'غير متصل — بيانات تجريبية')
    : allUp
      ? t('All Systems Operational', 'كل الأنظمة تعمل')
      : t('Some Systems Degraded', 'بعض الأنظمة متدهورة');

  const clusterTiles = cluster || [
    { label: t('Requests / min', 'الطلبات / دقيقة'), value: NA, icon: 'ArrowRightLeft', tone: 'cyan' },
    { label: t('Avg Latency', 'متوسط زمن الاستجابة'), value: NA, icon: 'Gauge', tone: 'success' },
    { label: t('Error Rate', 'معدل الأخطاء'), value: NA, icon: 'TriangleAlert', tone: 'success' },
    { label: t('Active Sessions', 'الجلسات النشطة'), value: NA, icon: 'Users', tone: 'primary' },
    { label: t('Documents', 'المستندات'), value: NA, icon: 'Database', tone: 'primary' },
    { label: t('Token Usage 24h', 'استهلاك الرموز 24 ساعة'), value: NA, icon: 'Cpu', tone: 'warning' },
  ];

  return React.createElement('div', { className: 'page-anim' },
    // control bar
    React.createElement('div', { className: 'card rise', style: { padding: '14px 18px', display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap', marginBottom: 4 } },
      React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 10 } },
        React.createElement('span', { className: 'pulse' }),
        React.createElement('div', null,
          React.createElement('div', { style: { fontWeight: 700, fontSize: 14 } }, headLabel),
          React.createElement('div', { className: 'cell-sub' }, t('Last updated', 'آخر تحديث'), ' ', fmtTime(updated)))),
      React.createElement('div', { style: { flex: 1 } }),
      live && React.createElement('span', { title: t('Reading live data from the app backend', 'قراءة بيانات حية من خادم التطبيق'), style: { display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, fontWeight: 700, letterSpacing: 0.4, color: '#0e9f6e', background: 'rgba(16,185,129,0.12)', padding: '4px 10px', borderRadius: 999 } },
        React.createElement('span', { style: { width: 7, height: 7, borderRadius: 999, background: '#10b981', display: 'inline-block' } }), t('LIVE', 'مباشر')),
      React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 9 } },
        React.createElement('span', { style: { fontSize: 13, color: 'var(--text-2)', fontWeight: 600 } }, t('Auto-refresh', 'تحديث تلقائي')),
        React.createElement(Toggle, { on: auto, onChange: setAuto })),
      React.createElement('button', { className: 'btn btn-ghost', onClick: refresh },
        React.createElement(Icon, { name: 'RefreshCw', size: 15, style: { animation: spin ? 'spin .6s linear' : 'none' } }), t('Refresh', 'تحديث'))
    ),

    React.createElement(SectionHead, { icon: 'Activity', title: t('Service Health', 'حالة الخدمات') }),
    React.createElement('div', { className: 'charts-grid grid-3' },
      services.map((svc, i) => {
        const st = STATUS[svc.status] || STATUS.unknown;
        return React.createElement('div', { key: svc.id, className: 'card rise', style: { padding: 20, animationDelay: i * 60 + 'ms' } },
          React.createElement('div', { className: 'health-head' },
            React.createElement('div', { className: 'health-icon', style: { background: `color-mix(in srgb, ${st.color} 16%, transparent)`, color: st.color } }, React.createElement(Icon, { name: svc.icon, size: 22 })),
            React.createElement('div', { style: { flex: 1 } },
              React.createElement('div', { style: { fontWeight: 700, fontSize: 15 } }, svc.name),
              React.createElement('span', { className: 'badge', style: { background: `color-mix(in srgb, ${st.color} 14%, transparent)`, color: st.color, marginTop: 4 } },
                React.createElement(Icon, { name: st.icon, size: 12 }), t(st.label, st.ar)))),
          React.createElement('div', { style: { display: 'flex', alignItems: 'baseline', gap: 6, margin: '14px 0 4px' } },
            React.createElement('span', { className: 'big-uptime', style: { color: st.color, fontSize: svc.uptimeLabel === NA ? 22 : undefined } }, svc.uptimeLabel),
            React.createElement('span', { className: 'cell-sub' }, t('current state', 'الحالة الحالية'))),
          React.createElement('div', { style: { marginTop: 10 } },
            svc.metrics.map((m, k) => React.createElement('div', { key: k, className: 'metric-row', 'data-testid': 'metric-tile' },
              React.createElement('div', { className: 'metric-label' }, m.label),
              React.createElement('div', { className: 'metric-bar' }, React.createElement(Progress, { value: m.pct, tone: tone(m) })),
              React.createElement('div', { className: 'metric-value', style: m.value === NA ? { color: 'var(--text-3)' } : m.tone === 'success' ? { color: 'var(--success)' } : m.tone === 'warning' ? { color: 'var(--warning)' } : null }, m.value)))));
      })
    ),

    // bottom: quick metrics + activity
    React.createElement('div', { className: 'charts-grid grid-1-2', style: { marginTop: 22 } },
      React.createElement('div', { className: 'card rise', style: { padding: 20 } },
        React.createElement('h3', { style: { fontSize: 14.5, fontWeight: 700, marginBottom: 14 } }, t('Cluster Snapshot', 'لمحة عن العنقود')),
        React.createElement('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 } },
          clusterTiles.map((m, i) => React.createElement('div', { key: i, style: { padding: 14, borderRadius: 12, background: 'var(--surface-2)', border: '1px solid var(--border)' } },
            React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 7, color: 'var(--text-3)', fontSize: 11.5, fontWeight: 600, marginBottom: 6 } }, React.createElement(Icon, { name: m.icon, size: 13 }), m.label),
            React.createElement('div', { className: 'tnum', style: { fontSize: 21, fontWeight: 800, letterSpacing: '-0.02em', color: m.value === NA ? 'var(--text-3)' : undefined } }, m.value)))) ),

      React.createElement('div', { className: 'card rise', style: { padding: 20 } },
        React.createElement('h3', { style: { fontSize: 14.5, fontWeight: 700, marginBottom: 14 } }, t('Recent Activity', 'النشاط الأخير')),
        React.createElement('div', { style: { display: 'flex', flexDirection: 'column' } },
          SF.HEALTH.incidents.map((inc, i) => React.createElement('div', { key: i, style: { display: 'flex', gap: 12, padding: '11px 0', borderBottom: i < SF.HEALTH.incidents.length - 1 ? '1px solid var(--hairline)' : 'none' } },
            React.createElement('div', { style: { width: 9, height: 9, borderRadius: '50%', background: LEVEL[inc.level], marginTop: 5, flexShrink: 0, boxShadow: `0 0 0 4px color-mix(in srgb, ${LEVEL[inc.level]} 18%, transparent)` } }),
            React.createElement('div', { style: { flex: 1 } },
              React.createElement('div', { style: { fontSize: 13, fontWeight: 600 } }, inc.text),
              React.createElement('div', { className: 'cell-sub', style: { display: 'flex', gap: 8, marginTop: 2 } },
                React.createElement('span', { style: { color: 'var(--accent-light)', fontWeight: 600 } }, inc.service), '·', inc.time))))))
    )
  );
}
