import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/smart_text_field.dart';
import '../../widgets/sf_feedback.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    final error = await authService.resetPassword(_emailController.text.trim());

    if (!mounted) return;

    if (error != null) {
      SfToast.show(context, tr(context, error), tone: SfTone.error);
    } else {
      SfToast.show(
        context,
        tr(context, 'تم إرسال رابط إعادة التعيين'),
        tone: SfTone.success,
      );
      setState(() => _emailSent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Light top bar with rounded back button (mirrors the design TopBar).
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 12),
              child: Row(
                children: [
                  _BackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Text(
                    tr(context, 'استعادة كلمة المرور'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsetsDirectional.fromSTEB(26, 8, 26, 28),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOut,
                  child: _emailSent ? _buildSuccessView() : _buildFormView(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Navy-soft rounded key tile
          Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.navySoft,
                    borderRadius: BorderRadius.circular(AppColors.rCard),
                  ),
                  child: const Icon(
                    Icons.vpn_key_rounded,
                    size: 28,
                    color: AppColors.navy,
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 450.ms)
              .scale(
                begin: const Offset(0.85, 0.85),
                duration: 450.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 18),
          Text(
            tr(context, 'نسيت كلمة المرور؟'),
            textAlign: TextAlign.start,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ).animate(delay: 120.ms).fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              'أدخل البريد الإلكتروني المرتبط بحسابك وسنرسل لك رابط إعادة تعيين آمنًا.',
            ),
            textAlign: TextAlign.start,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: AppColors.midGrey,
              height: 1.6,
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
          const SizedBox(height: 26),
          SmartTextField(
            label: tr(context, 'البريد الإلكتروني'),
            hint: 'you@email.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return tr(context, 'يرجى إدخال بريدك الإلكتروني');
              }
              if (!value.contains('@')) {
                return tr(context, 'يرجى إدخال بريد إلكتروني صحيح');
              }
              return null;
            },
          ).animate(delay: 280.ms).fadeIn(duration: 400.ms),
          const SizedBox(height: 24),
          SmartButton(
            label: tr(context, 'إرسال الرابط'),
            onPressed: _handleReset,
            icon: Icons.send_rounded,
            width: double.infinity,
          ).animate(delay: 340.ms).fadeIn(duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final theme = Theme.of(context);
    final email = _emailController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 30),
        Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: AppColors.successBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  size: 38,
                  color: AppColors.success,
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(
              begin: const Offset(0.5, 0.5),
              duration: 600.ms,
              curve: Curves.easeOutBack,
            ),
        const SizedBox(height: 22),
        Text(
          tr(context, 'تفقّد بريدك'),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: AppColors.charcoal,
          ),
        ).animate(delay: 250.ms).fadeIn(duration: 400.ms),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            text: '${tr(context, 'أرسلنا رابط إعادة التعيين إلى')}\n',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: AppColors.midGrey,
              height: 1.6,
            ),
            children: [
              TextSpan(
                text: email.isNotEmpty
                    ? email
                    : tr(context, 'بريدك الإلكتروني'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                  height: 1.6,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ).animate(delay: 350.ms).fadeIn(duration: 400.ms),
        const SizedBox(height: 28),
        SmartButton(
          label: tr(context, 'العودة لتسجيل الدخول'),
          onPressed: () => Navigator.pop(context),
          isOutlined: true,
          width: double.infinity,
        ).animate(delay: 450.ms).fadeIn(duration: 400.ms),
      ],
    );
  }
}

/// Light surface rounded back button (matches the design TopBar).
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: AppColors.navyShadow,
                blurRadius: 8,
                spreadRadius: -4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.charcoal,
          ),
        ),
      ),
    );
  }
}
