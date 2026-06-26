import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../map/location_picker_screen.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/smart_text_field.dart';
import '../../widgets/sf_feedback.dart';
import '../../widgets/sf_icons.dart';
import '../../models/user_model.dart';
import '../customer/customer_home_screen.dart';
import '../worker/worker_gate.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  UserRole _selectedRole = UserRole.customer;
  final Set<String> _selectedSkills = {};

  // Worker service location (detected via GPS or picked on the map).
  final _location = LocationService();
  double? _lat;
  double? _lng;
  bool _detecting = false;

  // National ID images (front/back) — required for technician registration.
  // Stored as bytes so the preview and upload work on both mobile and web PWA.
  Uint8List? _idFrontBytes;
  Uint8List? _idBackBytes;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Detect the worker's service location via GPS and reverse-geocode it into
  /// the address field. Falls back to the map picker when GPS is blocked
  /// (web PWA over HTTP / denied permission), mirroring the customer flow.
  Future<void> _detectLocation() async {
    setState(() => _detecting = true);
    final pos = await _location.getCurrentPosition();
    if (pos != null) {
      _lat = pos.latitude;
      _lng = pos.longitude;
      final addr = await _location.getAddressFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (mounted) {
        _addressController.text = addr;
        setState(() => _detecting = false);
      }
    } else {
      if (!mounted) return;
      setState(() => _detecting = false);
      _showSnack(
        tr(context, 'تعذّر تحديد موقعك تلقائياً — حدّده على الخريطة أو اكتب العنوان.'),
        AppColors.warning,
        Icons.location_off_outlined,
      );
      await _openMapPicker();
    }
  }

  /// Open the map picker and fill the address + coordinates from its result.
  Future<void> _openMapPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLat: _lat, initialLng: _lng),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        final lat = result['lat'];
        final lng = result['lng'];
        if (lat is num) _lat = lat.toDouble();
        if (lng is num) _lng = lng.toDouble();
        final addr = (result['address'] as String?)?.trim() ?? '';
        if (addr.isNotEmpty) _addressController.text = addr;
      });
    }
  }

  /// Pick a national ID image (front/back) from the gallery and keep its bytes
  /// for preview + upload. Used only on the technician registration path.
  Future<void> _pickNationalId({required bool isFront}) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (isFront) {
          _idFrontBytes = bytes;
        } else {
          _idBackBytes = bytes;
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        '${tr(context, 'تعذّر اختيار الصورة')}: $e',
        AppColors.error,
        Icons.error_outline,
      );
    }
  }

  void _showSnack(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: AppColors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == UserRole.worker && _selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(tr(context, 'يرجى اختيار مهارة واحدة على الأقل')),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    if (_selectedRole == UserRole.worker &&
        (_idFrontBytes == null || _idBackBytes == null)) {
      _showSnack(
        tr(context, 'يرجى رفع صورة البطاقة (الوجه والظهر)'),
        AppColors.warning,
        Icons.warning_amber_rounded,
      );
      return;
    }

    final authService = context.read<AuthService>();
    final error = await authService.signUp(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole,
      skills: _selectedSkills.toList(),
      phone: _phoneController.text.trim(),
      latitude: _lat,
      longitude: _lng,
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      nationalIdFront: _idFrontBytes,
      nationalIdBack: _idBackBytes,
    );

    if (!mounted) return;

    if (error != null) {
      // Friendly toast (e.g. "email already registered → try logging in")
      // instead of a scary red error bar.
      SfToast.show(context, tr(context, error), tone: SfTone.error);
    } else {
      final screen =
          _selectedRole == UserRole.customer
              ? const CustomerHomeScreen()
              : const WorkerGate();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => screen),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Light top bar with rounded back button
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 10, 18, 8),
              child: Row(
                children: [
                  _BackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Text(
                    tr(context, 'إنشاء حساب'),
                    style: const TextStyle(
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
                padding: const EdgeInsetsDirectional.fromSTEB(24, 4, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Text(
                        tr(context, 'انضم إلى سمارت فيكس'),
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                          letterSpacing: -0.4,
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.08),
                      const SizedBox(height: 5),
                      Text(
                        tr(context, 'أنشئ حسابك للبدء في الخدمة'),
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.midGrey,
                        ),
                      ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
                      const SizedBox(height: 22),

                      // Role selection
                      Text(
                        tr(context, 'أنا…'),
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Expanded(
                            child: _RoleCard(
                              icon: Icons.person_outline,
                              label: tr(context, 'عميل'),
                              subtitle: tr(context, 'أُبلّغ عن مشاكل وأتابعها'),
                              isSelected: _selectedRole == UserRole.customer,
                              onTap:
                                  () => setState(
                                    () => _selectedRole = UserRole.customer,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RoleCard(
                              icon: Icons.engineering_outlined,
                              label: tr(context, 'فني'),
                              subtitle: tr(context, 'أجد وظائف وأنفّذها'),
                              isSelected: _selectedRole == UserRole.worker,
                              onTap:
                                  () => setState(
                                    () => _selectedRole = UserRole.worker,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Name
                      SmartTextField(
                        label: tr(context, 'الاسم بالكامل'),
                        hint: tr(context, 'مثال: مريم حسن'),
                        controller: _nameController,
                        prefixIcon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return tr(context, 'يرجى إدخال اسمك');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Email
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
                      ),
                      const SizedBox(height: 14),

                      // Phone
                      SmartTextField(
                        label: tr(context, 'رقم الهاتف'),
                        hint: '٠١XX XXX XXXX',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: 14),

                      // Password
                      SmartTextField(
                        label: tr(context, 'كلمة المرور'),
                        hint: tr(context, '٦ أحرف على الأقل'),
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.midGrey,
                          ),
                          onPressed:
                              () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return tr(context, 'يرجى إدخال كلمة المرور');
                          }
                          if (value.length < 6) {
                            return tr(
                              context,
                              'يجب أن تتكون كلمة المرور من ٦ أحرف على الأقل',
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Confirm Password
                      SmartTextField(
                        label: tr(context, 'تأكيد كلمة المرور'),
                        hint: tr(context, 'أعد إدخال كلمة المرور'),
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.midGrey,
                          ),
                          onPressed:
                              () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return tr(context, 'كلمتا المرور غير متطابقتين');
                          }
                          return null;
                        },
                      ),

                      // Worker skills selection
                      if (_selectedRole == UserRole.worker) ...[
                        const SizedBox(height: 20),
                        Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(
                                  AppColors.rCard,
                                ),
                                border: Border.all(color: AppColors.lineSoft),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: AppColors.goldSoft,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          sfIcon('wrench'),
                                          size: 17,
                                          color: AppColors.goldDeep,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tr(context, 'مهاراتك'),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.charcoal,
                                              ),
                                            ),
                                            Text(
                                              tr(
                                                context,
                                                'اختر الخدمات التي تقدّمها',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.midGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 13),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                        kSfCategoryOrder.map((key) {
                                          final cat = kSfCategories[key]!;
                                          final isSelected = _selectedSkills
                                              .contains(key);
                                          return _SkillChip(
                                            label: cat.label,
                                            icon: cat.icon,
                                            color: cat.color,
                                            isSelected: isSelected,
                                            onTap: () {
                                              setState(() {
                                                if (isSelected) {
                                                  _selectedSkills.remove(key);
                                                } else {
                                                  _selectedSkills.add(key);
                                                }
                                              });
                                            },
                                          );
                                        }).toList(),
                                  ),
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.05),
                        const SizedBox(height: 14),
                        // National ID upload (front + back) — required to verify.
                        Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(
                                  AppColors.rCard,
                                ),
                                border: Border.all(color: AppColors.lineSoft),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: AppColors.goldSoft,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.badge_outlined,
                                          size: 17,
                                          color: AppColors.goldDeep,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tr(context, 'بطاقة الرقم القومي'),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.charcoal,
                                              ),
                                            ),
                                            Text(
                                              tr(
                                                context,
                                                'ارفع صورة واضحة للوجه والظهر للتوثيق',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.midGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 13),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _IdUploadTile(
                                          label: tr(context, 'الوجه الأمامي'),
                                          bytes: _idFrontBytes,
                                          onTap: () =>
                                              _pickNationalId(isFront: true),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _IdUploadTile(
                                          label: tr(context, 'الوجه الخلفي'),
                                          bytes: _idBackBytes,
                                          onTap: () =>
                                              _pickNationalId(isFront: false),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.05),
                        const SizedBox(height: 14),
                        // Service location (detect via GPS or pick on map) —
                        // mirrors the customer report flow's location step.
                        Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(
                                  AppColors.rCard,
                                ),
                                border: Border.all(color: AppColors.lineSoft),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: AppColors.goldSoft,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.location_on_outlined,
                                          size: 17,
                                          color: AppColors.goldDeep,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tr(context, 'منطقة الخدمة'),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.charcoal,
                                              ),
                                            ),
                                            Text(
                                              tr(
                                                context,
                                                'حدّد موقعك ليصلك العمل القريب منك',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.midGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 13),
                                  SmartTextField(
                                    label: tr(context, 'العنوان'),
                                    hint: tr(context, 'الشارع، الحي، المدينة'),
                                    controller: _addressController,
                                    prefixIcon: Icons.location_on_outlined,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _detecting
                                              ? null
                                              : _detectLocation,
                                          icon: _detecting
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.my_location,
                                                  size: 18,
                                                ),
                                          label: Text(
                                            tr(context, 'موقعي الحالي'),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.navy,
                                            side: const BorderSide(
                                              color: AppColors.line,
                                            ),
                                            padding:
                                                const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _detecting
                                              ? null
                                              : _openMapPicker,
                                          icon: const Icon(
                                            Icons.map_outlined,
                                            size: 18,
                                          ),
                                          label: Text(
                                            tr(context, 'على الخريطة'),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.navy,
                                            side: const BorderSide(
                                              color: AppColors.line,
                                            ),
                                            padding:
                                                const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.05),
                      ],
                      const SizedBox(height: 24),

                      // Register button
                      SmartButton(
                        label: tr(context, 'إنشاء الحساب'),
                        onPressed: _handleRegister,
                        isLoading: authService.isLoading,
                        icon: Icons.person_add_rounded,
                        width: double.infinity,
                      ),
                      const SizedBox(height: 18),

                      // Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tr(context, 'لديك حساب بالفعل؟'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.midGrey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              tr(context, 'سجّل الدخول'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White rounded back button used on light screens.
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
                color: AppColors.cardShadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            size: 17,
            color: AppColors.charcoal,
          ),
        ),
      ),
    );
  }
}

