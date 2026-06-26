'use client';
/* ============================================================
   SmartFix — App shell: sidebar, topbar, theme (Next.js port)
   ============================================================ */
import React, { useState, useEffect } from 'react';
import { usePathname } from 'next/navigation';
import Link from 'next/link';
import { Icon } from './Icon';
import { SF } from './data';
import { useT, useLang } from './i18n';

const NAV = [
  { id: 'dashboard', href: '/', label: 'Dashboard', ar: 'لوحة التحكم', icon: 'LayoutDashboard', section: 'Operations' },
  { id: 'issues', href: '/issues', label: 'Issues', ar: 'البلاغات', icon: 'TriangleAlert', count: SF.ANALYTICS.issueStats.active, section: 'Operations' },
  { id: 'technicians', href: '/technicians', label: 'Technicians', ar: 'الفنيون', icon: 'Users', count: SF.TECHNICIANS.length, section: 'Operations' },
  { id: 'users', href: '/users', label: 'Users', ar: 'المستخدمون', icon: 'UserRound', count: SF.USERS.length, section: 'Operations' },
  { id: 'tickets', href: '/tickets', label: 'Tickets', ar: 'التذاكر', icon: 'LifeBuoy', section: 'Operations' },
  { id: 'payments', href: '/payments', label: 'Payments', ar: 'المدفوعات', icon: 'CreditCard', section: 'Commerce' },
  { id: 'settings', href: '/settings', label: 'Commission Settings', ar: 'إعدادات العمولة', icon: 'Settings', section: 'Commerce' },
  { id: 'categories', href: '/categories', label: 'Categories', ar: 'الفئات', icon: 'LayoutGrid', section: 'Commerce' },
  { id: 'ai', href: '/ai-insights', label: 'AI Insights', ar: 'رؤى الذكاء الاصطناعي', icon: 'BrainCircuit', section: 'Intelligence' },
  { id: 'verified', href: '/verified', label: 'Verified Profiles', ar: 'الحسابات الموثّقة', icon: 'ShieldCheck', section: 'Quality' },
  { id: 'ratings', href: '/ratings', label: 'Ratings', ar: 'التقييمات', icon: 'Star', section: 'Quality' },
  { id: 'health', href: '/health', label: 'System Health', ar: 'حالة النظام', icon: 'Activity', section: 'Quality' },
  { id: 'connect', href: '/connect', label: 'Connect Devices', ar: 'ربط الأجهزة', icon: 'QrCode', section: 'Platform' },
  { id: 'install', href: '/install.html', label: 'Install Guide', ar: 'دليل التثبيت', icon: 'BookOpen', section: 'Platform', external: true },
];

const SECTION_AR = {
  Operations: 'العمليات',
  Commerce: 'التجارة',
  Intelligence: 'الذكاء',
  Quality: 'الجودة',
  Platform: 'المنصة',
};

// Public, standalone routes that must render WITHOUT the admin chrome
// (mobile-facing QR launch + responsive role web apps).
const STANDALONE = ['/launch', '/m/', '/m'];
function isStandalone(pathname) {
  return STANDALONE.some((p) => pathname === p || pathname.startsWith('/m/') || pathname.startsWith('/launch'));
}

const PAGE_META = {
  '/': { title: 'Dashboard Overview', subtitle: 'Real-time analytics across the SmartFix platform', titleAr: 'نظرة عامة', subAr: 'تحليلات لحظية عبر منصة سمارت فيكس' },
  '/issues': { title: 'Issues Management', subtitle: 'Track, assign and resolve maintenance requests', titleAr: 'إدارة البلاغات', subAr: 'تتبّع وإسناد وحل طلبات الصيانة' },
  '/technicians': { title: 'Technician Management', subtitle: 'Manage your field workforce across Egypt', titleAr: 'إدارة الفنيين', subAr: 'أدر فريقك الميداني في جميع أنحاء مصر' },
  '/users': { title: 'Users Management', subtitle: 'Customers and workers on the SmartFix platform', titleAr: 'إدارة المستخدمين', subAr: 'العملاء والفنيون على منصة سمارت فيكس' },
  '/tickets': { title: 'Support Tickets', subtitle: 'Resolve customer and technician support requests', titleAr: 'تذاكر الدعم', subAr: 'حل طلبات دعم العملاء والفنيين' },
  '/payments': { title: 'Payments', subtitle: 'Transactions, commissions and payout settlement', titleAr: 'المدفوعات', subAr: 'المعاملات والعمولات وتسوية المستحقات' },
  '/settings': { title: 'Commission Settings', subtitle: 'Configure platform commission and payout rules', titleAr: 'إعدادات العمولة', subAr: 'اضبط عمولة المنصة وقواعد المستحقات' },
  '/categories': { title: 'Service Categories', subtitle: 'Manage the service taxonomy across the platform', titleAr: 'فئات الخدمات', subAr: 'أدر تصنيف الخدمات عبر المنصة' },
  '/verified': { title: 'Verified Profiles', subtitle: 'Review and manage technician verification', titleAr: 'الحسابات الموثّقة', subAr: 'مراجعة وإدارة توثيق الفنيين' },
  '/ratings': { title: 'Ratings Management', subtitle: 'Transparent quality scoring across the network', titleAr: 'إدارة التقييمات', subAr: 'تقييم شفّاف للجودة عبر الشبكة' },
  '/health': { title: 'System Health', subtitle: 'Live infrastructure and AI-engine monitoring', titleAr: 'حالة النظام', subAr: 'مراقبة مباشرة للبنية ومحرّك الذكاء الاصطناعي' },
  '/ai-insights': { title: 'AI Insights', subtitle: 'Anomaly-detection research models powering SmartFix', titleAr: 'رؤى الذكاء الاصطناعي', subAr: 'نماذج بحثية لكشف الحالات الشاذة تشغّل سمارت فيكس' },
  '/connect': { title: 'Connect Devices', subtitle: 'Scan a QR to open SmartFix as customer, technician or admin', titleAr: 'ربط الأجهزة', subAr: 'امسح رمز QR لفتح سمارت فيكس كعميل أو فني أو مدير' },
};

