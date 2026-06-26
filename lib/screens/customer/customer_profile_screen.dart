import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_avatar.dart';
import '../../widgets/sf_profile_row.dart';
import '../../widgets/sf_feedback.dart';
import '../../widgets/sf_icons.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/verified_badge.dart';
import '../auth/login_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/settings_screen.dart';
import '../payment/wallet_screen.dart';
import '../payment/invoices_screen.dart';
import '../support/support_tickets_screen.dart';
import '../notifications/notifications_screen.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    final memberSince =
        user?.createdAt != null
            ? '${user!.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}'
            : tr(context, 'غير معروف');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Gradient profile header ──────────────────────────────────
          SfGradientHeader(
            bottomRadius: 32,
            padding: const EdgeInsetsDirectional.fromSTEB(22, 14, 22, 28),
            title: tr(context, 'الملف الشخصي'),
            actions: [
              Material(
                color: AppColors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.settings_outlined,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
            child: Column(
              children: [
                // Avatar + verified badge
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
                      begin: const Offset(0.8, 0.8),
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 14),
                Text(
                  user?.name ?? tr(context, 'مستخدم'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                // Role pill
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
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
                      Icon(sfIcon('user'), size: 14, color: AppColors.gold),
                      const SizedBox(width: 6),
                      Text(
                        tr(context, 'عميل'),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Account details + actions ────────────────────────────────
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 20, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'بيانات الحساب'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
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
                        icon: sfIcon('mail'),
                        label: tr(context, 'البريد الإلكتروني'),
                        value: user?.email ?? '',
                      ),
                      SfProfileRow(
                        icon: sfIcon('phone'),
                        label: tr(context, 'الهاتف'),
                        value: user?.phone ?? tr(context, 'غير محدد'),
                      ),
                      SfProfileRow(
                        icon: sfIcon('map-pin'),
                        label: tr(context, 'العنوان'),
                        value: user?.address ?? tr(context, 'غير محدد'),
                      ),
                      SfProfileRow(
                        icon: sfIcon('shield-check'),
                        label: tr(context, 'حالة التوثيق'),
                        value:
                            user?.isVerified == true
                                ? tr(context, 'موثّق')
                                : tr(context, 'غير موثّق'),
                        valueColor:
                            user?.isVerified == true
                                ? AppColors.success
                                : AppColors.midGrey,
                      ),
                      SfProfileRow(
                        icon: sfIcon('calendar'),
                        label: tr(context, 'عضو منذ'),
                        value: memberSince,
                        last: true,
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
                const SizedBox(height: 22),

                // ── Quick actions menu ─────────────────────────────────
                Text(
                  tr(context, 'حسابي وخدماتي'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
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
                        icon: sfIcon('wallet'),
                        label: tr(context, 'الرصيد والمدفوعات'),
                        value: tr(context, 'محفظتي'),
                        trailing: Icon(
                          sfIcon('chevron-left'),
                          size: 20,
                          color: AppColors.midGrey,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WalletScreen(),
                            ),
                          );
                        },
                      ),
                      SfProfileRow(
                        icon: sfIcon('file-text'),
                        label: tr(context, 'سجل المعاملات'),
                        value: tr(context, 'الفواتير'),
                        trailing: Icon(
                          sfIcon('chevron-left'),
                          size: 20,
                          color: AppColors.midGrey,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const InvoicesScreen(),
                            ),
                          );
                        },
                      ),
                      SfProfileRow(
                        icon: sfIcon('help-circle'),
                        label: tr(context, 'تحتاج مساعدة؟'),
                        value: tr(context, 'الدعم الفني'),
                        trailing: Icon(
                          sfIcon('chevron-left'),
                          size: 20,
                          color: AppColors.midGrey,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SupportTicketsScreen(),
                            ),
                          );
                        },
                      ),
                      SfProfileRow(
                        icon: sfIcon('bell'),
                        label: tr(context, 'آخر التحديثات'),
                        value: tr(context, 'الإشعارات'),
                        last: true,
                        trailing: Icon(
                          sfIcon('chevron-left'),
                          size: 20,
                          color: AppColors.midGrey,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(
                  begin: 0.05,
                ),
                const SizedBox(height: 22),

                // Edit profile (outline)
                SmartButton(
                  label: tr(context, 'تعديل الملف الشخصي'),
                  icon: sfIcon('pencil'),
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
                const SizedBox(height: 11),

                // Sign out (danger)
                _DangerButton(
                  label: tr(context, 'تسجيل الخروج'),
                  icon: sfIcon('log-out'),
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
                      icon: sfIcon('log-out'),
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
                // ── Footer: app version + university branding ───────────
                Center(
                  child: Column(
                    children: [
                      Text(
                        tr(context, 'سمارت فيكس · الإصدار ٢٫٠'),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          color: AppColors.midGrey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(context, 'جامعة أكتوبر للعلوم الحديثة · برنامج هندسة البرمجيات'),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          color: AppColors.goldDeep,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width danger button styled to match [SmartButton] (radius 14,
/// press scale) but with an error-red fill for destructive actions.
class _DangerButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function() onPressed;

  const _DangerButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_DangerButton> createState() => _DangerButtonState();
}

class _DangerButtonState extends State<_DangerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(AppColors.rBtn),
            boxShadow:
                _pressed
                    ? null
                    : [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.30),
                        blurRadius: 16,
                        spreadRadius: -6,
                        offset: const Offset(0, 6),
                      ),
                    ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 19, color: AppColors.white),
              const SizedBox(width: 9),
              Text(
                widget.label,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
