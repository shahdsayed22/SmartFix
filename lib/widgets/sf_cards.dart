import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../models/issue_model.dart';
import 'sf_icons.dart';
import 'sf_badges.dart';
import 'sf_cat_tile.dart';

/// The issue / job card used across home + list screens. A white rounded
/// card (radius [AppColors.rCard]) topped by a category-colored accent bar,
/// with a category tile, title, urgency pill, clamped description, address
/// row + status badge, and a relative timestamp footer.
///
/// All content is passed in as plain values so the card stays decoupled
/// from the [Issue] model — screens map their data in.
class SfIssueCard extends StatelessWidget {
  final String title;

  /// Category key (snake_case string) or [IssueCategory] enum value.
  final Object categoryName;
  final IssueUrgency urgency;
  final IssueStatus status;
  final String description;
  final String address;

  /// Pre-formatted relative time (e.g. "3 hours ago"); hidden when null/empty.
  final String? timeAgo;
  final VoidCallback? onTap;

  const SfIssueCard({
    super.key,
    required this.title,
    required this.categoryName,
    required this.urgency,
    required this.status,
    required this.description,
    required this.address,
    this.timeAgo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = sfCategory(categoryName);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.rCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.rCard),
            border: Border.all(color: AppColors.lineSoft),
            boxShadow: const [
              BoxShadow(
                color: AppColors.navyShadow,
                blurRadius: 14,
                spreadRadius: -8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 4, color: cfg.color),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SfCatTile(categoryName, size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.charcoal,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tr(context, cfg.label),
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cfg.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SfUrgencyPill(urgency),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 11),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.darkGrey,
                        ),
                      ),
                    ],
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppColors.midGrey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address.isNotEmpty ? address : tr(context, 'تم تحديد الموقع'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              color: AppColors.midGrey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SfStatusBadge(status, small: true),
                      ],
                    ),
                    if (timeAgo != null && timeAgo!.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        timeAgo!,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          color: AppColors.midGrey,
                        ),
                      ),
                    ],
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

/// A titled white section container used on detail screens. Optional
/// leading [icon], a bold [title], an optional [trailing] widget on the
/// header row, and arbitrary [child] content below.
class SfSectionCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SfSectionCard({
    super.key,
    this.icon,
    required this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(17),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: AppColors.navy),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

/// Compact metric card (icon tile + big value + small label) used in the
/// customer home overview row. [color]/[bg] tint the icon tile.
class SfStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;

  const SfStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.midGrey,
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
