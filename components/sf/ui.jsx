'use client';
/* ============================================================
   SmartFix — shared UI components (ES module port).
   ============================================================ */
import React, { useState, useRef, useEffect } from 'react';
import { Icon } from './Icon';
import { Sparkline, useCountUp } from './charts';
import { SF } from './data';
import { useT } from './i18n';

/* ── helpers ── */
export const initials = (n) => n.split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase();
const AV_COLORS = ['#6366f1', '#22d3ee', '#10b981', '#f59e0b', '#a855f7', '#ec4899', '#3b82f6', '#14b8a6', '#f97316'];
export const avatarColor = (n) => AV_COLORS[[...n].reduce((a, c) => a + c.charCodeAt(0), 0) % AV_COLORS.length];

export function Avatar({ name, className = 'row-avatar' }) {
  return React.createElement('div', { className, style: { background: `linear-gradient(135deg, ${avatarColor(name)}, ${avatarColor(name)}bb)` } }, initials(name));
}

export function Stars({ value, size = 13 }) {
  const full = Math.floor(value);
  const half = value - full >= 0.5;
  return React.createElement('span', { className: 'stars' },
    [0, 1, 2, 3, 4].map(i => {
      const filled = i < full;
      const isHalf = i === full && half;
      return React.createElement(Icon, { key: i, name: 'Star', size,
        color: filled || isHalf ? '#f59e0b' : 'var(--text-faint)',
        style: { fill: filled ? '#f59e0b' : (isHalf ? 'url(#halfstar)' : 'none') } });
    })
  );
}

export function CatChip({ cat, small }) {
  const c = SF.CATEGORY_CONFIG[cat] || { label: cat, color: '#6366f1', icon: 'Wrench' };
  return React.createElement('span', { className: 'cat-chip', style: { background: `${c.color}1f`, color: c.color, padding: small ? '3px 8px 3px 7px' : undefined, fontSize: small ? 11 : undefined } },
    React.createElement(Icon, { name: c.icon, size: small ? 12 : 13 }), c.label);
}

export function StatusBadge({ status }) {
  const s = SF.STATUS_CONFIG[status] || { label: status, color: '#64748b' };
  return React.createElement('span', { className: 'badge badge-soft', style: { background: `${s.color}1f`, color: s.color, border: `1px solid ${s.color}40` } },
    React.createElement('span', { className: 'bdot', style: { background: s.color } }), s.label);
}

export function UrgencyBadge({ urgency }) {
  const u = SF.URGENCY_CONFIG[urgency] || { label: urgency, color: '#64748b' };
  const emergency = urgency === 'emergency';
  return React.createElement('span', { className: 'badge badge-soft', style: { background: `${u.color}1f`, color: u.color, border: `1px solid ${u.color}40` } },
    emergency
      ? React.createElement(Icon, { name: 'TriangleAlert', size: 11 })
      : React.createElement('span', { className: 'bdot', style: { background: u.color } }),
    u.label);
}

export function VerifiedBadge({ verified }) {
  const t = useT();
  return verified
    ? React.createElement('span', { className: 'verif yes' }, React.createElement(Icon, { name: 'BadgeCheck', size: 15 }), t('Verified', 'موثّق'))
    : React.createElement('span', { className: 'verif no' }, React.createElement(Icon, { name: 'Clock', size: 14 }), t('Pending', 'قيد الانتظار'));
}

export function Toggle({ on, onChange }) {
  return React.createElement('button', { className: `switch ${on ? 'on' : ''}`, onClick: () => onChange(!on), role: 'switch', 'aria-checked': on });
}

export function Progress({ value, tone }) {
  return React.createElement('div', { className: `progress ${tone || ''}` }, React.createElement('span', { style: { width: `${Math.min(100, value)}%` } }));
}

/* ── Inline status dropdown (for issues table) ── */
export function StatusSelect({ value, onChange }) {
  const [open, setOpen] = useState(false);
  const ref = useRef();
  useEffect(() => {
    const h = (e) => { if (ref.current && !ref.current.contains(e.target)) setOpen(false); };
    document.addEventListener('mousedown', h);
    return () => document.removeEventListener('mousedown', h);
  }, []);
  // Fall back for statuses the app backend uses that aren't in STATUS_CONFIG
  // (e.g. "offered") — an unguarded lookup here crashes the whole table.
  const s = SF.STATUS_CONFIG[value] || { label: value, color: '#64748b' };
  return React.createElement('div', { className: 'status-select', ref },
    React.createElement('button', { className: 'status-trigger', style: { background: `${s.color}1f`, color: s.color, border: `1px solid ${s.color}40` }, onClick: () => setOpen(o => !o) },
      React.createElement('span', { className: 'bdot', style: { background: s.color } }), s.label,
      React.createElement(Icon, { name: 'ChevronDown', size: 13 })),
    open && React.createElement('div', { className: 'status-menu' },
      Object.entries(SF.STATUS_CONFIG).map(([k, cfg]) => React.createElement('div', { key: k, className: `status-opt ${k === value ? 'cur' : ''}`, onClick: () => { onChange(k); setOpen(false); } },
        React.createElement('span', { className: 'bdot', style: { background: cfg.color } }), cfg.label,
        k === value && React.createElement(Icon, { name: 'Check', size: 14, style: { marginLeft: 'auto', color: cfg.color } })))
    ));
}

