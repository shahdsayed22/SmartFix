import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/issue_model.dart';
import 'sf_icons.dart';

/// Rounded category icon tile (the soft-tinted square that fronts each
/// issue/job card). Accepts an [IssueCategory] enum or a raw string key.
class SfCatTile extends StatelessWidget {
  final Object category;
  final double size;

  /// When true (default) the tile uses a soft tinted background with a
  /// colored icon; when false it is a solid colored tile with a white icon.
  final bool soft;

  const SfCatTile(this.category, {super.key, this.size = 44, this.soft = true});

  @override
  Widget build(BuildContext context) {
    final cfg = sfCategory(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: soft ? cfg.color.withValues(alpha: 0.13) : cfg.color,
        borderRadius: BorderRadius.circular(size * 0.295),
      ),
      child: Icon(
        cfg.icon,
        size: size * 0.5,
        color: soft ? cfg.color : AppColors.white,
      ),
    );
  }
}

/// Selectable category chip used in the report-issue flow. Mirrors the
/// prototype's pill-shaped `CategoryChip` with a lift + shadow when active.
class SfCategoryChip extends StatelessWidget {
  final Object category;
  final bool selected;
  final VoidCallback? onTap;

  const SfCategoryChip({
    super.key,
    required this.category,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = sfCategory(category);
    final color = cfg.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform:
            selected
                ? (Matrix4.identity()..translateByDouble(0, -1, 0, 1))
                : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.28),
            width: 1.5,
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cfg.icon, size: 20, color: selected ? AppColors.white : color),
            const SizedBox(width: 8),
            Text(
              cfg.label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
