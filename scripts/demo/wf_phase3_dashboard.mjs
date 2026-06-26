export const meta = {
  name: 'smartfix-phase3-dashboard',
  description: 'SmartFix Phase 3: wire the Next.js admin dashboard to the live DB + add Tickets/Payments/Commission-Settings/Categories admin pages; self-healing next build loop',
  phases: [
    { title: 'Shared Infra' },
    { title: 'Pages' },
    { title: 'Build' },
    { title: 'Fix' },
  ],
}

const ROOT = process.env.SMARTFIX_ROOT || process.cwd()

const CONVENTIONS = `
SmartFix Phase 3 — make the Next.js admin dashboard FUNCTIONAL (wired to the live MongoDB API) and add the missing admin pages. Spec: ${ROOT}/SMARTFIX_BUILD_CONTRACT.md (§1 taxonomy, §2 status, §3 financial model, §5 API routes, §7 notifications).

ARCHITECTURE FACTS (verified):
- Next.js 16 App Router, React 19. EVERY dashboard page is a \`'use client'\` component written with React.createElement (NOT JSX). MATCH that style exactly in each file you touch.
- Shared UI kit (import via '@/components/sf/...'): ui.jsx exports StatCard, SectionHead, DataTable, SearchBox, Select, StatusSelect, CatChip, UrgencyBadge, Stars, VerifiedBadge, Toggle, Modal, Avatar, ChartCard, Badge (READ ${ROOT}/components/sf/ui.jsx for exact props). charts.jsx exports Donut, HBars, VBars, AreaChart, RatingBars. Icon.jsx exports Icon ({name, size} — lucide names).
- Display config + static fallback data: ${ROOT}/components/sf/data.js exports SF = { CATEGORY_CONFIG, CATEGORIES, CITIES, STATUS_CONFIG, URGENCY_CONFIG, TECHNICIANS, ISSUES, USERS, ANALYTICS, HEALTH, ... }. Use SF.CATEGORY_CONFIG/STATUS_CONFIG for labels+colors.
- API routes are LIVE (read the route.js for the exact request/response shape BEFORE wiring): /api/analytics, /api/issues(+/[id]), /api/technicians(+/[id]), /api/users(+/[id]), /api/reviews, /api/tickets(+/[id], +/[id]/messages), /api/payments(+/[id]), /api/notifications, /api/settings/commission, /api/categories, /api/nlp/classify.

DATA-FETCH PATTERN — copy app/issues/page.js & app/users/page.js EXACTLY:
- 'use client' + useEffect → \`const res = await fetch('/api/...', { cache: 'no-store' }); const data = await res.json();\` then setState.
- ON ERROR OR EMPTY RESULT, fall back to the SF static data so the dashboard ALWAYS renders (the demo must work even with no DB connected). Wrap fetch in try/catch.
- Mutations: fetch with method PUT/POST/PATCH/DELETE, JSON body, optimistic local update + .catch(() => {}).

GOLDEN RULES:
1. NEVER break the build. Preserve existing behaviour of any page you edit. Match the existing coding style (React.createElement, existing CSS classes: btn/btn-primary/btn-ghost/card/badge/badge-soft, CSS vars like var(--accent), var(--accent-2)).
2. Edit ONLY your assigned file(s). Do NOT modify the shared kit (ui.jsx/charts.jsx/Icon.jsx). If you need a small helper/sub-component, define it locally inside your page file.
3. Dashboard language stays ENGLISH (existing convention — Arabic-first applies to the mobile app, already done in Phase 1/2). Match sibling pages' tone.
4. Resilient UI: loading + empty states; never crash on missing/undefined fields (e.g. guard SF.STATUS_CONFIG[status]?.label).
5. Keep imports correct; no unused imports.
`

const CATALOG_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['uiComponents', 'navRoutes', 'configKeys', 'notes'],
  properties: {
    uiComponents: { type: 'array', items: { type: 'string' }, description: 'name — key props' },
    navRoutes: { type: 'array', items: { type: 'string' }, description: 'routes now present in the sidebar' },
    configKeys: { type: 'array', items: { type: 'string' }, description: 'SF.* config keys available (incl. newly added status configs)' },
    notes: { type: 'string' },
  },
}
const PAGE_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['file', 'status', 'summary', 'apiRoutesUsed'],
  properties: {
    file: { type: 'string' },
    status: { type: 'string', enum: ['done', 'partial', 'failed'] },
    summary: { type: 'string' },
    apiRoutesUsed: { type: 'array', items: { type: 'string' } },
    fallbackToStatic: { type: 'boolean' },
  },
}
const BUILD_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['clean', 'errors'],
  properties: {
    clean: { type: 'boolean', description: 'true if `next build` exits 0 (compiled successfully)' },
    errorCount: { type: 'number' },
    errors: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false, required: ['file', 'message'],
        properties: { file: { type: 'string' }, line: { type: 'number' }, message: { type: 'string' } },
      },
    },
    rawTail: { type: 'string', description: 'last ~25 lines of build output' },
  },
}

