import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../widgets/skills_picker_sheet.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../widgets/verified_badge.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_avatar.dart';
import '../../widgets/sf_cat_tile.dart';
import '../../widgets/sf_profile_row.dart';
import '../../widgets/sf_feedback.dart';
import '../../widgets/smart_button.dart';
import '../auth/login_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/settings_screen.dart';
import '../payment/earnings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../support/support_tickets_screen.dart';
import '../support/support_assistant_screen.dart';
import '../worker/availability_screen.dart';

class WorkerProfileScreen extends StatelessWidget {
  const WorkerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    final skills = user?.skills ?? const <String>[];
    final memberSince = _formatMemberSince(context, user?.createdAt);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Navy hero header: avatar, name, role pill, stat strip ──────
          SliverToBoxAdapter(
            child: SfGradientHeader(
              padding: const EdgeInsetsDirectional.fromSTEB(22, 8, 22, 28),
              bottomRadius: 32,
              title: tr(context, 'الملف الشخصي'),
              actions: [
                _HeaderGlassButton(
                  icon: Icons.settings_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
              child: Column(
                children: [
                  // Avatar with verified badge
                  Stack(
                        children: [
                          SfAvatar(
                            name: user?.name ?? '',
                            size: 92,
                            bg: AppColors.white.withValues(alpha: 0.14),
                            fg: AppColors.gold,
                            ring: true,
                          ),
                          PositionedDirectional(
                            bottom: 2,
                            start: 2,
                            child: VerifiedBadge(
                              isVerified: user?.isVerified ?? false,
                              size: 26,
                            ),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        duration: 500.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: 14),
                  Text(
                    user?.name ?? tr(context, 'فني'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Role pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.engineering_outlined,
                          size: 15,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tr(context, 'فني'),
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Stat strip (skills + verification — backed by real data)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _HeaderStat(
                        value: '${skills.length}',
                        label: tr(context, 'مهارة'),
                      ),
                      _statDivider(),
                      _HeaderStat(
                        value:
                            user?.isVerified == true
                                ? tr(context, 'نعم')
                                : tr(context, 'لا'),
                        label: tr(context, 'موثّق'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 20, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── My Skills ─────────────────────────────────────────
                  // Always shown so a worker can add/edit skills from here —
                  // they land in the profile chips, the dashboard Users page
                  // (User.skills) and the dashboard Technicians page
                  // (Technician.categories) via AuthService.updateSkills.
                  Row(
                    children: [
                      Expanded(child: _SectionLabel(tr(context, 'مهاراتي'))),
                      _EditSkillsButton(
                        initial: skills,
                        onSave: (picked) =>
                            authService.updateSkills(picked),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (skills.isNotEmpty)
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children:
                          skills
                              .map((skill) => SfCategoryChip(category: skill))
                              .toList(),
                    ).animate().fadeIn(duration: 400.ms)
                  else
                    Text(
                      tr(context, 'لم تُضِف أي مهارة بعد'),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.charcoal.withValues(alpha: 0.55),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // ── Account Details ───────────────────────────────────
                  _SectionLabel(tr(context, 'بيانات الحساب')),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppColors.rCard),
                      border: Border.all(color: AppColors.lineSoft),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: 14,
                          spreadRadius: -10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SfProfileRow(
                          icon: Icons.mail_outline,
                          label: tr(context, 'البريد الإلكتروني'),
                          value: user?.email ?? '',
                        ),
                        SfProfileRow(
                          icon: Icons.phone_outlined,
                          label: tr(context, 'الهاتف'),
                          value:
                              user?.phone.isNotEmpty == true
                                  ? user!.phone
                                  : tr(context, 'غير محدّد'),
                        ),
                        SfProfileRow(
                          icon: Icons.location_on_outlined,
                          label: tr(context, 'العنوان'),
                          value: user?.address ?? tr(context, 'غير محدّد'),
                        ),
                        SfProfileRow(
                          icon: Icons.verified_user_outlined,
                          label: tr(context, 'حالة التوثيق'),
                          value:
                              user?.isVerified == true
                                  ? tr(context, 'موثّق')
                                  : tr(context, 'بانتظار التوثيق'),
                          valueColor:
                              user?.isVerified == true
                                  ? AppColors.success
                                  : AppColors.warning,
                        ),
                        SfProfileRow(
                          icon: Icons.calendar_today_outlined,
                          label: tr(context, 'عضو منذ'),
                          value: memberSince,
                          last: true,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
                  const SizedBox(height: 24),

                  // ── My Services (navigation menu) ─────────────────────
                  _SectionLabel(tr(context, 'خدماتي')),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppColors.rCard),
                      border: Border.all(color: AppColors.lineSoft),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: 14,
                          spreadRadius: -10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SfProfileRow(
                          icon: Icons.event_available_outlined,
                          label: tr(context, 'التوفّر والتخصصات'),
                          value: tr(context, 'مواعيد عملك ومجالات خدمتك'),
                          trailing: const _MenuChevron(),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AvailabilityScreen(
                                  technicianId: user?.uid,
                                ),
                              ),
                            );
                          },
                        ),
                        SfProfileRow(
                          icon: Icons.payments_outlined,
                          label: tr(context, 'الأرباح'),
                          value: tr(context, 'تتبّع دخلك وعمولاتك'),
                          trailing: const _MenuChevron(),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EarningsScreen(),
                              ),
                            );
                          },
                        ),
                        SfProfileRow(
                          icon: Icons.notifications_none_rounded,
                          label: tr(context, 'الإشعارات'),
                          value: tr(context, 'آخر التحديثات والتنبيهات'),
                          trailing: const _MenuChevron(),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                          },
                        ),
                        SfProfileRow(
                          icon: Icons.support_agent_rounded,
                          label: tr(context, 'مساعد الدعم'),
                          value: tr(context, 'إجابات فورية عن الطلبات والدفع'),
                          trailing: const _MenuChevron(),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SupportAssistantScreen(
                                  role: 'worker',
                                ),
                              ),
                            );
                          },
                        ),
                        SfProfileRow(
                          icon: Icons.support_agent_outlined,
                          label: tr(context, 'الدعم الفني'),
                          value: tr(context, 'تذاكر الدعم والمساعدة'),
                          last: true,
                          trailing: const _MenuChevron(),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SupportTicketsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
                  const SizedBox(height: 24),

                  // ── Actions ───────────────────────────────────────────
                  SmartButton(
                    label: tr(context, 'تعديل الملف الشخصي'),
                    icon: Icons.edit_outlined,
                    isOutlined: true,
                    width: double.infinity,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _DangerButton(
                    label: tr(context, 'تسجيل الخروج'),
                    icon: Icons.logout_rounded,
                    onPressed: () async {
                      final confirm = await SfDialog.confirm(
                        context,
                        title: tr(context, 'تسجيل الخروج؟'),
                        body: tr(
                          context,
                          'هل تريد بالتأكيد تسجيل الخروج من سمارت فيكس؟',
                        ),
                        confirmLabel: tr(context, 'تسجيل الخروج'),
                        cancelLabel: tr(context, 'إلغاء'),
                        tone: SfTone.error,
                        icon: Icons.logout,
                      );
                      if (confirm == true) {
                        await authService.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 26),

                  // ── Footer / branding ─────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Text(
                          tr(context, 'سمارت فيكس · الإصدار ٢٫٠'),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: AppColors.midGrey,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tr(context, 'جامعة أكتوبر للعلوم الحديثة · برنامج هندسة البرمجيات'),
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.goldDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _statDivider() => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsetsDirectional.symmetric(horizontal: 22),
    color: AppColors.white.withValues(alpha: 0.18),
  );

  static String _formatMemberSince(BuildContext context, DateTime? date) {
    if (date == null) return '—';
    final months = [
      tr(context, 'يناير'),
      tr(context, 'فبراير'),
      tr(context, 'مارس'),
      tr(context, 'أبريل'),
      tr(context, 'مايو'),
      tr(context, 'يونيو'),
      tr(context, 'يوليو'),
      tr(context, 'أغسطس'),
      tr(context, 'سبتمبر'),
      tr(context, 'أكتوبر'),
      tr(context, 'نوفمبر'),
      tr(context, 'ديسمبر'),
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

/// Small section heading used above each block.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.charcoal,
      ),
    );
  }
}

/// Directional chevron used as the trailing affordance on navigation rows.
class _MenuChevron extends StatelessWidget {
  const _MenuChevron();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.chevron_left_rounded,
      size: 22,
      color: AppColors.midGrey,
    );
  }
}

/// A single value/label pair in the navy header stat strip.
class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: AppColors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

/// Translucent rounded glass button for the gradient header action slot.
class _HeaderGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderGlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: AppColors.white),
        ),
      ),
    );
  }
}