function isActive(pathname, href) {
  if (href === '/') return pathname === '/';
  return pathname === href || pathname.startsWith(href + '/');
}

function Sidebar({ pathname, collapsed, setCollapsed, mobileOpen, setMobileOpen }) {
  const t = useT();
  const navLink = (item) => {
    const active = isActive(pathname, item.href);
    const label = t(item.label, item.ar);
    const children = [
      React.createElement(Icon, { key: 'ic', name: item.icon, size: 19 }),
      React.createElement('span', { key: 'lb', className: 'nav-label' }, label),
      item.count != null ? React.createElement('span', { key: 'ct', className: 'nav-count tnum' }, item.count) : null,
    ];
    // Static/external targets (e.g. the /install.html guide) open in a new tab
    // via a plain anchor — the Next <Link> router would 404 on a non-route path.
    if (item.external) {
      return React.createElement('a', { key: item.id, href: item.href, target: '_blank', rel: 'noopener noreferrer', className: 'nav-item', title: collapsed ? label : '' }, children);
    }
    return React.createElement(Link, { key: item.id, href: item.href, className: `nav-item ${active ? 'active' : ''}`, onClick: () => setMobileOpen(false), title: collapsed ? label : '' }, children);
  };

  return React.createElement(React.Fragment, null,
    React.createElement('div', { className: `sidebar-scrim ${mobileOpen ? 'show' : ''}`, onClick: () => setMobileOpen(false) }),
    React.createElement('aside', { className: `sidebar ${mobileOpen ? 'open' : ''}` },
      React.createElement('div', { className: 'sidebar-brand' },
        React.createElement('div', { className: 'brand-mark' }, React.createElement(Icon, { name: 'Wrench', size: 22, strokeWidth: 2.4 })),
        React.createElement('div', { className: 'brand-text' },
          React.createElement('div', { className: 'brand-name' }, 'Smart', React.createElement('span', null, 'Fix')),
          React.createElement('div', { className: 'brand-sub' }, t('Ops Command', 'مركز العمليات'))),
        React.createElement('button', { className: 'collapse-btn', onClick: () => setCollapsed(c => !c), title: collapsed ? 'Expand' : 'Collapse' },
          React.createElement(Icon, { name: collapsed ? 'ChevronsRight' : 'ChevronsLeft', size: 15 }))),

      React.createElement('nav', { className: 'sidebar-nav' },
        NAV.map((item, idx) => {
          const newSection = idx === 0 || NAV[idx - 1].section !== item.section;
          if (newSection) return React.createElement(React.Fragment, { key: item.id },
            React.createElement('div', { className: 'nav-section-label', style: idx === 0 ? undefined : { marginTop: 6 } }, t(item.section, SECTION_AR[item.section])),
            navLink(item));
          return navLink(item);
        })),

      React.createElement('div', { className: 'sidebar-footer' },
        React.createElement('div', { className: 'sidebar-meta' },
          React.createElement('span', { className: 'pulse' }),
          React.createElement('span', { className: 'nav-label' }, t('All systems online', 'كل الأنظمة تعمل'))),
        React.createElement('div', { className: 'sidebar-version' }, 'v2.4 · Egypt Region'))
    ));
}