// ── Stage A: shared infra (Shell nav + data.js status config) ───────
phase('Shared Infra')
const catalog = await agent(
  `${CONVENTIONS}

TASK — additive shared-infra changes that the new admin pages depend on:
1. ${ROOT}/components/sf/data.js (ADDITIVE — keep ALL existing exports): extend STATUS_CONFIG with the 4 missing issue statuses: awaitingApproval, awaitingPayment, disputed, rejected (each { label, color } — English labels: 'Awaiting Approval','Awaiting Payment','Disputed','Rejected'; pick colors consistent with the existing palette, e.g. approval=#7A5AE0). Also ADD and export (inside SF) TICKET_STATUS_CONFIG (open/pending/resolved/closed), PAYMENT_STATUS_CONFIG (pending/paid/failed/refunded), and TICKET_PRIORITY_CONFIG (low/medium/high) — each as { label, color }. Do not remove or rename anything.
2. ${ROOT}/components/sf/Shell.jsx: add sidebar nav entries (matching the existing NAV array + HEADER_META object style) for the new pages: Tickets (href '/tickets', icon 'Ticket' or 'LifeBuoy', section 'Operations'), Payments (href '/payments', icon 'CreditCard', section 'Commerce'), Commission Settings (href '/settings', icon 'Settings', section 'Commerce'), Categories (href '/categories', icon 'LayoutGrid', section 'Commerce'). Add matching HEADER_META title/subtitle for each. Keep all existing entries + logic.

Read ui.jsx, data.js, and Shell.jsx first. Make ONLY additive changes. Return the catalog screen-authors need.`,
  { label: 'shared-infra', schema: CATALOG_SCHEMA }
)
const catalogText = JSON.stringify(catalog, null, 2)
log(`Shared infra ready. Nav routes: ${(catalog.navRoutes || []).join(', ')}`)

// ── Stage B: build new pages + wire existing pages (parallel) ───────
phase('Pages')
const PAGES = [
  // NEW admin pages
  { short: 'tickets', file: 'app/tickets/page.js', kind: 'new',
    task: `Create the Tickets admin page: fetch GET /api/tickets (filters: status, priority, search — paginated like issues). DataTable of tickets (ticketId, subject, customer, category, priority badge, status badge using SF.TICKET_STATUS_CONFIG/TICKET_PRIORITY_CONFIG, updatedAt). Row click → Modal showing the message thread (embedded messages: customer/admin/bot) with a reply composer (POST /api/tickets/[id]/messages as senderRole 'admin') and controls to change status/priority (PATCH /api/tickets/[id]). StatCards for open/pending/resolved counts. Empty state when no tickets.` },
  { short: 'payments', file: 'app/payments/page.js', kind: 'new',
    task: `Create the Payments admin page: fetch GET /api/payments. DataTable (issueId, customer, technician, method, total/currency, status badge via SF.PAYMENT_STATUS_CONFIG, paidAt). StatCards: total revenue (sum of paid totals), platform fees, pending count. Row click → Modal with the invoice breakdown (base/platformFee/vat/discount/total + workerCommission/payout). Empty state when none.` },
  { short: 'settings', file: 'app/settings/page.js', kind: 'new',
    task: `Create the Commission & Tax Settings page: GET /api/settings/commission → form fields platformFeePercent, vatPercent, workerCommissionPercent, minPlatformFee, currency. PUT /api/settings/commission to save (success toast/inline confirmation). Include a LIVE invoice preview that, given a sample base amount input, shows platformFee=max(min,round(base*fee%)), vat=round((base+platformFee)*vat%), total, and worker payout=base-round(base*commission%) — exactly per §3 of the contract. Use the existing card/form styling.` },
  { short: 'categories', file: 'app/categories/page.js', kind: 'new',
    task: `Create the Service Categories management page: GET /api/categories (returns DB categories, or static §1 fallback). Table/grid of the 9 categories (key, labelEn, labelAr, icon, color swatch, defaultPrice EGP, order, active toggle). Add/Edit via Modal (POST/PUT /api/categories). Toggle active. Keys are immutable per §1 — show key read-only on edit. Fall back to SF.CATEGORY_CONFIG-derived rows if the API is empty.` },
  // WIRE existing pages to the API
  { short: 'overview', file: 'app/page.js', kind: 'wire',
    task: `Wire the Dashboard Overview to live data: fetch GET /api/analytics in a useEffect and feed the existing StatCards/charts from it; FALL BACK to SF.ANALYTICS on error/empty. Keep every existing chart/section and the growthTab UI. Guard against missing keys.` },
  { short: 'technicians', file: 'app/technicians/page.js', kind: 'wire',
    task: `Wire Technicians to the API: fetch GET /api/technicians (fallback SF.TECHNICIANS). Keep the existing add/edit Modal but POST/PUT to /api/technicians(+/[id]). ADD verification actions: a Verify / Reject control per technician that PATCHes /api/technicians/[id] (verify/reject sets verificationStatus + isVerified) and a way to set categories. Optimistic UI. Preserve all existing table/search/logic.` },
  { short: 'ratings', file: 'app/ratings/page.js', kind: 'wire',
    task: `Wire Ratings to real reviews: fetch GET /api/reviews (and /api/technicians for names) to compute the per-technician averages and the reviews list; FALL BACK to SF.TECHNICIANS-derived data on error/empty. Keep the existing charts (RatingBars), stats, search, and layout.` },
  { short: 'verified', file: 'app/verified/page.js', kind: 'wire',
    task: `Turn Verified Profiles into a verification queue wired to the API: fetch technicians (GET /api/technicians) and/or users (GET /api/users), surface those with verificationStatus 'pending' for review with Approve/Reject actions (PATCH /api/technicians/[id] or /api/users/[id]), and list verified ones. Fall back to SF static data. Preserve existing layout/styling.` },
  { short: 'ai-insights', file: 'app/ai-insights/page.js', kind: 'wire',
    task: `Lightly wire AI Insights to live numbers: pull GET /api/analytics for any real counts the page shows, and (optional) add a small live demo box that POSTs to /api/nlp/classify { text } and shows the detected category/confidence. FALL BACK to existing static content on error. Do not remove existing insight sections; keep it resilient.` },
]

