import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../services/api_service.dart';
import '../../models/issue_model.dart';
import '../../widgets/smart_card.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_icons.dart';
import '../../widgets/sf_states.dart';
import '../../widgets/sf_bottom_nav.dart';
import 'job_detail_screen.dart';
import 'worker_offers_section.dart';
import 'worker_profile_screen.dart';
import '../chat/chat_list_screen.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  final JobService _jobService = JobService();
  final ApiService _api = ApiService();
  int _currentIndex = 0;
  bool _showAssignedOnly = false;
  bool _online = true;

  /// Key for the locally-persisted online/availability state. No server
  /// presence endpoint exists, so this is stored via shared_preferences.
  static const String _kOnlineKey = 'worker_online';

  @override
  void initState() {
    super.initState();
    _loadOnline();
  }

  Future<void> _loadOnline() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_kOnlineKey);
    if (saved != null && mounted) {
      setState(() => _online = saved);
    }
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    final navItems = [
      SfNavItem(
        key: 'jobs',
        label: tr(context, 'الوظائف'),
        icon: Icons.work_outline,
      ),
      SfNavItem(
        key: 'messages',
        label: tr(context, 'الرسائل'),
        icon: Icons.chat_bubble_outline,
      ),
      SfNavItem(
        key: 'profile',
        label: tr(context, 'حسابي'),
        icon: Icons.person_outline,
      ),
    ];

    final screens = [
      _buildHomeTab(user),
      const ChatListScreen(),
      const WorkerProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: screens[_currentIndex],
      bottomNavigationBar: SfBottomNav(
        items: navItems,
        activeKey: navItems[_currentIndex].key,
        onChange: (key) {
          final index = navItems.indexWhere((it) => it.key == key);
          if (index != -1) setState(() => _currentIndex = index);
        },
      ),
    );
  }

  Widget _buildHomeTab(user) {
    final userName = user?.name ?? tr(context, 'الفني');
    final firstName = userName.split(' ').first;
    final List<String> skills =
        (user?.skills is List<String>) ? user.skills : const <String>[];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Navy hero header: greeting + online toggle + skill tags ──
          SfGradientHeader(
            padding: const EdgeInsetsDirectional.fromSTEB(22, 14, 22, 22),
            title: '${tr(context, 'أهلًا')} $firstName 🔧',
            subtitle: tr(context, 'جاهز لإصلاح بعض الأعطال؟'),
            actions: [_OnlineToggle(online: _online, onTap: _toggleOnline)],
            child:
                skills.isEmpty
                    ? null
                    : Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children:
                          skills.map((skill) {
                            final cat = sfCategory(skill);
                            return Container(
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    cat.icon,
                                    size: 13,
                                    color: AppColors.gold,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    cat.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium?.copyWith(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 18),

          // ── Uber-style live offers + Available/Assigned toggle ──
          if (user != null) ...[
            // Jobs the dispatch workflow has offered to this worker.
            WorkerOffersSection(
              api: _api,
              uid: user.uid,
              // Accepting moves a job into "My jobs"; refresh both lists.
              onChanged: () => setState(() {}),
            ),
            _JobsBody(
              jobService: _jobService,
              api: _api,
              user: user,
              showAssignedOnly: _showAssignedOnly,
              onToggle:
                  (assigned) => setState(() => _showAssignedOnly = assigned),
              onOpenJob: (issue) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobDetailScreen(issue: issue),
                  ),
                );
              },
            ),
          ] else
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 80),
              child: Center(child: Text(tr(context, 'يرجى تسجيل الدخول'))),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _toggleOnline() async {
    setState(() => _online = !_online);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnlineKey, _online);
  }
}

/// Header pill that flips between Online / Offline (visual availability badge).
class _OnlineToggle extends StatelessWidget {
  final bool online;
  final VoidCallback onTap;

