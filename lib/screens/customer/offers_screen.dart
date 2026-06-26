import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_header.dart';

/// Section the offer belongs to (drives grouping + the section header label).
enum OfferSection { firstOrder, seasonal, referral, bundles, pro }

/// A single promotional offer shown on the offers screen: a discount, a
/// title/subtitle, a validity window, and a copyable promo code.
class _Offer {
  final String title;
  final String subtitle;
  final String discount; // e.g. '25%' or '50 ج.م'
  final String validity;
  final String code;
  final OfferSection section;
  final IconData icon;
  final LinearGradient gradient;
  final bool featured;

  const _Offer({
    required this.title,
    required this.subtitle,
    required this.discount,
    required this.validity,
    required this.code,
    required this.section,
    required this.icon,
    required this.gradient,
    this.featured = false,
  });
}

// NOTE: static design data, ready for backend wiring.
const List<_Offer> _kSampleOffers = [
  _Offer(
    title: 'خصم أول طلب',
    subtitle: 'وفّر على أول خدمة تحجزها عبر سمارت فيكس',
    discount: '25%',
    validity: 'صالح حتى 30 يونيو 2026',
    code: 'SMART25',
    section: OfferSection.firstOrder,
    icon: Icons.rocket_launch,
    gradient: AppColors.heroGradient,
    featured: true,
  ),
  _Offer(
    title: 'عرض الصيف على التكييف',
    subtitle: 'صيانة وتنظيف أجهزة التكييف بسعر مخفّض',
    discount: '30%',
    validity: 'صالح حتى 15 أغسطس 2026',
    code: 'SUMMER30',
    section: OfferSection.seasonal,
    icon: Icons.ac_unit,
    gradient: AppColors.tealGradient,
    featured: true,
  ),
  _Offer(
    title: 'ادعُ صديقًا',
    subtitle: 'أنت وصديقك تحصلان على رصيد عند أول حجز له',
    discount: '50 ج.م',
    validity: 'عرض دائم',
    code: 'FRIEND50',
    section: OfferSection.referral,
    icon: Icons.group_add,
    gradient: AppColors.accentGradient,
  ),
  _Offer(
    title: 'باقة المنزل المتكامل',
    subtitle: 'سباكة وكهرباء ودهان في زيارة واحدة',
    discount: '20%',
    validity: 'صالح حتى نهاية الشهر',
    code: 'BUNDLE20',
    section: OfferSection.bundles,
    icon: Icons.home_repair_service,
    gradient: AppColors.primaryGradient,
  ),
  _Offer(
    title: 'عضوية سمارت برو',
    subtitle: 'أولوية في الحجز وخصم ثابت على كل الخدمات',
    discount: '15%',
    validity: 'اشتراك شهري',
    code: 'PRO15',
    section: OfferSection.pro,
    icon: Icons.workspace_premium,
    gradient: AppColors.accentGradient,
  ),
];

