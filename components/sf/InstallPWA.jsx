'use client';

/* ============================================================
   InstallPWA — cross-platform "install this app" affordance.
   - Android/desktop Chrome: captures beforeinstallprompt and
     shows a one-tap Install button.
   - iOS Safari: no prompt API, so shows an "Add to Home Screen"
     hint (Share → Add to Home Screen).
   - Hidden when already running installed (standalone).
   ============================================================ */
import React, { useEffect, useState } from 'react';

function isStandalone() {
  if (typeof window === 'undefined') return false;
  return (
    window.matchMedia?.('(display-mode: standalone)').matches ||
    window.navigator.standalone === true
  );
}
function isIOS() {
  if (typeof navigator === 'undefined') return false;
  return /iphone|ipad|ipod/i.test(navigator.userAgent || '');
}

export default function InstallPWA({ label = 'تثبيت التطبيق', tone = 'teal' }) {
  const [deferred, setDeferred] = useState(null);
  const [installed, setInstalled] = useState(true); // assume hidden until mounted
  const [iosHint, setIosHint] = useState(false);

  useEffect(() => {
    if (isStandalone()) {
      setInstalled(true);
      return;
    }
    setInstalled(false);

    const onPrompt = (e) => {
      e.preventDefault();
      setDeferred(e);
    };
    const onInstalled = () => setInstalled(true);
    window.addEventListener('beforeinstallprompt', onPrompt);
    window.addEventListener('appinstalled', onInstalled);
    return () => {
      window.removeEventListener('beforeinstallprompt', onPrompt);
      window.removeEventListener('appinstalled', onInstalled);
    };
  }, []);

  if (installed) return null;

  const grad =
    tone === 'teal'
      ? 'linear-gradient(135deg,#1C8C8C 0%,#14323B 100%)'
      : 'linear-gradient(135deg,#6366f1 0%,#4338ca 100%)';

  const onClick = async () => {
    if (deferred) {
      deferred.prompt();
      try {
        await deferred.userChoice;
      } catch (_) {
        /* dismissed */
      }
      setDeferred(null);
    } else if (isIOS()) {
      setIosHint((v) => !v);
    }
  };

  // On Android we have a real prompt; on iOS we show a hint; otherwise hide.
  if (!deferred && !isIOS()) return null;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8, alignItems: 'stretch' }}>
      <button
        onClick={onClick}
        dir="rtl"
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 8,
          width: '100%',
          padding: '12px 16px',
          borderRadius: 14,
          border: 'none',
          cursor: 'pointer',
          background: grad,
          color: '#fff',
          fontSize: 14.5,
          fontWeight: 700,
          fontFamily: 'inherit',
        }}
      >
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M12 3v12" /><path d="m7 12 5 5 5-5" /><path d="M5 21h14" />
        </svg>
        {label}
      </button>
      {iosHint && (
        <div
          dir="rtl"
          style={{
            fontSize: 12.5,
            lineHeight: 1.7,
            color: '#c7d3d7',
            background: 'rgba(255,255,255,0.06)',
            border: '1px solid rgba(255,255,255,0.12)',
            borderRadius: 12,
            padding: '10px 12px',
          }}
        >
          لإضافة سمارت فيكس إلى شاشتك الرئيسية على iPhone: اضغط زر المشاركة <b>⬆️</b> في Safari ثم اختر
          <b> «إضافة إلى الشاشة الرئيسية»</b>.
        </div>
      )}
    </div>
  );
}
