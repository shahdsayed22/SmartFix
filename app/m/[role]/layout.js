/* Consumer PWA shell for the QR web app (/m/customer, /m/technician).
   Overrides the root (admin) manifest so these routes install as the
   "SmartFix" consumer app on iOS (Add to Home Screen) and Android (Install). */
export const metadata = {
  title: 'SmartFix — صيانة منزلية',
  manifest: '/app.webmanifest',
  appleWebApp: {
    capable: true,
    title: 'SmartFix',
    statusBarStyle: 'black-translucent',
  },
  formatDetection: { telephone: false },
};

export const viewport = {
  themeColor: '#14323B',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: 'cover',
};

export default function RoleLayout({ children }) {
  return children;
}
