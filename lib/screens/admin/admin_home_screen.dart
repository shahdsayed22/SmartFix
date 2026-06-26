import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/issue_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_avatar.dart';
import '../../widgets/sf_bottom_nav.dart';
import '../../widgets/sf_cards.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_stars.dart';
import '../../widgets/sf_states.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/verified_badge.dart';
import '../auth/login_screen.dart';
import '../profile/settings_screen.dart';
import '../support/support_tickets_screen.dart';

/// Mobile ADMIN home — Arabic-first / RTL, wired to the live REST API.
///
/// Mirrors the design's `AdminTabs`: a four-tab bottom nav over
/// نظرة عامة (overview) / البلاغات (issues) / الفنيون (technicians) /
/// الحساب (account). Each tab is a private section in this file and loads
/// its own data lazily (on first view) with loading / empty / error states,
/// matching the wallet screen's structure. No mock data.
///
/// - Overview  → [ApiService.getAnalytics]
/// - Issues    → [ApiService.getIssues] (mapped via [Issue.fromMap])
/// - Technicians → [ApiService.getTechnicians]
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final ApiService _api = ApiService();

  String _tab = 'overview';

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _OverviewTab(api: _api),
                  _IssuesTab(api: _api),
                  _TechniciansTab(api: _api),
                  const _AccountTab(),
                ],
              ),
            ),
            SfBottomNav(
              activeKey: _tab,
              onChange: (k) => setState(() => _tab = k),
              items: [
                SfNavItem(
                  key: 'overview',
                  label: tr(context, 'اللوحة'),
                  icon: Icons.dashboard_outlined,
                ),
                SfNavItem(
                  key: 'issues',
                  label: tr(context, 'البلاغات'),
                  icon: Icons.assignment_outlined,
                ),
                SfNavItem(
                  key: 'techs',
                  label: tr(context, 'الفنيون'),
                  icon: Icons.engineering_outlined,
                ),
                SfNavItem(
                  key: 'account',
                  label: tr(context, 'الحساب'),
                  icon: Icons.person_outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int get _tabIndex {
    switch (_tab) {
      case 'issues':
        return 1;
      case 'techs':
        return 2;
      case 'account':
        return 3;
      default:
        return 0;
    }
  }
}

// ── نظرة عامة (Overview) ─────────────────────────────────────────────

class _OverviewTab extends StatefulWidget {
  final ApiService api;
  const _OverviewTab({required this.api});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  bool _loading = true;
  bool _error = false;
  Map<String, dynamic> _data = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      final data = await widget.api.getAnalytics();
      if (mounted) {
        setState(() {
          _data = data;
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

  int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _asStr(dynamic v) => v == null ? '0' : v.toString();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SfGradientHeader(
          title: tr(context, 'لوحة الإدارة'),
          subtitle: tr(context, 'مؤشرات سمارت فيكس'),
        ),
        Expanded(child: _body()),
      ],
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
        title: tr(context, 'تعذّر تحميل المؤشرات'),
        body: tr(context, 'تحقّق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
        action: SmartButton(
          label: tr(context, 'إعادة المحاولة'),
          icon: Icons.refresh,
          width: 200,
          onPressed: _load,
        ),
      );
    }

    final issueStats = (_data['issueStats'] as Map?) ?? const {};
    final openIssues =
        _asInt(issueStats['pending']) +
        _asInt(issueStats['assigned']) +
        _asInt(issueStats['inProgress']);

    final stats = <_StatSpec>[
      _StatSpec(
        label: tr(context, 'بلاغات مفتوحة'),
        value: '$openIssues',
        icon: Icons.assignment_outlined,
        color: AppColors.warning,
        bg: AppColors.warningBg,
      ),
      _StatSpec(
        label: tr(context, 'إجمالي الفنيين'),
        value: _asStr(_data['totalTechnicians']),
        icon: Icons.engineering_outlined,
        color: AppColors.secondary,
        bg: AppColors.secondaryBg,
      ),
      _StatSpec(
        label: tr(context, 'فنيون موثّقون'),
        value: _asStr(_data['verifiedCount']),
        icon: Icons.verified_outlined,
        color: AppColors.info,
        bg: AppColors.infoBg,
      ),
      _StatSpec(
        label: tr(context, 'بلاغات مكتملة'),
        value: _asStr(_data['totalIssuesResolved']),
        icon: Icons.check_circle_outline,
        color: AppColors.success,
        bg: AppColors.successBg,
      ),
      _StatSpec(
        label: tr(context, 'متوسط التقييم'),
        value: _asStr(_data['avgRating']),
        icon: Icons.star_outline,
        color: AppColors.gold,
        bg: AppColors.warningBg,
      ),
      _StatSpec(
        label: tr(context, 'إجمالي البلاغات'),
        value: _asStr(issueStats['total']),
        icon: Icons.list_alt_outlined,
        color: AppColors.primary,
        bg: AppColors.navySoft,
      ),
    ];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 12, start: 2),
            child: Text(
              tr(context, 'نظرة عامة'),
              textAlign: TextAlign.start,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 11,
            crossAxisSpacing: 11,
            childAspectRatio: 1.55,
            children: stats
                .map(
                  (s) => SfStatCard(
                    label: s.label,
                    value: s.value,
                    icon: s.icon,
                    color: s.color,
                    bg: s.bg,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StatSpec {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;
  const _StatSpec({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });
}

// ── البلاغات (Issues) ────────────────────────────────────────────────

class _IssuesTab extends StatefulWidget {
  final ApiService api;
  const _IssuesTab({required this.api});

  @override
  State<_IssuesTab> createState() => _IssuesTabState();
}

class _IssuesTabState extends State<_IssuesTab> {
  bool _loading = true;
  bool _error = false;
  List<Issue> _issues = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      final raw = await widget.api.getIssues(limit: 50);
      final issues = raw.map(Issue.fromMap).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _issues = issues;
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

  String _timeAgo(BuildContext context, DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return tr(context, 'الآن');
    if (d.inMinutes < 60) return '${d.inMinutes} ${tr(context, 'دقيقة')}';
    if (d.inHours < 24) return '${d.inHours} ${tr(context, 'ساعة')}';
    if (d.inDays < 30) return '${d.inDays} ${tr(context, 'يوم')}';
    final months = (d.inDays / 30).floor();
    return '$months ${tr(context, 'شهر')}';
  }

  Future<void> _openIssueSheet(Issue iss) async {
    if (iss.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'تعذّر فتح هذا البلاغ'))),
      );
      return;
    }
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IssueActionSheet(api: widget.api, issue: iss),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SfGradientHeader(
          title: tr(context, 'إدارة البلاغات'),
          subtitle: _loading || _error
              ? tr(context, 'كل بلاغات المنصة')
              : '${_issues.length} ${tr(context, 'بلاغ في النظام')}',
        ),
        Expanded(child: _body()),
      ],
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
        title: tr(context, 'تعذّر تحميل البلاغات'),
        body: tr(context, 'تحقّق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
        action: SmartButton(
          label: tr(context, 'إعادة المحاولة'),
          icon: Icons.refresh,
          width: 200,
          onPressed: _load,
        ),
      );
    }

    if (_issues.isEmpty) {
      return SfEmptyState(
        icon: Icons.inbox_outlined,
        title: tr(context, 'لا توجد بلاغات بعد'),
        body: tr(context, 'ستظهر هنا بلاغات العملاء فور وصولها إلى المنصة.'),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
        itemCount: _issues.length,
        separatorBuilder: (_, _) => const SizedBox(height: 11),
        itemBuilder: (context, i) {
          final iss = _issues[i];
          return SfIssueCard(
            title: iss.title.isNotEmpty ? iss.title : iss.categoryLabel,
            categoryName: iss.category,
            urgency: iss.urgency,
            status: iss.status,
            description: iss.description,
            address: iss.address,
            timeAgo: _timeAgo(context, iss.createdAt),
            onTap: () => _openIssueSheet(iss),
          );
        },
      ),
    );
  }
}

