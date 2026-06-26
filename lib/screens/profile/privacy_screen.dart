import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_header.dart';

/// A single device-permission the app may request from the user, with a
/// plain why-we-need-this rationale (we request only when needed).
class _Permission {
  final String keyId;
  final IconData icon;
  final String label;
  final String rationale;
  final Color color;

  const _Permission({
    required this.keyId,
    required this.icon,
    required this.label,
    required this.rationale,
    required this.color,
  });
}

/// Privacy & permissions screen. Explains SmartFix's request-only-when-needed
/// approach, then lists toggle rows for Camera, Photos/Media, Location and
/// Notifications — each with a one-line rationale. Toggle state is kept in
/// local state (a real build would map these to OS permission requests).
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  // Local persisted toggle state, keyed by permission id.
  // NOTE: static design state, ready for OS permission wiring.
  final Map<String, bool> _granted = {
    'camera': true,
    'media': true,
    'location': true,
    'notifications': true,
  };

  static const _kPrefix = 'privacy.';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final key in _granted.keys) {
        _granted[key] = prefs.getBool('$_kPrefix$key') ?? _granted[key]!;
      }
    });
  }

  Future<void> _setPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kPrefix$key', value);
  }

  late final List<_Permission> _permissions = [
    _Permission(
      keyId: 'camera',
      icon: Icons.photo_camera_outlined,
      label: tr(context, 'الكاميرا'),
      rationale: tr(
        context,
        'لالتقاط صور المشكلة عند إنشاء بلاغ جديد — نطلبها فقط وقت التصوير.',
      ),
      color: AppColors.primary,
    ),
    _Permission(
      keyId: 'media',
      icon: Icons.image_outlined,
      label: tr(context, 'الصور والوسائط'),
      rationale: tr(
        context,
        'لإرفاق صور من معرض هاتفك إلى البلاغ — نصل إليها فقط عند اختيارك صورة.',
      ),
      color: AppColors.teal,
    ),
    _Permission(
      keyId: 'location',
      icon: Icons.location_on_outlined,
      label: tr(context, 'الموقع'),
      rationale: tr(
        context,
        'لتحديد عنوان الخدمة وإيجاد أقرب فني إليك — نطلبه فقط أثناء الطلب.',
      ),
      color: AppColors.gold,
    ),
    _Permission(
      keyId: 'notifications',
      icon: Icons.notifications_active_outlined,
      label: tr(context, 'الإشعارات'),
      rationale: tr(
        context,
        'لإبلاغك بعروض الفنيين وتحديثات حالة طلبك أولًا بأول.',
      ),
      color: AppColors.info,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            SfGradientHeader(
              title: tr(context, 'الخصوصية والأذونات'),
              subtitle: tr(context, 'تحكّم فيما يصل إليه التطبيق'),
              showBack: true,
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
                children: [
                  _intro(),
                  _groupTitle(tr(context, 'أذونات الجهاز')),
                  _permissionsCard(),
                  const SizedBox(height: 16),
                  _footerNote(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Section header matching the design's `GroupTitle` (13 / 700 / mid-grey,
  /// margin 18px top · 8px bottom · 4px inline).
  Widget _groupTitle(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 18, 4, 8),
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.midGrey,
        ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppColors.rCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(top: 1),
            child: Icon(
              Icons.shield_outlined,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              tr(
                context,
                'خصوصيتك أولًا. لا نطلب أي إذن إلا عند الحاجة الفعلية إليه، '
                'ويمكنك إيقاف أي منها في أي وقت دون التأثير على بقية التطبيق.',
              ),
              textAlign: TextAlign.start,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12.5,
                height: 1.6,
                color: AppColors.darkGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.rCard),
        border: Border.all(color: AppColors.lineSoft),
        boxShadow: const [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 14,
            spreadRadius: -10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < _permissions.length; i++) ...[
            _permissionRow(_permissions[i]),
            if (i < _permissions.length - 1)
              const Padding(
                padding: EdgeInsetsDirectional.only(start: 60),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.lineSoft,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _permissionRow(_Permission p) {
    final on = _granted[p.keyId] ?? false;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 13, 16, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Uniform soft tile (design SettingRow's `brand-soft`) with the
          // permission's accent applied to the glyph only.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.navySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(p.icon, size: 18, color: p.color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.label,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.rationale,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    height: 1.55,
                    color: AppColors.midGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2),
            child: _toggle(on, (v) {
              setState(() => _granted[p.keyId] = v);
              _setPref(p.keyId, v);
            }),
          ),
        ],
      ),
    );
  }

  /// Pill toggle matching the design's SwitchToggle (teal when on).
  Widget _toggle(bool value, ValueChanged<bool> onChanged) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 46,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? AppColors.teal : AppColors.line,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            alignment:
                value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _footerNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 15, color: AppColors.midGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tr(
              context,
              'يمكنك أيضًا تعديل هذه الأذونات من إعدادات نظام هاتفك في أي وقت.',
            ),
            textAlign: TextAlign.start,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11.5,
              height: 1.6,
              color: AppColors.midGrey,
            ),
          ),
        ),
      ],
    );
  }
}
