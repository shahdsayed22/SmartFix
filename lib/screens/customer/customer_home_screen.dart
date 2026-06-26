import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../providers/notification_provider.dart';
import '../../models/issue_model.dart';
import '../../widgets/smart_card.dart';
import '../../widgets/sf_cards.dart';
import '../../widgets/sf_states.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_cat_tile.dart';
import '../../widgets/sf_icons.dart';
import '../../widgets/sf_bottom_nav.dart';
import 'report_issue_screen.dart';
import 'issue_detail_screen.dart';
import 'customer_profile_screen.dart';
import 'services_screen.dart';
import 'offers_screen.dart';
import 'photo_diagnosis_screen.dart';
import '../chat/chat_list_screen.dart';
import '../chat/chatbot_screen.dart';
import '../notifications/notifications_screen.dart';
import '../support/support_tickets_screen.dart';
import '../map/technician_map_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final JobService _jobService = JobService();
  final TextEditingController _searchController = TextEditingController();
  int _currentIndex = 0;

  /// Client-side filter applied to the home services/categories strip.
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load the current user's notifications so the bell badge is accurate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthService>().currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        context.read<NotificationProvider>().load(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    final screens = [
      _buildHomeTab(user?.uid ?? ''),
      const ChatListScreen(),
      const CustomerProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: screens[_currentIndex],
      floatingActionButton:
          _currentIndex == 0
              ? FloatingActionButton.extended(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReportIssueScreen(),
                        ),
                      );
                      // Refresh the issue list when coming back
                      if (mounted) setState(() {});
                    },
                    backgroundColor: AppColors.navy,
                    foregroundColor: AppColors.white,
                    elevation: 6,
                    highlightElevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 23),
                    label: Text(
                      tr(context, 'بلاغ جديد'),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 300.ms)
                  .slideY(
                    begin: 0.5,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  )
              : null,
      bottomNavigationBar: SfBottomNav(
        activeKey: _navKeys[_currentIndex],
        onChange:
            (key) => setState(() => _currentIndex = _navKeys.indexOf(key)),
        items: [
          SfNavItem(
            key: 'home',
            label: tr(context, 'الرئيسية'),
            icon: Icons.home_rounded,
          ),
          SfNavItem(
            key: 'messages',
            label: tr(context, 'الرسائل'),
            icon: Icons.chat_bubble_rounded,
          ),
          SfNavItem(
            key: 'profile',
            label: tr(context, 'حسابي'),
            icon: Icons.person_rounded,
          ),
        ],
      ),
    );
  }

  static const List<String> _navKeys = ['home', 'messages', 'profile'];

  Widget _buildHomeTab(String customerId) {
    final userName = context.read<AuthService>().currentUser?.name ?? 'User';
    final firstName = userName.split(' ').first;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Navy hero header (greeting + search) ───────────────
          _buildHeader(firstName),

          // ── Quick services strip ───────────────────────────────
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(0, 18, 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionTitle(tr(context, 'خدماتنا')),
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ServicesScreen(),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.chevron_left_rounded, size: 18),
                        label: Text(tr(context, 'عرض الكل')),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          textStyle: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildServicesStrip(),
              ],
            ),
          ),

          // ── Quick actions (photo diagnosis + offers) ───────────
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 0),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.camera_alt_rounded,
                    label: tr(context, 'تشخيص بالصور'),
                    color: AppColors.teal,
                    bg: AppColors.secondaryBg,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PhotoDiagnosisScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.smart_toy_rounded,
                    label: tr(context, 'المساعد الذكي'),
                    color: AppColors.primary,
                    bg: AppColors.surfaceVariant,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatbotScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.local_offer_rounded,
                    label: tr(context, 'العروض'),
                    color: AppColors.gold,
                    bg: AppColors.warningBg,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OffersScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Overview stat cards ────────────────────────────────
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 22, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(tr(context, 'نظرة عامة')),
                const SizedBox(height: 12),
                _buildStats(customerId),
              ],
            ),
          ),

          // ── My Issues header row ───────────────────────────────
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 24, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle(tr(context, 'بلاغاتي')),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TechnicianMapScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: Text(tr(context, 'الفنيون القريبون')),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    textStyle: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Issues list ────────────────────────────────────────
          if (customerId.isNotEmpty)
            _buildIssuesList(customerId)
          else
            _buildEmptyState(),

          // Bottom padding for FAB
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHeader(String firstName) {
    return SfGradientHeader(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 14, 22, 24),
      title: '$firstName 👋',
      subtitle: tr(context, 'أهلًا بك،'),
      actions: [
        // Support / help entry → support tickets
        _buildHeaderAction(
          icon: Icons.headset_mic_outlined,
          tooltip: tr(context, 'الدعم والمساعدة'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupportTicketsScreen()),
          ),
        ),
        const SizedBox(width: 10),
        // Notification button with live unread badge → notifications
        _buildNotificationsAction(),
      ],
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: AppColors.white.withValues(alpha: 0.6),
              size: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) =>
                    setState(() => _searchQuery = v.trim().toLowerCase()),
                textInputAction: TextInputAction.search,
                cursorColor: AppColors.white,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.white,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: tr(context, 'ابحث عن خدمة…'),
                  hintStyle: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              InkWell(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                borderRadius: BorderRadius.circular(12),
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.white.withValues(alpha: 0.7),
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  /// Generic circular header action button matching the Phase-1 hero style.
  Widget _buildHeaderAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(13),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: AppColors.white, size: 22),
          ),
        ),
      ),
    );
  }

  /// Notification bell with a live unread badge driven by [NotificationProvider].
  Widget _buildNotificationsAction() {
    final unread = context.watch<NotificationProvider>().unread;
    return Material(
      color: AppColors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(13),
      child: Tooltip(
        message: tr(context, 'الإشعارات'),
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
            // Refresh the badge after returning (items may be marked read).
            if (!mounted) return;
            final uid = context.read<AuthService>().currentUser?.uid ?? '';
            if (uid.isNotEmpty) {
              context.read<NotificationProvider>().load(uid);
            }
          },
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.white,
                  size: 22,
                ),
                if (unread > 0)
                  PositionedDirectional(
                    top: 6,
                    end: 6,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.navy, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.navy,
                            fontSize: 9.5,
                            height: 1.0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicesStrip() {
    // When searching, filter the full catalog by label/key; otherwise show the
    // first 7 categories from the shared catalog, matching the design strip.
    final List<String> keys = _searchQuery.isEmpty
        ? kSfCategoryOrder.take(7).toList()
        : kSfCategoryOrder
              .where(
                (k) =>
                    sfCategory(k).label.toLowerCase().contains(_searchQuery) ||
                    k.toLowerCase().contains(_searchQuery),
              )
              .toList();

    if (keys.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 18, 14),
        child: Row(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 20,
              color: AppColors.midGrey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr(context, 'لا توجد خدمات مطابقة'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  color: AppColors.midGrey,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 6),
        itemCount: keys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final key = keys[index];
          final cfg = sfCategory(key);
          return SizedBox(
            width: 76,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReportIssueScreen(),
                  ),
                );
                if (mounted) setState(() {});
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SfCatTile(key, size: 60),
                  const SizedBox(height: 7),
                  Text(
                    cfg.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: AppColors.darkGrey,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(
            delay: Duration(milliseconds: index * 45),
            duration: 350.ms,
          );
        },
      ),
    );
  }

  /// Compact quick-action card matching the home cards styling.
  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 8,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          // Vertical layout: the full card width is available to the Arabic
          // label, so two-word labels (تشخيص بالصور / المساعد الذكي) fit on a
          // single line without wrapping or truncation.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 9),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms);
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: GoogleFonts.ibmPlexSansArabic(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: AppColors.charcoal,
      letterSpacing: -0.2,
    ),
  );

  Widget _buildStats(String customerId) {
    return FutureBuilder<Map<String, int>>(
      future: _jobService.getCustomerStats(customerId),
      builder: (context, snapshot) {
        final stats =
            snapshot.data ??
            {'total': 0, 'pending': 0, 'inProgress': 0, 'completed': 0};
        return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SfStatCard(
                        label: tr(context, 'الإجمالي'),
                        value: '${stats['total']}',
                        icon: Icons.grid_view_rounded,
                        color: AppColors.primary,
                        bg: AppColors.navySoft,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: SfStatCard(
                        label: tr(context, 'قيد الانتظار'),
                        value: '${stats['pending']}',
                        icon: Icons.schedule_rounded,
                        color: AppColors.warning,
                        bg: AppColors.warningBg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: SfStatCard(
                        label: tr(context, 'نشطة'),
                        value: '${stats['inProgress']}',
                        icon: Icons.build_rounded,
                        color: AppColors.teal,
                        bg: AppColors.secondaryBg,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: SfStatCard(
                        label: tr(context, 'مكتملة'),
                        value: '${stats['completed']}',
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                        bg: AppColors.successBg,
                      ),
                    ),
                  ],
                ),
              ],
            )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(begin: 0.1, duration: 400.ms);
      },
    );
  }

  Widget _buildIssuesList(String customerId) {
    return FutureBuilder<List<Issue>>(
      future: _jobService.getCustomerIssues(customerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(18, 0, 18, 0),
            child: Column(children: [SfSkeletonCard(), SfSkeletonCard()]),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: 48,
              horizontal: 40,
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: AppColors.midGrey,
                ),
                const SizedBox(height: 12),
                Text(
                  tr(context, 'تعذّر تحميل البلاغات'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.midGrey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(tr(context, 'إعادة المحاولة')),
                ),
              ],
            ),
          );
        }

        // Hide cancelled issues from the active list so cancelling visibly
        // removes the request.
        final issues = (snapshot.data ?? [])
            .where((i) => i.status != IssueStatus.cancelled)
            .toList();

        if (issues.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 18),
          itemCount: issues.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return SmartCard(
              issue: issues[index],
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IssueDetailScreen(issue: issues[index]),
                  ),
                );
                // Refresh on return so a cancel/status change shows immediately.
                if (mounted) setState(() {});
              },
            ).animate().fadeIn(
              delay: Duration(milliseconds: index * 80),
              duration: 400.ms,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return SfEmptyState(
          icon: Icons.assignment_outlined,
          title: tr(context, 'لا توجد بلاغات بعد'),
          body: tr(
            context,
            'عند تقديم بلاغ صيانة سيظهر هنا لمتابعته. اضغط الزر بالأسفل للبدء!',
          ),
        )
        .animate()
        .fadeIn(delay: 300.ms, duration: 400.ms)
        .slideY(begin: 0.1, duration: 400.ms);
  }
}
