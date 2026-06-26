'use client';

import { useState, useEffect } from 'react';
import { usePathname } from 'next/navigation';
import Link from 'next/link';
import { useTheme } from './ThemeProvider';
import {
  LayoutDashboard,
  Users,
  ShieldCheck,
  Star,
  Activity,
  Wrench,
  AlertTriangle,
  UserCircle,
  Menu,
  X,
  Sun,
  Moon,
  ChevronsLeft,
  ChevronsRight,
} from 'lucide-react';

const navItems = [
  { href: '/', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/issues', label: 'Issues', icon: AlertTriangle },
  { href: '/technicians', label: 'Technicians', icon: Users },
  { href: '/users', label: 'Users', icon: UserCircle },
  { href: '/verified', label: 'Verified Profiles', icon: ShieldCheck },
  { href: '/ratings', label: 'Ratings', icon: Star },
  { href: '/health', label: 'System Health', icon: Activity },
];

export default function Sidebar() {
  const pathname = usePathname();
  const { theme, toggleTheme } = useTheme();
  const [isOpen, setIsOpen] = useState(false);
  const [collapsed, setCollapsed] = useState(false);

  // Load collapsed state from localStorage
  useEffect(() => {
    const saved = localStorage.getItem('smartfix-sidebar-collapsed');
    if (saved === 'true') setCollapsed(true);
  }, []);

  // Close mobile sidebar on route change
  useEffect(() => {
    setIsOpen(false);
  }, [pathname]);

  // Prevent body scroll when mobile sidebar is open
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => { document.body.style.overflow = ''; };
  }, [isOpen]);

  // Update CSS variable and save preference
  useEffect(() => {
    document.documentElement.setAttribute('data-sidebar', collapsed ? 'collapsed' : 'expanded');
    localStorage.setItem('smartfix-sidebar-collapsed', collapsed.toString());
  }, [collapsed]);

  return (
    <>
      {/* Hamburger toggle — visible only on mobile/tablet */}
      <button
        className="menu-toggle"
        onClick={() => setIsOpen(!isOpen)}
        aria-label={isOpen ? 'Close menu' : 'Open menu'}
      >
        {isOpen ? <X size={22} /> : <Menu size={22} />}
      </button>

      {/* Overlay */}
      {isOpen && (
        <div
          className="sidebar-overlay"
          onClick={() => setIsOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside className={`sidebar ${isOpen ? 'sidebar-open' : ''} ${collapsed ? 'sidebar-collapsed' : ''}`}>
        <div className="sidebar-brand">
          <div className="brand-icon">
            <Wrench size={24} />
          </div>
          <div className="brand-text">
            <h1 className="brand-name">SmartFix</h1>
            <span className="brand-sub">Admin Dashboard</span>
          </div>
        </div>

        {/* Collapse toggle button */}
        <button
          className="collapse-btn"
          onClick={() => setCollapsed(!collapsed)}
          aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {collapsed ? <ChevronsRight size={16} /> : <ChevronsLeft size={16} />}
        </button>

        <nav className="sidebar-nav">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`nav-item ${isActive ? 'active' : ''}`}
                title={collapsed ? item.label : ''}
              >
                <Icon size={20} />
                <span className="nav-label">{item.label}</span>
                {isActive && <div className="nav-indicator" />}
              </Link>
            );
          })}
        </nav>

        <div className="sidebar-footer">
          <button className="theme-toggle-btn" onClick={toggleTheme} aria-label="Toggle theme">
            {theme === 'dark' ? <Sun size={16} /> : <Moon size={16} />}
            <span className="nav-label">{theme === 'dark' ? 'Light Mode' : 'Dark Mode'}</span>
          </button>
          <div className="sidebar-info">
            <div className="pulse green" />
            <span className="nav-label">System Online</span>
          </div>
          <div className="sidebar-version nav-label">v2.0 — Egypt Region</div>
        </div>
      </aside>
    </>
  );
}
