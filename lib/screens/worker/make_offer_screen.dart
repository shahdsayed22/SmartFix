import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_strings.dart';
import '../../models/commission_settings.dart';
import '../../models/issue_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_cat_tile.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/smart_text_field.dart';

/// Suggested base prices per category (ج.م). Mirrors the dashboard's
/// `CAT_PRICE` table so the worker gets a sensible default to anchor on.
/// NOTE: static design data, ready for backend wiring.
const Map<IssueCategory, double> kSuggestedPrices = {
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

/// Arrival-time choices the worker can pledge alongside the offer.
/// NOTE: static design data, ready for backend wiring.
const List<({String key, String label})> kEtaOptions = [
  (key: 'now', label: 'خلال ساعة'),
  (key: '2h', label: 'خلال ساعتين'),
  (key: 'today', label: 'اليوم'),
  (key: 'tomorrow', label: 'غدًا'),
];

/// Worker submits a price proposal for a job after inspecting it.
///
/// Shows a job summary, an EGP price input (seeded with a category-based
/// suggestion), an arrival-time picker, an optional note, and a live
/// breakdown preview computed through [CommissionSettings.computePayout] /
/// [CommissionSettings.computeInvoice] so the worker sees the platform
/// commission, VAT and their net payout before submitting.
///
/// Submitting persists the price via [ApiService.updateIssue].
/// Launched from the worker job-detail screen.
class MakeOfferScreen extends StatefulWidget {
  const MakeOfferScreen({super.key, required this.issue});

  final Issue issue;

  @override
  State<MakeOfferScreen> createState() => _MakeOfferScreenState();
}

class _MakeOfferScreenState extends State<MakeOfferScreen> {
  final ApiService _api = ApiService();

  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  bool _loadingSettings = true;
  bool _submitting = false;

  CommissionSettings _settings = CommissionSettings();
  String _eta = 'today';

  @override
  void initState() {
    super.initState();
    _priceCtrl.addListener(_onPriceChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    _priceCtrl.removeListener(_onPriceChanged);
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    _api.dispose();
    super.dispose();
  }

  double get _suggested =>
      kSuggestedPrices[widget.issue.category] ?? 250;

  double get _enteredPrice {
    final raw = _priceCtrl.text.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(raw) ?? 0;
  }

  void _onPriceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSettings() async {
    if (mounted) {
      setState(() => _loadingSettings = true);
    }
    // Commission settings drive the breakdown; fall back to defaults if the
    // endpoint is missing or disabled.
    CommissionSettings settings = CommissionSettings();
    try {
      settings = CommissionSettings.fromJson(
        await _api.getCommissionSettings(),
      );
    } catch (_) {
      // keep defaults
    }
    if (mounted) {
      setState(() {
        _settings = settings;
        _loadingSettings = false;
      });
    }
  }

  Future<void> _submit() async {
    final price = _enteredPrice;
    if (price <= 0) return;

    setState(() => _submitting = true);
    try {
      final note = _noteCtrl.text.trim();
      await _api.updateIssue(widget.issue.id, {
        'price': price,
        'estimatedEta': _eta,
        if (note.isNotEmpty) 'offerNote': note,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            tr(context, 'تم إرسال عرضك للعميل'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            tr(context, 'تعذّر إرسال العرض. حاول مرة أخرى.'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ),
      );
    }
  }

  String _egp(double v) {
    final n = v.abs();
    final s = n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
    final parts = s.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (int k = 0; k < intPart.length; k++) {
      if (k > 0 && (intPart.length - k) % 3 == 0) buf.write(',');
      buf.write(intPart[k]);
    }
    final grouped =
        parts.length > 1 ? '${buf.toString()}.${parts[1]}' : buf.toString();
    return '$grouped ${_settings.currency}';
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final canSubmit =
        _enteredPrice > 0 && !_submitting && !_loadingSettings;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            SfGradientHeader(
              title: tr(context, 'تقديم عرض'),
              subtitle: tr(context, 'حدّد سعرك للعميل'),
              showBack: true,
            ),
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
                children: [
                  _jobSummary(issue),
                  const SizedBox(height: 16),
                  _priceField(),
                  const SizedBox(height: 18),
                  _etaPicker(),
                  const SizedBox(height: 18),
                  SmartTextField(
                    label: tr(context, 'رسالة للعميل'),
                    hint: tr(context, 'عرّف بنفسك وما يشمله العرض…'),
                    controller: _noteCtrl,
                    prefixIcon: Icons.chat_bubble_outline,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 18),
                  _breakdown(),
                ],
              ),
            ),
            _submitBar(canSubmit),
          ],
        ),
      ),
    );
  }

  Widget _jobSummary(Issue issue) {
    final subtitleParts = <String>[
      if (issue.customerName.isNotEmpty) issue.customerName,
      if (issue.address.isNotEmpty) issue.address,
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.rCard),
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
      child: Row(
        children: [
          SfCatTile(issue.category, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title.isNotEmpty ? issue.title : issue.categoryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                if (subtitleParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitleParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.5,
                      color: AppColors.midGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 7),
          child: Text(
            tr(context, 'سعر العرض (ج.م)'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppColors.rField),
            border: Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 20,
                color: AppColors.midGrey,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 15),
                      hintText: _suggested
                          .toStringAsFixed(0),
                      hintStyle: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.lightGrey,
                      ),
                    ),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tr(context, 'ج.م'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  color: AppColors.midGrey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.lightbulb_outline,
              size: 14,
              color: AppColors.goldDeep,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${tr(context, 'السعر المقترح لهذه الخدمة حوالي')} ${_egp(_suggested)}',
                textAlign: TextAlign.start,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12,
                  color: AppColors.midGrey,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _etaPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 9),
          child: Text(
            tr(context, 'متى يمكنك الوصول؟'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
          ),
        ),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: kEtaOptions.map((o) {
            final on = _eta == o.key;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _eta = o.key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: on ? AppColors.secondaryBg : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: on ? AppColors.primary : AppColors.line,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  tr(context, o.label),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: on ? AppColors.primary : AppColors.darkGrey,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _breakdown() {
    final base = _enteredPrice;
    final hasPrice = base > 0;
    final payout = _settings.computePayout(base: base);
    final invoice = _settings.computeInvoice(base: base);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.rCard),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 7),
              Text(
                tr(context, 'تفاصيل العرض'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (!hasPrice)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8),
              child: Text(
                tr(context, 'أدخل السعر لعرض صافي أرباحك والعمولة.'),
                textAlign: TextAlign.start,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.5,
                  color: AppColors.midGrey,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 10),
            _row(
              tr(context, 'سعر العرض'),
              _egp(base),
            ),
            _divider(),
            _row(
              '${tr(context, 'عمولة المنصة')} (${_pct(_settings.workerCommissionPercent)})',
              '− ${_egp(payout.workerCommission)}',
              valueColor: AppColors.error,
            ),
            _divider(),
            _row(
              tr(context, 'صافي أرباحك'),
              _egp(payout.payout),
              emphasize: true,
              valueColor: AppColors.success,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 15,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${tr(context, 'يدفع العميل')} ${_egp(invoice.total)} ${tr(context, 'شاملة')} ${_pct(_settings.vatPercent)} ${tr(context, 'ضريبة')}',
                      textAlign: TextAlign.start,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _pct(double v) {
    final s = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);
    return '$s٪';
  }

  Widget _row(
    String label,
    String value, {
    bool emphasize = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.start,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: emphasize ? 14 : 13,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                color: emphasize ? AppColors.charcoal : AppColors.darkGrey,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: emphasize ? 16 : 13.5,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
                color: valueColor ?? AppColors.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
        height: 1,
        thickness: 1,
        color: AppColors.lineSoft,
      );

  Widget _submitBar(bool canSubmit) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.lineSoft),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SmartButton(
          label: tr(context, 'إرسال العرض'),
          icon: Icons.send_rounded,
          isLoading: _submitting,
          onPressed: canSubmit ? _submit : null,
        ),
      ),
    );
  }
}
