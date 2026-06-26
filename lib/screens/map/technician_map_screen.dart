import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../models/issue_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_avatar.dart';
import '../../widgets/sf_icons.dart';
import '../../widgets/sf_states.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/verified_badge.dart';
import '../customer/report_issue_screen.dart';

/// A single nearby technician shown on the map preview, derived from the live
/// API record (`ApiService.getTechnicians`).
class _MapTech {
  final String id;
  final String name;
  final String skill; // category key (plumbing, electrical, ...)
  final IssueCategory? category;
  final double rating;
  final int jobs;
  final bool verified;
  final String distance;

  /// Relative position on the map canvas, 0..1 of width / height — derived
  /// deterministically from the technician id so markers stay stable.
  final double fx;
  final double fy;

  const _MapTech({
    required this.id,
    required this.name,
    required this.skill,
    required this.category,
    required this.rating,
    required this.jobs,
    required this.verified,
    required this.distance,
    required this.fx,
    required this.fy,
  });
}

/// Nearby-technicians map preview: navy/teal field-service marketplace look.
///
/// Mirrors the Arabic prototype's interactive map screen — a styled map canvas
/// with a floating top bar, teardrop pin markers, a recenter button and a
/// bottom sheet listing the nearby technicians. The map itself remains a
/// styled placeholder (no GoogleMap widget/key), but every technician shown is
/// loaded live from [ApiService.getTechnicians] with loading / error / empty
/// states. Tapping a technician opens a detail sheet with a "احجز" (book) CTA
/// that routes into the report-issue flow pre-filled with the matching
/// category.
class TechnicianMapScreen extends StatefulWidget {
  const TechnicianMapScreen({super.key});

  @override
  State<TechnicianMapScreen> createState() => _TechnicianMapScreenState();
}

class _TechnicianMapScreenState extends State<TechnicianMapScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _error = false;
  List<_MapTech> _techs = const [];
  _MapTech? _selected;

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

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      final raw = await _api.getTechnicians();
      final techs = <_MapTech>[];
      for (var i = 0; i < raw.length; i++) {
        techs.add(_fromMap(raw[i], i));
      }
      if (mounted) {
        setState(() {
          _techs = techs;
          _selected = null;
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

  /// Build a [_MapTech] from a raw technician map, deriving a stable on-canvas
  /// position and a presentational distance from its index.
  _MapTech _fromMap(Map<String, dynamic> t, int index) {
    final id = (t['id'] ?? t['uid'] ?? t['_id'])?.toString() ?? 'tech-$index';
    final name = (t['name'] as String?)?.trim() ?? '';
    final rating = (t['rating'] as num?)?.toDouble() ?? 0;
    final jobs = (t['issuesResolved'] as num?)?.toInt() ?? 0;
    final verified = t['isVerified'] == true;

    String? key = t['category'] as String?;
    if (key == null || key.isEmpty) {
      final cats = t['categories'];
      if (cats is List && cats.isNotEmpty) key = cats.first?.toString();
    }
    final normalized = key == 'appliance_repair' ? 'applianceRepair' : key;
    IssueCategory? category;
    if (normalized != null && normalized.isNotEmpty) {
      for (final c in IssueCategory.values) {
        if (c.name == normalized) {
          category = c;
          break;
        }
      }
    }
    final skill = category?.name ?? (normalized ?? 'plumbing');

    // Deterministic pseudo-random placement spread across the canvas.
    final h = id.hashCode;
    final fx = 0.18 + ((h & 0xFF) / 255.0) * 0.64;
    final fy = 0.22 + (((h >> 8) & 0xFF) / 255.0) * 0.64;
    final distance =
        '${(0.4 + index * 0.4).toStringAsFixed(1)} ${tr(context, 'كم')}';

    return _MapTech(
      id: id,
      name: name,
      skill: skill,
      category: category,
      rating: rating,
      jobs: jobs,
      verified: verified,
      distance: distance,
      fx: fx,
      fy: fy,
    );
  }

  /// Focus a technician from the list / marker (mirrors the prototype's
  /// focusTech) and open its detail sheet.
  void _focusTech(_MapTech t) {
    setState(() => _selected = t);
    _openDetail(t);
  }

  /// Clear the selection / recenter (mirrors the prototype's recenter).
  void _recenter() => setState(() => _selected = null);

  void _openDetail(_MapTech t) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TechDetailSheet(
        tech: t,
        onBook: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ReportIssueScreen(initialCategory: t.category),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: AppColors.surfaceVariant,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              children: [
                // ── Map canvas (styled placeholder) ──────────────────────
                const Positioned.fill(child: _MapCanvas()),

                // ── User-location pulse ──────────────────────────────────
                Positioned(
                  left: w * 0.5 - 17,
                  top: h * 0.45 - 17,
                  child: const _UserLocationDot(),
                ),

                // ── Technician pin markers (live data) ───────────────────
                if (!_loading && !_error)
                  for (final t in _techs)
                    Positioned(
                      left: (w * t.fx) - 19,
                      top: (h * 0.9 * t.fy) - 46,
                      child: _PinMarker(
                        tech: t,
                        selected: identical(_selected, t),
                        onTap: () => _focusTech(t),
                      ),
                    ),

                // ── Floating top bar ─────────────────────────────────────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _TopBar(count: _techs.length),
                ),

                // ── Recenter button ──────────────────────────────────────
                PositionedDirectional(
                  end: 16,
                  bottom: 248,
                  child: _RecenterButton(onTap: _recenter),
                ),

                // ── Bottom sheet: nearby technicians list ────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _NearbySheet(
                    loading: _loading,
                    error: _error,
                    techs: _techs,
                    selected: _selected,
                    onSelect: _focusTech,
                    onRetry: _load,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Styled stand-in for the live map (subtle navy-tinted grid + radius ring).
class _MapCanvas extends StatelessWidget {
  const _MapCanvas();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDF2F5), Color(0xFFE3ECF1)],
        ),
      ),
      child: CustomPaint(
        painter: _MapGridPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid =
        Paint()
          ..color = AppColors.line.withValues(alpha: 0.55)
          ..strokeWidth = 1;
    const step = 46.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Soft search-radius ring around the user location.
    final center = Offset(size.width / 2, size.height * 0.45);
    final ringFill = Paint()..color = AppColors.navy.withValues(alpha: 0.05);
    final ringStroke =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppColors.navy.withValues(alpha: 0.28);
    final r = size.shortestSide * 0.34;
    canvas.drawCircle(center, r, ringFill);
    canvas.drawCircle(center, r, ringStroke);

    // A couple of faux "road" sweeps for depth.
    final road =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = AppColors.white.withValues(alpha: 0.7);
    canvas
      ..drawLine(
        Offset(0, size.height * 0.32),
        Offset(size.width, size.height * 0.44),
        road,
      )
      ..drawLine(
        Offset(size.width * 0.62, 0),
        Offset(size.width * 0.48, size.height),
        road,
      );
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) => false;
}

