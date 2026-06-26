'use client';

/* ============================================================
   SmartFix — Connect Devices
   ------------------------------------------------------------
   Admin page that exposes one QR code per role. A phone that
   scans a QR lands on /launch?role=<role>, which deep-links to
   the SmartFix mobile app if installed, otherwise opens the
   installable web app (admin -> /, customer/technician -> the
   Flutter Web PWA). A "How to install" link opens /install.html.
   ============================================================ */
import React, { useEffect, useMemo, useState } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { Icon } from '@/components/sf/Icon';
import InstallPWA from '@/components/sf/InstallPWA';

const ROLES = [
  {
    id: 'customer',
    label: 'Customer',
    labelAr: 'العميل',
    icon: 'UserRound',
    grad: 'linear-gradient(135deg,#1C8C8C 0%,#14323B 100%)',
    desc: 'Book services, track technicians and pay securely.',
  },
  {
    id: 'technician',
    label: 'Technician',
    labelAr: 'الفني',
    icon: 'Wrench',
    grad: 'linear-gradient(135deg,#D98E2B 0%,#A86A18 100%)',
    desc: 'Receive jobs, navigate, and settle earnings.',
  },
  {
    id: 'admin',
    label: 'Admin',
    labelAr: 'الإدارة',
    icon: 'ShieldCheck',
    grad: 'linear-gradient(135deg,#6366f1 0%,#4338ca 100%)',
    desc: 'Open the operations console on any device.',
  },
];

