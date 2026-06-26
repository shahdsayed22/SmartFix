export const meta = {
  name: 'smartfix-phase2-features',
  description: 'SmartFix Phase 2: wire functional systems end-to-end (payments, notifications, reviews, tickets+chatbot, NLP, worker-gating, completion-approval) into the Flutter app; self-healing flutter analyze loop',
  phases: [
    { title: 'New Screens' },
    { title: 'Wire Existing' },
    { title: 'Analyze' },
    { title: 'Fix' },
  ],
}

const ROOT = process.env.SMARTFIX_ROOT || process.cwd()
const AR = `${ROOT}/design_reference/smartfix-service-tracking-app/project/ar`

const CONVENTIONS = `
SmartFix Phase 2 — wire functional systems end-to-end into the Flutter mobile app. Canonical spec: ${ROOT}/SMARTFIX_BUILD_CONTRACT.md (§4 models, §5 routes, §6 libs, §7 notification event keys). Phase 1 (Arabic/RTL re-skin of all 17 screens) is DONE — your work MUST match that visual style.

ENVIRONMENT FACTS (verified):
- State mgmt = Provider. Current user: \`context.read<AuthService>().currentUser\` → AppUser? (fields: uid, name, phone, role (UserRole enum), skills (List<String> — for workers these are the service categories). AuthService also exposes \`.uid\`. Import: lib/services/auth_service.dart, lib/models/user_model.dart.
- Services are plain classes instantiated directly: \`final api = ApiService();\`, \`final jobService = JobService();\` (see any existing screen for the exact pattern).
- ApiService (${ROOT}/lib/services/api_service.dart) ALREADY contains every method you need — READ it for exact signatures/params/return shapes before calling: getTickets/createTicket/getTicket/replyTicket/updateTicket, getReviews/createReview, getNotifications/markNotificationRead, createPayment/getPayment/updatePaymentStatus, getCommissionSettings, classifyText, requestCompletion/approveCompletion/rejectCompletion, getAvailableJobsForWorker, verifyTechnician/setTechnicianCategories. They return Map<String,dynamic>/List<Map>; map to models with fromJson.
- Dart models exist — READ for field names before use: ${ROOT}/lib/models/{ticket,review,payment,app_notification,commission_settings,issue_model,user_model}.dart. Issue class = \`Issue\` (id, customerId, customerName, title, category:IssueCategory, status:IssueStatus, price, technicianId, ...).
- NLP: ${ROOT}/lib/services/category_service.dart → \`detectCategory(text)\` (local mirror) + \`kCategories\`. Backend equivalent: ApiService.classifyText(text).
- Payments run in MOCK mode when no MyFatoorah keys (createPayment returns a paymentUrl and the mock flow resolves to 'paid'). Never require real keys.

GOLDEN RULES — follow exactly:
1. NEVER break compilation. In files you edit, preserve ALL existing business logic (controllers, async flows, Navigator, Provider, Firebase, validation). For NEW screens, write REAL logic: actual ApiService calls, loading/empty/error states, and navigation — not placeholders.
2. Edit ONLY your assigned file(s). Consume shared widgets/services/models; do not modify them. (Your own new files are yours to create.)
3. Arabic-first + RTL: wrap user-facing strings in tr(context, 'النص العربي') (import lib/l10n/app_strings.dart — read it for the exact signature). Use EdgeInsetsDirectional, AlignmentDirectional, start/end, TextAlign.start.
4. Reuse the Phase-1 theme + AppColors.* + the sf_* shared widgets: SmartButton, SmartTextField, SmartCard, SfGradientHeader, SfSectionCard, SfStatCard, SfEmptyState, SfSkeletonCard, SfStatusBadge, SfUrgencyPill, SfChatBubble, SfStars, SfStarInput, SfToast, SfDialog, SfSheet, SfIssueCard, SfCatTile, SfAvatar. READ a neighboring Phase-1 screen as a style template before writing.
5. Every data screen needs loading (SfSkeletonCard) + empty (SfEmptyState) + error states. Keep the file analyzer-clean (no unused imports/vars/fields).
6. Visual target = the Arabic React prototype under ${AR}/ (mirror visual output + UX, not its code).

CANONICAL NEW-SCREEN CONSTRUCTORS — every agent must match these EXACTLY (cross-referenced):
- NotificationsScreen()                         @ lib/screens/notifications/notifications_screen.dart
- ChatbotScreen()                               @ lib/screens/chat/chatbot_screen.dart
- SupportTicketsScreen()                        @ lib/screens/support/support_tickets_screen.dart
- TicketDetailScreen({required String ticketId})@ lib/screens/support/ticket_detail_screen.dart
- PaymentScreen({required Issue issue})         @ lib/screens/payment/payment_screen.dart
- RatingScreen({required Issue issue})          @ lib/screens/payment/rating_screen.dart
- WalletScreen()                                @ lib/screens/payment/wallet_screen.dart
- InvoicesScreen()                              @ lib/screens/payment/invoices_screen.dart
- EarningsScreen()                              @ lib/screens/payment/earnings_screen.dart
Use relative imports in the same style as existing screens.
`