// ── Issue action bottom sheet ────────────────────────────────────────

/// Admin bottom sheet to change an issue's status and (optionally) assign a
/// technician. Returns `true` via [Navigator.pop] when a change was saved so
/// the caller can refresh the list.
class _IssueActionSheet extends StatefulWidget {
  final ApiService api;
  final Issue issue;
  const _IssueActionSheet({required this.api, required this.issue});

  @override
  State<_IssueActionSheet> createState() => _IssueActionSheetState();
}

class _IssueActionSheetState extends State<_IssueActionSheet> {
  late IssueStatus _status;
  String? _techId;
  String? _techName;

  bool _loadingTechs = true;
  List<Map<String, dynamic>> _techs = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.issue.status;
    _techId = (widget.issue.assignedWorkerId?.isNotEmpty ?? false)
        ? widget.issue.assignedWorkerId
        : null;
    _techName = widget.issue.assignedWorkerName;
    _loadTechs();
  }

  Future<void> _loadTechs() async {
    try {
      final techs = await widget.api.getTechnicians();
      if (mounted) {
        setState(() {
          _techs = techs;
          _loadingTechs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTechs = false);
    }
  }

  String _statusLabel(IssueStatus s) {
    switch (s) {
      case IssueStatus.pending:
        return tr(context, 'قيد الانتظار');
      case IssueStatus.offered:
        return tr(context, 'عرض جديد');
      case IssueStatus.assigned:
        return tr(context, 'تم التعيين');
      case IssueStatus.inProgress:
        return tr(context, 'قيد التنفيذ');
      case IssueStatus.awaitingApproval:
        return tr(context, 'بانتظار موافقة العميل');
      case IssueStatus.awaitingPayment:
        return tr(context, 'بانتظار الدفع');
      case IssueStatus.completed:
        return tr(context, 'مكتمل');
      case IssueStatus.cancelled:
        return tr(context, 'ملغى');
    }
  }

  String _techId2(Map<String, dynamic> t) =>
      (t['id'] ?? t['uid'] ?? t['_id'])?.toString() ?? '';

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final updates = <String, dynamic>{'status': _status.name};
    if (_techId != null && _techId!.isNotEmpty) {
      updates['assignedTechnicianId'] = _techId;
      updates['assignedTechnicianName'] = _techName ?? '';
    }
    try {
      await widget.api.updateIssue(widget.issue.id, updates);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'تعذّر حفظ التغييرات'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lineSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.issue.title.isNotEmpty
                  ? widget.issue.title
                  : tr(context, 'إدارة البلاغ'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              tr(context, 'الحالة'),
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.midGrey,
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: IssueStatus.values.map((s) {
                final selected = s == _status;
                return GestureDetector(
                  onTap: () => setState(() => _status = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.navySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel(s),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.white : AppColors.charcoal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              tr(context, 'تعيين فني'),
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.midGrey,
              ),
            ),
            const SizedBox(height: 9),
            _techField(),
            const SizedBox(height: 22),
            SmartButton(
              label: tr(context, 'حفظ التغييرات'),
              icon: Icons.check,
              isLoading: _saving,
              onPressed: widget.issue.id.isEmpty ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _techField() {
    if (_loadingTechs) {
      return Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.navySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    if (_techs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.navySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          tr(context, 'لا يوجد فنيون متاحون للتعيين'),
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13,
            color: AppColors.midGrey,
          ),
        ),
      );
    }

    // Ensure the current selection exists in the list; otherwise reset.
    final ids = _techs.map(_techId2).toSet();
    final value = (_techId != null && ids.contains(_techId)) ? _techId : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.navySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          hint: Text(
            tr(context, 'بدون تعيين'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              color: AppColors.midGrey,
            ),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                tr(context, 'بدون تعيين'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  color: AppColors.charcoal,
                ),
              ),
            ),
            ..._techs.map((t) {
              final id = _techId2(t);
              final name = (t['name'] as String?)?.trim();
              return DropdownMenuItem<String?>(
                value: id,
                child: Text(
                  (name != null && name.isNotEmpty)
                      ? name
                      : tr(context, 'فني'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    color: AppColors.charcoal,
                  ),
                ),
              );
            }),
          ],
          onChanged: (v) {
            setState(() {
              _techId = v;
              if (v == null) {
                _techName = null;
              } else {
                final t = _techs.firstWhere(
                  (e) => _techId2(e) == v,
                  orElse: () => const {},
                );
                _techName = (t['name'] as String?)?.trim();
              }
            });
          },
        ),
      ),
    );
  }
}

