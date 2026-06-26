'use client';

/* ============================================================
   SmartFix — AI Insights / Research Models page
   Surfaces the REAL anomaly-detection research (research/results/
   all_results.json) inside the admin dashboard: model performance,
   per-domain leaderboard, confusion matrices, ensemble ablation,
   and the publication figures from the IMSA-2026 paper.
   ============================================================ */
import React, { useState, useEffect } from 'react';
import { fetchWithTimeout } from '@/lib/fetchWithTimeout';
import { SF } from '@/components/sf/data';
import { Icon } from '@/components/sf/Icon';
import { StatCard, SectionHead, ChartCard, DataTable, Modal } from '@/components/sf/ui';
import { VBars, HBars } from '@/components/sf/charts';
import {
  AI_SUMMARY, AI_DATASETS, AI_MODELS, AI_MODEL_META, LEADERBOARD,
  ABLATION, AI_FIGURES, AI_BRIDGE, stat,
} from '@/components/sf/airesearch';
import { useT } from '@/components/sf/i18n';

const h = React.createElement;

/* Arabic translations for the descriptive copy that lives in the shared
   airesearch module constants (AI_BRIDGE / AI_FIGURES). Keyed by the English
   source so we never mutate the other file; looked up at render time and fed
   into t(en, ar). */
const BRIDGE_AR = {
  'Urgency & anomaly scoring': { title: 'تسجيل الإلحاح والشذوذ', text: 'تُربط درجات الشذوذ بمدى إلحاح البلاغ، لتحل النماذج محل التخمين بالكلمات المفتاحية في تحديد الخطورة.', status: 'الأساس مُشغّل · النموذج المُدرَّب تاليًا' },
  'Predictive auto-issues': { title: 'بلاغات تنبّؤية تلقائية', text: 'يُنشئ شذوذ مُستشعَر مُكتشَف بلاغ صيانة تلقائيًا قبل أن يبلّغ عنه أي شخص.', status: 'خارطة الطريق' },
  'Severity-aware routing': { title: 'توجيه مراعٍ للخطورة', text: 'تُوجَّه البلاغات عالية الشذوذ تلقائيًا إلى أعلى الفنيين الموثّقين تقييمًا.', status: 'مُشغّل جزئيًا' },
};
const FIGURE_AR = {
  'F1-Score Comparison': { title: 'مقارنة مقياس F1', sub: 'مقياس F1 لكل مجموعة بيانات عبر النماذج الثلاثة' },
  'AUC-ROC Comparison': { title: 'مقارنة AUC-ROC', sub: 'قدرة التمييز حسب النموذج والمجال' },
  'ROC Curves': { title: 'منحنيات ROC', sub: 'معدلات الإيجابيات الصحيحة مقابل الخاطئة' },
  'Confusion Matrices': { title: 'مصفوفات الالتباس', sub: 'تفصيل التصنيف لكل أفضل نموذج' },
  'Multi-Metric Radar': { title: 'رادار متعدد المقاييس', sub: 'الدقة · الإحكام · الاستدعاء · F1 · AUC' },
  'Latency vs Accuracy': { title: 'زمن الاستجابة مقابل الدقة', sub: 'مفاضلة تكلفة الاستدلال' },
  'Ensemble Ablation': { title: 'استئصال المجموعة', sub: 'المجموعة مقابل أفضل نموذج منفرد' },
  'System Architecture': { title: 'معمارية النظام', sub: 'مسار من البحث إلى الإنتاج' },
};

const pct1 = (v) => (v * 100).toFixed(1);
const f3 = (v) => v.toFixed(3);
const f1Color = (v) => (v >= 0.8 ? '#10b981' : v >= 0.55 ? '#f59e0b' : '#ef4444');

/* ── tiny inline metric bar ── */
function Bar({ value, color, max = 1 }) {
  return h('div', { style: { display: 'flex', alignItems: 'center', gap: 9, minWidth: 130 } },
    h('div', { style: { flex: 1, height: 7, background: 'var(--surface-2)', borderRadius: 5, overflow: 'hidden' } },
      h('div', { style: { height: '100%', width: `${Math.min(100, (value / max) * 100)}%`, background: `linear-gradient(90deg, ${color}, ${color}bb)`, borderRadius: 5, transition: 'width .9s cubic-bezier(.4,0,.2,1)' } })),
    h('span', { className: 'tnum', style: { fontSize: 12.5, fontWeight: 700, width: 42, textAlign: 'right', color: 'var(--text-1)' } }, f3(value)));
}