const NEW_SCREEN_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['files', 'status', 'summary'],
  properties: {
    files: { type: 'array', items: { type: 'string' } },
    status: { type: 'string', enum: ['done', 'partial', 'failed'] },
    summary: { type: 'string' },
    apiMethodsUsed: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
}
const WIRE_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['file', 'status', 'summary', 'logicPreserved'],
  properties: {
    file: { type: 'string' },
    status: { type: 'string', enum: ['done', 'partial', 'failed'] },
    summary: { type: 'string' },
    logicPreserved: { type: 'boolean' },
    navigatesTo: { type: 'array', items: { type: 'string' } },
  },
}
const ANALYZE_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['clean', 'errorCount', 'errors'],
  properties: {
    clean: { type: 'boolean' },
    errorCount: { type: 'number' },
    warningCount: { type: 'number' },
    infoCount: { type: 'number' },
    errors: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false, required: ['file', 'message'],
        properties: { file: { type: 'string' }, line: { type: 'number' }, message: { type: 'string' }, code: { type: 'string' } },
      },
    },
  },
}

// ── Stage 1: build NEW feature screens (parallel, independent files) ──
phase('New Screens')
const NEW_SCREENS = [
  { short: 'notifications', file: 'lib/screens/notifications/notifications_screen.dart',
    task: `Build NotificationsScreen() listing the current user's notifications (ApiService.getNotifications for currentUser.uid; mark read via markNotificationRead — one + mark-all). Use AppNotification model (tone/icon/title/body/read/createdAt). Tone→color via AppColors (info/success/warning/danger). ALSO create lib/providers/notification_provider.dart: a ChangeNotifier holding {List<AppNotification> items, int unread} with load(userId), markRead(id), markAllRead(userId) — the main.dart agent registers it later. Design ref: ${AR}/screens-extra.jsx → NotificationsScreen.` },
  { short: 'chatbot', file: 'lib/screens/chat/chatbot_screen.dart',
    task: `Build ChatbotScreen(): a guided Arabic triage chat (use SfChatBubble). Ask for the problem; run category_service.detectCategory(text) (and/or ApiService.classifyText) to detect the service category + urgency (mirror design guessCategory/guessUrgency); collect a subject + description; then create a support ticket via ApiService.createTicket(source:'chatbot', seed messages) and navigate to TicketDetailScreen(ticketId: <new id>). Design ref: ${AR}/screens-misc.jsx → ChatbotScreen.` },
  { short: 'payment', file: 'lib/screens/payment/payment_screen.dart',
    task: `Build PaymentScreen({required Issue issue}): fetch CommissionSettings (ApiService.getCommissionSettings) and show the invoice breakdown (base = issue.price (fallback estimatedCost) → platformFee 10% → VAT 14% → total) matching §3 of the contract. Provide method selection (card/meeza/fawry/wallet) and a Pay button that calls ApiService.createPayment({issueId, customerId, technicianId, base, ...}) (mock mode returns paymentUrl + resolves paid). On success call updatePaymentStatus('paid') and pop with success. Use the Payment + CommissionSettings models. Design ref: ${AR}/screens-flow.jsx → PaymentScreen.` },
  { short: 'rating', file: 'lib/screens/payment/rating_screen.dart',
    task: `Build RatingScreen({required Issue issue}): star input (SfStarInput), suggested tag chips, optional comment (SmartTextField). Submit via ApiService.createReview({issueId: issue.id, technicianId: issue.technicianId, customerId, rating, tags, comment, category}). Handle the 409 "already rated" case gracefully (SfToast). Design ref: ${AR}/screens-flow.jsx → RatingScreen.` },
  { short: 'tickets', file: 'lib/screens/support/support_tickets_screen.dart',
    task: `Build SupportTicketsScreen(): list the current user's tickets (ApiService.getTickets({customerId})) with subject, category, status badge (SfStatusBadge), last-updated. A button to create a new ticket (simple sheet/form → ApiService.createTicket) and an entry "محادثة المساعد الذكي" → ChatbotScreen(). Tap a ticket → TicketDetailScreen(ticketId). Use Ticket model. loading/empty/error states.` },
  { short: 'ticketdetail', file: 'lib/screens/support/ticket_detail_screen.dart',
    task: `Build TicketDetailScreen({required String ticketId}): load ApiService.getTicket(ticketId); render the embedded messages thread (customer/admin/bot) with SfChatBubble (align by senderRole); a composer that calls ApiService.replyTicket(ticketId, text) and appends. Show status; allow nothing destructive. Use Ticket model (embedded messages).` },
  { short: 'wallet', file: 'lib/screens/payment/wallet_screen.dart',
    task: `Build WalletScreen(): a wallet summary for the current user — balance/spend cards + recent transactions derived from the user's payments (ApiService.getPayment / a payments list if available; otherwise present an aggregate from getNotifications/payments you can fetch). Keep it wired but resilient with empty state. Design ref: ${AR}/screens-extra.jsx → WalletScreen.` },
  { short: 'invoices', file: 'lib/screens/payment/invoices_screen.dart',
    task: `Build InvoicesScreen(): list the customer's invoices (paid Payment records). Each row → total + status + date; tapping expands the base/fee/VAT/total breakdown. Use the Payment model. loading/empty/error. Design ref: ${AR}/screens-extra.jsx → InvoicesScreen.` },
  { short: 'earnings', file: 'lib/screens/payment/earnings_screen.dart',
    task: `Build EarningsScreen() for a worker: total payout, platform commission, and a list of completed jobs' payouts (Payment.payoutAmount/workerCommission) for currentUser.uid as technician. Use Payment + CommissionSettings. SfStatCard for totals. Design ref: ${AR}/screens-extra.jsx → EarningsScreen.` },
]