/// Customer offers & promotions screen.
///
/// Shows featured promo banner cards at the top (discount %, title, validity,
/// promo code with copy-to-clipboard), then the remaining offers grouped into
/// labelled sections (first-order, seasonal, referral, bundles, pro).
///
/// Static design data ([_kSampleOffers]) — ready for backend wiring.
/// Launched from the customer home offers banner.
class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  String _sectionLabel(OfferSection s) {
    switch (s) {
      case OfferSection.firstOrder:
        return 'عروض الطلب الأول';
      case OfferSection.seasonal:
        return 'عروض موسمية';
      case OfferSection.referral:
        return 'عروض الإحالة';
      case OfferSection.bundles:
        return 'الباقات';
      case OfferSection.pro:
        return 'سمارت برو';
    }
  }

  /// Leading icon for each section header — mirrors the design SectionCard
  /// header pattern (icon + title, brand-fg coloured icon).
  IconData _sectionIcon(OfferSection s) {
    switch (s) {
      case OfferSection.firstOrder:
        return Icons.rocket_launch;
      case OfferSection.seasonal:
        return Icons.wb_sunny_outlined;
      case OfferSection.referral:
        return Icons.group_add_outlined;
      case OfferSection.bundles:
        return Icons.home_repair_service_outlined;
      case OfferSection.pro:
        return Icons.workspace_premium_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final featured = _kSampleOffers.where((o) => o.featured).toList();
    final rest = _kSampleOffers.where((o) => !o.featured).toList();

    // Group the remaining offers by section, preserving declaration order.
    final sections = <OfferSection, List<_Offer>>{};
    for (final o in rest) {
      sections.putIfAbsent(o.section, () => []).add(o);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            SfGradientHeader(
              title: tr(context, 'العروض والخصومات'),
              subtitle: tr(context, 'وفّر أكثر على خدماتك المنزلية'),
              showBack: true,
            ),
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
                children: [
                  if (featured.isNotEmpty) ...[
                    _sectionTitle(
                      context,
                      tr(context, 'العروض المميّزة'),
                      Icons.auto_awesome,
                    ),
                    const SizedBox(height: 12),
                    ...featured.map((o) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _featuredBanner(context, o),
                        )),
                    const SizedBox(height: 8),
                  ],
                  for (final entry in sections.entries) ...[
                    _sectionTitle(
                      context,
                      tr(context, _sectionLabel(entry.key)),
                      _sectionIcon(entry.key),
                    ),
                    const SizedBox(height: 12),
                    ...entry.value.map((o) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _offerCard(context, o),
                        )),
                    const SizedBox(height: 8),
                  ],
                  _terms(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.navy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.start,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Large gradient banner used for featured promotions.
  Widget _featuredBanner(BuildContext context, _Offer o) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: o.gradient,
        borderRadius: BorderRadius.circular(AppColors.rCard),
        boxShadow: const [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 18,
            spreadRadius: -8,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(o.icon, size: 24, color: AppColors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, o.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr(context, o.subtitle),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tr(context, 'خصم')} ${tr(context, o.discount)}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: AppColors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr(context, o.validity),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _promoCode(context, o.code, onLight: true),
        ],
      ),
    );
  }

  /// Compact white card used for the grouped (non-featured) offers.
  Widget _offerCard(BuildContext context, _Offer o) {
    return Container(
      padding: const EdgeInsets.all(15),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondaryBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(o.icon, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, o.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(context, o.subtitle),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.midGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tr(context, o.discount),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.goldDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, size: 13, color: AppColors.midGrey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr(context, o.validity),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    color: AppColors.midGrey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          _promoCode(context, o.code, onLight: false),
        ],
      ),
    );
  }

  /// A dashed-look promo-code row with a copy-to-clipboard button.
  Widget _promoCode(BuildContext context, String code, {required bool onLight}) {
    final Color fg = onLight ? AppColors.white : AppColors.charcoal;
    final Color subtle = onLight
        ? AppColors.white.withValues(alpha: 0.85)
        : AppColors.midGrey;
    final Color fieldBg = onLight
        ? AppColors.white.withValues(alpha: 0.16)
        : AppColors.surfaceVariant;
    final Color border = onLight
        ? AppColors.white.withValues(alpha: 0.3)
        : AppColors.line;

    return Material(
      color: fieldBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _copyCode(context, code),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(Icons.local_offer, size: 15, color: subtle),
              const SizedBox(width: 8),
              Text(
                tr(context, 'كود الخصم'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: subtle,
                ),
              ),
              const SizedBox(width: 8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  code,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: fg,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded,
                      size: 15, color: onLight ? AppColors.gold : AppColors.primary),
                  const SizedBox(width: 5),
                  Text(
                    tr(context, 'نسخ'),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: onLight ? AppColors.gold : AppColors.primary,
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

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.charcoal,
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${tr(context, 'تم نسخ الكود')} $code',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _terms(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(AppColors.rCard),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 17, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(
                context,
                'تُطبَّق الشروط والأحكام على جميع العروض. لا يمكن الجمع بين أكثر من كود خصم في الطلب الواحد.',
              ),
              textAlign: TextAlign.start,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12,
                height: 1.6,
                color: AppColors.darkGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
