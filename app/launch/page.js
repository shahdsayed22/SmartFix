'use client';

/* ============================================================
   SmartFix — Smart launch landing (public, standalone)
   ------------------------------------------------------------
   Reached by scanning a QR from the dashboard /connect page.
   1. Reads ?role=customer|technician|admin.
   2. On a phone, tries to open the native app via the
      smartfix:// deep link.
   3. If the app does not take over within a short window (not
      installed) it reveals fallbacks: open the installable Flutter
      Web PWA at <host>:<webport>/?role= for ALL roles incl. admin
      (default 8090, override with ?webport=) — or get the app from
      the stores.
   ============================================================ */
import React, { Suspense, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';

const ROLES = {
  customer: { label: 'العميل', en: 'Customer', grad: 'linear-gradient(135deg,#1C8C8C 0%,#14323B 100%)' },
  technician: { label: 'الفني', en: 'Technician', grad: 'linear-gradient(135deg,#D98E2B 0%,#A86A18 100%)' },
  admin: { label: 'الإدارة', en: 'Admin', grad: 'linear-gradient(135deg,#6366f1 0%,#4338ca 100%)' },
};

function platform() {
  if (typeof navigator === 'undefined') return 'web';
  const ua = navigator.userAgent || '';
  if (/android/i.test(ua)) return 'android';
  if (/iphone|ipad|ipod/i.test(ua)) return 'ios';
  return 'web';
}

function LaunchInner() {
  const params = useSearchParams();
  const roleParam = (params.get('role') || 'customer').toLowerCase();
  const role = ROLES[roleParam] ? roleParam : 'customer';
  const meta = ROLES[role];

  // This standalone page lives outside the dashboard i18n provider, so it
  // carries its own tiny bilingual helper. Language comes from ?lang= (set by
  // the QR hub); otherwise we fall back to the browser language. Initial render
  // uses the param only (deterministic) to avoid a hydration mismatch.
  const [lang, setLang] = useState(
    (params.get('lang') || '').toLowerCase() === 'en' ? 'en' : 'ar',
  );
  const t = (en, ar) => (lang === 'en' ? en : ar);
  const roleLabel = lang === 'en' ? meta.en : meta.label;

  const [os, setOs] = useState('web');
  const [showFallback, setShowFallback] = useState(false);
  const [webHref, setWebHref] = useState('/install.html');
  // Flutter Web PWA port (see scripts/wireup.sh — default 8090). Overridable
  // via ?webport= so the QR hub can match an auto-picked port.
  const webPort = params.get('webport') || '8090';

  useEffect(() => {
    const p = platform();
    setOs(p);

    // Refine language: explicit ?lang= wins; otherwise fall back to the
    // browser language (post-hydration, so it can't cause a mismatch).
    const q = (params.get('lang') || '').toLowerCase();
    if (q === 'en' || q === 'ar') setLang(q);
    else if (typeof navigator !== 'undefined' && /^en/i.test(navigator.language || '')) setLang('en');

    // Resolve the web fallback target for this role on the serving host.
    // All roles (incl. admin) open the installable Flutter Web PWA.
    // Local dev: the PWA is served on a separate port (default 8090).
    // Deployed (e.g. Vercel): the PWA is same-origin under /app over HTTPS.
    const host = window.location.hostname;
    const isLocal =
      host === 'localhost' ||
      host === '127.0.0.1' ||
      /^\d{1,3}(\.\d{1,3}){3}$/.test(host);
    setWebHref(
      isLocal
        ? `http://${host}:${webPort}/?role=${role}`
        : `${window.location.origin}/app/?role=${role}`,
    );

    // Desktop never has the app — go straight to fallback.
    if (p === 'web') {
      setShowFallback(true);
      return;
    }

    // Try the native app; reveal fallback if it doesn't take over.
    const deepLink = `smartfix://launch?role=${role}`;
    const timer = setTimeout(() => setShowFallback(true), 1600);
    try {
      window.location.href = deepLink;
    } catch (_) {
      setShowFallback(true);
    }

    const onHide = () => clearTimeout(timer); // app opened → page hidden
    document.addEventListener('visibilitychange', onHide);
    return () => {
      clearTimeout(timer);
      document.removeEventListener('visibilitychange', onHide);
    };
  }, [role, webPort, params]);

  const storeHref =
    os === 'ios'
      ? 'https://apps.apple.com/app/smartfix'
      : 'https://play.google.com/store/apps/details?id=com.smartfix.app';

  return (
    <div className="sf-launch" dir={lang === 'en' ? 'ltr' : 'rtl'}>
      <div className="sf-card">
        <div className="sf-logo" style={{ background: meta.grad }}>
          <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" />
          </svg>
        </div>

        <h1 className="sf-title">SmartFix</h1>
        <p className="sf-sub">
          {t('Opening the app as', 'جارٍ فتح التطبيق بصفتك')} <b>{roleLabel}</b>
        </p>

        {!showFallback ? (
          <div className="sf-spin-wrap">
            <div className="sf-spin" />
            <span>{t('One moment…', 'لحظات…')}</span>
          </div>
        ) : (
          <div className="sf-actions">
            <a className="sf-btn sf-btn-primary" href={webHref}>
              {t('Continue in the browser', 'المتابعة عبر المتصفح')}
              <span className="sf-btn-sub">{t('Open the responsive web version now', 'افتح نسخة الويب المتجاوبة فوراً')}</span>
            </a>
            {os !== 'web' && (
              <a className="sf-btn sf-btn-ghost" href={storeHref} target="_blank" rel="noopener noreferrer">
                {os === 'ios' ? t('Download from App Store', 'تحميل من App Store') : t('Download from Google Play', 'تحميل من Google Play')}
              </a>
            )}
            <button
              className="sf-btn sf-btn-text"
              onClick={() => {
                setShowFallback(false);
                window.location.href = `smartfix://launch?role=${role}`;
                setTimeout(() => setShowFallback(true), 1600);
              }}
            >
              {t('I have the app — open it', 'لديّ التطبيق — افتحه')}
            </button>
          </div>
        )}

        <p className="sf-foot">
          {t('The trusted home-maintenance services platform', 'منصّة خدمات الصيانة المنزلية الموثوقة')} — {roleLabel}
        </p>
      </div>

      <style jsx global>{`
        html, body { margin: 0; background: #0b1117; }
        .sf-launch {
          min-height: 100vh;
          display: grid;
          place-items: center;
          padding: 22px;
          font-family: -apple-system, "Segoe UI", Tahoma, sans-serif;
          background:
            radial-gradient(1100px 520px at 50% -10%, rgba(28,140,140,0.22), transparent 70%),
            #0b1117;
        }
        .sf-card {
          width: 100%;
          max-width: 380px;
          background: rgba(255,255,255,0.04);
          border: 1px solid rgba(255,255,255,0.09);
          border-radius: 26px;
          padding: 34px 24px 26px;
          text-align: center;
          box-shadow: 0 30px 80px -30px rgba(0,0,0,0.8);
          backdrop-filter: blur(8px);
        }
        .sf-logo {
          width: 72px; height: 72px; border-radius: 22px;
          margin: 0 auto 16px; display: grid; place-items: center;
          box-shadow: 0 14px 30px -10px rgba(0,0,0,0.6);
        }
        .sf-title { color: #fff; font-size: 26px; margin: 0; font-weight: 800; letter-spacing: 0.3px; }
        .sf-sub { color: #9fb2bb; font-size: 14.5px; margin: 8px 0 22px; }
        .sf-sub b { color: #e9f3f3; }
        .sf-spin-wrap { display: flex; flex-direction: column; align-items: center; gap: 12px; color: #7e919a; font-size: 13px; padding: 8px 0 12px; }
        .sf-spin {
          width: 34px; height: 34px; border-radius: 50%;
          border: 3px solid rgba(255,255,255,0.12);
          border-top-color: #1C8C8C; animation: sf-rot 0.8s linear infinite;
        }
        @keyframes sf-rot { to { transform: rotate(360deg); } }
        .sf-actions { display: flex; flex-direction: column; gap: 11px; margin-top: 4px; }
        .sf-btn {
          display: flex; flex-direction: column; gap: 2px; align-items: center;
          padding: 13px 16px; border-radius: 15px; font-size: 15px; font-weight: 700;
          text-decoration: none; cursor: pointer; border: none; font-family: inherit;
        }
        .sf-btn-sub { font-size: 11.5px; font-weight: 500; opacity: 0.8; }
        .sf-btn-primary { background: linear-gradient(135deg,#1C8C8C 0%,#14323B 100%); color: #fff; }
        .sf-btn-ghost { background: rgba(255,255,255,0.06); color: #e9f3f3; border: 1px solid rgba(255,255,255,0.12); }
        .sf-btn-text { background: transparent; color: #7fd4cf; font-size: 13px; font-weight: 600; }
        .sf-foot { color: #5d6f78; font-size: 11.5px; margin: 20px 0 0; }
      `}</style>
    </div>
  );
}

export default function LaunchPage() {
  return (
    <Suspense fallback={<div style={{ minHeight: '100vh', background: '#0b1117' }} />}>
      <LaunchInner />
    </Suspense>
  );
}
