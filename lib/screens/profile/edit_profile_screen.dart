import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../l10n/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/sf_avatar.dart';
import '../../widgets/sf_feedback.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/smart_text_field.dart';
import '../../widgets/smart_button.dart';
import '../../services/location_service.dart';
import '../map/location_picker_screen.dart';

/// Real, functional profile editor — updates name / phone / address in
/// Firestore (and the local AppUser) via AuthService.updateProfile().
/// Shared by both the customer and worker profile screens.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _photoUrl;

  final _location = LocationService();
  double? _lat;
  double? _lng;
  bool _detecting = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthService>().currentUser;
    _name = TextEditingController(text: u?.name ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _address = TextEditingController(text: u?.address ?? '');
    _lat = u?.latitude;
    _lng = u?.longitude;
    final url = u?.profileImageUrl;
    _photoUrl = (url != null && url.isNotEmpty) ? url : null;
  }

  /// Pick an image, upload it to Firebase Storage under
  /// `users/<uid>/avatar.jpg`, then persist the download URL via
  /// AuthService.updateProfile(). Shows progress and a graceful error if
  /// Storage is unavailable.
  Future<void> _changePhoto() async {
    final auth = context.read<AuthService>();
    final uid = auth.uid;
    if (uid == null || uid.isEmpty || auth.isGuest) {
      SfToast.show(
        context,
        tr(context, 'سجّل الدخول لتغيير صورتك'),
        tone: SfTone.info,
      );
      return;
    }
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 80,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _uploadingPhoto = true);

      final ref = FirebaseStorage.instance.ref('users/$uid/avatar.jpg');
      await ref.putFile(
        File(picked.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      await auth.updateProfile(profileImageUrl: url);

      if (!mounted) return;
      setState(() => _photoUrl = url);
      SfToast.show(
        context,
        tr(context, 'تم تحديث الصورة'),
        tone: SfTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      SfToast.show(
        context,
        '${tr(context, 'تعذّر رفع الصورة')}: $e',
        tone: SfTone.error,
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  /// Detect the device GPS location, reverse-geocode it into the address field,
  /// and keep the coordinates. Falls back to the map picker when GPS is blocked
  /// (e.g. the web PWA over plain HTTP, or a denied permission).
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
        _address.text = addr;
        setState(() => _detecting = false);
      }
    } else {
      if (!mounted) return;
      setState(() => _detecting = false);
      SfToast.show(
        context,
        tr(
          context,
          'تعذّر تحديد موقعك تلقائياً — حدّده على الخريطة أو اكتب العنوان.',
        ),
        tone: SfTone.warning,
      );
      await _openMapPicker();
    }
  }

  /// Open the map picker (best-effort GPS + manual drag/address) and fill the
  /// address + coordinates from its result.
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
        if (addr.isNotEmpty) _address.text = addr;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthService>().updateProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        latitude: _lat,
        longitude: _lng,
      );
      if (!mounted) return;
      SfToast.show(
        context,
        tr(context, 'تم حفظ التغييرات'),
        tone: SfTone.success,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      SfToast.show(
        context,
        '${tr(context, 'تعذّر الحفظ')}: $e',
        tone: SfTone.error,
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final name = context.read<AuthService>().currentUser?.name ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SfGradientHeader(
            title: tr(context, 'تعديل الملف الشخصي'),
            subtitle: tr(context, 'تحديث بيانات حسابك'),
            showBack: true,
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(22, 24, 22, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Avatar + change-photo affordance (presentation only) ──
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (_photoUrl != null)
                                Container(
                                  width: 92,
                                  height: 92,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.surface,
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: AppColors.goldSoft,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      _photoUrl!,
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          SfAvatar(name: name, size: 92),
                                    ),
                                  ),
                                )
                              else
                                SfAvatar(name: name, size: 92, ring: true),
                              if (_uploadingPhoto)
                                Positioned.fill(
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.black
                                          .withValues(alpha: 0.35),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              PositionedDirectional(
                                bottom: 0,
                                end: 0,
                                child: GestureDetector(
                                  onTap: _uploadingPhoto ? null : _changePhoto,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.teal,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 15,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _uploadingPhoto ? null : _changePhoto,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              tr(context, 'تغيير الصورة'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SmartTextField(
                      label: tr(context, 'الاسم بالكامل'),
                      hint: tr(context, 'اسمك'),
                      controller: _name,
                      prefixIcon: Icons.person_outline,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? tr(context, 'الرجاء إدخال اسمك')
                          : null,
                    ),
                    const SizedBox(height: 16),
                    SmartTextField(
                      label: tr(context, 'رقم الهاتف'),
                      hint: '+20 1XX XXX XXXX',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                    ),
                    const SizedBox(height: 16),
                    SmartTextField(
                      label: tr(context, 'العنوان'),
                      hint: tr(context, 'الشارع، الحي، المدينة'),
                      controller: _address,
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _detecting ? null : _detectLocation,
                            icon: _detecting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location, size: 18),
                            label: Text(tr(context, 'موقعي الحالي')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.line),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _detecting ? null : _openMapPicker,
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: Text(tr(context, 'على الخريطة')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.line),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SmartButton(
                      label: tr(context, 'حفظ التغييرات'),
                      icon: Icons.check_rounded,
                      isLoading: _saving,
                      width: double.infinity,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
