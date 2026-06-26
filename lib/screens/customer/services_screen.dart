import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../../models/issue_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_cat_tile.dart';
import '../../widgets/sf_icons.dart';
import '../customer/service_category_screen.dart';

/// Average indicative starting price (EGP) per category, shown on each tile.
/// Mirrors the prototype's `CAT_PRICE` table. Static design data.
const Map<IssueCategory, int> _catPrice = {
  IssueCategory.plumbing: 180,
  IssueCategory.electrical: 200,
  IssueCategory.carpentry: 250,
  IssueCategory.painting: 1200,
  IssueCategory.hvac: 350,
  IssueCategory.cleaning: 300,
  IssueCategory.applianceRepair: 220,
  IssueCategory.welding: 280,
  IssueCategory.tiling: 900,
};

/// Full catalog of the 9 SmartFix service categories laid out as a two-column
/// grid. Each tile shows the category icon, its Arabic label, and an indicative
/// starting price. Tapping a tile pushes [ServiceCategoryScreen] for that
/// category, where the customer can browse trusted technicians and request the
/// service.
///
/// Static catalog screen (the categories are a fixed [IssueCategory] enum), so
/// there is no network wiring.
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  void _openCategory(BuildContext context, IssueCategory cat) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ServiceCategoryScreen(category: cat)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(title: tr(context, 'كل الخدمات')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 4, 18, 28),
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 16),
                      child: Text(
                        tr(
                          context,
                          'اختر الخدمة التي تحتاجها وستجد فنيين موثوقين قريبين منك.',
                        ),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13.5,
                          height: 1.6,
                          color: AppColors.midGrey,
                        ),
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.98,
                      children: [
                        for (final cat in IssueCategory.values)
                          _categoryCard(context, cat),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryCard(BuildContext context, IssueCategory cat) {
    final label = sfCategory(cat).label;
    final price = _catPrice[cat] ?? 250;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.rCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.rCard),
        onTap: () => _openCategory(context, cat),
        child: Ink(
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SfCatTile(cat, size: 50),
                const SizedBox(height: 12),
                Text(
                  tr(context, label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tr(context, 'يبدأ من')} ${_egp(context, price)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: AppColors.midGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Formats an EGP amount, switching between Arabic-Indic digits + "ج.م"
  /// and western digits + "EGP" based on the active locale.
  String _egp(BuildContext context, int n) {
    final grouped = n.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    bool isEn;
    try {
      isEn = context.read<LocaleProvider>().isEn;
    } catch (_) {
      isEn = false;
    }
    if (isEn) return 'EGP $grouped';
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var s = grouped;
    for (var i = 0; i < en.length; i++) {
      s = s.replaceAll(en[i], ar[i]);
    }
    return '$s ${tr(context, 'ج.م')}';
  }
}

/// Plain white top bar with a circular back button and a screen title —
/// the prototype's `TopBar`. Used on non-hero catalog screens.
class _TopBar extends StatelessWidget {
  final String title;

  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 18, 14),
      child: Row(
        children: [
          Material(
            color: AppColors.background,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: AppColors.charcoal,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