/* ── 2×2 confusion matrix ── */
function ConfusionMatrix({ cm }) {
  const t = useT();
  const cells = [
    { v: cm[0][0], tag: 'TN', ok: true },
    { v: cm[0][1], tag: 'FP', ok: false },
    { v: cm[1][0], tag: 'FN', ok: false },
    { v: cm[1][1], tag: 'TP', ok: true },
  ];
  const max = Math.max(...cells.map(c => c.v), 1);
  return h('div', null,
    h('div', { style: { display: 'flex', gap: 6, marginBottom: 6, paddingLeft: 92 } },
      [t('Pred. Normal', 'متوقّع: طبيعي'), t('Pred. Anomaly', 'متوقّع: شاذ')].map((tx, i) =>
        h('div', { key: i, style: { flex: 1, fontSize: 10.5, fontWeight: 700, letterSpacing: 0.3, color: 'var(--text-3)', textAlign: 'center', textTransform: 'uppercase' } }, tx))),
    [0, 1].map((row) =>
      h('div', { key: row, style: { display: 'flex', gap: 6, marginBottom: 6, alignItems: 'stretch' } },
        h('div', { style: { width: 86, fontSize: 10.5, fontWeight: 700, letterSpacing: 0.3, color: 'var(--text-3)', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingRight: 8, textTransform: 'uppercase', textAlign: 'right' } }, row === 0 ? t('Actual Normal', 'فعلي: طبيعي') : t('Actual Anomaly', 'فعلي: شاذ')),
        [0, 1].map((col) => {
          const c = cells[row * 2 + col];
          const base = c.ok ? '16,185,129' : '239,68,68';
          const op = 0.1 + (c.v / max) * 0.42;
          return h('div', { key: col, style: { flex: 1, padding: '14px 8px', borderRadius: 10, textAlign: 'center', background: `rgba(${base},${op})`, border: `1px solid rgba(${base},0.4)` } },
            h('div', { className: 'tnum', style: { fontSize: 19, fontWeight: 800, color: 'var(--text-1)', lineHeight: 1 } }, c.v.toLocaleString()),
            h('div', { style: { fontSize: 10, fontWeight: 700, letterSpacing: 0.5, color: c.ok ? '#10b981' : '#ef4444', marginTop: 4 } }, c.tag));
        }))));
}

/* ── live NLP triage demo ── posts free text to /api/nlp/classify and shows
   the detected service category + confidence. Resilient: any error just shows
   an inline message and never crashes the page. ── */
