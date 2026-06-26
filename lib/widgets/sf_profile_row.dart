import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// A labelled detail row for profile / info lists: a soft navy icon tile,
/// a small grey [label], and a [value] line. A hairline divider is drawn
/// beneath unless [last] is true.
class SfProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// Overrides the value text color (e.g. to highlight a status).
  final Color? valueColor;

  /// When true the bottom divider is omitted.
  final bool last;

  /// Optional tap handler (e.g. rows that navigate).
  final VoidCallback? onTap;

  /// Optional trailing widget (e.g. a chevron or switch).
  final Widget? trailing;

  const SfProfileRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.last = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.navySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.navy),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    color: AppColors.midGrey,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onTap != null) InkWell(onTap: onTap, child: row) else row,
        if (!last)
          Container(
            height: 1,
            margin: const EdgeInsetsDirectional.only(start: 60),
            color: AppColors.lineSoft,
          ),
      ],
    );
  }
}
