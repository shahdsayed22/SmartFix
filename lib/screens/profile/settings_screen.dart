import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/sf_header.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'privacy_screen.dart';
import '../support/help_center_screen.dart';

/// Functional settings screen (replaces the "coming soon" stub).
/// Preferences are kept in local state; account + about are live.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _kPush = 'settings.pushNotifications';
  static const _kEmail = 'settings.emailUpdates';
  static const _kLocation = 'settings.locationServices';

  bool _pushNotifications = true;
  bool _emailUpdates = false;
  bool _locationServices = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pushNotifications = prefs.getBool(_kPush) ?? _pushNotifications;
      _emailUpdates = prefs.getBool(_kEmail) ?? _emailUpdates;
      _locationServices = prefs.getBool(_kLocation) ?? _locationServices;
    });
  }

  Future<void> _setPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SfGradientHeader(
            title: tr(context, 'الإعدادات'),
            subtitle: tr(context, 'التفضيلات والحساب'),
            showBack: true,
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 28),
              children: [
                _GroupTitle(tr(context, 'اللغة')),
                _card([
                  _ToggleRow(
                    icon: Icons.translate_rounded,
                    title: tr(context, 'لغة التطبيق'),
                    subtitle: context.watch<LocaleProvider>().isEn
                        ? 'English'
                        : 'العربية',
                    value: context.watch<LocaleProvider>().isEn,
                    onChanged: (v) => context
                        .read<LocaleProvider>()
                        .setLocale(Locale(v ? 'en' : 'ar')),
                    last: true,
                  ),
                ]),
                _GroupTitle(tr(context, 'الإشعارات')),
                _card([
                  _ToggleRow(
                    icon: Icons.notifications_outlined,
                    title: tr(context, 'الإشعارات الفورية'),
                    subtitle: tr(context, 'تحديثات المهام والرسائل'),
                    value: _pushNotifications,
                    onChanged: (v) {
                      setState(() => _pushNotifications = v);
                      _setPref(_kPush, v);
                    },
                  ),
                  _ToggleRow(
                    icon: Icons.mark_email_unread_outlined,
                    title: tr(context, 'تحديثات البريد'),
                    subtitle: tr(context, 'أخبار المنتج من حين لآخر'),
                    value: _emailUpdates,
                    onChanged: (v) {
                      setState(() => _emailUpdates = v);
                      _setPref(_kEmail, v);
                    },
                  ),
                  _ToggleRow(
                    icon: Icons.location_on_outlined,
                    title: tr(context, 'خدمات الموقع'),
                    subtitle: tr(context, 'لمطابقة الفنيين القريبين'),
                    value: _locationServices,
                    onChanged: (v) {
                      setState(() => _locationServices = v);
                      _setPref(_kLocation, v);
                    },
                    last: true,
                  ),
                ]),
                _GroupTitle(tr(context, 'الحساب')),
                _card([
                  _NavRow(
                    icon: Icons.person_outline,
                    title: tr(context, 'تعديل الملف الشخصي'),
                    subtitle: user?.name ?? '',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    ),
                  ),
                  _InfoRow(
                    icon: Icons.mail_outline,
                    title: tr(context, 'البريد الإلكتروني'),
                    value: user?.email ?? '—',
                  ),
                  _NavRow(
                    icon: Icons.lock_outline,
                    title: tr(context, 'تغيير كلمة المرور'),
                    subtitle: '',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                    ),
                  ),
                  _NavRow(
                    icon: Icons.privacy_tip_outlined,
                    title: tr(context, 'الخصوصية والأذونات'),
                    subtitle: '',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                    ),
                  ),
                  _NavRow(
                    icon: Icons.help_outline,
                    title: tr(context, 'مركز المساعدة'),
                    subtitle: '',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                    ),
                  ),
                ]),
                _GroupTitle(tr(context, 'عن التطبيق')),
                _card([
                  _InfoRow(icon: Icons.info_outline, title: tr(context, 'الإصدار'), value: 'SmartFix v2.0'),
                  _InfoRow(icon: Icons.school_outlined, title: tr(context, 'الجامعة'), value: tr(context, 'جامعة أكتوبر للعلوم الحديثة والآداب')),
                  _InfoRow(
                    icon: Icons.code_rounded,
                    title: tr(context, 'البرنامج'),
                    value: tr(context, 'هندسة البرمجيات'),
                    last: true,
                  ),
                ]),
                const SizedBox(height: 26),
                Center(
                  child: Text(
                    'SmartFix · v2.0',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: AppColors.midGrey,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.rCard),
          border: Border.all(color: AppColors.lineSoft),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

class _GroupTitle extends StatelessWidget {
  final String text;
  const _GroupTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 18, 4, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.midGrey,
            ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      last: last,
      child: Row(
        children: [
          _iconBox(icon),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: AppColors.midGrey,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.white,
            activeTrackColor: AppColors.teal,
            inactiveThumbColor: AppColors.white,
            inactiveTrackColor: AppColors.line,
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _NavRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: _RowShell(
        child: Row(
          children: [
            _iconBox(icon),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: AppColors.midGrey,
                          ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppColors.midGrey),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool last;
  const _InfoRow({required this.icon, required this.title, required this.value, this.last = false});

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      last: last,
      child: Row(
        children: [
          _iconBox(icon),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: AppColors.midGrey,
                ),
          ),
        ],
      ),
    );
  }
}

/// Shared row container: consistent padding + a divider inset past the icon
/// tile (matching the design's `marginInlineStart: 60`).
class _RowShell extends StatelessWidget {
  final Widget child;
  final bool last;
  const _RowShell({required this.child, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 13, 16, 13),
          child: child,
        ),
        if (!last)
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 60),
            child: Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
          ),
      ],
    );
  }
}

Widget _iconBox(IconData icon) => Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.navySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: AppColors.navy),
    );