// ── الفنيون (Technicians) ────────────────────────────────────────────

class _TechniciansTab extends StatefulWidget {
  final ApiService api;
  const _TechniciansTab({required this.api});

  @override
  State<_TechniciansTab> createState() => _TechniciansTabState();
}

class _TechniciansTabState extends State<_TechniciansTab> {
  bool _loading = true;
  bool _error = false;
  List<Map<String, dynamic>> _techs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      final techs = await widget.api.getTechnicians();
      if (mounted) {
        setState(() {
          _techs = techs;
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

  int get _verifiedCount =>
      _techs.where((t) => t['isVerified'] == true).length;

  /// Ids of technicians with an in-flight verify/reject call.
  final Set<String> _updating = <String>{};

  Future<void> _setVerified(String id, bool verified) async {
    if (id.isEmpty || _updating.contains(id)) return;
    setState(() => _updating.add(id));
    try {
      await widget.api.verifyTechnician(id, verified: verified);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verified
                ? tr(context, 'تم توثيق الفني')
                : tr(context, 'تم إلغاء توثيق الفني'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'تعذّر تحديث حالة التوثيق'))),
      );
    } finally {
      if (mounted) setState(() => _updating.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SfGradientHeader(
          title: tr(context, 'الفنيون'),
          subtitle: _loading || _error
              ? tr(context, 'فنيو المنصة وتوثيقهم')
              : '${_techs.length} ${tr(context, 'فني')} · '
                    '$_verifiedCount ${tr(context, 'موثّق')}',
        ),
        Expanded(child: _body()),
      ],
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
        title: tr(context, 'تعذّر تحميل الفنيين'),
        body: tr(context, 'تحقّق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
        action: SmartButton(
          label: tr(context, 'إعادة المحاولة'),
          icon: Icons.refresh,
          width: 200,
          onPressed: _load,
        ),
      );
    }

    if (_techs.isEmpty) {
      return SfEmptyState(
        icon: Icons.engineering_outlined,
        title: tr(context, 'لا يوجد فنيون بعد'),
        body: tr(context, 'سيظهر هنا الفنيون فور انضمامهم إلى المنصة.'),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
        itemCount: _techs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 11),
        itemBuilder: (context, i) => _techTile(_techs[i]),
      ),
    );
  }

  Widget _techTile(Map<String, dynamic> t) {
    final id = (t['id'] ?? t['uid'] ?? t['_id'])?.toString() ?? '';
    final name = (t['name'] as String?)?.trim() ?? '';
    final verified = t['isVerified'] == true;
    final rating = (t['rating'] as num?)?.toDouble() ?? 0;
    final jobs = (t['issuesResolved'] as num?)?.toInt() ?? 0;
    final skill = _skillLabel(t);
    final busy = _updating.contains(id);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lineSoft),
        boxShadow: const [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 14,
            spreadRadius: -11,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SfAvatar(name: name.isNotEmpty ? name : '؟', size: 46),
              if (verified)
                const PositionedDirectional(
                  bottom: -2,
                  end: -2,
                  child: VerifiedBadge(isVerified: true, size: 18),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : tr(context, 'فني'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        skill,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SfStars(value: rating, size: 13),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  rating.toStringAsFixed(1),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$jobs ${tr(context, 'مهمة')}',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.midGrey,
                ),
              ),
            ],
          ),
        ],
        ),
        const SizedBox(height: 11),
        const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
        const SizedBox(height: 10),
        _techActions(id: id, verified: verified, busy: busy),
        ],
      ),
    );
  }

  Widget _techActions({
    required String id,
    required bool verified,
    required bool busy,
  }) {
    if (busy) {
      return const SizedBox(
        height: 36,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      );
    }

    final disabled = id.isEmpty;

    if (verified) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 5),
                Text(
                  tr(context, 'موثّق'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _techActionButton(
            label: tr(context, 'إلغاء التوثيق'),
            icon: Icons.cancel_outlined,
            color: AppColors.error,
            onTap: disabled ? null : () => _setVerified(id, false),
          ),
        ],
      );
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.warningBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_empty,
                size: 14,
                color: AppColors.warning,
              ),
              const SizedBox(width: 5),
              Text(
                tr(context, 'بانتظار التوثيق'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _techActionButton(
          label: tr(context, 'رفض'),
          icon: Icons.close,
          color: AppColors.error,
          onTap: disabled ? null : () => _setVerified(id, false),
        ),
        const SizedBox(width: 8),
        _techActionButton(
          label: tr(context, 'توثيق'),
          icon: Icons.check,
          color: AppColors.success,
          filled: true,
          onTap: disabled ? null : () => _setVerified(id, true),
        ),
      ],
    );
  }

  Widget _techActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: filled ? color : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: filled ? AppColors.white : color,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: filled ? AppColors.white : color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Map the technician's category (or first of its categories list) to an
  /// Arabic label via the [Issue] model's category enum + RTL copy.
  String _skillLabel(Map<String, dynamic> t) {
    String? key = t['category'] as String?;
    if (key == null || key.isEmpty) {
      final cats = t['categories'];
      if (cats is List && cats.isNotEmpty) key = cats.first?.toString();
    }
    if (key == null || key.isEmpty) return tr(context, 'خدمة عامة');
    final normalized = key == 'appliance_repair' ? 'applianceRepair' : key;
    final cat = IssueCategory.values.firstWhere(
      (c) => c.name == normalized,
      orElse: () => IssueCategory.plumbing,
    );
    return _arCategory(cat);
  }

  String _arCategory(IssueCategory c) {
    switch (c) {
      case IssueCategory.plumbing:
        return tr(context, 'سباكة');
      case IssueCategory.electrical:
        return tr(context, 'كهرباء');
      case IssueCategory.carpentry:
        return tr(context, 'نجارة');
      case IssueCategory.painting:
        return tr(context, 'دهان');
      case IssueCategory.hvac:
        return tr(context, 'تكييف');
      case IssueCategory.cleaning:
        return tr(context, 'تنظيف');
      case IssueCategory.applianceRepair:
        return tr(context, 'إصلاح أجهزة');
      case IssueCategory.welding:
        return tr(context, 'لحام');
      case IssueCategory.tiling:
        return tr(context, 'بلاط');
    }
  }
}

