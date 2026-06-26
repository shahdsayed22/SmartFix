import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Small "verified" check badge.
///
/// Restyled to the new design (info-blue circle, white check, surface ring)
/// while preserving the existing public API (`VerifiedBadge({isVerified,
/// size})`). Renders nothing when [isVerified] is false.
class VerifiedBadge extends StatelessWidget {
  final bool isVerified;
  final double size;

  const VerifiedBadge({super.key, required this.isVerified, this.size = 20});

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.info,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppColors.surface, spreadRadius: 2)],
      ),
      child: Icon(Icons.check, size: size * 0.62, color: AppColors.white),
    );
  }
}

/// Generic rounded status pill (free-form label + color + optional icon).
///
/// Kept for screens that build their own status chips. For issue statuses,
/// prefer `SfStatusBadge` from `sf_badges.dart`. Public API unchanged:
/// `StatusBadge({label, color, icon})`.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
