import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../models/issue_model.dart';
import '../../widgets/sf_icons.dart';
import '../../widgets/sf_cards.dart';
import '../../widgets/ai_analysis_card.dart';
import '../../widgets/sf_avatar.dart';
import '../../widgets/sf_stars.dart';
import '../../widgets/sf_timeline.dart';
import '../../widgets/sf_states.dart';
import '../../widgets/sf_feedback.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/smart_text_field.dart';
import '../../widgets/verified_badge.dart';
import '../../services/api_service.dart';
import '../chat/chat_screen.dart';
import '../payment/payment_screen.dart';
import '../payment/rating_screen.dart';
import '../customer/approval_screen.dart';
import '../customer/tracking_screen.dart';
import '../customer/dispute_screen.dart';

class IssueDetailScreen extends StatefulWidget {
  final Issue issue;

  const IssueDetailScreen({super.key, required this.issue});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  final JobService _jobService = JobService();
  final ApiService _api = ApiService();

  /// Live backend lifecycle status string for this issue. The Dart [Issue]
  /// enum only models {pending, assigned, inProgress, completed, cancelled},
  /// so the richer post-job states (`awaitingApproval`, `awaitingPayment`,
  /// `disputed`, `rejected`) are read straight from the API as a raw string.
  String? _liveStatus;

  /// Reason a previously-requested completion was rejected (if any).
  String? _rejectionReason;

  /// Worker's completion summary, surfaced when awaiting the customer's review.
  String? _completionSummary;

  /// Backend status-history entries (`{status, at, by}`) for the timeline.
  List<Map<String, dynamic>> _statusHistory = const [];

  /// Whether the customer has already left a review for this completed job.
  bool _hasReview = false;

  /// Issue re-parsed from the authoritative backend record — carries the AI
  /// triage fields (urgency/anomaly/suggested-category/classification) for the
  /// "AI Analysis" panel. Falls back to [widget.issue] when the fetch fails.
  Issue? _liveIssue;

