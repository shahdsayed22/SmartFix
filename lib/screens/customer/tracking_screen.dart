import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../models/issue_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../chat/chat_screen.dart';
import '../../widgets/sf_badges.dart';
import '../../widgets/sf_cards.dart';
import '../../widgets/sf_cat_tile.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_icons.dart';
import '../../widgets/sf_states.dart';
import '../../widgets/sf_timeline.dart';
import '../../widgets/smart_button.dart';

/// Live technician tracking for an en-route assignment.
///
/// Renders a stylized map-placeholder hero (gradient container with a dashed
/// route, a technician pin and a customer pin built from simple shapes — no
/// real map dependency), the assigned technician card (name / rating / ETA),
/// and a vertical status timeline derived from [Issue.status].
///
/// The issue is refreshed from [ApiService.getIssues] so the timeline and the
/// technician name stay in sync with the backend. ETA / distance are
/// estimated client-side with a clear note (the model carries no live GPS).
class TrackingScreen extends StatefulWidget {
  final Issue issue;

  const TrackingScreen({super.key, required this.issue});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _error = false;

  late Issue _issue;

  /// Phone of the assigned technician (looked up from the backend), used by
  /// the call button. Null when unassigned / unavailable.
  String? _techPhone;

  @override
  void initState() {
    super.initState();
    _issue = widget.issue;
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }

    try {
      // Refresh the issue so the timeline reflects the latest backend status.
      final raw = await _api.getIssues(customerId: widget.issue.customerId);
      final issues = raw.map(Issue.fromMap).toList();
      final fresh = issues.firstWhere(
        (i) => i.id == widget.issue.id,
        orElse: () => widget.issue,
      );

      // Look up the assigned technician's phone for the call button.
      String? phone;
      final techId = fresh.assignedWorkerId;
      if (techId != null && techId.isNotEmpty) {
        try {
          final techs = await _api.getTechnicians();
          final match = techs.firstWhere(
            (t) => (t['id'] ?? t['uid'] ?? t['_id'])?.toString() == techId,
            orElse: () => <String, dynamic>{},
          );
          final raw = match['phone']?.toString().trim();
          if (raw != null && raw.isNotEmpty) phone = raw;
        } catch (_) {
          // Non-fatal: tracking still works without a callable number.
        }
      }

      if (mounted) {
        setState(() {
          _issue = fresh;
          _techPhone = phone;
          _loading = false;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  /// Coarse ETA estimate from the urgency (no live GPS on the model).
  int get _etaMinutes {
    if (_issue.status == IssueStatus.inProgress ||
        _issue.status == IssueStatus.completed) {
      return 0;
    }
    switch (_issue.urgency) {
      case IssueUrgency.emergency:
        return 6;
      case IssueUrgency.high:
        return 10;
      case IssueUrgency.medium:
        return 15;
      case IssueUrgency.low:
        return 22;
    }
  }

  String get _etaLabel {
    if (_issue.status == IssueStatus.completed) {
      return tr(context, 'اكتملت الخدمة');
    }
    if (_issue.status == IssueStatus.inProgress) {
      return tr(context, 'الفني في موقعك');
    }
    return '${tr(context, 'في الطريق إليك')} · $_etaMinutes ${tr(context, 'دقيقة')}';
  }

  String get _techName {
    final n = _issue.assignedWorkerName;
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return tr(context, 'الفني المعيّن');
  }

  /// Open the in-app chat for this issue.
  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          issueId: _issue.id,
          issueTitle: _techName,
        ),
      ),
    );
  }

