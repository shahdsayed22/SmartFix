import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../models/issue_model.dart';

/// Rounded status pill with a leading color dot — matches the prototype's
/// `StatusBadge`. Driven by the [IssueStatus] enum.
class SfStatusBadge extends StatelessWidget {
  final IssueStatus status;

  /// When true renders the compact variant (used inside cards).
  final bool small;

  const SfStatusBadge(this.status, {super.key, this.small = false});

  Color get _color {
    switch (status) {
      case IssueStatus.pending:
        return AppColors.warning;
      case IssueStatus.offered:
        return AppColors.secondary;
      case IssueStatus.assigned:
        return AppColors.info;
      case IssueStatus.inProgress:
        return AppColors.secondary;
      case IssueStatus.awaitingApproval:
        return AppColors.warning;
      case IssueStatus.awaitingPayment:
        return AppColors.info;
      case IssueStatus.completed:
        return AppColors.success;
      case IssueStatus.cancelled:
        return AppColors.error;
    }
  }

  Color get _bg {
    switch (status) {
      case IssueStatus.pending:
        return AppColors.warningBg;
      case IssueStatus.offered:
        return AppColors.secondaryBg;
      case IssueStatus.assigned:
        return AppColors.infoBg;
      case IssueStatus.inProgress:
        return AppColors.secondaryBg;
      case IssueStatus.awaitingApproval:
        return AppColors.warningBg;
      case IssueStatus.awaitingPayment:
        return AppColors.infoBg;
      case IssueStatus.completed:
        return AppColors.successBg;
      case IssueStatus.cancelled:
        return AppColors.dangerBg;
    }
  }

  String get _label {
    switch (status) {
      case IssueStatus.pending:
        return 'قيد الانتظار';
      case IssueStatus.offered:
        return 'عرض جديد';
      case IssueStatus.assigned:
        return 'تم التعيين';
      case IssueStatus.inProgress:
        return 'قيد التنفيذ';
      case IssueStatus.awaitingApproval:
        return 'بانتظار موافقة العميل';
      case IssueStatus.awaitingPayment:
        return 'بانتظار الدفع';
      case IssueStatus.completed:
        return 'مكتمل';
      case IssueStatus.cancelled:
        return 'ملغى';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 9 : 11,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            tr(context, _label),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: small ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded urgency pill with a leading icon — matches the prototype's
/// `UrgencyPill`. Driven by the [IssueUrgency] enum.
class SfUrgencyPill extends StatelessWidget {
  final IssueUrgency urgency;

  const SfUrgencyPill(this.urgency, {super.key});

  Color get _color {
    switch (urgency) {
      case IssueUrgency.low:
        return AppColors.success;
      case IssueUrgency.medium:
        return AppColors.warning;
      case IssueUrgency.high:
        return AppColors.error;
      case IssueUrgency.emergency:
        return const Color(0xFFB71C1C);
    }
  }

  IconData get _icon {
    switch (urgency) {
      case IssueUrgency.low:
        return Icons.check_circle;
      case IssueUrgency.medium:
        return Icons.info_outline;
      case IssueUrgency.high:
        return Icons.warning_amber;
      case IssueUrgency.emergency:
        return Icons.emergency_share;
    }
  }

  String get _label {
    switch (urgency) {
      case IssueUrgency.low:
        return 'منخفضة';
      case IssueUrgency.medium:
        return 'متوسطة';
      case IssueUrgency.high:
        return 'عالية';
      case IssueUrgency.emergency:
        return 'طارئة';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            tr(context, _label),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
