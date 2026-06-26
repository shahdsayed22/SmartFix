import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';

/// Tone of an [SfToast] / [SfDialog]: success, error, warning, or info.
enum SfTone { success, error, warning, info }

Color _toneColor(SfTone tone) {
  switch (tone) {
    case SfTone.success:
      return AppColors.success;
    case SfTone.error:
      return AppColors.error;
    case SfTone.warning:
      return AppColors.warning;
    case SfTone.info:
      return AppColors.navy;
  }
}

Color _toneBg(SfTone tone) {
  switch (tone) {
    case SfTone.success:
      return AppColors.successBg;
    case SfTone.error:
      return AppColors.dangerBg;
    case SfTone.warning:
      return AppColors.warningBg;
    case SfTone.info:
      return AppColors.navySoft;
  }
}

IconData _toneIcon(SfTone tone) {
  switch (tone) {
    case SfTone.success:
      return Icons.check_circle;
    case SfTone.error:
      return Icons.cancel;
    case SfTone.warning:
      return Icons.warning_amber;
    case SfTone.info:
      return Icons.info_outline;
  }
}

/// Branded toast — mirrors the prototype's `Toast`. A colored floating pill
/// with a leading icon, shown via the [ScaffoldMessenger].
///
/// Usage: `SfToast.show(context, 'تم الحفظ', tone: SfTone.success);`
class SfToast {
  SfToast._();

  static void show(
    BuildContext context,
    String message, {
    SfTone tone = SfTone.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final color = _toneColor(tone);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          elevation: 0,
          duration: duration,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(_toneIcon(tone), size: 20, color: AppColors.white),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  tr(context, message),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

/// Branded confirm dialog — mirrors the prototype's `Dialog`. Returns `true`
/// when confirmed, `false`/`null` otherwise.
///
/// Usage:
/// ```dart
/// final ok = await SfDialog.confirm(
///   context,
///   title: 'حذف البلاغ',
///   body: 'لا يمكن التراجع عن هذا الإجراء.',
///   tone: SfTone.error,
/// );
/// ```
class SfDialog {
  SfDialog._();

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String body,
    String confirmLabel = 'تأكيد',
    String cancelLabel = 'إلغاء',
    SfTone tone = SfTone.success,
    IconData? icon,
  }) {
    final color = _toneColor(tone);
    return showDialog<bool>(
      context: context,
      barrierColor: const Color(0x80081418),
      builder:
          (ctx) => Dialog(
            backgroundColor: AppColors.surface,
            insetPadding: const EdgeInsets.all(28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _toneBg(tone),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          icon ?? _toneIcon(tone),
                          size: 20,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          tr(ctx, title),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(ctx, body),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14.5,
                      height: 1.6,
                      color: AppColors.darkGrey,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.navySoft,
                            foregroundColor: AppColors.navy,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppColors.rBtn),
                            ),
                          ),
                          child: Text(
                            tr(ctx, cancelLabel),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: TextButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppColors.rBtn),
                            ),
                          ),
                          child: Text(
                            tr(ctx, confirmLabel),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

/// Branded bottom sheet — mirrors the prototype's `Sheet`. Rounded top
/// corners, a grab handle, and scrollable content. Returns whatever the
/// sheet pops with.
///
/// Usage:
/// ```dart
/// await SfSheet.show(context, builder: (ctx) => MyFilters());
/// ```
class SfSheet {
  SfSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: AppColors.surface,
      barrierColor: const Color(0x73081418),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder:
          (ctx) => SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 10,
                bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Flexible(child: builder(ctx)),
                ],
              ),
            ),
          ),
    );
  }
}
