import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../services/api_service.dart';
import '../../models/issue_model.dart';
import '../../widgets/sf_icons.dart';
import '../../widgets/sf_cards.dart';
import '../../widgets/ai_analysis_card.dart';
import '../../widgets/sf_badges.dart';
import '../../widgets/sf_avatar.dart';
import '../../widgets/sf_feedback.dart';
import '../../widgets/smart_text_field.dart';
import '../../widgets/smart_button.dart';
import '../chat/chat_screen.dart';
import '../worker/make_offer_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final Issue issue;

  const JobDetailScreen({super.key, required this.issue});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen>
    with WidgetsBindingObserver {
  final JobService _jobService = JobService();
  late Issue _issue;

  @override
  void initState() {
    super.initState();
    _issue = widget.issue;
    WidgetsBinding.instance.addObserver(this);
    // Refetch so a payment confirmed on the backend (issue → completed, worker
    // payout credited) reflects here without restarting the app.
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _jobService.getIssue(widget.issue.id);
      if (mounted) setState(() => _issue = fresh);
    } catch (_) {
      // keep the current issue on failure (offline / transient)
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobService = _jobService;
    final currentUser = context.read<AuthService>().currentUser;

    return Builder(
      builder: (context) {
        final currentIssue = _issue;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // ── Navy hero header with category identity ─────────────
              _JobHeader(issue: currentIssue),

              // ── Scrollable detail body ──────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 24),
                  children: [
                    // Customer
                    SfSectionCard(
                      icon: sfIcon('user'),
                      title: tr(context, 'العميل'),
                      child: Row(
                        children: [
                          SfAvatar(name: currentIssue.customerName, size: 46),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentIssue.customerName.isNotEmpty
                                      ? currentIssue.customerName
                                      : tr(context, 'عميل'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.charcoal,
                                      ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  tr(context, 'عميل'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontSize: 12.5,
                                        color: AppColors.midGrey,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          _ChatIconButton(
                            onTap: () => _openChat(context, currentIssue),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
                    const SizedBox(height: 14),

                    // AI Analysis (heuristic/anomaly baseline) — helps the
                    // worker gauge urgency/anomaly before accepting.
                    AiAnalysisCard(issue: currentIssue),

                    // Description
                    SfSectionCard(
                          icon: sfIcon('align-right'),
                          title: tr(context, 'الوصف'),
                          child: Text(
                            currentIssue.description,
                            textAlign: TextAlign.start,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 14,
                                  height: 1.7,
                                  color: AppColors.darkGrey,
                                ),
                          ),
                        )
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.05),
                    const SizedBox(height: 14),

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
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    const SizedBox(height: 1),
                                    // Coordinates stay LTR for correct numeral order.
                                    Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        '${currentIssue.latitude.toStringAsFixed(4)}, ${currentIssue.longitude.toStringAsFixed(4)}',
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
                        .animate(delay: 200.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.05),
                  ],
                ),
              ),

              // ── Contextual action bar (pinned to bottom) ────────────
              if (currentUser != null)
                _ActionBar(
                  issue: currentIssue,
                  jobService: jobService,
                  user: currentUser,
                ),
            ],
          ),
        );
      },
    );
  }

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
}

// ───────────────────────────────────────────────────────────────────
// Navy hero header (category-colored brand strip + identity + badges)
// ───────────────────────────────────────────────────────────────────
class _JobHeader extends StatelessWidget {
  final Issue issue;

  const _JobHeader({required this.issue});

