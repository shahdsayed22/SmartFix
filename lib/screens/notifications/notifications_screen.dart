import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../l10n/app_strings.dart';
import '../../models/app_notification.dart';
import '../../models/issue_model.dart';
import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_feedback.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_states.dart';
import '../chat/chat_screen.dart';
import '../customer/issue_detail_screen.dart';
import '../payment/payment_screen.dart';
import '../payment/wallet_screen.dart';
import '../support/ticket_detail_screen.dart';

/// Ensures the timeago Arabic locale is registered once (the package ships the
/// messages but does not register them by default). Safe to call repeatedly.
bool _arTimeagoReady = false;
void _ensureArTimeago() {
  if (_arTimeagoReady) return;
  timeago.setLocaleMessages('ar', timeago.ArMessages());
  _arTimeagoReady = true;
}

/// Lists the current user's in-app notifications.
///
/// Reads from [NotificationProvider] when one is registered globally; otherwise
/// it spins up a screen-local instance so it works standalone before the
/// `main.dart` agent wires the global provider. Supports pull-to-refresh,
/// "mark all read" from the header, and tap-to-read on each row.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Reuse the global provider if present; fall back to a local one.
    NotificationProvider? global;
    try {
      global = context.read<NotificationProvider>();
    } catch (_) {
      global = null;
    }

    if (global != null) {
      return const _NotificationsView();
    }
    return ChangeNotifierProvider<NotificationProvider>(
      create: (_) => NotificationProvider(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatefulWidget {
  const _NotificationsView();

  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<_NotificationsView> {
  final ApiService _api = ApiService();

  String get _userId => context.read<AuthService>().currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().load(_userId);
    });
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  /// Marks [n] as read, then deep-links to the screen its [type]/[relatedId]
  /// points at. If no target can be resolved, it just marks the row read.
  Future<void> _handleTap(AppNotification n) async {
    // Mark read first (provider performs the backend markNotificationRead and
    // is a no-op if the row is already read).
    if (!n.read) {
      await context.read<NotificationProvider>().markRead(n.id);
    }
    if (!mounted) return;

    final type = n.type.toLowerCase();
    final relatedId = n.relatedId;

    // Payment notifications → invoice screen (needs the linked issue) or the
    // wallet overview when no specific issue is attached.
    if (type.contains('payment') || type.contains('invoice')) {
      if (relatedId.isEmpty) {
        _push(const WalletScreen());
        return;
      }
      final issue = await _fetchIssue(relatedId);
      if (!mounted) return;
      if (issue != null) {
        _push(PaymentScreen(issue: issue));
      } else {
        _push(const WalletScreen());
      }
      return;
    }

    if (relatedId.isEmpty) return;

    // Chat / message notifications → conversation thread for the issue.
    if (type.contains('chat') || type.contains('message')) {
      _push(ChatScreen(issueId: relatedId, issueTitle: n.title));
      return;
    }

    // Support ticket notifications → ticket conversation.
    if (type.contains('ticket')) {
      _push(TicketDetailScreen(ticketId: relatedId));
      return;
    }

    // Issue / job notifications → issue detail (fetch the issue by id).
    if (type.contains('issue') ||
        type.contains('job') ||
        type.contains('completion') ||
        type.contains('assign')) {
      final issue = await _fetchIssue(relatedId);
      if (!mounted) return;
      if (issue != null) _push(IssueDetailScreen(issue: issue));
      return;
    }

    // Unknown type → already marked read above; nothing else to do.
  }

  /// Looks up a single [Issue] by id via [ApiService.getIssues]. Returns null
  /// on failure or when no matching issue exists.
  Future<Issue?> _fetchIssue(String id) async {
    try {
      final raw = await _api.getIssues();
      final match = raw.firstWhere(
        (m) => (m['id'] ?? m['_id'])?.toString() == id,
        orElse: () => const <String, dynamic>{},
      );
      if (match.isEmpty) return null;
      return Issue.fromMap(match);
    } catch (_) {
      return null;
    }
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _markAllRead() async {
    final provider = context.read<NotificationProvider>();
    if (provider.unread == 0) return;
    await provider.markAllRead(_userId);
    if (mounted) {
      SfToast.show(
        context,
        tr(context, 'تم تعليم الكل كمقروء'),
        tone: SfTone.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SfGradientHeader(
            title: tr(context, 'الإشعارات'),
            subtitle: provider.unread > 0
                ? '${provider.unread} ${tr(context, 'غير مقروء')}'
                : tr(context, 'كل التحديثات هنا'),
            showBack: true,
            actions: [
              if (provider.unread > 0)
                _HeaderTextAction(
                  label: tr(context, 'تعليم الكل'),
                  onTap: _markAllRead,
                ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => context.read<NotificationProvider>().load(_userId),
              child: _buildBody(context, provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationProvider provider) {
    if (provider.isLoading && provider.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
        children: const [
          SfSkeletonCard(),
          SizedBox(height: 10),
          SfSkeletonCard(),
          SizedBox(height: 10),
          SfSkeletonCard(),
        ],
      );
    }

    if (provider.error != null && provider.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 70),
          SfEmptyState(
            icon: Icons.wifi_off_rounded,
            title: tr(context, 'تعذّر تحميل الإشعارات'),
            body: tr(
              context,
              'تحقّق من اتصالك بالإنترنت ثم اسحب للأسفل لإعادة المحاولة.',
            ),
          ),
        ],
      );
    }

    if (provider.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 70),
          SfEmptyState(
            icon: Icons.notifications_none_rounded,
            title: tr(context, 'لا توجد إشعارات'),
            body: tr(
              context,
              'ستظهر تنبيهات بلاغاتك ومدفوعاتك ورسائلك هنا.',
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
      itemCount: provider.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final n = provider.items[i];
        return _NotificationTile(
          notification: n,
          onTap: () => _handleTap(n),
        ).animate().fadeIn(duration: 260.ms, delay: (i * 45).ms).slideY(
              begin: 0.06,
              end: 0,
              duration: 260.ms,
              curve: Curves.easeOut,
            );
      },
    );
  }
}

/// A single notification row. Unread rows get a surface background, a soft
/// shadow, and a gold dot; read rows are flat.
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;

  const _NotificationTile({required this.notification, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = _toneColor(notification.tone);
    final toneBg = _toneBg(notification.tone);
    final unread = !notification.read;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppColors.rCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.rCard),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: unread ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppColors.rCard),
            border: Border.all(color: AppColors.lineSoft),
            boxShadow: unread
                ? const [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: toneBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_resolveIcon(notification), size: 20, color: tone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            textAlign: TextAlign.start,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        textAlign: TextAlign.start,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.darkGrey,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      timeago.format(
                        notification.createdAt,
                        locale: _timeagoLocale(context),
                      ),
                      textAlign: TextAlign.start,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: AppColors.midGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White text button suitable for the gradient header's action slot.
class _HeaderTextAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _HeaderTextAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tone → color mapping (info / success / warning / danger) ────────────

Color _toneColor(String tone) {
  switch (tone) {
    case 'success':
      return AppColors.success;
    case 'warning':
      return AppColors.warning;
    case 'danger':
      return AppColors.error;
    case 'info':
    default:
      return AppColors.info;
  }
}

Color _toneBg(String tone) {
  switch (tone) {
    case 'success':
      return AppColors.successBg;
    case 'warning':
      return AppColors.warningBg;
    case 'danger':
      return AppColors.dangerBg;
    case 'info':
    default:
      return AppColors.infoBg;
  }
}

/// Best-effort mapping of common backend icon names + tones to Material icons.
IconData _resolveIcon(AppNotification n) {
  switch (n.icon) {
    case 'check':
    case 'check-circle':
      return Icons.check_circle_rounded;
    case 'alert':
    case 'alert-triangle':
    case 'warning':
      return Icons.warning_amber_rounded;
    case 'x':
    case 'x-circle':
      return Icons.cancel_rounded;
    case 'credit-card':
    case 'payment':
      return Icons.credit_card_rounded;
    case 'wrench':
    case 'tool':
      return Icons.build_rounded;
    case 'message':
    case 'chat':
      return Icons.chat_bubble_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'user':
      return Icons.person_rounded;
    case 'bell':
      return Icons.notifications_rounded;
  }
  switch (n.tone) {
    case 'success':
      return Icons.check_circle_rounded;
    case 'warning':
      return Icons.warning_amber_rounded;
    case 'danger':
      return Icons.cancel_rounded;
    default:
      return Icons.info_rounded;
  }
}

/// timeago Arabic locale by default; English when the app is in English mode.
String _timeagoLocale(BuildContext context) {
  _ensureArTimeago();
  // tr() returns the Arabic source unchanged in Arabic mode, so comparing the
  // translation of a known key tells us which language is active.
  final isEn = tr(context, 'دقيقة') != 'دقيقة';
  return isEn ? 'en' : 'ar';
}