// ── الحساب (Account) ─────────────────────────────────────────────────

class _AccountTab extends StatelessWidget {
  const _AccountTab();

  Future<void> _signOut(BuildContext context) async {
    await context.read<AuthService>().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final name = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name
        : tr(context, 'مشرف سمارت فيكس');
    final email = user?.email ?? '';

    final items = <_AccountLink>[
      _AccountLink(
        icon: Icons.tune,
        label: tr(context, 'إعدادات المنصة'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
      _AccountLink(icon: Icons.percent, label: tr(context, 'العمولات والأسعار')),
      _AccountLink(
        icon: Icons.description_outlined,
        label: tr(context, 'التقارير'),
      ),
      _AccountLink(
        icon: Icons.shield_outlined,
        label: tr(context, 'الصلاحيات والأمان'),
      ),
      _AccountLink(
        icon: Icons.help_outline,
        label: tr(context, 'الدعم'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SupportTicketsScreen()),
        ),
      ),
    ];

    return Column(
      children: [
        SfGradientHeader(
          title: tr(context, 'الحساب'),
          child: Row(
            children: [
              SfAvatar(
                name: name,
                size: 64,
                bg: AppColors.white.withValues(alpha: 0.14),
                fg: AppColors.gold,
                ring: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          color: AppColors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 13,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            tr(context, 'مشرف النظام'),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
            children: [
              Container(
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
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      _linkRow(context, items[i]),
                      if (i < items.length - 1)
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
              ),
              const SizedBox(height: 20),
              SmartButton(
                label: tr(context, 'تسجيل الخروج'),
                icon: Icons.logout,
                onPressed: () => _signOut(context),
              ),
              const SizedBox(height: 22),
              Center(
                child: Text(
                  tr(context, 'سمارت فيكس · لوحة الإدارة'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: AppColors.midGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _linkRow(BuildContext context, _AccountLink link) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            link.onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr(context, 'قريباً'))),
              );
            },
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.navySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(link.icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  link.label,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_left,
                size: 20,
                color: AppColors.midGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountLink {
  final IconData icon;
  final String label;

  /// Destination handler; when null the row shows a "قريباً" snackbar.
  final VoidCallback? onTap;
  const _AccountLink({required this.icon, required this.label, this.onTap});
}