/* ── StatCard (KPI) ── */
export function StatCard({ icon, label, value, suffix, tone = 'primary', trend, trendDir, foot, spark, sparkColor, delay = 0, decimals = 0 }) {
  const numeric = typeof value === 'number';
  const animated = useCountUp(numeric ? value : 0, { decimals });
  const display = numeric ? Number(animated).toLocaleString(undefined, { minimumFractionDigits: decimals, maximumFractionDigits: decimals }) : value;
  return React.createElement('div', { className: 'stat-card rise', 'data-testid': 'stat-card', style: { animationDelay: delay + 'ms' } },
    React.createElement('div', { className: 'accent-bar', style: { background: `var(--${tone === 'primary' ? 'accent' : tone === 'cyan' ? 'accent-2' : tone})` } }),
    React.createElement('div', { className: 'stat-top' },
      React.createElement('div', null,
        React.createElement('div', { className: 'stat-label' }, label),
        React.createElement('div', { className: 'stat-value tnum' }, display, suffix && React.createElement('span', { className: 'suffix' }, suffix))
      ),
      React.createElement('div', { className: `stat-icon bg-${tone}-soft` }, React.createElement(Icon, { name: icon, size: 20 }))
    ),
    (trend || foot) && React.createElement('div', { className: 'stat-foot' },
      trend && React.createElement('span', { className: `trend ${trendDir || 'up'}` },
        React.createElement(Icon, { name: trendDir === 'down' ? 'TrendingDown' : trendDir === 'flat' ? 'Minus' : 'TrendingUp', size: 12 }), trend),
      foot && React.createElement('span', null, foot)
    ),
    spark && React.createElement('div', { className: 'stat-spark' }, React.createElement(Sparkline, { data: spark, color: sparkColor || `var(--${tone === 'primary' ? 'accent' : tone === 'cyan' ? 'accent-2' : tone})`, width: 84, height: 30 }))
  );
}

/* ── ChartCard wrapper ── */
export function ChartCard({ title, sub, tools, children, className = '', style }) {
  return React.createElement('div', { className: `card chart-card rise ${className}`, style },
    React.createElement('div', { className: 'chart-head' },
      React.createElement('div', null,
        React.createElement('h3', null, title),
        sub && React.createElement('div', { className: 'chart-sub' }, sub)),
      tools),
    children);
}

export function Legend({ items, total }) {
  return React.createElement('div', { className: 'legend' },
    items.map((it, i) => React.createElement('div', { className: 'legend-item', key: i },
      React.createElement('span', { className: 'legend-dot', style: { background: it.color } }),
      it.name,
      React.createElement('span', { className: 'lv tnum' }, it.value))));
}

/* ── PageHeader / SectionHead ── */
export function SectionHead({ icon, title, sub, right }) {
  return React.createElement('div', { className: 'section-head' },
    React.createElement('h2', null, icon && React.createElement('span', { className: 'ico' }, React.createElement(Icon, { name: icon, size: 17 })), title,
      sub && React.createElement('span', { className: 'sub', style: { fontWeight: 400, marginLeft: 2 } }, sub)),
    right);
}

/* ── Modal ── */
export function Modal({ title, sub, onClose, children, footer, wide }) {
  useEffect(() => {
    const h = (e) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', h);
    return () => document.removeEventListener('keydown', h);
  }, []);
  return React.createElement('div', { className: 'modal-scrim', onMouseDown: (e) => { if (e.target === e.currentTarget) onClose(); } },
    React.createElement('div', { className: `modal ${wide ? 'wide' : ''}` },
      React.createElement('div', { className: 'modal-head' },
        React.createElement('div', null,
          React.createElement('h3', null, title),
          sub && React.createElement('p', null, sub)),
        React.createElement('button', { className: 'icon-btn', onClick: onClose, style: { width: 34, height: 34 } }, React.createElement(Icon, { name: 'X', size: 17 }))),
      React.createElement('div', { className: 'modal-body' }, children),
      footer && React.createElement('div', { className: 'modal-foot' }, footer)
    ));
}

/* ── Empty / Loading states ── */
export function EmptyState({ icon = 'Inbox', title, sub, action }) {
  return React.createElement('div', { className: 'state' },
    React.createElement('div', { className: 'state-icon' }, React.createElement(Icon, { name: icon, size: 28 })),
    React.createElement('h4', null, title),
    sub && React.createElement('p', null, sub),
    action);
}
export function Loading({ text }) {
  const t = useT();
  const label = text != null ? text : t('Loading analytics…', 'جارٍ تحميل التحليلات…');
  return React.createElement('div', { className: 'loading-full' },
    React.createElement('div', { className: 'spinner' }),
    React.createElement('div', { className: 'loading-text' }, label));
}

