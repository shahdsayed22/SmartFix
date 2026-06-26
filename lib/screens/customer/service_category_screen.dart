import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_strings.dart';
import '../../models/issue_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_avatar.dart';
import '../../widgets/sf_icons.dart';
import '../../widgets/sf_stars.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/verified_badge.dart';
import 'report_issue_screen.dart';

/// Category detail screen: a category-colored hero header showing the average
/// price and number of available technicians, a list of trusted technicians
/// nearby (avatar, verified badge, rating, distance), a trust band, and a
/// primary "request the service now" CTA.
///
/// Static design content (no API): the technician pool is curated per category
/// to mirror the prototype's `MAP_TECHS`. Ready for backend wiring when a
/// nearby-technicians endpoint exists.
class ServiceCategoryScreen extends StatelessWidget {
  final IssueCategory category;

  const ServiceCategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final cfg = sfCategory(category);
    final pool = _poolFor(category);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _hero(context, cfg, pool.length),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 16),
                children: [
                  _sectionTitle(context, tr(context, 'فنيون موثوقون بالقرب منك')),
                  const SizedBox(height: 12),
                  ...pool.map((t) => _techTile(context, t)),
                  const SizedBox(height: 16),
                  _trustBand(context),
                ],
              ),
            ),
            _ctaBar(context),
          ],
        ),
      ),
    );
  }

  // ── Hero header ────────────────────────────────────────────────────
  Widget _hero(BuildContext context, SfCategory cfg, int techCount) {
    final color = cfg.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 48, 18, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [color, _darken(color, 0.16)],
        ),
        borderRadius: const BorderRadiusDirectional.only(
          bottomStart: Radius.circular(26),
          bottomEnd: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.32),
            blurRadius: 22,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Material(
                color: AppColors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.arrow_forward,
                      size: 19,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(cfg.icon, size: 30, color: AppColors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cfg.label,
                      textAlign: TextAlign.start,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _heroSubtitle(context, techCount),
                      textAlign: TextAlign.start,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        color: AppColors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _heroSubtitle(BuildContext context, int techCount) {
    final price = tr(context, _priceFor(category));
    final count = tr(context, _countWord(techCount));
    return '${tr(context, 'متوسط السعر')} $price · $count ${tr(context, 'فنيين متاحين')}';
  }

  // ── Section title ──────────────────────────────────────────────────
  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2),
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.charcoal,
        ),
      ),
    );
  }

  // ── A single trusted-technician row ────────────────────────────────
  Widget _techTile(BuildContext context, _Tech t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          SfAvatar(name: tr(context, t.name), size: 50),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tr(context, t.name),
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const VerifiedBadge(isVerified: true, size: 14),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    SfStars(value: t.rating, size: 13),
                    const SizedBox(width: 10),
                    Text(
                      tr(context, _ratingStr(t.rating)),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        color: AppColors.midGrey,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: AppColors.midGrey,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      tr(context, t.distance),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        color: AppColors.midGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Trust band ─────────────────────────────────────────────────────
  Widget _trustBand(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: AppColors.teal,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              tr(
                context,
                'جميع الفنيين موثّقون ومراجَعون. ادفع بأمان عبر التطبيق بعد إتمام العمل.',
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

  // ── Bottom CTA bar ─────────────────────────────────────────────────
  Widget _ctaBar(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: SmartButton(
        label: tr(context, 'اطلب الخدمة الآن'),
        icon: Icons.add,
        onPressed: () {
          // Open the report form with this category preselected.
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReportIssueScreen(initialCategory: category),
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────
  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  /// Average estimated price label per category — mirrors the prototype's
  /// `CAT_PRICE`. Arabic copy carries Arabic-Indic numerals.
  static String _priceFor(IssueCategory category) {
    switch (category) {
      case IssueCategory.plumbing:
        return '١٨٠ ج.م';
      case IssueCategory.electrical:
        return '٢٠٠ ج.م';
      case IssueCategory.carpentry:
        return '٢٥٠ ج.م';
      case IssueCategory.painting:
        return '١٬٢٠٠ ج.م';
      case IssueCategory.hvac:
        return '٣٥٠ ج.م';
      case IssueCategory.cleaning:
        return '٣٠٠ ج.م';
      case IssueCategory.applianceRepair:
        return '٢٢٠ ج.م';
      case IssueCategory.welding:
        return '٢٨٠ ج.م';
      case IssueCategory.tiling:
        return '٩٠٠ ج.م';
    }
  }

  /// Arabic-Indic count word for the available-technicians line.
  static String _countWord(int n) {
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final buf = StringBuffer();
    for (final ch in n.toString().split('')) {
      final d = int.tryParse(ch);
      buf.write(d == null ? ch : ar[d]);
    }
    return buf.toString();
  }

  /// One-decimal rating with Arabic-Indic numerals (e.g. 4.8 -> '٤٫٨').
  static String _ratingStr(double rating) {
    final s = rating.toStringAsFixed(1);
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      if (ch == '.') {
        buf.write('٫');
        continue;
      }
      final d = int.tryParse(ch);
      buf.write(d == null ? ch : ar[d]);
    }
    return buf.toString();
  }

  /// Curated technician pool per category — mirrors the prototype's
  /// `MAP_TECHS.filter(skill === cat)` with a 3-tech fallback re-skilled to
  /// the requested category. Static design data, ready for backend wiring.
  static List<_Tech> _poolFor(IssueCategory category) {
    final matches = _kMapTechs
        .where((t) => t.skill == category)
        .toList(growable: false);
    if (matches.isNotEmpty) return matches;
    return _kMapTechs.take(3).toList(growable: false);
  }

  /// Demo technicians (Cairo) — mirrors the prototype's `MAP_TECHS`.
  static const List<_Tech> _kMapTechs = [
    _Tech('أحمد السيد', IssueCategory.plumbing, 4.8, '٠٫٤ كم'),
    _Tech('سارة كمال', IssueCategory.electrical, 4.9, '١٫١ كم'),
    _Tech('عمر فاروق', IssueCategory.carpentry, 4.6, '١٫٣ كم'),
    _Tech('مصطفى زكي', IssueCategory.hvac, 4.7, '١٫٦ كم'),
    _Tech('ليلى عادل', IssueCategory.cleaning, 5.0, '٢٫٠ كم'),
    _Tech('كريم سليمان', IssueCategory.tiling, 4.5, '٢٫٤ كم'),
  ];
}

/// A single trusted-technician entry (static design content).
class _Tech {
  final String name;
  final IssueCategory skill;
  final double rating;
  final String distance;

  const _Tech(this.name, this.skill, this.rating, this.distance);
}
