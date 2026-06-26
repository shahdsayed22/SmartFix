'use client';
/* ============================================================
   SmartFix — SVG chart library (React).
   Charts: Donut, HBars, VBars, AreaChart, Sparkline, RatingBars
   ============================================================ */
import React, { useState, useRef, useEffect, useId } from 'react';
import { Icon } from './Icon';

/* ── count-up hook (micro animation) ── */
export function useCountUp(target, { duration = 900, decimals = 0 } = {}) {
  const [val, setVal] = useState(parseFloat(target) || 0);
  useEffect(() => {
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const end = parseFloat(target) || 0;
    if (reduce) { setVal(end); return; }
    setVal(0);
    let raf, start;
    const step = (t) => {
      if (!start) start = t;
      const p = Math.min((t - start) / duration, 1);
      const eased = 1 - Math.pow(1 - p, 3);
      setVal(end * eased);
      if (p < 1) raf = requestAnimationFrame(step);
      else setVal(end);
    };
    raf = requestAnimationFrame(step);
    // Guarantee final value even if rAF is throttled (offscreen preview)
    const fallback = setTimeout(() => setVal(end), duration + 150);
    return () => { cancelAnimationFrame(raf); clearTimeout(fallback); };
  }, [target]);
  return decimals ? val.toFixed(decimals) : Math.round(val);
}

/* ── shared tooltip ── */
function useTip() {
  const [tip, setTip] = useState(null); // {x,y,content}
  const node = tip ? React.createElement('div', {
    className: 'chart-tip',
    style: { left: tip.x, top: tip.y },
  }, tip.content) : null;
  return { tip, setTip, node };
}

/* ════════ DONUT ════════ */
export function Donut({ data, size = 220, thickness = 26, centerVal, centerLabel }) {
  const { setTip, node } = useTip();
  const total = data.reduce((a, d) => a + d.value, 0) || 1;
  const r = (size - thickness) / 2;
  const cx = size / 2, cy = size / 2;
  const circ = 2 * Math.PI * r;
  let offset = 0;
  const [hovered, setHovered] = useState(null);

  return React.createElement('div', { className: 'donut-wrap', style: { height: size } },
    React.createElement('svg', { width: size, height: size, style: { transform: 'rotate(-90deg)' } },
      data.map((d, i) => {
        const frac = d.value / total;
        const len = frac * circ;
        const el = React.createElement('circle', {
          key: i, cx, cy, r, fill: 'none', stroke: d.color,
          strokeWidth: hovered === i ? thickness + 5 : thickness,
          strokeDasharray: `${len} ${circ - len}`,
          strokeDashoffset: -offset,
          style: { transition: 'stroke-width .18s, opacity .18s', opacity: hovered === null || hovered === i ? 1 : 0.35, cursor: 'pointer' },
          onMouseMove: (e) => { setHovered(i); setTip({ x: e.clientX, y: e.clientY, content: tipContent(d, total) }); },
          onMouseLeave: () => { setHovered(null); setTip(null); },
        });
        offset += len;
        return el;
      })
    ),
    React.createElement('div', { className: 'donut-center' },
      React.createElement('div', { className: 'dc-val tnum' }, centerVal != null ? centerVal : total),
      React.createElement('div', { className: 'dc-label' }, centerLabel || 'Total')
    ),
    node
  );
}
function tipContent(d, total) {
  const pct = ((d.value / total) * 100).toFixed(1);
  return [
    React.createElement('div', { className: 'tip-label', key: 'l' }, d.name),
    React.createElement('div', { className: 'tip-row', key: 'r' },
      React.createElement('span', { className: 'legend-dot', style: { background: d.color } }),
      React.createElement('span', { className: 'tnum' }, `${d.value} · ${pct}%`)),
  ];
}