/* ── Sortable / paginated DataTable ── */
export function DataTable({ columns, rows, pageSize = 8, initialSort, emptyTitle, emptySub }) {
  const t = useT();
  const emptyTitleLabel = emptyTitle != null ? emptyTitle : t('No results', 'لا توجد نتائج');
  const [sort, setSort] = useState(initialSort || null); // {key, dir}
  const [page, setPage] = useState(0);
  useEffect(() => { setPage(0); }, [rows]);

  const sorted = React.useMemo(() => {
    if (!sort) return rows;
    const col = columns.find(c => c.key === sort.key);
    const acc = col?.sortAccessor || ((r) => r[sort.key]);
    return [...rows].sort((a, b) => {
      let va = acc(a), vb = acc(b);
      if (typeof va === 'string') { va = va.toLowerCase(); vb = (vb || '').toLowerCase(); }
      if (va < vb) return sort.dir === 'asc' ? -1 : 1;
      if (va > vb) return sort.dir === 'asc' ? 1 : -1;
      return 0;
    });
  }, [rows, sort, columns]);

  const pages = Math.ceil(sorted.length / pageSize) || 1;
  const view = sorted.slice(page * pageSize, page * pageSize + pageSize);

  const toggleSort = (key, sortable) => {
    if (sortable === false) return;
    setSort(s => s && s.key === key ? (s.dir === 'asc' ? { key, dir: 'desc' } : null) : { key, dir: 'asc' });
  };

  if (rows.length === 0) {
    return React.createElement('div', { className: 'card table-card' }, React.createElement(EmptyState, { icon: 'SearchX', title: emptyTitleLabel, sub: emptySub }));
  }

  return React.createElement('div', { className: 'card table-card' },
    React.createElement('div', { className: 'table-scroll' },
      React.createElement('table', { className: 'data' },
        React.createElement('thead', null, React.createElement('tr', null,
          columns.map(c => React.createElement('th', { key: c.key, className: `${c.sortable === false ? 'no-sort' : ''} ${sort && sort.key === c.key ? 'sorted' : ''} ${c.hideSm ? 'hide-sm' : ''}`, style: { width: c.width, textAlign: c.align }, onClick: () => toggleSort(c.key, c.sortable) },
            React.createElement('span', { className: 'th-in' }, c.label,
              c.sortable !== false && React.createElement(Icon, { name: sort && sort.key === c.key ? (sort.dir === 'asc' ? 'ChevronUp' : 'ChevronDown') : 'ChevronsUpDown', size: 13, className: 'sort-ico' })))))),
        React.createElement('tbody', null,
          view.map((row, i) => React.createElement('tr', { key: row._id || i, 'data-testid': 'data-row' },
            columns.map(c => React.createElement('td', { key: c.key, className: c.hideSm ? 'hide-sm' : '', style: { textAlign: c.align } }, c.render ? c.render(row, page * pageSize + i) : row[c.key])))))
      )),
    React.createElement('div', { className: 'table-foot' },
      React.createElement('div', { className: 'info' }, t(`Showing ${page * pageSize + 1}–${Math.min((page + 1) * pageSize, sorted.length)} of ${sorted.length}`, `عرض ${page * pageSize + 1}–${Math.min((page + 1) * pageSize, sorted.length)} من ${sorted.length}`)),
      pages > 1 && React.createElement('div', { className: 'pager' },
        React.createElement('button', { onClick: () => setPage(p => Math.max(0, p - 1)), disabled: page === 0 }, React.createElement(Icon, { name: 'ChevronLeft', size: 15 })),
        Array.from({ length: pages }).map((_, i) => React.createElement('button', { key: i, className: i === page ? 'on' : '', onClick: () => setPage(i) }, i + 1)),
        React.createElement('button', { onClick: () => setPage(p => Math.min(pages - 1, p + 1)), disabled: page === pages - 1 }, React.createElement(Icon, { name: 'ChevronRight', size: 15 })))
    ));
}

/* ── Filter primitives ── */
export function SearchBox({ value, onChange, placeholder }) {
  const t = useT();
  return React.createElement('div', { className: 'search-box' },
    React.createElement(Icon, { name: 'Search', size: 16 }),
    React.createElement('input', { value, onChange: (e) => onChange(e.target.value), placeholder: placeholder || t('Search…', 'بحث…') }),
    value && React.createElement('button', { className: 'act-btn', style: { width: 22, height: 22 }, onClick: () => onChange('') }, React.createElement(Icon, { name: 'X', size: 13 })));
}
export function Select({ value, onChange, options, icon }) {
  return React.createElement('div', { className: 'select-wrap' },
    React.createElement('select', { className: 'select', value, onChange: (e) => onChange(e.target.value), style: { paddingLeft: icon ? 34 : undefined } },
      options.map(o => React.createElement('option', { key: o.value, value: o.value }, o.label))),
    React.createElement(Icon, { name: 'ChevronDown', size: 15, className: 'chev' }),
    icon && React.createElement(Icon, { name: icon, size: 15, style: { position: 'absolute', left: 11, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-3)', pointerEvents: 'none' } }));
}