  const _OnlineToggle({required this.online, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dotColor =
        online ? AppColors.success : AppColors.white.withValues(alpha: 0.5);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 12,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color:
              online
                  ? AppColors.success.withValues(alpha: 0.28)
                  : AppColors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                online
                    ? AppColors.success.withValues(alpha: 0.5)
                    : AppColors.white.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow:
                    online ? [BoxShadow(color: dotColor, blurRadius: 8)] : null,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              online ? tr(context, 'متاح') : tr(context, 'غير متاح'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    online
                        ? AppColors.white
                        : AppColors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The toggle + jobs list region. Keeps the original FutureBuilder logic,
/// just restyled. Counts are derived from the loaded list so the pills can
/// echo the prototype's badge numbers.
class _JobsBody extends StatelessWidget {
  final JobService jobService;
  final ApiService api;
  final dynamic user;
  final bool showAssignedOnly;
  final ValueChanged<bool> onToggle;
  final ValueChanged<Issue> onOpenJob;

  const _JobsBody({
    required this.jobService,
    required this.api,
    required this.user,
    required this.showAssignedOnly,
    required this.onToggle,
    required this.onOpenJob,
  });

  /// Skill-gated available feed: only pending, unassigned jobs whose category
  /// is one of the worker's skills (server-side filtered via the API).
  Future<List<Issue>> _availableJobs() async {
    final List<String> skills =
        (user?.skills is List<String>) ? user.skills : const <String>[];
    final raw = await api.getAvailableJobsForWorker(skills);
    final issues =
        raw.map((m) {
          // Normalize MongoDB `_id` → `id` before mapping to the Issue model.
          final normalized = Map<String, dynamic>.from(m);
          if (normalized['id'] == null && normalized['_id'] != null) {
            normalized['id'] = normalized['_id'].toString();
          }
          return Issue.fromMap(normalized);
        }).toList();
    issues.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return issues;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Issue>>(
      future:
          showAssignedOnly
              ? jobService.getAssignedJobs(user.uid)
              : _availableJobs(),
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final issues = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── segmented toggle ──
              Row(
                children: [
                  Expanded(
                    child: _SegToggle(
                      label: tr(context, 'وظائف متاحة'),
                      icon: Icons.checklist_rtl,
                      count: showAssignedOnly ? null : issues.length,
                      selected: !showAssignedOnly,
                      onTap: () => onToggle(false),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _SegToggle(
                      label: tr(context, 'وظائفي'),
                      icon: Icons.assignment_turned_in_outlined,
                      count: showAssignedOnly ? issues.length : null,
                      selected: showAssignedOnly,
                      onTap: () => onToggle(true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── list / loading / empty ──
              if (loading) ...const [
                SfSkeletonCard(),
                SfSkeletonCard(),
              ] else if (issues.isEmpty)
                SfEmptyState(
                  icon:
                      showAssignedOnly
                          ? Icons.assignment_outlined
                          : Icons.search_off_rounded,
                  title:
                      showAssignedOnly
                          ? tr(context, 'لا توجد وظائف مُعيَّنة')
                          : tr(context, 'لا توجد وظائف مطابقة'),
                  body:
                      showAssignedOnly
                          ? tr(context, 'اقبل وظيفة من قائمة المتاح لتظهر هنا.')
                          : tr(
                            context,
                            'تفقّد لاحقًا — ستظهر هنا وظائف جديدة تطابق مهاراتك.',
                          ),
                )
              else
                Column(
                  children: [
                    for (int i = 0; i < issues.length; i++)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 12),
                        child: SmartCard(
                          issue: issues[i],
                          onTap: () => onOpenJob(issues[i]),
                        ).animate().fadeIn(
                          delay: Duration(milliseconds: i * 80),
                          duration: 400.ms,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Pill-style segmented toggle button (navy when active, with a count badge).
class _SegToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _SegToggle({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.white : AppColors.darkGrey;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: 12,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.rBtn),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.line,
            width: 1.5,
          ),
          boxShadow:
              selected
                  ? const [
                    BoxShadow(
                      color: AppColors.navyShadow,
                      blurRadius: 18,
                      spreadRadius: -10,
                      offset: Offset(0, 8),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? AppColors.white : AppColors.midGrey,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 7,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color:
                      selected
                          ? AppColors.white.withValues(alpha: 0.14)
                          : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.gold : AppColors.midGrey,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
