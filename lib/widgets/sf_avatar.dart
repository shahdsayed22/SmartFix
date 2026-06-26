import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Initial-letter avatar — mirrors the prototype's `Avatar`.
///
/// Renders the first character of [name] (Arabic-aware) centered in a navy
/// circle with a gold glyph. Set [ring] to draw the soft gold focus ring used
/// on highlighted avatars. Override [bg]/[fg] for custom tones.
class SfAvatar extends StatelessWidget {
  final String name;
  final double size;

  /// Circle fill (defaults to brand navy).
  final Color bg;

  /// Glyph color (defaults to gold).
  final Color fg;

  /// When true draws a soft gold ring around the avatar.
  final bool ring;

  const SfAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.bg = AppColors.navy,
    this.fg = AppColors.gold,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isNotEmpty ? trimmed.characters.first : '؟';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow:
            ring
                ? [
                  const BoxShadow(color: AppColors.surface, spreadRadius: 2),
                  BoxShadow(color: AppColors.goldSoft, spreadRadius: 4),
                ]
                : null,
      ),
      child: Text(
        initial,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
