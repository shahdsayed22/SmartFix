import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/smart_text_field.dart';
import '../../widgets/sf_logo.dart';
import '../../widgets/sf_icons.dart';
import '../../widgets/sf_feedback.dart';
import '../../models/user_model.dart';
import '../admin/admin_home_screen.dart';
import '../customer/customer_home_screen.dart';
import '../worker/worker_gate.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    await _doSignIn(_emailController.text.trim(), _passwordController.text);
  }

  Future<void> _doSignIn(String email, String password) async {
    final authService = context.read<AuthService>();
    final error = await authService.signIn(email: email, password: password);

    if (!mounted) return;

    if (error != null) {
      _showError(error);
    } else {
      _navigateToHome(authService.currentUser!);
    }
  }

  void _showError(String error) {
    // Calm, friendly toast instead of a harsh red error bar.
    SfToast.show(context, tr(context, error), tone: SfTone.error);
  }

  void _navigateToHome(AppUser user) {
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

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.only(start: 26, end: 26),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 52),

                // Brand mark
                const Center(child: SfLogoMark(size: 84))
                    .animate()
                    .fadeIn(duration: 450.ms)
                    .scale(
                      begin: const Offset(0.82, 0.82),
                      duration: 450.ms,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 22),

                // Welcome heading
                Text(
                  tr(context, 'أهلًا بعودتك'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ).animate(delay: 120.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 6),
                Text(
                  tr(context, 'سجّل الدخول إلى حسابك في سمارت فيكس'),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.midGrey),
                ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 30),

                // Email field
                SmartTextField(
                      label: tr(context, 'البريد الإلكتروني'),
                      hint: 'you@email.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: sfIcon('mail'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return tr(context, 'يرجى إدخال البريد الإلكتروني');
                        }
                        if (!value.contains('@')) {
                          return tr(context, 'يرجى إدخال بريد إلكتروني صحيح');
                        }
                        return null;
                      },
                    )
                    .animate(delay: 260.ms)
                    .fadeIn(duration: 380.ms)
                    .slideY(
                      begin: 0.12,
                      duration: 380.ms,
                      curve: Curves.easeOut,
                    ),
                const SizedBox(height: 15),

                // Password field
                SmartTextField(
                      label: tr(context, 'كلمة المرور'),
                      hint: tr(context, 'كلمة المرور'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      prefixIcon: sfIcon('lock'),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.midGrey,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return tr(context, 'يرجى إدخال كلمة المرور');
                        }
                        if (value.length < 6) {
                          return tr(
                            context,
                            'كلمة المرور يجب أن تكون ٦ أحرف على الأقل',
                          );
                        }
                        return null;
                      },
                    )
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 380.ms)
                    .slideY(
                      begin: 0.12,
                      duration: 380.ms,
                      curve: Curves.easeOut,
                    ),
                const SizedBox(height: 6),

                // Forgot password
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(tr(context, 'نسيت كلمة المرور؟')),
                  ),
                ),
                const SizedBox(height: 20),

                // Sign in button
                SmartButton(
                  label: tr(context, 'تسجيل الدخول'),
                  onPressed: _handleLogin,
                  isLoading: authService.isLoading,
                  icon: Icons.login_rounded,
                  width: double.infinity,
                ).animate(delay: 360.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 24),

                // OR divider
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.line)),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 14,
                        end: 14,
                      ),
                      child: Text(
                        tr(context, 'أو'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.midGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: AppColors.line)),
                  ],
                ),
                const SizedBox(height: 24),

                // Create account
                SmartButton(
                  label: tr(context, 'إنشاء حساب جديد'),
                  isOutlined: true,
                  icon: Icons.person_add_outlined,
                  width: double.infinity,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Terms / privacy footer
                Center(
                  child: Text(
                    tr(
                      context,
                      'بتسجيلك أنت توافق على الشروط وسياسة الخصوصية',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.midGrey,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