export default function ConnectPage() {
  // The host the QR should point at. Defaults to the dashboard origin, but is
  // editable so an admin can paste a public/tunnel URL (e.g. ngrok) that a
  // phone on another network can actually reach.
  const [base, setBase] = useState('');
  const [copied, setCopied] = useState('');

  useEffect(() => {
    let origin = 'https://smartfix.app';
    try {
      origin = window.location.origin;
    } catch (_) {
      /* SSR / no window */
    }
    setBase(origin);

    // When the dashboard is opened on localhost, the QR codes would encode
    // localhost (not reachable from a phone). Swap to the machine's LAN IP so
    // the codes are scannable from any device on the same Wi-Fi.
    try {
      const h = window.location.hostname;
      if (h === 'localhost' || h === '127.0.0.1' || h === '::1') {
        fetch('/api/host')
          .then((r) => r.json())
          .then((d) => {
            const ip = d && Array.isArray(d.ips) ? d.ips[0] : '';
            if (ip) {
              const port = window.location.port ? `:${window.location.port}` : '';
              setBase(`${window.location.protocol}//${ip}${port}`);
            }
          })
          .catch(() => {});
      }
    } catch (_) {
      /* ignore */
    }
  }, []);

  const cleanBase = useMemo(() => base.replace(/\/+$/, ''), [base]);

  const linkFor = (role) => `${cleanBase}/launch?role=${role}`;

  const copy = async (role) => {
    try {
      await navigator.clipboard.writeText(linkFor(role));
      setCopied(role);
      setTimeout(() => setCopied(''), 1600);
    } catch (_) {
      /* clipboard unavailable */
    }
  };

  return (
    <div style={{ maxWidth: 1100, margin: '0 auto' }}>
      {/* Hero / how-it-works */}
      <div
        style={{
          display: 'flex',
          gap: 16,
          alignItems: 'center',
          flexWrap: 'wrap',
          padding: '20px 22px',
          marginBottom: 22,
          borderRadius: 'var(--radius-lg)',
          background: 'var(--surface)',
          border: '1px solid var(--border)',
          boxShadow: 'var(--shadow-md)',
        }}
      >
        <div
          style={{
            width: 54,
            height: 54,
            borderRadius: 14,
            display: 'grid',
            placeItems: 'center',
            background: 'linear-gradient(135deg,#1C8C8C 0%,#14323B 100%)',
            color: '#fff',
            flexShrink: 0,
          }}
        >
          <Icon name="QrCode" size={26} />
        </div>
        <div style={{ flex: 1, minWidth: 240 }}>
          <h2 style={{ margin: 0, fontSize: 18, color: 'var(--text)' }}>Open SmartFix on any phone</h2>
          <p style={{ margin: '4px 0 0', fontSize: 13.5, color: 'var(--text-muted, #94a3b8)' }}>
            Scan a QR with a phone camera. If the SmartFix app is installed it opens directly to the
            right role; otherwise the installable web app (PWA) launches — works on iOS &amp; Android.
          </p>
        </div>
        <div style={{ minWidth: 180, display: 'flex', flexDirection: 'column', gap: 8 }}>
          <InstallPWA label="Install dashboard app" tone="indigo" />
          <a
            href="/install.html"
            target="_blank"
            rel="noopener noreferrer"
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 8,
              padding: '9px 12px',
              borderRadius: 'var(--radius-sm)',
              border: '1px solid var(--border-strong)',
              background: 'var(--surface-hover)',
              color: 'var(--text)',
              fontSize: 12.5,
              fontWeight: 600,
              textDecoration: 'none',
            }}
          >
            <Icon name="BookOpen" size={14} />
            How to install (guide)
          </a>
        </div>
      </div>

      {/* Base URL control */}
      <label
        style={{
          display: 'flex',
          gap: 10,
          alignItems: 'center',
          padding: '10px 14px',
          marginBottom: 22,
          borderRadius: 'var(--radius)',
          background: 'var(--input-bg)',
          border: '1px solid var(--border)',
        }}
      >
        <Icon name="Link" size={15} />
        <span style={{ fontSize: 12.5, color: 'var(--text-faint)', whiteSpace: 'nowrap' }}>
          QR target host
        </span>
        <input
          value={base}
          onChange={(e) => setBase(e.target.value)}
          placeholder="https://your-public-host"
          style={{
            flex: 1,
            background: 'transparent',
            border: 'none',
            outline: 'none',
            color: 'var(--text)',
            fontSize: 13.5,
          }}
        />
      </label>

      {/* Role QR grid */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
          gap: 18,
        }}
      >
        {ROLES.map((r) => (
          <div
            key={r.id}
            style={{
              borderRadius: 'var(--radius-lg)',
              background: 'var(--surface)',
              border: '1px solid var(--border)',
              boxShadow: 'var(--shadow-md)',
              overflow: 'hidden',
              display: 'flex',
              flexDirection: 'column',
            }}
          >
            <div
              style={{
                background: r.grad,
                padding: '16px 18px',
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                color: '#fff',
              }}
            >
              <div
                style={{
                  width: 40,
                  height: 40,
                  borderRadius: 11,
                  background: 'rgba(255,255,255,0.18)',
                  display: 'grid',
                  placeItems: 'center',
                }}
              >
                <Icon name={r.icon} size={20} />
              </div>
              <div>
                <div style={{ fontSize: 15.5, fontWeight: 700 }}>{r.label}</div>
                <div style={{ fontSize: 12.5, opacity: 0.85 }} dir="rtl">
                  {r.labelAr}
                </div>
              </div>
            </div>

            <div style={{ padding: 18, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
              <div style={{ background: '#fff', padding: 12, borderRadius: 14, lineHeight: 0 }}>
                {cleanBase ? (
                  <QRCodeSVG
                    value={linkFor(r.id)}
                    size={168}
                    level="M"
                    bgColor="#ffffff"
                    fgColor="#14323B"
                    marginSize={0}
                  />
                ) : (
                  <div style={{ width: 168, height: 168 }} />
                )}
              </div>

              <p style={{ margin: 0, fontSize: 12.5, color: 'var(--text-faint)', textAlign: 'center' }}>
                {r.desc}
              </p>

              <button
                onClick={() => copy(r.id)}
                style={{
                  width: '100%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 8,
                  padding: '9px 12px',
                  borderRadius: 'var(--radius-sm)',
                  border: '1px solid var(--border-strong)',
                  background: 'var(--surface-hover)',
                  color: 'var(--text)',
                  fontSize: 12.5,
                  cursor: 'pointer',
                }}
              >
                <Icon name={copied === r.id ? 'Check' : 'Copy'} size={14} />
                {copied === r.id ? 'Link copied' : 'Copy link'}
              </button>

              <a
                href={linkFor(r.id)}
                target="_blank"
                rel="noopener noreferrer"
                style={{ fontSize: 11.5, color: 'var(--accent-light)', textDecoration: 'none', wordBreak: 'break-all', textAlign: 'center' }}
              >
                {linkFor(r.id)}
              </a>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
