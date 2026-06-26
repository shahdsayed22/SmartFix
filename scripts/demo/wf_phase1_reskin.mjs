export const meta = {
  name: 'smartfix-phase1-reskin',
  description: 'SmartFix Phase 1: re-skin all 17 Flutter screens to the Arabic/RTL design, preserving all business logic; self-healing flutter analyze loop',
  phases: [
    { title: 'Align Widgets' },
    { title: 'Re-skin Screens' },
    { title: 'Analyze' },
    { title: 'Fix' },
  ],
}

const ROOT = process.env.SMARTFIX_ROOT || process.cwd()
const AR = `${ROOT}/design_reference/smartfix-service-tracking-app/project/ar`

const CONVENTIONS = `
SmartFix Phase 1 — Arabic/RTL re-skin. Canonical spec: ${ROOT}/SMARTFIX_BUILD_CONTRACT.md (§8 Flutter foundation, §9 RTL/i18n). Read it if unsure.

GOLDEN RULES — follow exactly:
1. NEVER break compilation and NEVER remove or alter business logic. Preserve every: method call, controller, TextEditingController, setState, async/await flow, Navigator push/pop/arguments, Provider/Consumer usage, Firebase calls, ApiService calls, form validation, error handling. RE-SKIN = change ONLY presentation: layout, spacing, colors, typography, icons, copy, and which widgets render. Behaviour must be identical.
2. EDIT ONLY your single assigned screen file. Do NOT modify anything under lib/widgets/, lib/theme/, lib/l10n/, lib/models/, lib/services/. You CONSUME them.
3. Arabic-first + RTL. Wrap NEW user-facing strings with tr(context, 'النص العربي') from lib/l10n/app_strings.dart (Read it first to confirm the exact signature/import). Use EdgeInsetsDirectional, AlignmentDirectional, start/end, TextAlign.start — never hardcoded left/right padding or alignment. The app is already wrapped in Directionality(rtl) at root, so use directional widgets.
4. Use the new theme. Colors via AppColors.* (brand/navy #14323B, primary #185B56, primaryLight/teal #1C8C8C, accent/gold #D98E2B, background #F4F7F7, surface #FFFFFF, plus success/warning/error/info + *Bg variants, and 'approval' #7A5AE0 for awaitingApproval). Radii AppColors.rCard(18)/rBtn(14)/rField(14). Fonts: the global theme already uses IBM Plex Sans Arabic — rely on Theme.of(context).textTheme; don't hardcode GoogleFonts unless matching an existing pattern in the file.
5. Prefer the existing sf_* shared widgets (catalog provided) over re-implementing buttons/fields/cards/badges/headers. Match the design's component look.
6. Keep the file analyzer-clean: every import used, add imports for anything newly used. No unused vars.

The visual target is the React/JSX Arabic prototype under ${AR}/. Mirror its visual output and UX, NOT its code structure (it's React; you write Flutter). Screenshots: ${ROOT}/design_reference/smartfix-service-tracking-app/project/screenshots/ar-*.png.
`

const CATALOG_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['widgets', 'notes'],
  properties: {
    widgets: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['name', 'file', 'usage'],
        properties: {
          name: { type: 'string' },
          file: { type: 'string' },
          usage: { type: 'string', description: 'one-line: constructor + key named params + when to use' },
        },
      },
    },
    helpers: { type: 'array', items: { type: 'string' }, description: 'global helpers like tr(context, ar), SnackBar/Dialog/Sheet helpers, with import path' },
    notes: { type: 'string' },
  },
}

const SCREEN_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['file', 'status', 'summary', 'logicPreserved'],
  properties: {
    file: { type: 'string' },
    status: { type: 'string', enum: ['done', 'partial', 'failed'] },
    summary: { type: 'string' },
    logicPreserved: { type: 'boolean' },
    sharedWidgetsUsed: { type: 'array', items: { type: 'string' } },
  },
}

const ANALYZE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['clean', 'errorCount', 'errors'],
  properties: {
    clean: { type: 'boolean', description: 'true if zero ERROR-severity issues (warnings/infos are OK)' },
    errorCount: { type: 'number' },
    warningCount: { type: 'number' },
    infoCount: { type: 'number' },
    errors: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['file', 'message'],
        properties: {
          file: { type: 'string' },
          line: { type: 'number' },
          message: { type: 'string' },
          code: { type: 'string' },
        },
      },
    },
  },
}

