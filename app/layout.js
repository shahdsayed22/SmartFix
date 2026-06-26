import './globals.css';
import Shell from '@/components/sf/Shell';
import { LangProvider } from '@/components/sf/i18n';

export const metadata = {
  title: 'SmartFix Admin Dashboard',
  description: 'Monitor and manage the Egypt Maintenance Technicians Harvester dataset with real-time analytics.',
  manifest: '/manifest.json',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'black-translucent',
    title: 'SmartFix',
  },
};

export const viewport = {
  themeColor: '#0a0e1a',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
};

export default function RootLayout({ children }) {
  return (
    <html lang="ar" dir="rtl" data-theme="dark" suppressHydrationWarning>
      <head>
        <link rel="icon" href="/icon.svg" type="image/svg+xml" />
        <link rel="apple-touch-icon" href="/icon.svg" />
        <meta name="mobile-web-app-capable" content="yes" />
        <script
          dangerouslySetInnerHTML={{
            __html: `
              (function() {
                var t = localStorage.getItem('smartfix-theme') || 'dark';
                document.documentElement.setAttribute('data-theme', t);
                var l = localStorage.getItem('sf-lang') || 'ar';
                document.documentElement.setAttribute('lang', l);
                document.documentElement.setAttribute('dir', l === 'ar' ? 'rtl' : 'ltr');
              })();
            `,
          }}
        />
      </head>
      <body suppressHydrationWarning>
        <div className="app-bg" />
        <svg width="0" height="0" style={{ position: 'absolute' }} aria-hidden="true">
          <defs>
            <linearGradient id="halfstar" x1="0" y1="0" x2="1" y2="0">
              <stop offset="50%" stopColor="#f59e0b" />
              <stop offset="50%" stopColor="transparent" />
            </linearGradient>
          </defs>
        </svg>
        <LangProvider>
          <Shell>{children}</Shell>
        </LangProvider>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              if ('serviceWorker' in navigator) {
                window.addEventListener('load', () => {
                  navigator.serviceWorker.register('/sw.js');
                });
              }
            `,
          }}
        />
      </body>
    </html>
  );
}