/// Full-width danger (sign-out) button matching the prototype's red action.
class _DangerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _DangerButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.rBtn),
          ),
        ),
      ),
    );
  }
}

/// Compact "Edit skills" action that opens the multi-select skills picker and
/// hands the chosen list back to the profile (which persists it everywhere via
/// [AuthService.updateSkills]). Localized AR/EN.
class _EditSkillsButton extends StatelessWidget {
  const _EditSkillsButton({required this.initial, required this.onSave});

  final List<String> initial;
  final Future<void> Function(List<String> picked) onSave;

  Future<void> _open(BuildContext context) async {
    // Resolve everything that needs `context` up front so nothing touches it
    // across the async gaps below.
    final messenger = ScaffoldMessenger.of(context);
    final savedMsg = tr(context, 'تم حفظ المهارات');
    final failedMsg = tr(context, 'تعذّر حفظ المهارات، حاول مرة أخرى');

    final picked = await showSkillsPicker(context, initial: initial);
    if (picked == null) return; // dismissed without saving

    SnackBar snack(String text, Color bg) => SnackBar(
          backgroundColor: bg,
          content: Text(
            text,
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        );

    try {
      await onSave(picked);
      messenger.showSnackBar(snack(savedMsg, AppColors.success));
    } catch (_) {
      messenger.showSnackBar(snack(failedMsg, AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = initial.isEmpty
        ? tr(context, 'أضِف مهاراتك')
        : tr(context, 'تعديل المهارات');
    return TextButton.icon(
      onPressed: () => _open(context),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(initial.isEmpty ? Icons.add_rounded : Icons.edit_outlined,
          size: 17),
      label: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