// ── Stage A: align shared widgets, produce catalog ──────────────────
phase('Align Widgets')
const catalog = await agent(
  `${CONVENTIONS}

TASK: Audit and align the shared Flutter widget set to the Arabic design system, then return a catalog screen-authors will consume.

1. Read the design components: ${AR}/core.jsx (Icon, Avatar, Btn, Field, StatusBar, Toast, Dialog, Sheet) and ${AR}/cards.jsx (cards, badges, category tile, status badge, etc.).
2. Read EVERY file in ${ROOT}/lib/widgets/*.dart and ${ROOT}/lib/l10n/app_strings.dart and ${ROOT}/lib/theme/app_colors.dart.
3. Make the widgets match the design visually (palette already lives in AppColors). ADDITIVE CHANGES ONLY: do NOT remove or rename any existing public class, constructor, or named parameter — other code depends on them. You MAY add optional params, new style variants, or new small helper widgets/functions (e.g. an SfToast/sheet/dialog helper) if the design needs one and it's missing.
4. Everything must stay analyzer-clean and compile. Run no destructive commands.

Return the catalog of shared widgets available for screen authors (name, file, one-line usage), the list of global helpers (e.g. tr(context, ar) and its import), and any notes screen authors must know.`,
  { label: 'align-widgets', schema: CATALOG_SCHEMA }
)
const catalogText = JSON.stringify(catalog, null, 2)
log(`Widget catalog ready: ${(catalog.widgets || []).length} shared widgets`)

// ── Stage B: re-skin each screen in parallel ────────────────────────
phase('Re-skin Screens')
const SCREENS = [
  { short: 'splash',        file: 'lib/screens/auth/splash_screen.dart',              ref: 'screens-auth.jsx → SplashScreen' },
  { short: 'login',         file: 'lib/screens/auth/login_screen.dart',               ref: 'screens-auth.jsx → LoginScreen (also LangToggle pattern)' },
  { short: 'register',      file: 'lib/screens/auth/register_screen.dart',            ref: 'screens-auth.jsx → RegisterScreen' },
  { short: 'forgot',        file: 'lib/screens/auth/forgot_password_screen.dart',     ref: 'screens-auth.jsx → ForgotScreen' },
  { short: 'custhome',      file: 'lib/screens/customer/customer_home_screen.dart',   ref: 'screens-customer.jsx → CustomerHomeTab + ServicesScreen (category grid)' },
  { short: 'report',        file: 'lib/screens/customer/report_issue_screen.dart',    ref: 'screens-customer.jsx → ReportIssueScreen (the multi-step report wizard)' },
  { short: 'issuedetail',   file: 'lib/screens/customer/issue_detail_screen.dart',    ref: 'screens-customer.jsx → IssueDetailScreen (status timeline + actions)' },
  { short: 'custprofile',   file: 'lib/screens/customer/customer_profile_screen.dart',ref: 'screens-misc.jsx → ProfileTab' },
  { short: 'workerhome',    file: 'lib/screens/worker/worker_home_screen.dart',       ref: 'screens-worker.jsx → WorkerJobsTab (available jobs list)' },
  { short: 'jobdetail',     file: 'lib/screens/worker/job_detail_screen.dart',        ref: 'screens-worker.jsx → JobDetailScreen + MakeOfferScreen' },
  { short: 'workerprofile', file: 'lib/screens/worker/worker_profile_screen.dart',    ref: 'screens-extra.jsx → TechProfileScreen and screens-misc.jsx → ProfileTab' },
  { short: 'chatlist',      file: 'lib/screens/chat/chat_list_screen.dart',           ref: 'screens-misc.jsx → MessagesTab' },
  { short: 'chat',          file: 'lib/screens/chat/chat_screen.dart',                ref: 'screens-misc.jsx → ChatScreen (chat bubbles, composer)' },
  { short: 'techmap',       file: 'lib/screens/map/technician_map_screen.dart',       ref: 'screens-misc.jsx → MapScreen + MiniMap (ar-map.png)' },
  { short: 'locpicker',     file: 'lib/screens/map/location_picker_screen.dart',      ref: 'screens-misc.jsx → MapScreen (location-picker variant)' },
  { short: 'settings',      file: 'lib/screens/profile/settings_screen.dart',         ref: 'screens-extra.jsx → SettingsScreen (SettingRow/GroupTitle/SwitchToggle). NOTE: fix the pre-existing deprecated activeColor warning here.' },
  { short: 'editprofile',   file: 'lib/screens/profile/edit_profile_screen.dart',     ref: 'screens-extra.jsx → EditProfileScreen' },
]

