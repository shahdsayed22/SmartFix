import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/issue_model.dart';

/// Maps a Lucide icon name (as used in the SmartFix prototype) to the
/// closest Material [IconData]. Falls back to [Icons.help_outline] for
/// any name that is not recognised.
///
/// Usage: `Icon(sfIcon('wrench'))`
IconData sfIcon(String lucideName) {
  switch (lucideName) {
    // ── category icons ──────────────────────────────────────────
    case 'wrench':
      return Icons.build;
    case 'zap':
      return Icons.bolt;
    case 'hammer':
      return Icons.handyman;
    case 'paint-roller':
      return Icons.format_paint;
    case 'wind':
      return Icons.air;
    case 'spray-can':
      return Icons.cleaning_services;
    case 'washing-machine':
      return Icons.local_laundry_service;
    case 'flame':
      return Icons.local_fire_department;
    case 'grid-3x3':
    case 'grid-3-x-3':
      return Icons.grid_view;

    // ── status / urgency / feedback ─────────────────────────────
    case 'check-circle-2':
    case 'circle-check':
      return Icons.check_circle;
    case 'check':
      return Icons.check;
    case 'alert-triangle':
      return Icons.warning_amber;
    case 'siren':
      return Icons.emergency_share;
    case 'info':
      return Icons.info_outline;
    case 'x-circle':
      return Icons.cancel;
    case 'x':
      return Icons.close;

    // ── navigation / chrome ─────────────────────────────────────
    case 'map-pin':
      return Icons.location_on;
    case 'arrow-left':
      return Icons.arrow_back;
    case 'arrow-right':
      return Icons.arrow_forward;
    case 'chevron-right':
      return Icons.chevron_right;
    case 'chevron-left':
      return Icons.chevron_left;
    case 'home':
      return Icons.home_outlined;
    case 'list':
      return Icons.list_alt;
    case 'plus':
    case 'plus-circle':
      return Icons.add;
    case 'search':
      return Icons.search;
    case 'bell':
      return Icons.notifications_none;
    case 'menu':
      return Icons.menu;
    case 'settings':
      return Icons.settings_outlined;
    case 'log-out':
      return Icons.logout;
    case 'filter':
      return Icons.tune;
    case 'sliders':
    case 'sliders-horizontal':
      return Icons.tune;

    // ── people / profile ────────────────────────────────────────
    case 'user':
      return Icons.person_outline;
    case 'users':
      return Icons.group_outlined;
    case 'user-circle':
      return Icons.account_circle_outlined;
    case 'mail':
      return Icons.mail_outline;
    case 'phone':
      return Icons.phone_outlined;
    case 'calendar':
      return Icons.calendar_today_outlined;
    case 'shield':
    case 'shield-check':
      return Icons.verified_user_outlined;
    case 'badge-check':
      return Icons.verified_outlined;
    case 'award':
      return Icons.workspace_premium_outlined;

    // ── messaging ───────────────────────────────────────────────
    case 'message-circle':
    case 'message-square':
      return Icons.chat_bubble_outline;
    case 'send':
      return Icons.send;
    case 'paperclip':
      return Icons.attach_file;

    // ── media / misc ────────────────────────────────────────────
    case 'camera':
      return Icons.photo_camera_outlined;
    case 'image':
      return Icons.image_outlined;
    case 'map':
      return Icons.map_outlined;
    case 'navigation':
      return Icons.near_me_outlined;
    case 'star':
      return Icons.star;
    case 'star-half':
      return Icons.star_half;
    case 'clock':
      return Icons.access_time;
    case 'eye':
      return Icons.visibility_outlined;
    case 'eye-off':
      return Icons.visibility_off_outlined;
    case 'lock':
      return Icons.lock_outline;
    case 'edit':
    case 'pencil':
      return Icons.edit_outlined;
    case 'trash':
    case 'trash-2':
      return Icons.delete_outline;
    case 'briefcase':
      return Icons.work_outline;
    case 'wallet':
      return Icons.account_balance_wallet_outlined;
    case 'help-circle':
      return Icons.help_outline;
    case 'file-text':
      return Icons.description_outlined;
    case 'inbox':
      return Icons.inbox_outlined;
    case 'play':
      return Icons.play_arrow;
    case 'wrench-screwdriver':
      return Icons.handyman;

    // ── status-bar glyphs (rarely needed on Flutter) ────────────
    case 'wifi':
      return Icons.wifi;
    case 'signal':
      return Icons.signal_cellular_alt;
    case 'battery-full':
      return Icons.battery_full;

    default:
      return Icons.help_outline;
  }
}

/// Resolved display configuration for a service category:
/// a human label, a Material icon, and the category accent color.
class SfCategory {
  final String label;
  final IconData icon;
  final Color color;

  const SfCategory({
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// Category config keyed by the *string* names used across the app
/// (snake_case, matching the prototype + the REST API: `plumbing`,
/// `electrical`, `carpentry`, `painting`, `hvac`, `cleaning`,
/// `appliance_repair`, `welding`, `tiling`).
///
/// Both `appliance_repair` (API form) and `applianceRepair` (Dart enum
/// `.name`) resolve to the same entry.
const Map<String, SfCategory> kSfCategories = {
  'plumbing': SfCategory(
    label: 'السباكة',
    icon: Icons.build,
    color: AppColors.plumbing,
  ),
  'electrical': SfCategory(
    label: 'الكهرباء',
    icon: Icons.bolt,
    color: AppColors.electrical,
  ),
  'carpentry': SfCategory(
    label: 'النجارة',
    icon: Icons.handyman,
    color: AppColors.carpentry,
  ),
  'painting': SfCategory(
    label: 'الدهانات',
    icon: Icons.format_paint,
    color: AppColors.painting,
  ),
  'hvac': SfCategory(
    label: 'التكييف والتبريد',
    icon: Icons.air,
    color: AppColors.hvac,
  ),
  'cleaning': SfCategory(
    label: 'التنظيف',
    icon: Icons.cleaning_services,
    color: AppColors.cleaning,
  ),
  'appliance_repair': SfCategory(
    label: 'صيانة الأجهزة',
    icon: Icons.local_laundry_service,
    color: AppColors.applianceRepair,
  ),
  'applianceRepair': SfCategory(
    label: 'صيانة الأجهزة',
    icon: Icons.local_laundry_service,
    color: AppColors.applianceRepair,
  ),
  'welding': SfCategory(
    label: 'اللحام',
    icon: Icons.local_fire_department,
    color: AppColors.welding,
  ),
  'tiling': SfCategory(
    label: 'السيراميك والبلاط',
    icon: Icons.grid_view,
    color: AppColors.tiling,
  ),
};

/// Ordered list of category string keys for grids / chip rows.
const List<String> kSfCategoryOrder = [
  'plumbing',
  'electrical',
  'carpentry',
  'painting',
  'hvac',
  'cleaning',
  'appliance_repair',
  'welding',
  'tiling',
];

/// Resolve an [SfCategory] from either an [IssueCategory] enum value or a
/// raw string key. Always returns a valid config (defaults to plumbing).
SfCategory sfCategory(Object category) {
  if (category is IssueCategory) {
    return kSfCategories[category.name] ?? kSfCategories['plumbing']!;
  }
  final key = category.toString();
  return kSfCategories[key] ?? kSfCategories['plumbing']!;
}