/// Pulsing navy dot marking the user's current location.
class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: AppColors.navy,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.navyShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating top bar: rounded back button + "الفنيون القريبون" pill + count.
class _TopBar extends StatelessWidget {
  final int count;
  const _TopBar({required this.count});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
        child: Row(
          children: [
            _FloatingButton(
              icon: sfIcon('arrow-right'),
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppColors.rField),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      sfIcon('map-pin'),
                      size: 17,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        tr(context, 'الفنيون القريبون'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FloatingButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.rField),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.rField),
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.rField),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: AppColors.charcoal),
        ),
      ),
    );
  }
}

/// Floating recenter / "my location" button.
class _RecenterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RecenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.rField),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.rField),
        onTap: onTap,
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.rField),
            boxShadow: [
              BoxShadow(
                color: AppColors.navyShadow.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.my_location,
            size: 21,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Teardrop pin marker (category-colored) used for each technician.
class _PinMarker extends StatelessWidget {
  final _MapTech tech;
  final bool selected;
  final VoidCallback onTap;

  const _PinMarker({
    required this.tech,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cat = sfCategory(tech.skill);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 38,
        height: 46,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Teardrop body (rounded square rotated 45°, bottom-left point).
            Transform.rotate(
              angle: 0.7853981634, // 45°
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 38 : 34,
                height: selected ? 38 : 34,
                decoration: BoxDecoration(
                  color: cat.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                    bottomLeft: Radius.circular(3),
                  ),
                  border: Border.all(color: AppColors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: cat.color.withValues(alpha: 0.45),
                      blurRadius: selected ? 14 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            // Upright icon centred on the teardrop.
            Positioned(
              top: selected ? 8 : 7,
              child: Icon(cat.icon, size: 16, color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing nearby technicians (mirrors the prototype's sheet),
/// with loading / error / empty states wrapping the live list.
class _NearbySheet extends StatelessWidget {
  final bool loading;
  final bool error;
  final List<_MapTech> techs;
  final _MapTech? selected;
  final ValueChanged<_MapTech> onSelect;
  final VoidCallback onRetry;

  const _NearbySheet({
    required this.loading,
    required this.error,
    required this.techs,
    required this.selected,
    required this.onSelect,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 34,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // Grab handle.
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 2, 18, 10),
            child: Text(
              loading || error
                  ? tr(context, 'فنيون بالقرب منك')
                  : '${techs.length} ${tr(context, 'فنيون بالقرب منك')}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
          ),
          Expanded(child: _content(context)),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (loading) {
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 14),
        children: const [
          SfSkeletonCard(),
          SfSkeletonCard(),
        ],
      );
    }

    if (error) {
      return SfEmptyState(
        icon: Icons.wifi_off_rounded,
        title: tr(context, 'تعذّر تحميل الفنيين'),
        body: tr(context, 'تحقّق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
        action: SmartButton(
          label: tr(context, 'إعادة المحاولة'),
          icon: Icons.refresh,
          width: 200,
          onPressed: onRetry,
        ),
      );
    }

    if (techs.isEmpty) {
      return SfEmptyState(
        icon: Icons.engineering_outlined,
        title: tr(context, 'لا يوجد فنيون بالقرب منك'),
        body: tr(context, 'سيظهر هنا الفنيون فور انضمامهم إلى المنصة.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 14),
      itemCount: techs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, i) {
        final tc = techs[i];
        return _NearbyRow(
          tech: tc,
          selected: identical(selected, tc),
          onTap: () => onSelect(tc),
        );
      },
    );
  }
}

/// One technician row inside the nearby sheet.
class _NearbyRow extends StatelessWidget {
  final _MapTech tech;
  final bool selected;
  final VoidCallback onTap;

  const _NearbyRow({
    required this.tech,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cat = sfCategory(tech.skill);
    final name = tech.name.isNotEmpty ? tech.name : tr(context, 'فني');
    return Material(
      color: selected ? AppColors.navySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.lineSoft,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Avatar with category badge (start side under RTL).
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SfAvatar(name: name, size: 46),
                    PositionedDirectional(
                      bottom: -2,
                      start: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: cat.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                        child: Icon(cat.icon, size: 11, color: AppColors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Name + meta.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.titleSmall?.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ),
                        if (tech.verified) ...[
                          const SizedBox(width: 5),
                          const VerifiedBadge(isVerified: true, size: 13),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            cat.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cat.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: AppColors.goldDeep,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          tech.rating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: AppColors.midGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Distance.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sfIcon('map-pin'),
                    size: 13,
                    color: AppColors.midGrey,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    tech.distance,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.midGrey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail sheet shown when a technician is tapped — name / rating / skill /
/// jobs and a "احجز" (book) CTA into the report-issue flow.
class _TechDetailSheet extends StatelessWidget {
  final _MapTech tech;
  final VoidCallback onBook;

  const _TechDetailSheet({required this.tech, required this.onBook});

  @override
  Widget build(BuildContext context) {
    // Read auth so guests are nudged to sign in before booking; mirrors the
    // app's Provider-based auth access.
    final auth = context.watch<AuthService>();
    final cat = sfCategory(tech.skill);
    final name = tech.name.isNotEmpty ? tech.name : tr(context, 'فني');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SfAvatar(name: name, size: 58),
                      PositionedDirectional(
                        bottom: -2,
                        start: -2,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: cat.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            cat.icon,
                            size: 13,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.charcoal,
                                    ),
                              ),
                            ),
                            if (tech.verified) ...[
                              const SizedBox(width: 6),
                              const VerifiedBadge(isVerified: true, size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cat.label,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cat.color,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatChip(
                    icon: Icons.star_rounded,
                    iconColor: AppColors.goldDeep,
                    label: tech.rating.toStringAsFixed(1),
                    sub: tr(context, 'التقييم'),
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    icon: Icons.task_alt_rounded,
                    iconColor: AppColors.secondary,
                    label: '${tech.jobs}',
                    sub: tr(context, 'مهمة'),
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    icon: sfIcon('map-pin'),
                    iconColor: AppColors.primary,
                    label: tech.distance,
                    sub: tr(context, 'المسافة'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SmartButton(
                label: tr(context, 'احجز الآن'),
                icon: Icons.handyman_outlined,
                onPressed: auth.isGuest ? null : onBook,
              ),
              if (auth.isGuest) ...[
                const SizedBox(height: 10),
                Text(
                  tr(context, 'سجّل الدخول لإتمام الحجز.'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: AppColors.midGrey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sub;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lineSoft),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: AppColors.midGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