/* ════════ HORIZONTAL BARS ════════ */
export function HBars({ data, max, unit = '', color }) {
  const { setTip, node } = useTip();
  const mx = max || Math.max(...data.map(d => d.value), 1);
  return React.createElement('div', { style: { display: 'flex', flexDirection: 'column', gap: 11 } },
    data.map((d, i) => React.createElement('div', { key: i, style: { display: 'flex', alignItems: 'center', gap: 12 } },
      React.createElement('div', { style: { width: 116, fontSize: 12.5, color: 'var(--text-2)', fontWeight: 600, textAlign: 'right', flexShrink: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' } }, d.name),
      React.createElement('div', {
        style: { flex: 1, height: 22, background: 'var(--surface-2)', borderRadius: 7, overflow: 'hidden', position: 'relative', cursor: 'pointer' },
        onMouseMove: (e) => setTip({ x: e.clientX, y: e.clientY, content: [React.createElement('div', { className: 'tip-label', key: 'l' }, d.name), React.createElement('div', { className: 'tip-row', key: 'r' }, React.createElement('span', { className: 'tnum' }, `${d.value}${unit}`))] }),
        onMouseLeave: () => setTip(null),
      },
        React.createElement('div', { style: { position: 'absolute', inset: 0, width: `${(d.value / mx) * 100}%`, background: d.color ? `linear-gradient(90deg, ${d.color}, ${d.color}cc)` : 'var(--grad-accent)', borderRadius: 7, transition: 'width .9s cubic-bezier(.4,0,.2,1)' } })
      ),
      React.createElement('div', { className: 'tnum', style: { width: 38, fontSize: 12.5, fontWeight: 700, textAlign: 'right' } }, d.value)
    )),
    node
  );
}

/* ════════ VERTICAL BARS ════════ */
export function VBars({ data, height = 240, unit = '' }) {
  const { setTip, node } = useTip();
  const mx = Math.max(...data.map(d => d.value), 1);
  const ticks = 4;
  return React.createElement('div', { style: { position: 'relative' } },
    React.createElement('div', { style: { display: 'flex', alignItems: 'flex-end', gap: 10, height, paddingLeft: 6, borderLeft: '1px solid var(--grid-line)', borderBottom: '1px solid var(--grid-line)', position: 'relative' } },
      // gridlines
      Array.from({ length: ticks }).map((_, i) => React.createElement('div', { key: 'g' + i, style: { position: 'absolute', left: 0, right: 0, bottom: `${((i + 1) / ticks) * 100}%`, height: 1, background: 'var(--grid-line)' } })),
      data.map((d, i) => {
        const h = (d.value / mx) * 100;
        return React.createElement('div', { key: i, style: { flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'flex-end', height: '100%', gap: 8, zIndex: 1 } },
          React.createElement('div', {
            style: { width: '100%', maxWidth: 46, height: `${h}%`, minHeight: d.value > 0 ? 4 : 0, background: d.color ? `linear-gradient(180deg, ${d.color}, ${d.color}99)` : 'var(--grad-accent)', borderRadius: '7px 7px 3px 3px', transition: 'height .9s cubic-bezier(.4,0,.2,1)', cursor: 'pointer', position: 'relative' },
            onMouseMove: (e) => setTip({ x: e.clientX, y: e.clientY, content: [React.createElement('div', { className: 'tip-label', key: 'l' }, d.name), React.createElement('div', { className: 'tip-row', key: 'r' }, React.createElement('span', { className: 'tnum' }, `${d.value}${unit}`))] }),
            onMouseLeave: () => setTip(null),
          }),
          React.createElement('div', { style: { fontSize: 11, color: 'var(--text-3)', fontWeight: 600, whiteSpace: 'nowrap', textAlign: 'center', lineHeight: 1.15 } }, d.short || d.name)
        );
      })
    ),
    node
  );
}

/* ════════ AREA CHART (multi-series) ════════ */
export function AreaChart({ data, series, height = 250 }) {
  const { setTip, node } = useTip();
  const [hi, setHi] = useState(null);
  const wrapRef = useRef();
  const W = 560, H = height, padL = 36, padB = 26, padT = 12, padR = 10;
  const iw = W - padL - padR, ih = H - padB - padT;
  const maxV = Math.max(...data.flatMap(d => series.map(s => d[s.key])), 1);
  const niceMax = Math.ceil(maxV / 50) * 50 || maxV;
  const xFor = (i) => padL + (data.length === 1 ? iw / 2 : (i / (data.length - 1)) * iw);
  const yFor = (v) => padT + ih - (v / niceMax) * ih;

  const buildPath = (key, close) => {
    let d = data.map((row, i) => `${i === 0 ? 'M' : 'L'} ${xFor(i)} ${yFor(row[key])}`).join(' ');
    if (close) d += ` L ${xFor(data.length - 1)} ${padT + ih} L ${xFor(0)} ${padT + ih} Z`;
    return d;
  };

  const onMove = (e) => {
    const rect = wrapRef.current.getBoundingClientRect();
    const sx = (e.clientX - rect.left) / rect.width * W;
    let idx = Math.round((sx - padL) / iw * (data.length - 1));
    idx = Math.max(0, Math.min(data.length - 1, idx));
    setHi(idx);
    setTip({
      x: e.clientX, y: e.clientY,
      content: [
        React.createElement('div', { className: 'tip-label', key: 'l' }, data[idx].label || data[idx].month),
        ...series.map((s, k) => React.createElement('div', { className: 'tip-row', key: k },
          React.createElement('span', { className: 'legend-dot', style: { background: s.color } }),
          React.createElement('span', null, s.name + ': '),
          React.createElement('span', { className: 'tnum', style: { marginLeft: 2 } }, data[idx][s.key]))),
      ],
    });
  };

  return React.createElement('div', { ref: wrapRef, style: { position: 'relative' } },
    React.createElement('svg', { viewBox: `0 0 ${W} ${H}`, width: '100%', height: H, onMouseMove: onMove, onMouseLeave: () => { setHi(null); setTip(null); }, style: { display: 'block', overflow: 'visible' } },
      React.createElement('defs', null, series.map((s, i) => React.createElement('linearGradient', { key: i, id: 'ag' + i, x1: 0, y1: 0, x2: 0, y2: 1 },
        React.createElement('stop', { offset: '0%', stopColor: s.color, stopOpacity: 0.35 }),
        React.createElement('stop', { offset: '100%', stopColor: s.color, stopOpacity: 0 })))),
      // y gridlines + labels
      [0, 0.25, 0.5, 0.75, 1].map((f, i) => {
        const y = padT + ih - f * ih;
        return React.createElement('g', { key: i },
          React.createElement('line', { x1: padL, y1: y, x2: W - padR, y2: y, stroke: 'var(--grid-line)', strokeWidth: 1 }),
          React.createElement('text', { x: padL - 8, y: y + 3, textAnchor: 'end', fontSize: 10, fill: 'var(--text-faint)' }, Math.round(niceMax * f)));
      }),
      // x labels
      data.map((row, i) => React.createElement('text', { key: 'x' + i, x: xFor(i), y: H - 8, textAnchor: 'middle', fontSize: 10, fill: 'var(--text-faint)' }, row.label || row.month)),
      // areas + lines
      series.map((s, i) => React.createElement('g', { key: i },
        React.createElement('path', { d: buildPath(s.key, true), fill: `url(#ag${i})` }),
        React.createElement('path', { d: buildPath(s.key, false), fill: 'none', stroke: s.color, strokeWidth: 2.5 }))),
      // hover crosshair + dots
      hi != null && React.createElement('g', null,
        React.createElement('line', { x1: xFor(hi), y1: padT, x2: xFor(hi), y2: padT + ih, stroke: 'var(--border-accent)', strokeWidth: 1, strokeDasharray: '4 4' }),
        series.map((s, i) => React.createElement('circle', { key: i, cx: xFor(hi), cy: yFor(data[hi][s.key]), r: 4.5, fill: s.color, stroke: 'var(--bg-elevated)', strokeWidth: 2 })))
    ),
    node
  );
}

/* ════════ SPARKLINE (tiny) ════════ */
export function Sparkline({ data, color = 'var(--accent)', width = 84, height = 30, fill = true }) {
  // Guard the empty/zero-data case (fresh DB) so we render a flat baseline
  // instead of crashing on pts[-1] / Math.max() of an empty array.
  const series = Array.isArray(data) && data.length ? data : [0, 0];
  const max = Math.max(...series), min = Math.min(...series);
  const range = max - min || 1;
  const pts = series.map((v, i) => [(series.length === 1 ? 0 : (i / (series.length - 1))) * width, height - ((v - min) / range) * (height - 4) - 2]);
  const line = pts.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
  const area = `${line} L ${width} ${height} L 0 ${height} Z`;
  const uid = useId();
  const id = 'sp' + uid.replace(/[:]/g, '');
  return React.createElement('svg', { width, height, style: { display: 'block', overflow: 'visible' } },
    fill && React.createElement('defs', null, React.createElement('linearGradient', { id, x1: 0, y1: 0, x2: 0, y2: 1 },
      React.createElement('stop', { offset: '0%', stopColor: color, stopOpacity: 0.3 }),
      React.createElement('stop', { offset: '100%', stopColor: color, stopOpacity: 0 }))),
    fill && React.createElement('path', { d: area, fill: `url(#${id})` }),
    React.createElement('path', { d: line, fill: 'none', stroke: color, strokeWidth: 2, strokeLinecap: 'round', strokeLinejoin: 'round' }),
    React.createElement('circle', { cx: pts[pts.length - 1][0], cy: pts[pts.length - 1][1], r: 2.4, fill: color })
  );
}

/* ════════ RATING DISTRIBUTION BARS ════════ */
export function RatingBars({ data }) {
  const { setTip, node } = useTip();
  const mx = Math.max(...data.map(d => d.count), 1);
  const total = data.reduce((a, d) => a + d.count, 0) || 1;
  const colors = ['#10b981', '#34d399', '#f59e0b', '#fb923c', '#ef4444'];
  return React.createElement('div', { style: { display: 'flex', flexDirection: 'column', gap: 10 } },
    data.map((d, i) => React.createElement('div', { key: i, style: { display: 'flex', alignItems: 'center', gap: 12 } },
      React.createElement('div', { style: { width: 64, fontSize: 12, fontWeight: 600, color: 'var(--text-2)', display: 'flex', alignItems: 'center', gap: 4 } },
        React.createElement(Icon, { name: 'Star', size: 12, color: colors[i], style: { fill: colors[i] } }), d.range.replace(' – ', '–')),
      React.createElement('div', { style: { flex: 1, height: 20, background: 'var(--surface-2)', borderRadius: 6, overflow: 'hidden', cursor: 'pointer' },
        onMouseMove: (e) => setTip({ x: e.clientX, y: e.clientY, content: [React.createElement('div', { className: 'tip-label', key: 'l' }, d.range + ' stars'), React.createElement('div', { className: 'tip-row tnum', key: 'r' }, `${d.count} techs · ${((d.count / total) * 100).toFixed(0)}%`)] }),
        onMouseLeave: () => setTip(null) },
        React.createElement('div', { style: { height: '100%', width: `${(d.count / mx) * 100}%`, background: `linear-gradient(90deg, ${colors[i]}, ${colors[i]}aa)`, borderRadius: 6, transition: 'width .9s cubic-bezier(.4,0,.2,1)' } })
      ),
      React.createElement('div', { className: 'tnum', style: { width: 28, fontSize: 12.5, fontWeight: 700, textAlign: 'right' } }, d.count)
    )),
    node
  );
}
