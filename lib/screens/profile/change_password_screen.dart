import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/smart_text_field.dart';

/// Change-password form: current / new / confirm fields with obscured input,
/// a live password-strength meter, client-side validation (min length +
/// match), and a sticky bottom submit action.
///
/// Submit calls [AuthService.changePassword] (Firebase reauthenticate +
/// updatePassword); on success it shows a SnackBar and pops, otherwise it
/// surfaces the returned error message.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Password strength (0 none, 1 weak, 2 medium, 3 strong) ────────
  int get _strength {
    final len = _newController.text.length;
    if (len == 0) return 0;
    if (len < 6) return 1;
    if (len < 9) return 2;
    return 3;
  }

  Color get _strengthColor {
    switch (_strength) {
      case 1:
        return AppColors.error;
      case 2:
        return AppColors.warning;
      case 3:
        return AppColors.success;
      default:
        return AppColors.line;
    }
  }

  String get _strengthLabel {
    switch (_strength) {
      case 1:
        return 'ضعيفة';
      case 2:
        return 'متوسطة';
      case 3:
        return 'قوية';
      default:
        return '';
    }
  }

  bool get _isValid {
    final cur = _currentController.text;
    final pw = _newController.text;
    final conf = _confirmController.text;
    return cur.isNotEmpty && pw.length >= 6 && pw == conf;
  }

  Widget _eyeToggle(bool obscured, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 19,
        color: AppColors.midGrey,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final err = await context.read<AuthService>().changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr(context, err),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    _currentController.clear();
    _newController.clear();
    _confirmController.clear();
    _formKey.currentState!.reset();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr(context, 'تم تغيير كلمة المرور'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );

    Navigator.of(context).maybePop();
  }

  String? _validateCurrent(String? v) {
    if (v == null || v.isEmpty) {
      return tr(context, 'أدخل كلمة المرور الحالية');
    }
    return null;
  }

  String? _validateNew(String? v) {
    if (v == null || v.isEmpty) {
      return tr(context, 'أدخل كلمة المرور الجديدة');
    }
    if (v.length < 6) {
      return tr(context, 'يجب ألا تقل عن ٦ أحرف');
    }
    if (v == _currentController.text) {
      return tr(context, 'كلمة المرور الجديدة مطابقة للحالية');
    }
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) {
      return tr(context, 'أعد إدخال كلمة المرور الجديدة');
    }
    if (v != _newController.text) {
      return tr(context, 'كلمتا المرور غير متطابقتين');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            SfGradientHeader(
              title: tr(context, 'تغيير كلمة المرور'),
              subtitle: tr(context, 'حدّث كلمة مرورك للحفاظ على أمان حسابك'),
              showBack: true,
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 24),
                  children: [
                    // Hero icon tile (brand-soft square + key icon).
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.key_outlined,
                        size: 28,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      tr(
                        context,
                        'اختر كلمة مرور قوية لا تستخدمها في مواقع أخرى.',
                      ),
                      textAlign: TextAlign.start,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13.5,
                        height: 1.6,
                        color: AppColors.midGrey,
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Current password.
                    SmartTextField(
                      label: tr(context, 'كلمة المرور الحالية'),
                      hint: tr(context, 'أدخل كلمة المرور الحالية'),
                      controller: _currentController,
                      obscureText: _obscureCurrent,
                      prefixIcon: Icons.lock_outline,
                      validator: _validateCurrent,
                      onChanged: (_) => setState(() {}),
                      suffixIcon: _eyeToggle(
                        _obscureCurrent,
                        () => setState(
                          () => _obscureCurrent = !_obscureCurrent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // New password + strength meter.
                    SmartTextField(
                      label: tr(context, 'كلمة المرور الجديدة'),
                      hint: tr(context, '٦ أحرف على الأقل'),
                      controller: _newController,
                      obscureText: _obscureNew,
                      prefixIcon: Icons.lock_open_outlined,
                      validator: _validateNew,
                      onChanged: (_) => setState(() {}),
                      suffixIcon: _eyeToggle(
                        _obscureNew,
                        () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    if (_newController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _strengthMeter(),
                    ],
                    const SizedBox(height: 16),
                    // Confirm password.
                    SmartTextField(
                      label: tr(context, 'تأكيد كلمة المرور'),
                      hint: tr(context, 'أعد إدخال كلمة المرور الجديدة'),
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      prefixIcon: Icons.lock_open_outlined,
                      validator: _validateConfirm,
                      onChanged: (_) => setState(() {}),
                      suffixIcon: _eyeToggle(
                        _obscureConfirm,
                        () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Sticky bottom action bar.
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _strengthMeter() {
    final active = _strength;
    final color = _strengthColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: List.generate(3, (i) {
              final filled = (i + 1) <= active;
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: filled ? color : AppColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          tr(context, _strengthLabel),
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: BorderDirectional(
          top: BorderSide(color: AppColors.lineSoft),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SmartButton(
          label: tr(context, 'تحديث كلمة المرور'),
          icon: Icons.check,
          isLoading: _submitting,
          onPressed: (!_isValid || _submitting) ? null : _submit,
        ),
      ),
    );
  }
}