  /// Dial the assigned technician via the device dialer.
  Future<void> _callTechnician() async {
    final phone = _techPhone;
    if (phone == null || phone.isEmpty) {
      _showSnack(tr(context, 'رقم هاتف الفني غير متاح حاليًا.'));
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          _showSnack(tr(context, 'تعذّر فتح تطبيق الاتصال.'));
        }
      }
    } catch (_) {
      if (mounted) {
        _showSnack(tr(context, 'تعذّر فتح تطبيق الاتصال.'));
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            SfGradientHeader(
              title: tr(context, 'تتبّع الفني'),
              subtitle: tr(context, 'تابع وصول الفني إلى موقعك مباشرةً'),
              showBack: true,
              actions: [
                Material(
                  color: AppColors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _loading ? null : _load,
                    child: const SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.refresh,
                        size: 19,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
        children: const [
          SfSkeletonCard(),
          SfSkeletonCard(),
          SfSkeletonCard(),
        ],
      );
    }

    if (_error) {
      return SfEmptyState(
        icon: Icons.wifi_off_rounded,
        title: tr(context, 'تعذّر تحميل التتبّع'),
        body: tr(context, 'تحقّق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
        action: SmartButton(
          label: tr(context, 'إعادة المحاولة'),
          icon: Icons.refresh,
          width: 200,
          onPressed: _load,
        ),
      );
    }

    if (_issue.status == IssueStatus.completed) {
      // Still show the screen, but lead with a clear completion banner.
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
        children: [
          _mapHero(),
          const SizedBox(height: 14),
          _techCard(),
          const SizedBox(height: 14),
          _timelineCard(),
          const SizedBox(height: 12),
          _estimateNote(),
        ],
      ),
    );
  }

  // ── Stylized map placeholder (no real map dependency) ──────────────
  Widget _mapHero() {
    final cfg = sfCategory(_issue.category);
    return Container(
      height: 210,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppColors.rCard),
        boxShadow: const [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 18,
            spreadRadius: -8,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // faint "street grid" overlay
          Positioned.fill(
            child: CustomPaint(painter: _MapGridPainter()),
          ),
          // dashed route + the two pins
          Positioned.fill(
            child: CustomPaint(
              painter: _RoutePainter(
                techColor: cfg.color,
                pinColor: AppColors.gold,
                progress: _routeProgress,
              ),
            ),
          ),
          // technician pin (moving end)
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: 34, start: 30),
              child: _pin(
                icon: Icons.navigation_rounded,
                color: cfg.color,
                label: tr(context, 'الفني'),
              ),
            ),
          ),
          // customer pin (destination)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 34, end: 30),
              child: _pin(
                icon: Icons.place_rounded,
                color: AppColors.gold,
                label: tr(context, 'موقعك'),
              ),
            ),
          ),
          // ETA chip
          PositionedDirectional(
            top: 12,
            start: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timelapse, size: 14, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Text(
                    _etaLabel,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Route fill fraction for the painter, derived from the live status.
  double get _routeProgress {
    switch (_issue.status) {
      case IssueStatus.pending:
        return 0.12;
      case IssueStatus.offered:
        return 0.3;
      case IssueStatus.assigned:
        return 0.5;
      case IssueStatus.inProgress:
        return 0.92;
      case IssueStatus.awaitingApproval:
        return 0.96;
      case IssueStatus.awaitingPayment:
        return 0.98;
      case IssueStatus.completed:
        return 1.0;
      case IssueStatus.cancelled:
        return 0.0;
    }
  }

  Widget _pin({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: AppColors.white),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.charcoal.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ),
      ],
    );
  }

  // ── Assigned technician card ───────────────────────────────────────
  Widget _techCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.rCard),
        border: Border.all(color: AppColors.lineSoft),
        boxShadow: const [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 14,
            spreadRadius: -10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SfCatTile(_issue.category, size: 50, soft: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _techName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: AppColors.teal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _etaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ),
              SfStatusBadge(_issue.status, small: true),
            ],
          ),
          const SizedBox(height: 13),
          // Design route progress bar (teal → brand gradient).
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _routeProgress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation(AppColors.teal),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: SmartButton(
                  label: tr(context, 'محادثة'),
                  icon: Icons.chat_bubble_outline_rounded,
                  isOutlined: true,
                  onPressed: _openChat,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: SmartButton(
                  label: tr(context, 'اتصال'),
                  icon: Icons.phone,
                  onPressed: _callTechnician,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Vertical status timeline (ports the design Timeline component) ──
  Widget _timelineCard() {
    return SfSectionCard(
      icon: Icons.route_rounded,
      title: tr(context, 'مراحل الخدمة'),
      child: SfTimeline(
        _issue.status,
        assignedName: _issue.assignedWorkerName,
        reportedAgo: timeago.format(_issue.createdAt),
        updatedAgo: timeago.format(_issue.updatedAt),
      ),
    );
  }

  Widget _estimateNote() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(
                context,
                'الوقت والمسافة تقديريّان ويُحدَّثان مع تقدّم الخدمة. التتبّع المباشر على الخريطة يصبح متاحًا عند تفعيل تحديد الموقع للفني.',
              ),
              textAlign: TextAlign.start,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11.5,
                height: 1.6,
                color: AppColors.darkGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Faint diagonal "street grid" behind the route, painted onto the hero.
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 26.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
    for (double x = 0; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x - size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) => false;
}

/// Dashed route from the technician pin (top-left) to the customer pin
/// (bottom-right), with a solid "travelled" portion proportional to progress.
class _RoutePainter extends CustomPainter {
  final Color techColor;
  final Color pinColor;
  final double progress;

  _RoutePainter({
    required this.techColor,
    required this.pinColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width * 0.2, size.height * 0.28);
    final end = Offset(size.width * 0.8, size.height * 0.72);
    final ctrl = Offset(size.width * 0.5, size.height * 0.2);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);

    // full dashed route (faint)
    final dashPaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    _drawDashed(canvas, path, dashPaint);

    // travelled portion (solid, gold)
    final metrics = path.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final m = metrics.first;
      final travelled = m.extractPath(0, m.length * progress.clamp(0.0, 1.0));
      final solidPaint = Paint()
        ..color = pinColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(travelled, solidPaint);
    }
  }

  void _drawDashed(Canvas canvas, Path source, Paint paint) {
    const dash = 7.0;
    const gap = 7.0;
    for (final metric in source.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = dist + dash;
        canvas.drawPath(
          metric.extractPath(dist, next.clamp(0.0, metric.length)),
          paint,
        );
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.techColor != techColor ||
      oldDelegate.pinColor != pinColor;
}