const screenResults = await parallel(SCREENS.map((s) => () =>
  agent(
    `${CONVENTIONS}

SHARED WIDGET CATALOG (consume these — do not redefine them):
${catalogText}

TASK: Re-skin exactly ONE screen to the Arabic/RTL design, preserving 100% of its logic.
Screen file (edit IN PLACE): ${ROOT}/${s.file}
Design reference: ${AR}/${s.ref}

Steps:
1. Read your screen file fully. Map out its state, controllers, async calls, navigation, and every piece of behaviour — you must keep all of it.
2. Read the matching design component(s) in the reference file above to understand the target Arabic/RTL look (layout, colors, copy, components).
3. Read ${ROOT}/lib/l10n/app_strings.dart for the exact tr() signature/import, and skim ${ROOT}/lib/theme/app_colors.dart for available colors.
4. Rewrite ONLY the presentation: use the new theme + AppColors, the sf_* shared widgets from the catalog, directional layout, and tr(context, 'عربي') for user-facing strings. Keep all logic wiring intact.
5. Ensure the file imports everything it uses and has no unused imports/vars. Do NOT run flutter (a later stage analyzes). Do NOT edit any other file.

Return the result for this screen.`,
    { label: `screen:${s.short}`, phase: 'Re-skin Screens', schema: SCREEN_SCHEMA }
  )
))
const done = screenResults.filter(Boolean)
log(`Re-skinned ${done.filter(r => r.status === 'done').length}/${SCREENS.length} screens`)

// ── Stage C/D: analyze + self-heal loop ─────────────────────────────
const analyzePrompt = (tag) => `Run \`flutter analyze\` in ${ROOT} (use Bash with a 300000 ms timeout; you may pass --no-pub since deps are already fetched). Parse the output.
Count ERROR, WARNING, and INFO severities separately. "clean" = TRUE only when there are ZERO error-severity issues (warnings and infos do NOT block).
Return every ERROR-severity issue with its file path (relative to ${ROOT} if possible), line, message, and lint code. Do not include warnings/infos in the errors array. Do not edit any files.${tag ? ` (run tag: ${tag})` : ''}`

phase('Analyze')
let analysis = await agent(analyzePrompt(''), { label: 'analyze', schema: ANALYZE_SCHEMA })
log(`Analyze: ${analysis.errorCount} errors, ${analysis.warningCount ?? '?'} warnings, ${analysis.infoCount ?? '?'} infos`)

let round = 0
while (!analysis.clean && (analysis.errors || []).length && round < 2) {
  round++
  phase('Fix')
  const byFile = {}
  for (const e of analysis.errors) { (byFile[e.file] ||= []).push(e) }
  const files = Object.keys(byFile)
  log(`Fix round ${round}: ${analysis.errors.length} errors across ${files.length} file(s)`)
  await parallel(files.map((f) => () =>
    agent(
      `${CONVENTIONS}

A \`flutter analyze\` run reported ERROR-severity issues in this file:
File: ${f}
Errors:
${byFile[f].map((e) => `- line ${e.line ?? '?'} [${e.code ?? ''}]: ${e.message}`).join('\n')}

TASK: Read the file and fix ONLY these errors with the MINIMAL change. Do NOT change business logic, remove features, or undo the Arabic/RTL styling. Keep imports consistent. If the fix requires a tiny touch to a shared file referenced by the error, that's allowed. Do not run flutter.`,
      { label: `fix:${f.split('/').pop()}`, phase: 'Fix' }
    )
  ))
  phase('Analyze')
  analysis = await agent(analyzePrompt(`round ${round}`), { label: `analyze:r${round}`, schema: ANALYZE_SCHEMA })
  log(`After fix round ${round}: ${analysis.errorCount} errors remain`)
}

return {
  catalog: (catalog.widgets || []).map((w) => w.name),
  screens: done.map((r) => ({ file: r.file, status: r.status, logicPreserved: r.logicPreserved })),
  finalAnalysis: { clean: analysis.clean, errorCount: analysis.errorCount, warningCount: analysis.warningCount, infoCount: analysis.infoCount, remainingErrors: analysis.errors },
}