/// National ID upload tile — shows a dashed placeholder, or the picked image
/// with a small "change" overlay once an image is selected.
class _IdUploadTile extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final VoidCallback onTap;

  const _IdUploadTile({
    required this.label,
    required this.bytes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = bytes != null;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.55,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasImage ? AppColors.navy : AppColors.line,
              width: 1.5,
            ),
          ),
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(bytes!, fit: BoxFit.cover),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: AppColors.navy.withValues(alpha: 0.78),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.edit, size: 12,
                                color: AppColors.white),
                            const SizedBox(width: 4),
                            Text(
                              tr(context, 'تغيير'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        size: 22, color: AppColors.navy),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Role selection card — navy filled with gold icon when selected.
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navy : AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.rCard),
          border: Border.all(
            color: isSelected ? AppColors.navy : AppColors.line,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.navyShadow.withValues(
                alpha: isSelected ? 0.40 : 0.10,
              ),
              blurRadius: isSelected ? 26 : 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.white.withValues(alpha: 0.14)
                        : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 25,
                color: isSelected ? AppColors.gold : AppColors.navy,
              ),
            ),
            const SizedBox(height: 11),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.white : AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color:
                    isSelected
                        ? AppColors.white.withValues(alpha: 0.70)
                        : AppColors.midGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skill chip — navy filled with a gold check when selected; category-colored
/// icon when unselected.
class _SkillChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _SkillChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navy : AppColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isSelected ? AppColors.navy : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? AppColors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.white : AppColors.charcoal,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check, size: 13, color: AppColors.gold),
            ],
          ],
        ),
      ),
    );
  }
}