  @override
  Widget build(BuildContext context) {
    final cfg = sfCategory(issue.category);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Stack(
          children: [
            PositionedDirectional(
              top: -40,
              end: -30,
              child: _decoCircle(150, AppColors.white.withValues(alpha: 0.06)),
            ),
            PositionedDirectional(
              bottom: -60,
              start: -40,
              child: _decoCircle(140, cfg.color.withValues(alpha: 0.18)),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // top chrome row: back + chat
                    Row(
                      children: [
                        _HeaderGlassButton(
                          icon: sfIcon('arrow-right'),
                          onTap: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        _HeaderGlassButton(
                          icon: sfIcon('message-circle'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ChatScreen(
                                      issueId: issue.id,
                                      issueTitle: issue.title,
                                    ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // identity row: category tile + title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            cfg.icon,
                            size: 24,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.white,
                                  height: 1.2,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    // badge row: status + urgency + time
                    Row(
                      children: [
                        SfStatusBadge(issue.status, small: true),
                        const SizedBox(width: 8),
                        _HeaderPill(label: issue.urgencyLabel),
                        const Spacer(),
                        Text(
                          timeago.format(issue.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11.5,
                            color: AppColors.white.withValues(alpha: 0.85),
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
    );
  }

  Widget _decoCircle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// White-glass rounded square button for the header chrome.
class _HeaderGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderGlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 19, color: AppColors.white),
        ),
      ),
    );
  }
}

// Translucent white pill used for the urgency label on the gradient header.
class _HeaderPill extends StatelessWidget {
  final String label;

  const _HeaderPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
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

// Soft navy-tinted round chat button on the customer card.
class _ChatIconButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ChatIconButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navySoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            sfIcon('message-circle'),
            size: 20,
            color: AppColors.navy,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Contextual bottom action bar — preserves the exact JobService logic.
// ───────────────────────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  final Issue issue;
  final JobService jobService;
  final dynamic user;

  const _ActionBar({
    required this.issue,
    required this.jobService,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final button = _buildActionButton(context);
    if (button == null) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 16),
          child: button,
        ),
      ),
    );
  }

  Widget? _buildActionButton(BuildContext context) {
    if (issue.status == IssueStatus.pending) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AccentButton(
            label: tr(context, 'قبول الوظيفة'),
            icon: sfIcon('check-circle-2'),
            color: AppColors.success,
            onPressed: () async {
              try {
                await jobService.acceptJob(issue.id, user.uid, user.name);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr(context, 'تم قبول الوظيفة بنجاح ✅')),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${tr(context, 'تعذّر القبول')}: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 10),
          _AccentButton(
            label: tr(context, 'تقديم عرض سعر'),
            icon: sfIcon('wallet'),
            color: AppColors.secondary,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MakeOfferScreen(issue: issue),
                ),
              );
            },
          ),
        ],
      ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1);
    } else if (issue.status == IssueStatus.assigned &&
        issue.assignedWorkerId == user.uid) {
      return _AccentButton(
        label: tr(context, 'بدء العمل'),
        icon: sfIcon('play-circle'),
        color: AppColors.secondary,
        onPressed: () async {
          try {
            await jobService.updateIssueStatus(
              issue.id,
              IssueStatus.inProgress,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr(context, 'بدأ العمل 🔧')),
                  backgroundColor: AppColors.secondary,
                ),
              );
              Navigator.pop(context, true);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${tr(context, 'فشل العملية')}: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
      ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1);
    } else if (issue.status == IssueStatus.inProgress &&
        issue.assignedWorkerId == user.uid) {
      // The only way to finish a job: report completion. This collects a
      // summary (+ optional photos) and sends the job to the customer to
      // review & approve before it is marked done. There is no instant-finish
      // path — completion must be confirmed by the customer.
      return _AccentButton(
        label: tr(context, 'أبلغ عن إتمام العمل'),
        icon: sfIcon('flag'),
        color: AppColors.success,
        onPressed: () => _reportCompletion(context),
      ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1);
    } else if (issue.status == IssueStatus.awaitingApproval &&
        issue.assignedWorkerId == user.uid) {
      // Worker reported completion → waiting for the customer to confirm.
      return _WaitingBanner(
        icon: Icons.hourglass_top_rounded,
        color: AppColors.warning,
        title: tr(context, 'بانتظار تأكيد العميل'),
        subtitle: tr(
          context,
          'أبلغتَ عن إتمام العمل. سيظهر هنا التأكيد بمجرد موافقة العميل.',
        ),
      ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
    } else if (issue.status == IssueStatus.awaitingPayment &&
        issue.assignedWorkerId == user.uid) {
      // Customer approved the work → waiting for payment to settle.
      return _WaitingBanner(
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        title: tr(context, 'وافق العميل على إتمام العمل'),
        subtitle: tr(context, 'بانتظار إتمام الدفع.'),
      ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
    }

    return null;
  }

  /// Worker → request completion: opens a sheet to capture a completion
  /// summary and optional photo URLs, then calls
  /// [ApiService.requestCompletion]. On success the job moves to the
  /// awaiting-approval stage and the customer is notified to review it.
  Future<void> _reportCompletion(BuildContext context) async {
    final result = await SfSheet.show<_CompletionResult>(
      context,
      builder: (ctx) => _CompletionSheet(issue: issue),
    );
    if (result == null) return; // cancelled

    final api = ApiService();
    try {
      await api.requestCompletion(
        issue.id,
        summary: result.summary,
        photos: result.photos,
        by: user.uid,
      );
      if (context.mounted) {
        SfToast.show(
          context,
          tr(context, 'تم إرسال طلب إتمام العمل — بانتظار موافقة العميل'),
          tone: SfTone.success,
        );
        // Reflect the awaiting-approval transition to the caller list.
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        SfToast.show(
          context,
          '${tr(context, 'تعذّر إرسال طلب الإتمام')}: $e',
          tone: SfTone.error,
        );
      }
    } finally {
      api.dispose();
    }
  }

}

// ───────────────────────────────────────────────────────────────────
// Completion report sheet — collects a summary + optional photo URLs.
// Pops with a [_CompletionResult] on submit, or null on cancel.
// ───────────────────────────────────────────────────────────────────
class _CompletionResult {
  final String summary;
  final List<String> photos;