function NlpClassifyDemo() {
  const t = useT();
  const [text, setText] = useState('صنبور المطبخ يسرب ماء بشكل مستمر');
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState(null);
  const [err, setErr] = useState(false);

  const run = async () => {
    if (!text.trim() || busy) return;
    setBusy(true); setErr(false);
    try {
      const res = await fetch('/api/nlp/classify', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text }),
      });
      if (!res.ok) throw new Error('bad response');
      const data = await res.json();
      setResult(data);
    } catch {
      setErr(true); setResult(null);
    } finally {
      setBusy(false);
    }
  };

  const cat = result && result.category;
  const cfg = cat ? SF.CATEGORY_CONFIG[cat] : null;
  const conf = result ? Math.round((result.confidence || 0) * 100) : 0;
  const matched = (result && result.matched) || [];

  return h(ChartCard, { title: t('Live triage demo', 'عرض حي للفرز'), sub: t('Classify free-text via /api/nlp/classify — trained model when configured, heuristic baseline otherwise', 'تصنيف نص حر عبر /api/nlp/classify — نموذج مُدرَّب عند التهيئة، وأساس استدلالي فيما عدا ذلك') },
    h('div', { style: { display: 'flex', flexDirection: 'column', gap: 12 } },
      h('textarea', {
        className: 'textarea',
        value: text,
        onChange: (e) => setText(e.target.value),
        placeholder: t('Describe a maintenance issue (Arabic or English)…', 'صف مشكلة صيانة (بالعربية أو الإنجليزية)…'),
        rows: 3,
        style: { resize: 'vertical', minHeight: 70 },
        onKeyDown: (e) => { if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') run(); },
      }),
      h('div', { style: { display: 'flex', alignItems: 'center', gap: 10 } },
        h('button', { className: 'btn btn-primary', onClick: run, disabled: busy || !text.trim() },
          h(Icon, { name: busy ? 'Loader' : 'Sparkles', size: 16 }), busy ? t('Classifying…', 'جارٍ التصنيف…') : t('Classify', 'تصنيف')),
        h('span', { style: { fontSize: 11.5, color: 'var(--text-3)' } }, 'Ctrl/⌘ + Enter')),

      err && h('div', { style: { fontSize: 12.5, color: '#ef4444', display: 'flex', alignItems: 'center', gap: 6 } },
        h(Icon, { name: 'TriangleAlert', size: 14 }), t('Classifier unavailable — backend not reachable.', 'المصنّف غير متاح — تعذّر الوصول إلى الخادم.')),

      result && !err && (cfg
        ? h('div', { style: { padding: 14, borderRadius: 12, border: `1px solid ${cfg.color}55`, background: `${cfg.color}0f` } },
            h('div', { style: { display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 } },
              h('div', { style: { width: 36, height: 36, borderRadius: 10, display: 'grid', placeItems: 'center', flexShrink: 0, background: `${cfg.color}22`, color: cfg.color } }, h(Icon, { name: cfg.icon, size: 18 })),
              h('div', null,
                h('div', { style: { fontSize: 11, fontWeight: 700, letterSpacing: 0.4, color: 'var(--text-3)', textTransform: 'uppercase' } }, t('Detected category', 'الفئة المكتشفة')),
                h('div', { style: { fontSize: 15, fontWeight: 800, color: 'var(--text-1)' } }, cfg.label)),
              h('div', { style: { marginLeft: 'auto', textAlign: 'right' } },
                h('div', { className: 'tnum', style: { fontSize: 20, fontWeight: 800, color: cfg.color, lineHeight: 1 } }, `${conf}%`),
                h('div', { style: { fontSize: 10.5, fontWeight: 700, letterSpacing: 0.3, color: 'var(--text-3)', textTransform: 'uppercase' } }, t('Confidence', 'درجة الثقة')))),
            h('div', { style: { height: 7, background: 'var(--surface-2)', borderRadius: 5, overflow: 'hidden' } },
              h('div', { style: { height: '100%', width: `${conf}%`, background: `linear-gradient(90deg, ${cfg.color}, ${cfg.color}bb)`, borderRadius: 5, transition: 'width .6s cubic-bezier(.4,0,.2,1)' } })),
            matched.length > 0 && h('div', { style: { display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 11 } },
              matched.slice(0, 8).map((m, i) => h('span', { key: i, className: 'badge badge-soft', style: { background: 'var(--surface-2)', color: 'var(--text-2)', border: '1px solid var(--border)' } }, m))))
        : h('div', { style: { padding: 14, borderRadius: 12, border: '1px solid var(--border)', background: 'var(--surface)', display: 'flex', alignItems: 'center', gap: 9, fontSize: 13, color: 'var(--text-2)' } },
            h(Icon, { name: 'HelpCircle', size: 16, color: 'var(--text-3)' }), t('No category matched — try adding more detail about the problem.', 'لم تُطابق أي فئة — حاول إضافة المزيد من التفاصيل حول المشكلة.')))));
}

