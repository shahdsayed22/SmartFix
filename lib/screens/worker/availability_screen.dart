import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_strings.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_cards.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_icons.dart';
import '../../widgets/sf_states.dart';
import '../../widgets/smart_button.dart';

/// Worker availability & work-range control.
///
/// Mirrors the Arabic design `AvailabilityScreen` (التوفّر ونطاق العمل):
/// a job-acceptance radius card with a slider, a working-hours card with
/// from/to time fields and selectable work-day chips, plus the worker's
/// served-trade selection.
///
/// The category selection is persisted through [AuthService.updateSkills],
/// which writes both the worker's skills (profile + dashboard Users page) and
/// the technician categories (dashboard Technicians page), keyed by uid. The
/// radius, hours, and days are local UI state (the backend has no
/// presence/schedule endpoint yet). Wired to [ApiService.getTechnicians] with
/// loading (skeleton), empty, and error states. No mock data.
class AvailabilityScreen extends StatefulWidget {
  final String? technicianId;

  const AvailabilityScreen({super.key, this.technicianId});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _error = false;
  bool _saving = false;

  /// Job-acceptance radius in km (1–25). Local UI state.
  double _radius = 8;

  /// Working-hours window. Local UI state.
  TimeOfDay _from = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 20, minute: 0);

  /// Work days, by key. Defaults to Sat–Thu (Friday off).
  final Set<String> _days = <String>{'sat', 'sun', 'mon', 'tue', 'wed', 'thu'};

  static const List<List<String>> _kDays = [
    ['sat', 'السبت'],
    ['sun', 'الأحد'],
    ['mon', 'الإثنين'],
    ['tue', 'الثلاثاء'],
    ['wed', 'الأربعاء'],
    ['thu', 'الخميس'],
    ['fri', 'الجمعة'],
  ];

  /// Categories the worker is currently available for (snake_case API keys).
  final Set<String> _selected = <String>{};

  String? _techId; // Firebase uid

  // ── Local persistence keys (no server presence/schedule endpoint yet) ──
  static const String _kRadiusKey = 'availability_radius';
  static const String _kFromKey = 'availability_from_minutes';
  static const String _kToKey = 'availability_to_minutes';
  static const String _kDaysKey = 'availability_days';
  static const String _kCategoriesKey = 'availability_categories';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  /// Loads the locally-persisted radius, working-hours window, and work days.
  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final radius = prefs.getDouble(_kRadiusKey);
    final fromMin = prefs.getInt(_kFromKey);
    final toMin = prefs.getInt(_kToKey);
    final days = prefs.getStringList(_kDaysKey);
    final cats = prefs.getStringList(_kCategoriesKey);
    if (!mounted) return;
    setState(() {
      if (radius != null) _radius = radius.clamp(1, 25);
      if (fromMin != null) {
        _from = TimeOfDay(hour: fromMin ~/ 60, minute: fromMin % 60);
      }
      if (toMin != null) {
        _to = TimeOfDay(hour: toMin ~/ 60, minute: toMin % 60);
      }
      if (days != null) {
        _days
          ..clear()
          ..addAll(days);
      }
      if (cats != null) {
        _selected
          ..clear()
          ..addAll(cats);
      }
    });
  }

  /// Persists the radius, working-hours window, work days, and selected
  /// service categories locally (so guests/demo sessions keep their choices).
  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kRadiusKey, _radius);
    await prefs.setInt(_kFromKey, _from.hour * 60 + _from.minute);
    await prefs.setInt(_kToKey, _to.hour * 60 + _to.minute);
    await prefs.setStringList(_kDaysKey, _days.toList());
    await prefs.setStringList(_kCategoriesKey, _selected.toList());
  }

  Future<void> _load() async {
    await _loadLocal();
    if (!mounted) return;
    final uid = widget.technicianId ?? context.read<AuthService>().uid;
    _techId = uid;

    if (uid == null || uid.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }

    try {
      // Look the worker up by their Firebase uid (NOT the Mongo _id). The old
      // code matched `t['_id'] ?? t['uid']`, which always resolved to the Mongo
      // _id and never matched the uid — so the saved skills never loaded and
      // every toggle showed OFF.
      final me = await _api.getTechnicianByUid(uid);

      // Only override the (locally-loaded) selection when a real technician
      // record exists. Guests aren't in the roster, so we keep their local
      // choices loaded in _loadLocal().
      if (me != null && me.isNotEmpty) {
        final cats = <String>{};
        final rawCats = me['categories'];
        if (rawCats is List) {
          for (final c in rawCats) {
            if (c is String && c.isNotEmpty) cats.add(c);
          }
        }
        final single = me['category'];
        if (cats.isEmpty && single is String && single.isNotEmpty) {
          cats.add(single);
        }
        if (mounted && cats.isNotEmpty) {
          setState(() {
            _selected
              ..clear()
              ..addAll(cats);
          });
        }
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  Future<void> _save() async {
    final auth = context.read<AuthService>();

    setState(() => _saving = true);
    try {
      // Always persist locally so guests/demo sessions keep their choices.
      await _saveLocal();
      // One unified call persists the selection everywhere: the worker's
      // skills (profile + dashboard Users page) AND the technician categories
      // (dashboard Technicians page), keyed by uid. For guests this is
      // in-memory only — handled inside updateSkills.
      await auth.updateSkills(_selected.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            tr(context, 'تم حفظ التوفّر'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ),
      );
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            tr(context, 'تعذّر حفظ التوفّر، حاول مرة أخرى'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleDay(String key) {
    setState(() {
      if (_days.contains(key)) {
        _days.remove(key);
      } else {
        _days.add(key);
      }
    });
    _saveLocal();
  }

  void _toggleCategory(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  Future<void> _pickTime(bool isFrom) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? _from : _to,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
      _saveLocal();
    }
  }

  String _fmt(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
              title: tr(context, 'التوفّر ونطاق العمل'),
              showBack: true,
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
        children: const [
          SfSkeletonCard(),
          SfSkeletonCard(),
          SfSkeletonCard(),
        ],
      );
    }

    if (_error) {
      return SfEmptyState(
        icon: Icons.wifi_off_rounded,
        title: tr(context, 'تعذّر تحميل التوفّر'),
        body: tr(context, 'تحقّق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
        action: SmartButton(
          label: tr(context, 'إعادة المحاولة'),
          icon: Icons.refresh,
          width: 200,
          onPressed: _load,
        ),
      );
    }

    if (_techId == null || _techId!.isEmpty) {
      return SfEmptyState(
        icon: Icons.badge_outlined,
        title: tr(context, 'لا يوجد حساب فنّي'),
        body: tr(
          context,
          'سجّل الدخول بحساب فنّي للتحكّم في توفّرك وتخصصاتك.',
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
        children: [
          _radiusCard(),
          _groupTitle(tr(context, 'ساعات العمل')),
          _hoursCard(),
          _groupTitle(tr(context, 'تخصصاتك')),
          _categoriesCard(),
          const SizedBox(height: 18),
          SmartButton(
            label: tr(context, 'حفظ'),
            icon: Icons.check,
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  // Card shell matching the design `Card` component.
  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(17),
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
      child: child,
    );
  }

  Widget _groupTitle(String label) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 18, 4, 8),
      child: Text(
        label,
        textAlign: TextAlign.start,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.midGrey,
        ),
      ),
    );
  }

  Widget _radiusCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  tr(context, 'نطاق قبول الوظائف'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              Text(
                '${_radius.round()} ${tr(context, 'كم')}',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.teal,
              inactiveTrackColor: AppColors.lineSoft,
              thumbColor: AppColors.teal,
              overlayColor: AppColors.teal.withValues(alpha: 0.14),
              trackHeight: 4,
            ),
            child: Slider(
              value: _radius,
              min: 1,
              max: 25,
              divisions: 24,
              onChanged: (v) => setState(() => _radius = v),
              onChangeEnd: (_) => _saveLocal(),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tr(context, 'ستصلك الوظائف ضمن هذا النطاق فقط'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              color: AppColors.midGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hoursCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _timeField(tr(context, 'من'), _from, true)),
              const SizedBox(width: 12),
              Expanded(child: _timeField(tr(context, 'إلى'), _to, false)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            tr(context, 'أيام العمل'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final entry in _kDays) _dayChip(entry[0], entry[1]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay value, bool isFrom) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12,
            color: AppColors.midGrey,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickTime(isFrom),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 17,
                  color: AppColors.midGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  _fmt(value),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayChip(String key, String label) {
    final on = _days.contains(key);
    return GestureDetector(
      onTap: () => _toggleDay(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.secondaryBg : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: on ? AppColors.teal : AppColors.line,
            width: 1.5,
          ),
        ),
        child: Text(
          tr(context, label),
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: on ? AppColors.teal : AppColors.midGrey,
          ),
        ),
      ),
    );
  }

  Widget _categoriesCard() {
    return SfSectionCard(
      icon: Icons.handyman_outlined,
      title: tr(context, 'الخدمات التي تقبلها'),
      trailing: Text(
        '${_selected.length}/${kSfCategoryOrder.length}',
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.teal,
        ),
      ),
      child: Column(
        children: [
          for (final key in kSfCategoryOrder) ...[
            _categoryRow(key),
            if (key != kSfCategoryOrder.last)
              const Divider(height: 18, color: AppColors.lineSoft),
          ],
        ],
      ),
    );
  }

  Widget _categoryRow(String key) {
    final cfg = sfCategory(key);
    final on = _selected.contains(key);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cfg.color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(cfg.icon, size: 21, color: cfg.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            cfg.label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: on,
          activeThumbColor: AppColors.white,
          activeTrackColor: cfg.color,
          inactiveThumbColor: AppColors.white,
          inactiveTrackColor: AppColors.line,
          onChanged: (_) => _toggleCategory(key),
        ),
      ],
    );
  }
}