// Reflects real API reachability. Starts optimistic ("online") so the chip
// doesn't flash a warning before the first request, then flips on the
// `sf:netstatus` event that fetchWithTimeout broadcasts on success/failure,
// plus the browser's own online/offline events.
function useNetStatus() {
  const [online, setOnline] = useState(true);
  useEffect(() => {
    const onStatus = (e) => { if (e && e.detail) setOnline(!!e.detail.online); };
    const onOffline = () => setOnline(false);
    const onOnline = () => setOnline(true);
    window.addEventListener('sf:netstatus', onStatus);
    window.addEventListener('offline', onOffline);
    window.addEventListener('online', onOnline);
    return () => {
      window.removeEventListener('sf:netstatus', onStatus);
      window.removeEventListener('offline', onOffline);
      window.removeEventListener('online', onOnline);
    };
  }, []);
  return online;
}

function Topbar({ page, theme, setTheme, onMenu }) {
  const t = useT();
  const { lang, toggle } = useLang();
  const online = useNetStatus();
  return React.createElement('header', { className: 'topbar' },
    React.createElement('button', { className: 'menu-toggle', onClick: onMenu }, React.createElement(Icon, { name: 'Menu', size: 20 })),
    React.createElement('div', { className: 'topbar-title' },
      React.createElement('h1', null, t(page.title, page.titleAr)),
      React.createElement('p', null, t(page.subtitle, page.subAr))),
    React.createElement('div', { className: 'topbar-spacer' }),
    React.createElement('div', { className: 'topbar-actions' },
      React.createElement('label', { className: 'global-search' },
        React.createElement(Icon, { name: 'Search', size: 16 }),
        React.createElement('input', { placeholder: t('Search issues, techs, users…', 'ابحث عن بلاغات، فنيين، مستخدمين…') })),
      React.createElement('div', {
        className: 'online-chip',
        style: online ? undefined : { background: 'rgba(239,68,68,.12)', color: '#ef4444', borderColor: 'rgba(239,68,68,.35)' },
      },
        React.createElement('span', { className: 'pulse', style: online ? undefined : { background: '#ef4444' } }),
        online ? t('System Online', 'النظام متصل') : t('Connection Issue', 'مشكلة في الاتصال')),
      React.createElement('button', { className: 'icon-btn lang-toggle', onClick: toggle, title: t('Switch language', 'تبديل اللغة'), style: { fontWeight: 700, fontSize: 13 } },
        lang === 'ar' ? 'EN' : 'ع'),
      React.createElement('button', { className: 'icon-btn', onClick: () => setTheme(th => th === 'dark' ? 'light' : 'dark'), title: t('Toggle theme', 'تبديل السمة') },
        React.createElement(Icon, { name: theme === 'dark' ? 'Sun' : 'Moon', size: 18 })),
      React.createElement('button', { className: 'icon-btn', title: t('Notifications', 'الإشعارات') }, React.createElement(Icon, { name: 'Bell', size: 18 }), React.createElement('span', { className: 'dot' })),
      React.createElement('div', { className: 'admin-chip' },
        React.createElement('div', { style: { textAlign: lang === 'ar' ? 'left' : 'right' } },
          React.createElement('div', { className: 'who' }, t('Admin', 'المدير')),
          React.createElement('div', { className: 'role' }, t('Operations', 'العمليات'))),
        React.createElement('div', { className: 'avatar' }, t('AD', 'إد'))
    )));
}

export default function Shell({ children }) {
  const pathname = usePathname();
  // Deterministic initial state for SSR safety; sync real values after mount.
  const [theme, setTheme] = useState('dark');
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const t = localStorage.getItem('smartfix-theme') || 'dark';
    setTheme(t);
    setCollapsed(localStorage.getItem('sf-collapsed') === 'true');
  }, []);

  useEffect(() => { document.documentElement.setAttribute('data-theme', theme); localStorage.setItem('smartfix-theme', theme); }, [theme]);
  useEffect(() => { localStorage.setItem('sf-collapsed', String(collapsed)); }, [collapsed]);
  useEffect(() => { setMobileOpen(false); window.scrollTo(0, 0); }, [pathname]);

  const page = PAGE_META[pathname] || PAGE_META['/'];

  // Public mobile-facing routes render bare (no sidebar/topbar).
  if (isStandalone(pathname)) {
    return React.createElement(React.Fragment, null, children);
  }

  return React.createElement('div', { className: 'app', 'data-collapsed': String(collapsed) },
    React.createElement(Sidebar, { pathname, collapsed, setCollapsed, mobileOpen, setMobileOpen }),
    React.createElement('div', { className: 'main' },
      React.createElement(Topbar, { page, theme, setTheme, onMenu: () => setMobileOpen(true) }),
      React.createElement('main', { className: 'content' }, children))
  );
}
