import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Reusable navy hero-gradient header for branded screens.
///
/// Renders the rich [AppColors.heroGradient] with two faint decorative
/// circles (white + gold), rounded bottom corners, and white content. It
/// includes a [SafeArea] top inset and sets a light status-bar style.
///
/// - [title] / [subtitle]: the headline rows (white).
/// - [leading]: a custom leading widget; if null and [showBack] is true a
///   white rounded back button is shown (pops the navigator).
/// - [actions]: trailing widgets on the title row.
/// - [child]: optional extra content rendered below the title row (e.g. a
///   search field, stat row, or segmented control).
class SfGradientHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final double bottomRadius;

  const SfGradientHeader({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.showBack = false,
    this.onBack,
    this.actions = const [],
    this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 14, 22, 22),
    this.bottomRadius = 30,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(bottom: Radius.circular(bottomRadius));

    Widget? leadingWidget = leading;
    if (leadingWidget == null && showBack) {
      leadingWidget = _HeaderIconButton(
        icon: Icons.arrow_back,
        onTap: onBack ?? () => Navigator.of(context).maybePop(),
      );
    }

    final hasTitleRow =
        title != null ||
        subtitle != null ||
        leadingWidget != null ||
        actions.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: Stack(
            children: [
              Positioned(
                top: -50,
                right: -30,
                child: _decoCircle(
                  160,
                  AppColors.white.withValues(alpha: 0.06),
                ),
              ),
              Positioned(
                bottom: -70,
                left: -40,
                child: _decoCircle(150, AppColors.gold.withValues(alpha: 0.10)),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasTitleRow)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (leadingWidget != null) ...[
                              leadingWidget,
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (title != null)
                                    Text(
                                      title!,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.white,
                                        height: 1.1,
                                      ),
                                    ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      subtitle!,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 13.5,
                                        color: AppColors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            ...actions,
                          ],
                        ),
                      if (child != null) ...[
                        if (hasTitleRow) const SizedBox(height: 18),
                        child!,
                      ],
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

  Widget _decoCircle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// White rounded icon button suitable for placement on the gradient header.
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.16),
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
