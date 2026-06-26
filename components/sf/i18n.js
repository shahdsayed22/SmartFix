'use client';

/* ============================================================
   SmartFix Admin — lightweight bilingual (Arabic-first) i18n
   ------------------------------------------------------------
   Arabic is the default. `t(en, ar)` returns the Arabic string
   when the active language is Arabic (inline `ar` wins, then a
   shared AR_DICT lookup, then the English fallback), so pages can
   localise inline without touching a shared file:

       const t = useT();
       t('Issues', 'البلاغات')

   The provider also flips <html dir> to rtl/ltr and persists the
   choice. SSR renders Arabic/RTL by default (see app/layout.js).
   ============================================================ */
import React, { createContext, useContext, useEffect, useState } from 'react';

const LangContext = createContext({ lang: 'ar', setLang: () => {}, toggle: () => {} });

// Shared dictionary for common terms reused across many pages. Pages may also
// pass an inline Arabic string as the 2nd arg to t(), which takes precedence.
export const AR_DICT = {
  // generic UI
  Search: 'بحث',
  'Search…': 'بحث…',
  All: 'الكل',
  Status: 'الحالة',
  Actions: 'إجراءات',
  Save: 'حفظ',
  Cancel: 'إلغاء',
  Close: 'إغلاق',
  Apply: 'تطبيق',
  Filter: 'تصفية',
  'View all': 'عرض الكل',
  Loading: 'جارٍ التحميل',
  'No results': 'لا توجد نتائج',
  Name: 'الاسم',
  Rating: 'التقييم',
  City: 'المدينة',
  Category: 'الفئة',
  Date: 'التاريخ',
  Amount: 'المبلغ',
  Customer: 'العميل',
  Technician: 'الفني',
  Admin: 'المدير',
  Total: 'الإجمالي',
  Active: 'نشط',
  Pending: 'قيد الانتظار',
  Completed: 'مكتمل',
  Cancelled: 'ملغي',
  // language switch label
  العربية: 'العربية',
  English: 'English',
};

export function LangProvider({ children }) {
  const [lang, setLang] = useState('ar');

  useEffect(() => {
    const saved = localStorage.getItem('sf-lang') || 'ar';
    setLang(saved);
  }, []);

  useEffect(() => {
    const el = document.documentElement;
    el.setAttribute('lang', lang);
    el.setAttribute('dir', lang === 'ar' ? 'rtl' : 'ltr');
    localStorage.setItem('sf-lang', lang);
  }, [lang]);

  const toggle = () => setLang((l) => (l === 'ar' ? 'en' : 'ar'));

  return (
    <LangContext.Provider value={{ lang, setLang, toggle }}>
      {children}
    </LangContext.Provider>
  );
}

export function useLang() {
  return useContext(LangContext);
}

/** Returns a translator: t(en, ar?) -> Arabic when lang==='ar', else English. */
export function useT() {
  const { lang } = useLang();
  return (en, ar) => (lang === 'ar' ? (ar ?? AR_DICT[en] ?? en) : en);
}