const newResults = await parallel(NEW_SCREENS.map((s) => () =>
  agent(
    `${CONVENTIONS}

TASK — create a NEW feature screen with full real logic.
Primary file: ${ROOT}/${s.file}
${s.task}

Steps: (1) Read api_service.dart for the exact signatures of the methods you call, and the model file(s) for field names. (2) Read one neighboring Phase-1 screen for the visual style + tr() usage. (3) Write the screen (and any noted extra file) with loading/empty/error states, Arabic/RTL, sf_* widgets. (4) Do NOT run flutter; do NOT edit other files. Use the canonical constructor signature EXACTLY.`,
    { label: `new:${s.short}`, phase: 'New Screens', schema: NEW_SCREEN_SCHEMA }
  )
))
const newDone = newResults.filter(Boolean)
log(`New screens: ${newDone.filter((r) => r.status === 'done').length}/${NEW_SCREENS.length} done`)

// ── Stage 2: wire new screens + flows into EXISTING screens ──────────
phase('Wire Existing')
const WIRE = [
  { short: 'reportNLP', file: 'lib/screens/customer/report_issue_screen.dart',
    task: `Add NLP category auto-detection to the report wizard: as the user enters the title/description, run category_service.detectCategory(text) (local) to suggest a category, and show a dismissable "الفئة المقترحة" chip that pre-selects that category when tapped. Optionally confirm with ApiService.classifyText. Preserve ALL existing Form/validation/_submit/createIssue/location logic exactly.` },
  { short: 'workerGating', file: 'lib/screens/worker/worker_home_screen.dart',
    task: `Make the available-jobs feed skill-gated: load via ApiService.getAvailableJobsForWorker(currentUser.skills) so a worker only sees pending, unassigned jobs in their categories; map results to Issue and render with the existing SfIssueCard layout. Preserve refresh/empty/loading and all existing logic.` },
  { short: 'workerComplete', file: 'lib/screens/worker/job_detail_screen.dart',
    task: `Add a worker "أبلغ عن إتمام العمل" (request completion) action visible when the job is inProgress: collect a completion summary (and optional photo URLs) via a sheet, then call ApiService.requestCompletion(issueId, summary, photos). On success reflect status awaitingApproval. Preserve all existing accept/make-offer/logic.` },
  { short: 'approvalFlow', file: 'lib/screens/customer/issue_detail_screen.dart',
    task: `Wire the customer post-job lifecycle: when status==awaitingApproval show Approve/Reject (ApiService.approveCompletion / rejectCompletion(reason via a sheet)); when status==awaitingPayment show "ادفع الآن" → Navigator push PaymentScreen(issue: currentIssue); when status==completed and the job has no review yet show "قيّم الفني" → push RatingScreen(issue: currentIssue). If a statusHistory exists, render it in the timeline. Preserve existing cancel/chat/navigation logic.` },
  { short: 'custHome', file: 'lib/screens/customer/customer_home_screen.dart',
    task: `Add a notifications bell with an unread badge (read NotificationProvider, or fetch ApiService.getNotifications for currentUser.uid) that pushes NotificationsScreen(); and a support/help entry that pushes SupportTicketsScreen(). Preserve all existing home logic and layout.` },
  { short: 'custProfile', file: 'lib/screens/customer/customer_profile_screen.dart',
    task: `Add profile menu rows (SfProfileRow style) navigating to: WalletScreen(), InvoicesScreen(), SupportTicketsScreen(), NotificationsScreen(). Preserve existing profile/logout/logic.` },
  { short: 'workerProfile', file: 'lib/screens/worker/worker_profile_screen.dart',
    task: `Add profile menu rows navigating to: EarningsScreen(), NotificationsScreen(), SupportTicketsScreen(). Preserve all existing worker profile logic (verification badge, skills, etc.).` },
  { short: 'mainProvider', file: 'lib/main.dart',
    task: `Register the new NotificationProvider (created at lib/providers/notification_provider.dart by the notifications screen) in the existing MultiProvider by adding one ChangeNotifierProvider entry. Do NOT remove or reorder AuthService/LocaleProvider, Firebase initialization, the RTL Directionality builder, locale/delegates, or AuthService auto-login. Add the import.` },
]

