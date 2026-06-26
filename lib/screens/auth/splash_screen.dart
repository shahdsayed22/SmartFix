import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../widgets/sf_logo.dart';
import '../admin/admin_home_screen.dart';
import '../customer/customer_home_screen.dart';
import '../worker/worker_gate.dart';
import 'onboarding_screen.dart';
import 'role_chooser_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final authService = context.read<AuthService>();

    // Wait for auto-login to complete AND show splash for minimum 1.5s
    // (whichever finishes last), then navigate immediately
    await Future.wait([
      authService.tryAutoLogin(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

    if (!mounted) return;

    // Web PWA "open by role": a URL like /?role=customer|technician|admin starts
    // a no-login guest session and drops straight into that role's home. A real
    // signed-in session (auto-login above) always takes precedence.
    if (kIsWeb && !authService.isLoggedIn) {
      final guestRole = _roleFromQuery(Uri.base.queryParameters['role']);
      if (guestRole != null) authService.enterGuest(guestRole);
    }

    if (authService.isLoggedIn && authService.currentUser != null) {
      // User is already signed in — skip login, go straight to home
      final user = authService.currentUser!;
      final Widget screen;
      switch (user.role) {
        case UserRole.customer:
          screen = const CustomerHomeScreen();
          break;
        case UserRole.worker:
          screen = const WorkerGate();
          break;
        case UserRole.admin:
          screen = const AdminHomeScreen();
          break;
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => screen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      // Logged-out: the web PWA gets a no-login role chooser (customer/technician);
      // native still gets the onboarding intro whose CTA continues to login.
      final Widget entry =
          kIsWeb ? const RoleChooserScreen() : const OnboardingScreen();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => entry,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  /// Maps a `?role=` query value (incl. the PWA's `technician` alias) to a
  /// [UserRole]. Returns null for unknown/missing values.
  UserRole? _roleFromQuery(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'customer':
      case 'client':
        return UserRole.customer;
      case 'technician':
      case 'worker':
      case 'tech':
        return UserRole.worker;
      case 'admin':
        return UserRole.admin;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: Stack(
            children: [
              // Decorative blurred blobs (white top-start, gold bottom-end)
              PositionedDirectional(
                top: -40,
                start: -50,
                child: _Blob(
                  size: 220,
                  color: AppColors.white.withValues(alpha: 0.05),
                ),
              ),
              PositionedDirectional(
                bottom: 40,
                end: -60,
                child: _Blob(
                  size: 200,
                  color: AppColors.accent.withValues(alpha: 0.08),
                ),
              ),
              // Centered brand block
              SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SfLogoMark(size: 104)
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .scale(
                            begin: const Offset(0.6, 0.6),
                            duration: 600.ms,
                            curve: Curves.easeOutBack,
                          ),
                      const SizedBox(height: 26),
                      // Title — "Smart" white + "Fix" gold (brand wordmark stays LTR)
                      Directionality(
                            textDirection: TextDirection.ltr,
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.outfit(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  height: 1.0,
                                ),
                                children: const [
                                  TextSpan(
                                    text: 'Smart',
                                    style: TextStyle(color: AppColors.white),
                                  ),
                                  TextSpan(
                                    text: 'Fix',
                                    style: TextStyle(color: AppColors.gold),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .animate(delay: 120.ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.3, curve: Curves.easeOut),
                      const SizedBox(height: 8),
                      Text(
                            tr(context, 'حلول الصيانة المنزلية الذكية'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.white.withValues(alpha: 0.82),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                          )
                          .animate(delay: 220.ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.3, curve: Curves.easeOut),
                      const SizedBox(height: 40),
                      // Gold loading bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          width: 110,
                          height: 4,
                          child: LinearProgressIndicator(
                            backgroundColor: AppColors.white.withValues(
                              alpha: 0.18,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.gold,
                            ),
                          ),
                        ),
                      ).animate(delay: 420.ms).fadeIn(duration: 400.ms),
                    ],
                  ),
                ),
              ),
              // Footer — university branding
              Positioned(
                left: 0,
                right: 0,
                bottom: 46,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(context, 'جامعة أكتوبر للعلوم الحديثة والآداب'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.6),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr(context, 'برنامج هندسة البرمجيات · ©2026'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.gold.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ).animate(delay: 520.ms).fadeIn(duration: 400.ms),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft circular decorative blob used on the splash background.
class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
