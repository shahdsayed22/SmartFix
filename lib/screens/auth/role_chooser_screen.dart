import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../widgets/sf_logo.dart';
import '../customer/customer_home_screen.dart';
import '../worker/worker_gate.dart';
import 'login_screen.dart';

/// No-login entry shown on the installed web PWA when opened without a
/// `?role=` parameter. Lets one "SmartFix" home-screen icon serve both the
/// customer and the technician by picking a guest role here (demo mode).
class RoleChooserScreen extends StatelessWidget {
  const RoleChooserScreen({super.key});

  void _enter(BuildContext context, UserRole role) {
    context.read<AuthService>().enterGuest(role);
    final Widget home = role == UserRole.worker
        ? const WorkerGate()
        : const CustomerHomeScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => home,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  /// Open the full sign-in screen (email/password + one-tap demo logins for
  /// customer / technician / admin). Admin needs a real account, so the admin
  /// card and the "sign in" link both route here rather than to a guest home.
  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const SfLogoMark(size: 82),
                const SizedBox(height: 22),
                Text(
                  tr(context, 'كيف تريد استخدام سمارت فيكس؟'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(context, 'اختر نوع حسابك للمتابعة'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.8),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(flex: 2),
                _RoleCard(
                  icon: Icons.person_rounded,
                  title: tr(context, 'عميل'),
                  subtitle: tr(context, 'اطلب خدمة صيانة وتابع طلبك'),
                  color: AppColors.secondary,
                  onTap: () => _enter(context, UserRole.customer),
                ),
                const SizedBox(height: 14),
                _RoleCard(
                  icon: Icons.handyman_rounded,
                  title: tr(context, 'فنّي'),
                  subtitle: tr(context, 'استقبل الأعمال وقدّم عروضك'),
                  color: AppColors.accent,
                  onTap: () => _enter(context, UserRole.worker),
                ),
                const SizedBox(height: 14),
                _RoleCard(
                  icon: Icons.shield_rounded,
                  title: tr(context, 'مدير'),
                  subtitle: tr(context, 'سجّل الدخول لإدارة المنصة'),
                  color: AppColors.primary,
                  onTap: () => _openLogin(context),
                ),
                const Spacer(flex: 3),
                TextButton(
                  onPressed: () => _openLogin(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.white,
                  ),
                  child: Text(
                    tr(context, 'لديك حساب؟ تسجيل الدخول'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(context, 'وضع العرض — بدون تسجيل دخول'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppColors.rCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.rCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.midGrey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.midGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