  bool _loadingLifecycle = true;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _loadLifecycle();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  /// Fetch the authoritative post-job state (status, history, rejection reason,
  /// completion summary) plus whether a review already exists. Failures degrade
  /// gracefully to the local [Issue] data so the screen always renders.
  Future<void> _loadLifecycle() async {
    final issue = widget.issue;
    try {
      final issues = await _api.getIssues(customerId: issue.customerId);
      Map<String, dynamic>? raw;
      for (final m in issues) {
        final mid = (m['id'] ?? m['_id'])?.toString();
        if (mid == issue.id) {
          raw = m;
          break;
        }
      }

      bool hasReview = false;
      try {
        final reviews = await _api.getReviews(customerId: issue.customerId);
        hasReview = reviews.any((r) => (r['issueId']?.toString()) == issue.id);
      } catch (_) {
        // Reviews are optional context; ignore fetch errors.
      }

      if (!mounted) return;
      setState(() {
        _liveIssue = raw != null ? Issue.fromMap(raw) : null;
        _liveStatus = raw?['status']?.toString();
        _rejectionReason = raw?['rejectionReason']?.toString();
        _completionSummary = raw?['completionSummary']?.toString();
        _statusHistory =
            (raw?['statusHistory'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            const [];
        _hasReview = hasReview;
        _loadingLifecycle = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingLifecycle = false);
    }
  }

  bool get _isAwaitingApproval => _liveStatus == 'awaitingApproval';
  bool get _isAwaitingPayment => _liveStatus == 'awaitingPayment';
  bool get _isCompleted =>
      _liveStatus == 'completed' ||
      widget.issue.status == IssueStatus.completed;

  void _openChat(BuildContext context, Issue currentIssue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ChatScreen(
              issueId: currentIssue.id,
              issueTitle: currentIssue.title,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobService = _jobService;
    final currentUser = context.read<AuthService>().currentUser;

    return Builder(
      builder: (context) {
        final currentIssue = widget.issue;
        final cfg = sfCategory(currentIssue.category);
        final catColor = cfg.color;

        // Customer can cancel any time before work actually starts
        // (pending OR assigned). Once in-progress/completed it's locked.
        final canCancel =
            (currentIssue.status == IssueStatus.pending ||
                    currentIssue.status == IssueStatus.assigned) &&
            currentUser?.uid == currentIssue.customerId;
        final hasWorker = currentIssue.assignedWorkerId != null;
        final isOwner = currentUser?.uid == currentIssue.customerId;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Category-colored hero header ───────────────────────
              _CategoryHeader(
                issue: currentIssue,
                color: catColor,
                icon: cfg.icon,
                onBack: () => Navigator.pop(context),
                onChat:
                    hasWorker ? () => _openChat(context, currentIssue) : null,
              ),

              // ── Scrollable body ────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 32)
                      .resolve(Directionality.of(context)),
                  children: [
                    // Description
                    SfSectionCard(
                      icon: sfIcon('align-right'),
                      title: tr(context, 'الوصف'),
                      child: Text(
                        currentIssue.description,
                        textAlign: TextAlign.start,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.7,
                          color: AppColors.darkGrey,
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
                    const SizedBox(height: 14),

                    // AI Analysis (heuristic/anomaly baseline)
                    AiAnalysisCard(issue: _liveIssue ?? currentIssue),

                    // Location
                    SfSectionCard(
                          icon: sfIcon('map-pin'),
                          title: tr(context, 'الموقع'),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  sfIcon('navigation'),
                                  color: AppColors.teal,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentIssue.address.isNotEmpty
                                          ? currentIssue.address
                                          : tr(context, 'تم تحديد الموقع'),
                                      textAlign: TextAlign.start,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.charcoal,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        '${currentIssue.latitude.toStringAsFixed(4)}, '
                                        '${currentIssue.longitude.toStringAsFixed(4)}',
                                        textAlign: TextAlign.start,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontSize: 12,
                                              color: AppColors.midGrey,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.05),
                    const SizedBox(height: 14),

                    // Assigned technician
                    if (currentIssue.assignedWorkerName != null) ...[
                      SfSectionCard(
                            icon: sfIcon('hard-hat'),
                            title: tr(context, 'الفني المُعيَّن'),
                            child: Row(
                              children: [
                                SfAvatar(
                                  name: currentIssue.assignedWorkerName!,
                                  size: 46,
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              currentIssue.assignedWorkerName!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.start,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.charcoal,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const VerifiedBadge(
                                            isVerified: true,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const SfStars(value: 4.8, size: 12),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              '4.8 · ${tr(context, 'متخصص')} ${cfg.label}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.start,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontSize: 12.5,
                                                    color: AppColors.midGrey,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (hasWorker) ...[
                                  const SizedBox(width: 8),
                                  _RoundIconButton(
                                    icon: sfIcon('message-circle'),
                                    bg: AppColors.navySoft,
                                    fg: AppColors.navy,
                                    onTap:
                                        () => _openChat(context, currentIssue),
                                  ),
                                ],
                              ],
                            ),
                          )
                          .animate(delay: 200.ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.05),
                      const SizedBox(height: 14),
                    ],

                    // Worker's completion summary — shown while the customer
                    // is asked to approve the finished work.
                    if (_isAwaitingApproval &&
                        (_completionSummary?.trim().isNotEmpty ?? false)) ...[
                      SfSectionCard(
                            icon: sfIcon('circle-check'),
                            title: tr(context, 'ملخص العمل المُنجَز'),
                            child: Text(
                              _completionSummary!.trim(),
                              textAlign: TextAlign.start,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontSize: 14,
                                    height: 1.7,
                                    color: AppColors.darkGrey,
                                  ),
                            ),
                          )
                          .animate(delay: 250.ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.05),
                      const SizedBox(height: 14),
                    ],

                    // Previous rejection reason, if the work was sent back.
                    if ((_rejectionReason?.trim().isNotEmpty ?? false) &&
                        !_isAwaitingApproval) ...[
                      _NoticeBanner(
                            icon: sfIcon('alert-triangle'),
                            color: AppColors.warning,
                            bg: AppColors.warningBg,
                            title: tr(context, 'تم رفض إتمام العمل سابقًا'),
                            body: _rejectionReason!.trim(),
                          )
                          .animate(delay: 250.ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.05),
                      const SizedBox(height: 14),
                    ],

                    // Timeline
                    SfSectionCard(
                          icon: sfIcon('git-commit-horizontal'),
                          title: tr(context, 'مسار البلاغ'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SfTimeline(
                                currentIssue.status,
                                assignedName: currentIssue.assignedWorkerName,
                                reportedAgo: timeago.format(
                                  currentIssue.createdAt,
                                ),
                                updatedAgo: timeago.format(
                                  currentIssue.updatedAt,
                                ),
                              ),
                              if (_statusHistory.isNotEmpty)
                                _StatusHistory(entries: _statusHistory),
                            ],
                          ),
                        )
                        .animate(delay: 300.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.05),
                    const SizedBox(height: 20),

                    // ── Post-job lifecycle actions (owner only) ──────────
                    // While the authoritative backend status is loading we
                    // show a skeleton so the wrong CTA never flashes.
                    if (isOwner && _loadingLifecycle) const SfSkeletonCard(),
                    // While the technician is on the way / working, the
                    // customer can open the live tracking screen.
                    if (isOwner &&
                        !_loadingLifecycle &&
                        (currentIssue.status == IssueStatus.assigned ||
                            currentIssue.status == IssueStatus.inProgress)) ...[
                      SmartButton(
                        label: tr(context, 'تتبّع الفني'),
                        icon: sfIcon('navigation'),
                        width: double.infinity,
                        onPressed: () => _goToTracking(currentIssue),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (isOwner && !_loadingLifecycle && _isAwaitingApproval) ...[
                      // Prompt: the worker reported completion; ask the
                      // customer to confirm the work is finished.
                      _NoticeBanner(
                            icon: sfIcon('badge-check'),
                            color: AppColors.success,
                            bg: AppColors.successBg,
                            title: tr(
                              context,
                              'الفني أبلغ عن إتمام العمل',
                            ),
                            body: tr(
                              context,
                              'يرجى مراجعة العمل والموافقة على إتمامه.',
                            ),
                          )
                          .animate(delay: 150.ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.05),
                      const SizedBox(height: 12),
                      // Open the dedicated approval review screen.
                      SmartButton(
                        label: tr(context, 'مراجعة العمل المُنجَز'),
                        icon: sfIcon('badge-check'),
                        width: double.infinity,
                        onPressed: () => _goToApproval(currentIssue),
                      ),
                      const SizedBox(height: 12),
                      SmartButton(
                        label: tr(context, 'الموافقة على إتمام العمل'),
                        icon: sfIcon('circle-check'),
                        width: double.infinity,
                        isLoading: _actionBusy,
                        onPressed:
                            _actionBusy
                                ? null
                                : () => _approveCompletion(currentIssue),
                      ),
                      const SizedBox(height: 12),
                      SmartButton(
                        label: tr(context, 'رفض وإعادة العمل'),
                        icon: sfIcon('x-circle'),
                        isOutlined: true,
                        width: double.infinity,
                        onPressed:
                            _actionBusy
                                ? null
                                : () => _rejectCompletion(currentIssue),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (isOwner && !_loadingLifecycle && _isAwaitingPayment) ...[
                      SmartButton(
                        label: tr(context, 'ادفع الآن'),
                        icon: sfIcon('wallet'),
                        width: double.infinity,
                        onPressed: () => _goToPayment(currentIssue),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (isOwner &&
                        !_loadingLifecycle &&
                        _isCompleted &&
                        !_isAwaitingApproval &&
                        !_isAwaitingPayment &&
                        !_hasReview) ...[
                      SmartButton(
                        label: tr(context, 'قيّم الفني'),
                        icon: sfIcon('star'),
                        width: double.infinity,
                        onPressed: () => _goToRating(currentIssue),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Once the job is completed, the customer can raise a
                    // dispute / report a problem with the finished work.
                    if (isOwner &&
                        !_loadingLifecycle &&
                        _isCompleted &&
                        !_isAwaitingApproval &&
                        !_isAwaitingPayment) ...[
                      SmartButton(
                        label: tr(context, 'الإبلاغ عن مشكلة'),
                        icon: sfIcon('alert-triangle'),
                        isOutlined: true,
                        width: double.infinity,
                        onPressed: () => _goToDispute(currentIssue),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Actions
                    if (canCancel)
                      SmartButton(
                        label: tr(context, 'إلغاء البلاغ'),
                        icon: sfIcon('x-circle'),
                        isOutlined: true,
                        width: double.infinity,
                        onPressed:
                            () => _confirmCancel(
                              context,
                              jobService,
                              currentIssue,
                            ),
                      ),
                    if (hasWorker) ...[
                      if (canCancel) const SizedBox(height: 12),
                      SmartButton(
                        label:
                            '${tr(context, 'مراسلة')} ${currentIssue.assignedWorkerName!.split(' ').first}',
                        icon: sfIcon('message-circle'),
                        width: double.infinity,
                        onPressed: () => _openChat(context, currentIssue),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    JobService jobService,
    Issue currentIssue,
  ) async {
    final confirm = await SfDialog.confirm(
      context,
      title: tr(context, 'إلغاء هذا البلاغ؟'),
      body: tr(
        context,
        'سيؤدي ذلك إلى سحب طلب الصيانة. لا يمكن التراجع عن هذا الإجراء.',
      ),
      confirmLabel: tr(context, 'إلغاء البلاغ'),
      cancelLabel: tr(context, 'تراجع'),
      tone: SfTone.error,
      icon: sfIcon('alert-triangle'),
    );
    if (confirm == true) {
      await jobService.cancelIssue(currentIssue.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  /// Customer approves the worker's completion → backend moves the issue to
  /// `awaitingPayment`. On success we refresh the lifecycle so the "Pay now"
  /// CTA appears in place of the approve/reject pair.
  Future<void> _approveCompletion(Issue currentIssue) async {
    if (_actionBusy) return;
    final by = context.read<AuthService>().currentUser?.uid;
    setState(() => _actionBusy = true);
    try {
      await _api.approveCompletion(currentIssue.id, by: by);
      if (!mounted) return;
      SfToast.show(
        context,
        tr(context, 'تمت الموافقة، يمكنك الدفع الآن'),
        tone: SfTone.success,
      );
      await _loadLifecycle();
    } catch (_) {
      if (!mounted) return;
      SfToast.show(
        context,
        tr(context, 'تعذّرت الموافقة، حاول مرة أخرى'),
        tone: SfTone.error,
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  /// Customer rejects the completion. We collect a reason in a bottom sheet,
  /// then call [ApiService.rejectCompletion] so the job returns to inProgress.
  Future<void> _rejectCompletion(Issue currentIssue) async {
    if (_actionBusy) return;
    final by = context.read<AuthService>().currentUser?.uid;
    final reason = await _askRejectionReason();
    if (reason == null || reason.trim().isEmpty) return;
    setState(() => _actionBusy = true);
    try {
      await _api.rejectCompletion(
        currentIssue.id,
        rejectionReason: reason.trim(),
        by: by,
      );
      if (!mounted) return;
      SfToast.show(
        context,
        tr(context, 'تم إرسال طلب إعادة العمل للفني'),
        tone: SfTone.warning,
      );
      await _loadLifecycle();
    } catch (_) {
      if (!mounted) return;
      SfToast.show(
        context,
        tr(context, 'تعذّر إرسال الرفض، حاول مرة أخرى'),
        tone: SfTone.error,
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  /// Bottom sheet that captures the customer's rejection reason. Returns the
  /// entered text, or `null` if dismissed.
  Future<String?> _askRejectionReason() {
    final controller = TextEditingController();
    return SfSheet.show<String>(
      context,
      builder:
          (sheetCtx) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(sheetCtx, 'سبب رفض إتمام العمل'),
                textAlign: TextAlign.start,
                style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  sheetCtx,
                  'وضّح ما الذي يحتاج إلى إصلاح حتى يعيد الفني العمل.',
                ),
                textAlign: TextAlign.start,
                style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.midGrey,
                ),
              ),
              const SizedBox(height: 16),
              SmartTextField(
                controller: controller,
                label: tr(sheetCtx, 'سبب الرفض'),
                hint: tr(sheetCtx, 'اكتب سبب الرفض هنا...'),
                maxLines: 4,
              ),
              const SizedBox(height: 18),
              SmartButton(
                label: tr(sheetCtx, 'إرسال الرفض'),
                icon: sfIcon('x-circle'),
                isOutlined: true,
                width: double.infinity,
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    SfToast.show(
                      sheetCtx,
                      tr(sheetCtx, 'الرجاء كتابة سبب الرفض'),
                      tone: SfTone.warning,
                    );
                    return;
                  }
                  Navigator.of(sheetCtx).pop(text);
                },
              ),
            ],
          ),
    );
  }

  /// Navigate to the checkout screen, then refresh the lifecycle on return so
  /// a successful payment surfaces the "Rate technician" CTA.
  Future<void> _goToPayment(Issue currentIssue) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(issue: currentIssue)),
    );
    if (mounted) await _loadLifecycle();
  }

  /// Navigate to the rating screen, then refresh so the CTA disappears once a
  /// review has been submitted.
  Future<void> _goToRating(Issue currentIssue) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RatingScreen(issue: currentIssue)),
    );
    if (mounted) await _loadLifecycle();
  }

  /// Open the live technician tracking screen while the job is on the way /
  /// in progress.
  void _goToTracking(Issue currentIssue) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrackingScreen(issue: currentIssue)),
    );
  }

  /// Open the dedicated approval review screen, then refresh the lifecycle on
  /// return so the CTAs reflect any decision made there.
  Future<void> _goToApproval(Issue currentIssue) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ApprovalScreen(issue: currentIssue)),
    );
    if (mounted) await _loadLifecycle();
  }

  /// Open the dispute screen so the customer can report a problem with a
  /// completed job, then refresh the lifecycle on return.
  Future<void> _goToDispute(Issue currentIssue) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DisputeScreen(issue: currentIssue)),
    );
    if (mounted) await _loadLifecycle();
  }
}

/// Category-colored hero header for the issue detail screen. Mirrors the
/// prototype's colored header: gradient from the category color, a faint
/// decorative circle, back + chat actions, a category tile + title, and a
/// row of status / urgency pills with a relative timestamp.
class _CategoryHeader extends StatelessWidget {
  final Issue issue;
  final Color color;
  final IconData icon;
  final VoidCallback onBack;
  final VoidCallback? onChat;

  const _CategoryHeader({
    required this.issue,
    required this.color,
    required this.icon,
    required this.onBack,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                color,
                Color.alphaBlend(Colors.black.withValues(alpha: 0.10), color),
              ],
            ),
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                top: -40,
                start: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Action row
                      Row(
                        children: [
                          _RoundIconButton(
                            icon: sfIcon('arrow-right'),
                            bg: AppColors.white.withValues(alpha: 0.2),
                            fg: AppColors.white,
                            onTap: onBack,
                          ),
                          const Spacer(),
                          if (onChat != null)
                            _RoundIconButton(
                              icon: sfIcon('message-circle'),
                              bg: AppColors.white.withValues(alpha: 0.2),
                              fg: AppColors.white,
                              onTap: onChat!,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Category tile + title
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(icon, color: AppColors.white, size: 24),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              issue.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: AppColors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Status / urgency pills + timestamp
                      Row(
                        children: [
                          _HeaderPill(label: issue.statusLabel),
                          const SizedBox(width: 8),
                          _HeaderPill(label: issue.urgencyLabel),
                          const Spacer(),
                          Text(
                            timeago.format(issue.createdAt),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontSize: 11.5,
                                  color: AppColors.white
                                      .withValues(alpha: 0.85),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Translucent white pill used for status / urgency on the colored header.
class _HeaderPill extends StatelessWidget {
  final String label;

  const _HeaderPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
    );
  }
}

/// Small rounded square icon button used on the header and technician card.
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 19, color: fg),
        ),
      ),
    );
  }
}

/// Tinted notice banner used for the post-job rejection reason. A leading
/// icon tile, a bold title, and a body line — fully RTL-aware.
class _NoticeBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String body;

  const _NoticeBanner({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppColors.rCard),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.darkGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the backend `statusHistory` entries (`{status, at, by}`) as a
/// compact, RTL list appended under the main 4-step timeline. Surfaces the
/// richer post-job states the Dart [Issue] enum cannot represent.
class _StatusHistory extends StatelessWidget {
  final List<Map<String, dynamic>> entries;

  const _StatusHistory({required this.entries});

  /// Arabic label for a backend status string.
  String _label(BuildContext context, String status) {
    switch (status) {
      case 'awaitingApproval':
        return tr(context, 'بانتظار موافقتك');
      case 'awaitingPayment':
        return tr(context, 'بانتظار الدفع');
      case 'inProgress':
        return tr(context, 'العمل جارٍ');
      case 'completed':
        return tr(context, 'مكتمل');
      case 'disputed':
        return tr(context, 'محل نزاع');
      case 'rejected':
        return tr(context, 'مرفوض');
      case 'assigned':
        return tr(context, 'تم تعيين فني');
      case 'cancelled':
        return tr(context, 'ملغي');
      default:
        return tr(context, 'تم استلام البلاغ');
    }
  }

  String _agoOf(dynamic at) {
    if (at is String) {
      final d = DateTime.tryParse(at);
      if (d != null) return timeago.format(d);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppColors.lineSoft, height: 1),
          const SizedBox(height: 12),
          Text(
            tr(context, 'سجل الحالة'),
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.midGrey,
            ),
          ),
          const SizedBox(height: 8),
          ...entries.map((e) {
            final ago = _agoOf(e['at']);
            return Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.navy,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _label(context, (e['status'] ?? '').toString()),
                      textAlign: TextAlign.start,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ),
                  if (ago.isNotEmpty)
                    Text(
                      ago,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: AppColors.midGrey,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