const wireResults = await parallel(WIRE.map((w) => () =>
  agent(
    `${CONVENTIONS}

TASK — wire features into an EXISTING screen. Edit IN PLACE, preserving 100% of current logic.
File: ${ROOT}/${w.file}
${w.task}

Steps: (1) Read the file fully and map its existing logic — keep all of it. (2) Read api_service.dart for exact signatures and the new screens you navigate to (canonical constructors above). (3) Make the additions using sf_* widgets + tr() + AppColors, matching the Phase-1 style. (4) Keep imports correct; no unused symbols. Do NOT run flutter; do NOT edit other files.`,
    { label: `wire:${w.short}`, phase: 'Wire Existing', schema: WIRE_SCHEMA }
  )
))
const wireDone = wireResults.filter(Boolean)
log(`Wiring: ${wireDone.filter((r) => r.status === 'done').length}/${WIRE.length} done`)

// ── Stage 3: analyze + self-heal ────────────────────────────────────
const analyzePrompt = (tag) => `Run \`flutter analyze\` in ${ROOT} (Bash, 300000 ms timeout; --no-pub is fine, deps are fetched). Parse output. Count ERROR/WARNING/INFO separately. "clean" = TRUE only when ZERO error-severity issues. Return each ERROR with file (relative to ${ROOT} if possible), line, message, lint code. Exclude warnings/infos from errors[]. Do not edit files.${tag ? ` (run ${tag})` : ''}`

phase('Analyze')
let analysis = await agent(analyzePrompt(''), { label: 'analyze', schema: ANALYZE_SCHEMA })
log(`Analyze: ${analysis.errorCount} errors, ${analysis.warningCount ?? '?'} warnings, ${analysis.infoCount ?? '?'} infos`)

let round = 0
while (!analysis.clean && (analysis.errors || []).length && round < 3) {
  round++
  phase('Fix')
  const byFile = {}
  for (const e of analysis.errors) { (byFile[e.file] ||= []).push(e) }
  const files = Object.keys(byFile)
  log(`Fix round ${round}: ${analysis.errors.length} errors across ${files.length} file(s)`)
  await parallel(files.map((f) => () =>
    agent(
      `${CONVENTIONS}

\`flutter analyze\` reported ERROR-severity issues in this file:
File: ${f}
Errors:
${byFile[f].map((e) => `- line ${e.line ?? '?'} [${e.code ?? ''}]: ${e.message}`).join('\n')}

TASK: Read the file and fix ONLY these errors with the minimal change. Do NOT remove features or business logic, and keep the Arabic/RTL styling. Ensure cross-screen constructors match the canonical signatures. Fix imports as needed. Do not run flutter.`,
      { label: `fix:${f.split('/').pop()}`, phase: 'Fix' }
    )
  ))
  phase('Analyze')
  analysis = await agent(analyzePrompt(`round ${round}`), { label: `analyze:r${round}`, schema: ANALYZE_SCHEMA })
  log(`After fix round ${round}: ${analysis.errorCount} errors remain`)
}

return {
  newScreens: newDone.map((r) => ({ files: r.files, status: r.status })),
  wiring: wireDone.map((r) => ({ file: r.file, status: r.status, logicPreserved: r.logicPreserved })),
  finalAnalysis: { clean: analysis.clean, errorCount: analysis.errorCount, warningCount: analysis.warningCount, infoCount: analysis.infoCount, remainingErrors: analysis.errors },
}
