'use client';

/* ============================================================
   SmartFix — Responsive web app (public, standalone)
   ------------------------------------------------------------
   The in-browser experience a phone lands on when the native
   app isn't installed. One branded, RTL, mobile-first shell
   per role:
     /m/customer    → customer quick-actions home
     /m/technician  → technician quick-actions home
     /m/admin       → redirect to the operations dashboard
   ============================================================ */
import React, { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import InstallPWA from '@/components/sf/InstallPWA';

const CATEGORIES = [
  { id: 'hvac', ar: 'تكييف وتبريد', icon: '❄️', color: '#189FB6' },
  { id: 'plumbing', ar: 'سباكة', icon: '🚰', color: '#1E6FD9' },
  { id: 'electrical', ar: 'كهرباء', icon: '💡', color: '#EBA110' },
  { id: 'carpentry', ar: 'نجارة', icon: '🪚', color: '#8A5A3B' },
  { id: 'appliance_repair', ar: 'أجهزة منزلية', icon: '🔌', color: '#F2700B' },
  { id: 'cleaning', ar: 'تنظيف', icon: '🧽', color: '#DE3F7C' },
  { id: 'painting', ar: 'دهانات', icon: '🎨', color: '#8E44C4' },
  { id: 'welding', ar: 'لحام', icon: '🔧', color: '#D23A2A' },
  { id: 'tiling', ar: 'بلاط وسيراميك', icon: '🧱', color: '#0E9C8C' },
];

const CUSTOMER_ACTIONS = [
  { ar: 'اطلب خدمة جديدة', sub: 'صف مشكلتك وسنرسل أقرب فني', icon: '🛠️' },
  { ar: 'تتبّع طلباتي', sub: 'تابع موقع الفني والحالة لحظياً', icon: '📍' },
  { ar: 'محفظتي والفواتير', sub: 'مدفوعاتك وسجلّ معاملاتك', icon: '💳' },
  { ar: 'العروض والخصومات', sub: 'أكواد خصم وباقات الصيانة', icon: '🎁' },
];

const TECH_ACTIONS = [
  { ar: 'الوظائف المتاحة', sub: 'استقبل المهام القريبة من تخصصك', icon: '📋' },
  { ar: 'أرباحي والمحفظة', sub: 'العمولة والمستحقات والتسوية', icon: '💰' },
  { ar: 'حالة التوفّر', sub: 'فعّل أو أوقف استقبال الطلبات', icon: '🟢' },
  { ar: 'تقييماتي', sub: 'متوسط تقييمك وملاحظات العملاء', icon: '⭐' },
];

const ROLE_META = {
  customer: { label: 'العميل', grad: 'linear-gradient(135deg,#1C8C8C 0%,#14323B 100%)', actions: CUSTOMER_ACTIONS, showCats: true },
  technician: { label: 'الفني', grad: 'linear-gradient(135deg,#D98E2B 0%,#A86A18 100%)', actions: TECH_ACTIONS, showCats: false },
};

export default function RoleWebApp() {
  const params = useParams();
  const router = useRouter();
  const role = String(params?.role || 'customer').toLowerCase();
  const [toast, setToast] = useState('');

  useEffect(() => {
    if (role === 'admin') router.replace('/');
  }, [role, router]);

  if (role === 'admin') {
    return <div style={{ minHeight: '100vh', background: '#0b1117' }} />;
  }

  const meta = ROLE_META[role] || ROLE_META.customer;

  const ping = (label) => {
    setToast(label + ' — متاحة في تطبيق سمارت فيكس');
    setTimeout(() => setToast(''), 2200);
  };

  return (
    <div className="m-app" dir="rtl">
      <header className="m-head" style={{ background: meta.grad }}>
        <div className="m-head-row">
          <div className="m-brand">
            <span className="m-mark">🛠️</span>
            <div>
              <div className="m-brand-name">SmartFix</div>
              <div className="m-brand-sub">نسخة الويب · {meta.label}</div>
            </div>
          </div>
          <a className="m-getapp" href={`/launch?role=${role}`}>التطبيق</a>
        </div>
        <h1 className="m-hello">أهلاً بك في سمارت فيكس</h1>
        <p className="m-hello-sub">منصّة خدمات الصيانة المنزلية الموثوقة — تجربة متجاوبة على أي جهاز.</p>
      </header>

      <main className="m-main">
        <div style={{ marginBottom: 14 }}>
          <InstallPWA label="ثبّت تطبيق سمارت فيكس" tone="teal" />
        </div>
        <section className="m-actions">
          {meta.actions.map((a) => (
            <button key={a.ar} className="m-action" onClick={() => ping(a.ar)}>
              <span className="m-action-ic">{a.icon}</span>
              <span className="m-action-tx">
                <span className="m-action-t">{a.ar}</span>
                <span className="m-action-s">{a.sub}</span>
              </span>
              <span className="m-chev">‹</span>
            </button>
          ))}
        </section>

        {meta.showCats && (
          <section>
            <h2 className="m-sec">فئات الخدمات</h2>
            <div className="m-cats">
              {CATEGORIES.map((c) => (
                <button key={c.id} className="m-cat" onClick={() => ping(c.ar)}>
                  <span className="m-cat-ic" style={{ background: c.color + '22', color: c.color }}>{c.icon}</span>
                  <span className="m-cat-t">{c.ar}</span>
                </button>
              ))}
            </div>
          </section>
        )}

        <a className="m-cta" href={`/launch?role=${role}`}>
          احصل على التجربة الكاملة في التطبيق
        </a>
      </main>

      {toast && <div className="m-toast">{toast}</div>}

      <style jsx global>{`
        html, body { margin: 0; background: #f4f7f7; }
        * { box-sizing: border-box; }
        .m-app {
          min-height: 100vh; max-width: 520px; margin: 0 auto;
          background: #f4f7f7; color: #16242a;
          font-family: -apple-system, "Segoe UI", Tahoma, sans-serif;
          padding-bottom: 28px;
        }
        .m-head { color: #fff; padding: 18px 20px 30px; border-radius: 0 0 26px 26px; }
        .m-head-row { display: flex; align-items: center; justify-content: space-between; }
        .m-brand { display: flex; align-items: center; gap: 10px; }
        .m-mark {
          width: 42px; height: 42px; border-radius: 13px; display: grid; place-items: center;
          background: rgba(255,255,255,0.18); font-size: 20px;
        }
        .m-brand-name { font-weight: 800; font-size: 17px; }
        .m-brand-sub { font-size: 11.5px; opacity: 0.85; }
        .m-getapp {
          background: rgba(255,255,255,0.16); color: #fff; text-decoration: none;
          font-size: 12.5px; font-weight: 700; padding: 8px 14px; border-radius: 11px;
        }
        .m-hello { margin: 20px 0 0; font-size: 21px; font-weight: 800; }
        .m-hello-sub { margin: 6px 0 0; font-size: 13px; opacity: 0.9; line-height: 1.6; }
        .m-main { padding: 18px; margin-top: -14px; }
        .m-actions { display: flex; flex-direction: column; gap: 11px; }
        .m-action {
          display: flex; align-items: center; gap: 13px; width: 100%;
          background: #fff; border: 1px solid #eaf0f0; border-radius: 18px;
          padding: 14px; cursor: pointer; text-align: right;
          box-shadow: 0 10px 26px -20px rgba(10,35,42,0.5);
        }
        .m-action-ic {
          width: 46px; height: 46px; flex-shrink: 0; border-radius: 13px;
          background: #daefee; display: grid; place-items: center; font-size: 22px;
        }
        .m-action-tx { display: flex; flex-direction: column; flex: 1; }
        .m-action-t { font-weight: 700; font-size: 14.5px; color: #16242a; }
        .m-action-s { font-size: 12px; color: #84949b; margin-top: 2px; }
        .m-chev { color: #c2cfd2; font-size: 22px; }
        .m-sec { font-size: 15px; font-weight: 800; margin: 24px 2px 12px; color: #16242a; }
        .m-cats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 11px; }
        .m-cat {
          background: #fff; border: 1px solid #eaf0f0; border-radius: 16px; padding: 14px 8px;
          display: flex; flex-direction: column; align-items: center; gap: 9px; cursor: pointer;
          box-shadow: 0 10px 26px -22px rgba(10,35,42,0.5);
        }
        .m-cat-ic { width: 44px; height: 44px; border-radius: 13px; display: grid; place-items: center; font-size: 22px; }
        .m-cat-t { font-size: 12px; font-weight: 600; color: #44545b; text-align: center; }
        .m-cta {
          display: block; text-align: center; margin: 24px 0 0; padding: 15px;
          background: linear-gradient(135deg,#D98E2B 0%,#A86A18 100%); color: #fff;
          border-radius: 16px; font-weight: 800; font-size: 15px; text-decoration: none;
        }
        .m-toast {
          position: fixed; left: 50%; bottom: 22px; transform: translateX(-50%);
          background: #14323b; color: #fff; padding: 11px 18px; border-radius: 13px;
          font-size: 13px; max-width: 90%; text-align: center; z-index: 50;
          box-shadow: 0 16px 40px -14px rgba(0,0,0,0.5);
        }
      `}</style>
    </div>
  );
}
