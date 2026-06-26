import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Primary action button for SmartFix.
///
/// Restyled to the new design (navy fill, radius 14, soft navy shadow,
/// subtle press scale) while preserving the existing public API:
/// `label`, `onPressed`, `isLoading`, `isOutlined`, `icon`, `width`.
class SmartButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final double? width;

  const SmartButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.width,
  });

  @override
  State<SmartButton> createState() => _SmartButtonState();
}

class _SmartButtonState extends State<SmartButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    final outlined = widget.isOutlined;

    final fg = outlined ? AppColors.navy : AppColors.white;

    final content =
        widget.isLoading
            ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(fg),
              ),
            )
            : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 19, color: fg),
                  const SizedBox(width: 9),
                ],
                Text(
                  widget.label,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: fg,
                  ),
                ),
              ],
            );

    final decoration = BoxDecoration(
      color: outlined ? Colors.transparent : AppColors.navy,
      borderRadius: BorderRadius.circular(AppColors.rBtn),
      border: outlined ? Border.all(color: AppColors.navy, width: 1.5) : null,
      boxShadow:
          (outlined || _pressed)
              ? null
              : const [
                BoxShadow(
                  color: AppColors.navyShadow,
                  blurRadius: 16,
                  spreadRadius: -6,
                  offset: Offset(0, 6),
                ),
              ],
    );

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: disabled ? null : () => setState(() => _pressed = false),
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.width,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: decoration,
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}