  const _CompletionResult({required this.summary, required this.photos});
}

class _CompletionSheet extends StatefulWidget {
  final Issue issue;

  const _CompletionSheet({required this.issue});

  @override
  State<_CompletionSheet> createState() => _CompletionSheetState();
}

class _CompletionSheetState extends State<_CompletionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _summaryCtrl = TextEditingController();
  final _photosCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _photosCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Optional photo URLs: comma- or newline-separated, blanks dropped.
    final photos =
        _photosCtrl.text
            .split(RegExp(r'[,\n]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    setState(() => _submitting = true);
    Navigator.pop(
      context,
      _CompletionResult(summary: _summaryCtrl.text.trim(), photos: photos),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(sfIcon('flag'), color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'الإبلاغ عن إتمام العمل'),
                      textAlign: TextAlign.start,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(context, 'سيُطلب من العميل مراجعة العمل والموافقة عليه'),
                      textAlign: TextAlign.start,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        color: AppColors.midGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SmartTextField(
            label: tr(context, 'ملخص العمل المنجز'),
            hint: tr(context, 'صف باختصار ما تم إنجازه...'),
            controller: _summaryCtrl,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return tr(context, 'الرجاء إدخال ملخص العمل');
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          SmartTextField(
            label: tr(context, 'روابط الصور (اختياري)'),
            hint: tr(context, 'الصق روابط الصور مفصولة بفواصل'),
            controller: _photosCtrl,
            maxLines: 2,
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: 20),
          SmartButton(
            label: tr(context, 'إرسال طلب الإتمام'),
            icon: sfIcon('check-circle-2'),
            isLoading: _submitting,
            onPressed: _submit,
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// Full-width colored action button (navy/teal/gold success styling) that
// matches the prototype's large contextual CTA.
class _AccentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _AccentButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.rBtn),
          ),
          textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Non-interactive status banner shown in the worker action bar while a job is
/// awaiting the customer's confirmation (or payment). Replaces an action button
/// so the worker can see the job is paused on the customer's side. Bilingual —
/// the caller passes already-localized strings.
class _WaitingBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _WaitingBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppColors.rBtn),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.darkGrey,
                    height: 1.3,
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
