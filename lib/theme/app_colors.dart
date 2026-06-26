import 'package:flutter/material.dart';

/// SmartFix — MSA University / SE Program branded color palette.
///
/// Light-first navy / teal / gold field-service marketplace.
/// Values mirror the "SmartFix mobile redesign" prototype's CSS :root.
/// Every public symbol the existing codebase already references is kept
/// so screens keep compiling — only the values are updated, plus new
/// tokens are added below.
class AppColors {
  AppColors._();

  // ── Brand navy ───────────────────────────────────────────────────
  static const Color navy = Color(0xFF14323B);
  static const Color navyDeep = Color(0xFF0E2A31);
  static const Color primaryDark = Color(0xFF14323B);
  static const Color primary = Color(0xFF185B56);
  static const Color primaryLight = Color(0xFF1C8C8C);

  // ── Secondary / teal ─────────────────────────────────────────────
  static const Color secondary = Color(0xFF1C8C8C);
  static const Color teal = Color(0xFF1C8C8C);
  static const Color secondaryLight = Color(0xFF3FA9A0);

  // ── Accent / gold ────────────────────────────────────────────────
  static const Color accent = Color(0xFFD98E2B);
  static const Color gold = Color(0xFFD98E2B);
  static const Color accentLight = Color(0xFFE8A94D);
  static const Color goldDeep = Color(0xFFA86A18);
  static const Color goldSoft = Color(0x73D98E2B);

  // ── Surface / background ─────────────────────────────────────────
  static const Color background = Color(0xFFF4F7F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE9F0F0);

  // ── Neutrals ─────────────────────────────────────────────────────
  static const Color charcoal = Color(0xFF16242A);
  static const Color darkGrey = Color(0xFF44545B);
  static const Color midGrey = Color(0xFF84949B);
  static const Color lightGrey = Color(0xFFDCE6E7);
  static const Color line = Color(0xFFDCE6E7);
  static const Color lineSoft = Color(0xFFEAF0F0);
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF4F7F7);
  static const Color black = Color(0xFF000000);

  // ── Tinted navy helpers ──────────────────────────────────────────
  static const Color navySoft = Color(0x12143235);
  static const Color navyShadow = Color(0x660A232A);
  static const Color cardShadow = Color(0x1A0A232A);

  // ── Status colors + soft backgrounds ─────────────────────────────
  static const Color success = Color(0xFF2E7D44);
  static const Color successBg = Color(0xFFE6F3EB);
  static const Color warning = Color(0xFFE08A18);
  static const Color warningBg = Color(0xFFFBEFDB);
  static const Color error = Color(0xFFC62828);
  static const Color dangerBg = Color(0xFFFAE7E7);
  static const Color info = Color(0xFF1565C0);
  static const Color infoBg = Color(0xFFE5EEFB);
  static const Color secondaryBg = Color(0xFFDAEFEE);

  // ── Approval (awaitingApproval) ──────────────────────────────────
  static const Color approval = Color(0xFF7A5AE0);
  static const Color approvalBg = Color(0x1F7A5AE0);

  // ── Category colors ──────────────────────────────────────────────
  static const Color plumbing = Color(0xFF1E6FD9);
  static const Color electrical = Color(0xFFEBA110);
  static const Color carpentry = Color(0xFF8A5A3B);
  static const Color painting = Color(0xFF8E44C4);
  static const Color hvac = Color(0xFF189FB6);
  static const Color cleaning = Color(0xFFDE3F7C);
  static const Color applianceRepair = Color(0xFFF2700B);
  static const Color welding = Color(0xFFD23A2A);
  static const Color tiling = Color(0xFF0E9C8C);

  // ── Radii (logical pixels) ───────────────────────────────────────
  static const double rCard = 18;
  static const double rBtn = 14;
  static const double rField = 14;

  // ── Gradients ────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentLight],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryLight],
  );

  /// Rich navy → teal hero gradient used on branded headers.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF14323B), Color(0xFF185B56), Color(0xFF1C8C8C)],
  );
}