export default function AiInsightsPage() {
  const t = useT();
  const [sel, setSel] = useState('Elec. Fault');
  const [fig, setFig] = useState(null);
  // Live platform counts from the Mongo-backed analytics API. Falls back to the
  // static SF.ANALYTICS so this strip always renders (demo works with no DB).
  const [live, setLive] = useState(null);

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const res = await fetchWithTimeout('/api/analytics', { cache: 'no-store' });
        if (!res.ok) return;
        const data = await res.json();
        if (active && data && !data.error) setLive(data);
      } catch { /* keep static fallback */ }
    })();
    return () => { active = false; };
  }, []);

  // Real platform numbers (live API → static SF fallback), guarded throughout.
  const totalIssues = live?.issueStats?.total ?? SF.ANALYTICS?.issueStats?.total ?? (SF.ISSUES?.length || 0);
  const resolvedIssues = live?.issueStats?.completed ?? SF.ANALYTICS?.issueStats?.completed ?? 0;
  const totalTechs = live?.totalTechnicians ?? SF.ANALYTICS?.totalTechnicians ?? (SF.TECHNICIANS?.length || 0);
  const totalUsers = live?.userStats?.total ?? SF.ANALYTICS?.userStats?.total ?? (SF.USERS?.length || 0);
  const isLive = !!live;

  const ds = AI_DATASETS.find(d => d.key === sel);
  const models = AI_MODELS.map(m => ({ key: m, ...AI_MODEL_META[m], ...stat(sel, m) }));
  const bestF1 = Math.max(...models.map(m => m.f1));
  const best = models.find(m => m.f1 === bestF1);
  const abl = ABLATION[sel];

  /* leaderboard table columns */
  const columns = [
    { key: 'domain', label: t('Domain', 'المجال'), width: 220, render: (r) => h('div', { style: { display: 'flex', alignItems: 'center', gap: 10 } },
      h('div', { style: { width: 32, height: 32, borderRadius: 9, display: 'grid', placeItems: 'center', flexShrink: 0, background: `${r.color}1f`, color: r.color } }, h(Icon, { name: r.icon, size: 16 })),
      h('div', null,
        h('div', { className: 'cell-primary' }, r.domain),
        h('div', { className: 'cell-sub' }, r.sensor))) },
    { key: 'bestModelKey', label: t('Best Model', 'أفضل نموذج'), render: (r) => h('span', { className: 'badge badge-soft', style: { background: `${AI_MODEL_META[r.bestModelKey].color}1f`, color: AI_MODEL_META[r.bestModelKey].color, border: `1px solid ${AI_MODEL_META[r.bestModelKey].color}40` } },
      h('span', { className: 'bdot', style: { background: AI_MODEL_META[r.bestModelKey].color } }), r.bestModelKey) },
    { key: 'f1', label: t('F1-Score', 'مقياس F1'), sortAccessor: (r) => r.f1, render: (r) => h(Bar, { value: r.f1, color: f1Color(r.f1) }) },
    { key: 'auc', label: t('AUC-ROC', 'AUC-ROC'), hideSm: true, sortAccessor: (r) => r.auc, render: (r) => h(Bar, { value: r.auc, color: '#6366f1' }) },
    { key: 'precision', label: t('Precision', 'الدقة'), hideSm: true, sortAccessor: (r) => r.precision, render: (r) => h('span', { className: 'tnum cell-muted' }, f3(r.precision)) },
    { key: 'recall', label: t('Recall', 'الاستدعاء'), hideSm: true, sortAccessor: (r) => r.recall, render: (r) => h('span', { className: 'tnum cell-muted' }, f3(r.recall)) },
    { key: 'allSig', label: t('Significance', 'الدلالة الإحصائية'), hideSm: true, align: 'right', sortable: false, render: (r) => h('span', { className: 'badge badge-soft', style: { background: 'rgba(16,185,129,0.12)', color: '#10b981', border: '1px solid rgba(16,185,129,0.35)' } },
      h(Icon, { name: 'BadgeCheck', size: 13 }), `${r.sigCount}/${r.sigCount} p<.005`) },
  ];

  const f1ChartData = LEADERBOARD.map(r => ({ name: r.short, short: r.short, value: Math.round(r.f1 * 1000) / 10, color: f1Color(r.f1) }));
  const aucChartData = LEADERBOARD.map(r => ({ name: r.short, value: Math.round(r.auc * 1000) / 10, color: '#6366f1' }));

  return h('div', { className: 'page-anim' },

    /* ── headline KPIs ── */
    h('div', { className: 'stat-grid grid-4', style: { gridTemplateColumns: 'repeat(5,1fr)' } },
      h(StatCard, { icon: 'Database', label: t('Datasets', 'مجموعات البيانات'), value: AI_SUMMARY.datasets, tone: 'primary', foot: t('7 sensor domains', '7 مجالات استشعار'), delay: 0 }),
      h(StatCard, { icon: 'BrainCircuit', label: t('Models', 'النماذج'), value: AI_SUMMARY.models, tone: 'cyan', foot: 'IF · LSTM-AE · Trans-D', delay: 50 }),
      h(StatCard, { icon: 'FlaskConical', label: t('Experiments', 'التجارب'), value: AI_SUMMARY.experiments, tone: 'info', foot: t('7 × 3 × 10-fold CV', '7 × 3 × تحقّق متقاطع 10 طيّات'), delay: 100 }),
      h(StatCard, { icon: 'Trophy', label: t('Best F1-Score', 'أفضل مقياس F1'), value: AI_SUMMARY.bestF1, decimals: 3, tone: 'success', foot: `${AI_SUMMARY.bestF1Domain} · Trans-D`, delay: 150 }),
      h(StatCard, { icon: 'Gauge', label: t('Best AUC-ROC', 'أفضل AUC-ROC'), value: AI_SUMMARY.bestAuc, decimals: 3, tone: 'warning', foot: `${AI_SUMMARY.bestAucDomain} ${t('fault', 'عطل')}`, delay: 200 })),

    /* ── intro / research→product bridge ── */
    h('div', { className: 'card rise', style: { padding: 20, marginTop: 4, display: 'flex', gap: 16, alignItems: 'flex-start', flexWrap: 'wrap' } },
      h('div', { style: { width: 46, height: 46, borderRadius: 13, flexShrink: 0, display: 'grid', placeItems: 'center', background: 'linear-gradient(135deg, var(--accent), var(--accent-2))', color: '#fff' } }, h(Icon, { name: 'BrainCircuit', size: 24 })),
      h('div', { style: { flex: 1, minWidth: 280 } },
        h('h3', { style: { margin: '2px 0 5px', fontSize: 16, fontWeight: 700, color: 'var(--text-1)' } }, t('Anomaly-detection research powering SmartFix', 'أبحاث كشف الشذوذ التي تُشغّل SmartFix')),
        h('p', { style: { margin: 0, fontSize: 13.5, lineHeight: 1.6, color: 'var(--text-2)', maxWidth: 880 } },
          t('Three model families — Isolation Forest, an LSTM Autoencoder and a Transformer detector — were benchmarked across seven real sensor datasets with 10-fold cross-validation and Wilcoxon significance testing (IMSA-2026). ', 'تمّ قياس أداء ثلاث عائلات من النماذج — Isolation Forest وLSTM Autoencoder وكاشف Transformer — عبر سبع مجموعات بيانات استشعار حقيقية باستخدام تحقّق متقاطع 10 طيّات واختبار دلالة Wilcoxon (IMSA-2026). '),
          h('span', { style: { color: 'var(--text-3)' } }, t('These trained models drive SmartFix’s predictive-maintenance roadmap. The live in-app triage classifier is model-ready: it loads a trained artifact for serving whenever one is configured, and otherwise falls back to a transparent keyword heuristic baseline.', 'تقود هذه النماذج المُدرَّبة خارطة طريق الصيانة التنبّؤية في SmartFix. ومُصنّف الفرز الحي داخل التطبيق جاهز للنماذج: فهو يُحمّل أداة (artifact) مُدرَّبة للتشغيل عند تهيئتها، وإلا فإنه يعود إلى أساس استدلالي شفّاف قائم على الكلمات المفتاحية.')))),
      h('div', { style: { display: 'flex', gap: 8, alignItems: 'center', flexShrink: 0 } },
        h('span', { className: 'badge badge-soft', style: { background: 'rgba(16,185,129,0.12)', color: '#10b981', border: '1px solid rgba(16,185,129,0.35)' } },
          h(Icon, { name: 'ShieldCheck', size: 13 }), `${AI_SUMMARY.sigPairwise}/${AI_SUMMARY.pairwise} ${t('tests significant', 'اختبار ذو دلالة')}`))),

    /* ── live platform AI activity + interactive triage demo ── */
    h(SectionHead, { icon: 'Activity', title: t('Live AI Triage on SmartFix', 'الفرز الذكي الحي على SmartFix'), sub: isLive ? t('· live platform data', '· بيانات المنصة الحية') : t('· demo data (backend offline)', '· بيانات تجريبية (الخادم غير متصل)'), right:
      h('span', { title: isLive ? t('Reading live data from the platform API', 'قراءة بيانات حية من واجهة برمجة المنصة') : t('Showing static demo data — backend not reachable', 'عرض بيانات تجريبية ثابتة — تعذّر الوصول إلى الخادم'), style: { display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, fontWeight: 700, letterSpacing: 0.4, color: isLive ? '#0e9f6e' : 'var(--text-3)', background: isLive ? 'rgba(16,185,129,0.12)' : 'var(--surface-2)', padding: '4px 10px', borderRadius: 999 } },
        h('span', { style: { width: 7, height: 7, borderRadius: 999, background: isLive ? '#10b981' : 'var(--text-3)', display: 'inline-block' } }), isLive ? t('LIVE', 'مباشر') : t('DEMO', 'تجريبي')) }),
    h('div', { className: 'stat-grid', style: { gridTemplateColumns: '1fr 1.2fr', alignItems: 'stretch' } },
      h('div', { className: 'stat-grid grid-4', style: { gridTemplateColumns: '1fr 1fr' } },
        h(StatCard, { icon: 'TriangleAlert', label: t('Issues triaged', 'البلاغات المُفرزة'), value: totalIssues, tone: 'primary', foot: t('auto-classified on intake', 'مُصنّفة تلقائيًا عند الاستلام'), delay: 0 }),
        h(StatCard, { icon: 'CircleCheck', label: t('Resolved', 'المحلولة'), value: resolvedIssues, tone: 'success', foot: t('completed jobs', 'مهام مكتملة'), delay: 50 }),
        h(StatCard, { icon: 'Wrench', label: t('Technicians', 'الفنيون'), value: totalTechs, tone: 'cyan', foot: t('matched by category', 'مطابقة حسب الفئة'), delay: 100 }),
        h(StatCard, { icon: 'Users', label: t('Platform users', 'مستخدمو المنصة'), value: totalUsers, tone: 'info', foot: t('customers + workers', 'عملاء + فنيون'), delay: 150 })),
      h(NlpClassifyDemo)),

    /* ── F1 / AUC charts ── */
    h(SectionHead, { icon: 'ChartColumn', title: t('Model Performance by Domain', 'أداء النماذج حسب المجال'), sub: t('· best model per dataset', '· أفضل نموذج لكل مجموعة بيانات') }),
    h('div', { className: 'stat-grid', style: { gridTemplateColumns: '1fr 1fr', alignItems: 'stretch' } },
      h(ChartCard, { title: t('F1-Score by domain', 'مقياس F1 حسب المجال'), sub: t('Higher is better · best model shown', 'الأعلى أفضل · يُعرض أفضل نموذج') },
        h(VBars, { data: f1ChartData, height: 240, unit: '%' })),
      h(ChartCard, { title: t('AUC-ROC by domain', 'AUC-ROC حسب المجال'), sub: t('Discrimination power (best model)', 'قدرة التمييز (أفضل نموذج)') },
        h(HBars, { data: aucChartData, max: 100, unit: '%' }))),

    /* ── interactive model comparison ── */
    h(SectionHead, { icon: 'Microscope', title: t('Model Comparison', 'مقارنة النماذج'), sub: t('· pick a domain to inspect', '· اختر مجالًا للفحص'), right:
      h('div', { className: 'select-wrap', style: { minWidth: 220 } },
        h('select', { className: 'select', value: sel, onChange: (e) => setSel(e.target.value), style: { paddingLeft: 34 } },
          AI_DATASETS.map(d => h('option', { key: d.key, value: d.key }, d.domain))),
        h(Icon, { name: 'ChevronDown', size: 15, className: 'chev' }),
        h(Icon, { name: ds.icon, size: 15, style: { position: 'absolute', left: 11, top: '50%', transform: 'translateY(-50%)', color: ds.color, pointerEvents: 'none' } })) }),

    h('div', { className: 'stat-grid', style: { gridTemplateColumns: '1.4fr 1fr', alignItems: 'stretch' } },
      /* model metric cards */
      h(ChartCard, { title: `${ds.domain}`, sub: ds.sensor },
        h('div', { style: { display: 'flex', flexDirection: 'column', gap: 10 } },
          models.map((m) => h('div', { key: m.key, style: { padding: 13, borderRadius: 12, border: `1px solid ${m.key === best.key ? m.color + '55' : 'var(--border)'}`, background: m.key === best.key ? `${m.color}0f` : 'var(--surface)' } },
            h('div', { style: { display: 'flex', alignItems: 'center', gap: 9, marginBottom: 11 } },
              h('span', { className: 'bdot', style: { background: m.color, width: 9, height: 9 } }),
              h('div', { style: { fontWeight: 700, fontSize: 13.5, color: 'var(--text-1)' } }, m.name),
              h('span', { style: { fontSize: 11, color: 'var(--text-3)' } }, m.kind),
              m.key === best.key && h('span', { className: 'badge badge-soft', style: { marginLeft: 'auto', background: `${m.color}1f`, color: m.color, border: `1px solid ${m.color}40` } },
                h(Icon, { name: 'Trophy', size: 11 }), t('Best', 'الأفضل'))),
            h('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px 18px' } },
              [['F1', m.f1, f1Color(m.f1)], ['AUC', m.auc_roc, '#6366f1'], [t('Precision', 'الدقة'), m.precision, '#22d3ee'], [t('Recall', 'الاستدعاء'), m.recall, '#a855f7']].map(([lbl, val, col]) =>
                h('div', { key: lbl, style: { display: 'flex', alignItems: 'center', gap: 8 } },
                  h('span', { style: { fontSize: 11, fontWeight: 600, color: 'var(--text-3)', width: 56 } }, lbl),
                  h(Bar, { value: val, color: col }))))))),
          /* ablation footnote */
          abl && h('div', { style: { marginTop: 12, paddingTop: 12, borderTop: '1px solid var(--border)', display: 'flex', alignItems: 'center', gap: 8, fontSize: 12.5, color: 'var(--text-2)' } },
            h(Icon, { name: 'Layers', size: 14, color: 'var(--text-3)' }),
            h('span', null, t('Ensemble ablation: ', 'تحليل استئصال المجموعة: ')),
            h('span', { className: 'tnum', style: { fontWeight: 700, color: 'var(--text-1)' } }, f3(abl.ensemble_f1_mean)),
            h('span', { style: { color: 'var(--text-3)' } }, t(' ensemble vs ', ' للمجموعة مقابل ')),
            h('span', { className: 'tnum', style: { fontWeight: 700, color: 'var(--text-1)' } }, f3(abl.single_best_f1_mean)),
            h('span', { style: { color: 'var(--text-3)' } }, t(' single-best F1', ' لأفضل نموذج منفرد (F1)')),
            h('span', { className: 'badge badge-soft', style: { marginLeft: 'auto', background: abl.ensemble_f1_mean >= abl.single_best_f1_mean ? 'rgba(16,185,129,0.12)' : 'rgba(148,163,184,0.12)', color: abl.ensemble_f1_mean >= abl.single_best_f1_mean ? '#10b981' : 'var(--text-3)', border: '1px solid var(--border)' } },
              abl.ensemble_f1_mean >= abl.single_best_f1_mean ? t('Ensemble wins', 'تفوّقت المجموعة') : t('Single best wins', 'تفوّق النموذج المنفرد')))),
      /* confusion matrix of best model */
      h(ChartCard, { title: t('Confusion Matrix', 'مصفوفة الالتباس'), sub: `${best.name} · ${t('best model on', 'أفضل نموذج على')} ${ds.short}` },
        h('div', { style: { padding: '6px 2px' } }, h(ConfusionMatrix, { cm: best.cm })),
        h('div', { style: { marginTop: 12, fontSize: 11.5, color: 'var(--text-3)', display: 'flex', alignItems: 'center', gap: 6 } },
          h(Icon, { name: 'Timer', size: 12 }), `~${best.infer_ms.toFixed(3)} ${t('ms inference · 10-fold mean', 'م.ث للاستدلال · متوسط 10 طيّات')}`))),

    /* ── leaderboard table ── */
    h(SectionHead, { icon: 'Trophy', title: t('Per-Domain Leaderboard', 'لوحة الصدارة حسب المجال'), sub: `· ${LEADERBOARD.length} ${t('datasets · best model each', 'مجموعة بيانات · أفضل نموذج لكلٍّ منها')}` }),
    h(DataTable, { columns, rows: LEADERBOARD, pageSize: 8, initialSort: { key: 'f1', dir: 'desc' }, emptyTitle: t('No results', 'لا توجد نتائج') }),

    /* ── research → product bridge ── */
    h(SectionHead, { icon: 'Workflow', title: t('From Research to Product', 'من البحث إلى المنتج'), sub: t('· how the models feed SmartFix', '· كيف تُغذّي النماذج SmartFix') }),
    h('div', { className: 'stat-grid grid-4', style: { gridTemplateColumns: 'repeat(3,1fr)' } },
      AI_BRIDGE.map((b, i) => h('div', { key: i, className: 'card rise', style: { padding: 18, animationDelay: `${i * 60}ms` } },
        h('div', { style: { width: 40, height: 40, borderRadius: 11, display: 'grid', placeItems: 'center', background: 'var(--accent-soft, rgba(99,102,241,0.14))', color: 'var(--accent)', marginBottom: 12 } }, h(Icon, { name: b.icon, size: 20 })),
        h('div', { style: { fontWeight: 700, fontSize: 14, color: 'var(--text-1)', marginBottom: 5 } }, t(b.title, BRIDGE_AR[b.title]?.title || b.title)),
        h('p', { style: { margin: 0, fontSize: 12.5, lineHeight: 1.55, color: 'var(--text-2)' } }, t(b.text, BRIDGE_AR[b.title]?.text || b.text)),
        h('div', { style: { marginTop: 12, fontSize: 11, fontWeight: 700, letterSpacing: 0.3, color: 'var(--text-3)', textTransform: 'uppercase' } }, t(b.status, BRIDGE_AR[b.title]?.status || b.status))))),

    /* ── publication figures ── */
    h(SectionHead, { icon: 'Images', title: t('Publication Figures', 'أشكال النشر العلمي'), sub: t('· IMSA-2026 paper · click to enlarge', '· بحث IMSA-2026 · انقر للتكبير') }),
    h('div', { className: 'stat-grid grid-4', style: { gridTemplateColumns: 'repeat(4,1fr)' } },
      AI_FIGURES.map((f, i) => h('div', { key: i, className: 'card rise', style: { padding: 10, cursor: 'pointer', animationDelay: `${i * 40}ms` }, onClick: () => setFig(f) },
        h('div', { style: { borderRadius: 9, overflow: 'hidden', background: '#fff', aspectRatio: '4 / 3', display: 'grid', placeItems: 'center' } },
          h('img', { src: f.src, alt: f.title, loading: 'lazy', style: { width: '100%', height: '100%', objectFit: 'contain' } })),
        h('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 6, marginTop: 9, padding: '0 2px' } },
          h('div', null,
            h('div', { style: { fontSize: 12.5, fontWeight: 700, color: 'var(--text-1)' } }, t(f.title, FIGURE_AR[f.title]?.title || f.title)),
            h('div', { style: { fontSize: 11, color: 'var(--text-3)' } }, t(f.sub, FIGURE_AR[f.title]?.sub || f.sub))),
          h(Icon, { name: 'Maximize2', size: 14, color: 'var(--text-3)' }))))),

    /* ── figure lightbox ── */
    fig && h(Modal, { title: t(fig.title, FIGURE_AR[fig.title]?.title || fig.title), sub: t(fig.sub, FIGURE_AR[fig.title]?.sub || fig.sub), onClose: () => setFig(null), wide: true },
      h('div', { style: { background: '#fff', borderRadius: 12, padding: 12 } },
        h('img', { src: fig.src, alt: fig.title, style: { width: '100%', height: 'auto', display: 'block' } })))
  );
}