const pageResults = await parallel(PAGES.map((p) => () =>
  agent(
    `${CONVENTIONS}

SHARED CATALOG (nav routes, ui components, config keys now available):
${catalogText}

TASK — ${p.kind === 'new' ? 'CREATE a new admin page' : 'WIRE an existing admin page to the live API (edit in place, preserve all existing behaviour)'}.
File: ${ROOT}/${p.file}
${p.task}

Steps: (1) ${p.kind === 'wire' ? 'Read the existing page fully; keep all its logic/UI.' : 'Read a sibling page (app/issues/page.js) as the structural template.'} (2) Read the API route.js files you call for exact request/response shapes, and ui.jsx for component props. (3) Implement with the fetch+static-fallback pattern, React.createElement style, existing CSS classes. (4) Do NOT run next build; do NOT edit other files (shared kit is read-only).`,
    { label: `${p.kind}:${p.short}`, phase: 'Pages', schema: PAGE_SCHEMA }
  )
))
const pagesDone = pageResults.filter(Boolean)
log(`Pages: ${pagesDone.filter((r) => r.status === 'done').length}/${PAGES.length} done`)

// ── Stage C: next build + self-heal ─────────────────────────────────
const buildPrompt = (tag) => `Run \`npm run build\` in ${ROOT} (Bash, 600000 ms timeout; this runs the LOCAL next 16.1.6 — do NOT use npx, which pulls a wrong version). It compiles the dashboard. "clean" = TRUE iff the command exits 0 (Compiled successfully). If it fails, extract each compile/type/lint ERROR with its file path (relative to ${ROOT}) and message; include the last ~25 lines of output in rawTail. Do not edit files.${tag ? ` (run ${tag})` : ''}`

phase('Build')
let build = await agent(buildPrompt(''), { label: 'build', schema: BUILD_SCHEMA })
log(`Build: ${build.clean ? 'CLEAN' : `${(build.errors || []).length} errors`}`)

let round = 0
while (!build.clean && (build.errors || []).length && round < 2) {
  round++
  phase('Fix')
  const byFile = {}
  for (const e of build.errors) { (byFile[e.file] ||= []).push(e) }
  const files = Object.keys(byFile)
  log(`Fix round ${round}: ${build.errors.length} errors across ${files.length} file(s)`)
  await parallel(files.map((f) => () =>
    agent(
      `${CONVENTIONS}

\`next build\` failed with errors in this file:
File: ${f}
Errors:
${byFile[f].map((e) => `- line ${e.line ?? '?'}: ${e.message}`).join('\n')}

TASK: Read the file and fix ONLY these errors minimally. Preserve features + the fetch/static-fallback behaviour and React.createElement style. Fix imports as needed. Do not run next build.`,
      { label: `fix:${f.split('/').slice(-2).join('/')}`, phase: 'Fix' }
    )
  ))
  phase('Build')
  build = await agent(buildPrompt(`round ${round}`), { label: `build:r${round}`, schema: BUILD_SCHEMA })
  log(`After fix round ${round}: ${build.clean ? 'CLEAN' : `${(build.errors || []).length} errors remain`}`)
}

return {
  shared: { navRoutes: catalog.navRoutes, configKeys: catalog.configKeys },
  pages: pagesDone.map((r) => ({ file: r.file, status: r.status, apiRoutesUsed: r.apiRoutesUsed })),
  finalBuild: { clean: build.clean, errorCount: (build.errors || []).length, remainingErrors: build.errors, rawTail: build.rawTail },
}
