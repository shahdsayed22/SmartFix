import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// SmartFix Material 3 theme — premium navy / teal / gold field-service look.
///
/// IBM Plex Sans Arabic for headings and body (Arabic-first / RTL). White cards
/// (radius 18) with soft navy-tinted shadows, buttons radius 14, filled fields
/// (surfaceVariant, radius 14) that focus to navy. Gold is reserved for FAB /
/// brand emphasis.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.navy,
      scaffoldBackgroundColor: AppColors.background,
      splashColor: AppColors.navySoft,
      highlightColor: AppColors.navySoft,
      colorScheme: const ColorScheme.light(
        primary: AppColors.navy,
        onPrimary: AppColors.white,
        primaryContainer: AppColors.navySoft,
        onPrimaryContainer: AppColors.navy,
        secondary: AppColors.teal,
        onSecondary: AppColors.white,
        secondaryContainer: AppColors.secondaryBg,
        onSecondaryContainer: AppColors.teal,
        tertiary: AppColors.accent,
        onTertiary: AppColors.charcoal,
        tertiaryContainer: AppColors.goldSoft,
        onTertiaryContainer: AppColors.goldDeep,
        error: AppColors.error,
        onError: AppColors.white,
        errorContainer: AppColors.dangerBg,
        onErrorContainer: AppColors.error,
        surface: AppColors.surface,
        onSurface: AppColors.charcoal,
        onSurfaceVariant: AppColors.darkGrey,
        surfaceContainerHighest: AppColors.surfaceVariant,
        outline: AppColors.line,
        outlineVariant: AppColors.lineSoft,
        shadow: AppColors.navyShadow,
      ),

      // ── Typography (IBM Plex Sans Arabic) ───────────────────────
      textTheme: TextTheme(
        displayLarge: GoogleFonts.ibmPlexSansArabic(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.charcoal,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.ibmPlexSansArabic(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.charcoal,
          letterSpacing: -0.3,
        ),
        displaySmall: GoogleFonts.ibmPlexSansArabic(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.charcoal,
        ),
        headlineMedium: GoogleFonts.ibmPlexSansArabic(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.charcoal,
        ),
        headlineSmall: GoogleFonts.ibmPlexSansArabic(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.charcoal,
        ),
        titleLarge: GoogleFonts.ibmPlexSansArabic(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.charcoal,
        ),
        titleMedium: GoogleFonts.ibmPlexSansArabic(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.charcoal,
        ),
        titleSmall: GoogleFonts.ibmPlexSansArabic(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.darkGrey,
        ),
        bodyLarge: GoogleFonts.ibmPlexSansArabic(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.darkGrey,
        ),
        bodyMedium: GoogleFonts.ibmPlexSansArabic(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.darkGrey,
        ),
        bodySmall: GoogleFonts.ibmPlexSansArabic(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.midGrey,
        ),
        labelLarge: GoogleFonts.ibmPlexSansArabic(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
          letterSpacing: 0.2,
        ),
        labelMedium: GoogleFonts.ibmPlexSansArabic(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.darkGrey,
        ),
        labelSmall: GoogleFonts.ibmPlexSansArabic(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.midGrey,
        ),
      ),

      // ── App Bar ─────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: GoogleFonts.ibmPlexSansArabic(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),

      // ── Elevated Button (navy, radius 14) ───────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.lightGrey,
          disabledForegroundColor: AppColors.midGrey,
          elevation: 0,
          shadowColor: AppColors.navyShadow,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.rBtn),
          ),
          textStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── Filled Button (navy, radius 14) ─────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: AppColors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.rBtn),
          ),
          textStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── Outlined Button (radius 14) ─────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.navy, width: 1.5),
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.rBtn),
          ),
          textStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── Text Button ─────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navy,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.rBtn),
          ),
          textStyle: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── Input Decoration (filled surfaceVariant, radius 14) ─────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.rField),
          borderSide: const BorderSide(color: Colors.transparent, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.rField),
          borderSide: const BorderSide(color: Colors.transparent, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.rField),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.rField),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.rField),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 14, color: AppColors.midGrey),
        labelStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 14, color: AppColors.darkGrey),
        floatingLabelStyle: GoogleFonts.ibmPlexSansArabic(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.navy,
        ),
        errorStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: AppColors.error),
        prefixIconColor: AppColors.midGrey,
        suffixIconColor: AppColors.midGrey,
      ),

      // ── Card (radius 18, soft navy shadow) ──────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: AppColors.cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.rCard),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ── Bottom Navigation (navy selected) ───────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.navy,
        unselectedItemColor: AppColors.midGrey,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.ibmPlexSansArabic(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.ibmPlexSansArabic(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
        elevation: 0,
      ),

      // ── Navigation Bar (M3) ─────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.navySoft,
        elevation: 0,
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.ibmPlexSansArabic(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.navy : AppColors.midGrey,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.navy : AppColors.midGrey,
          );
        }),
      ),

      // ── Floating Action Button (gold) ───────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.charcoal,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 6,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.rBtn),
        ),
      ),

      // ── Chip ────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.navy,
        secondarySelectedColor: AppColors.navy,
        disabledColor: AppColors.lightGrey,
        checkmarkColor: AppColors.white,
        side: BorderSide.none,
        labelStyle: GoogleFonts.ibmPlexSansArabic(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.darkGrey,
        ),
        secondaryLabelStyle: GoogleFonts.ibmPlexSansArabic(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      ),

      // ── Dialog ──────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.ibmPlexSansArabic(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.charcoal,
        ),
        contentTextStyle: GoogleFonts.ibmPlexSansArabic(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.darkGrey,
        ),
      ),

      // ── Bottom Sheet ────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.line,
      ),

      // ── SnackBar ────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.charcoal,
        contentTextStyle: GoogleFonts.ibmPlexSansArabic(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: AppColors.white,
        ),
        actionTextColor: AppColors.accentLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.rBtn),
        ),
      ),

      // ── Switch ──────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.white
                  : AppColors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.teal
                  : AppColors.lightGrey,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ── Progress Indicator ──────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.navy,
        linearTrackColor: AppColors.surfaceVariant,
        circularTrackColor: AppColors.surfaceVariant,
      ),

      // ── Icon ────────────────────────────────────────────────────
      iconTheme: const IconThemeData(color: AppColors.darkGrey),
      primaryIconTheme: const IconThemeData(color: AppColors.white),

      // ── Divider ─────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.lineSoft,
        thickness: 1,
        space: 24,
      ),

      // ── Tooltip ─────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: AppColors.white),
      ),
    );
  }
}
