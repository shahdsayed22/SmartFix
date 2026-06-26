import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/category_service.dart';
import '../../models/issue_model.dart';
import '../../models/payment.dart';
import '../../models/commission_settings.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_cards.dart';
import '../../widgets/sf_states.dart';
import '../../widgets/sf_feedback.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/smart_text_field.dart';
import 'payment_webview_screen.dart';
import 'rating_screen.dart';

/// Checkout / invoice screen (§3 financial model).
///
/// Fetches the [CommissionSettings] singleton, derives the §3 invoice
/// breakdown (base → platformFee → vat → total), lets the customer pick a
/// payment method (card / meeza / fawry / wallet), then creates a Payment
/// (real MyFatoorah flow): opens the returned `paymentUrl` in the external
/// browser and polls `getPayment(_id)` until the status becomes `paid` or
/// `failed`.
class PaymentScreen extends StatefulWidget {
  final Issue issue;

  const PaymentScreen({super.key, required this.issue});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

/// One selectable payment method (mirrors the design's PAY_METHODS).
class _PayMethod {
  final String key;
  final String labelAr;
  final String subAr;
  final IconData icon;

  const _PayMethod(this.key, this.labelAr, this.subAr, this.icon);
}

const List<_PayMethod> _kPayMethods = [
  _PayMethod('card', 'بطاقة ائتمان', 'فيزا / ماستركارد', Icons.credit_card),
  _PayMethod('meeza', 'بطاقة ميزة', 'بطاقة الدفع الوطنية', Icons.payment),
  _PayMethod('fawry', 'فوري', 'ادفع نقدًا من أقرب منفذ', Icons.storefront),
  _PayMethod('wallet', 'محفظة إلكترونية', 'فودافون كاش / إنستاباي', Icons.account_balance_wallet),
];

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _hasError = false;
  bool _processing = false;

  CommissionSettings? _settings;
  Invoice? _invoice;

  String _method = 'card';

  // ── Live MyFatoorah payment state ──────────────────────────────────
  /// Created payment doc id (Mongo _id) once createPayment succeeds.
  String? _paymentId;

  /// Current server-confirmed status: pending / paid / failed.
  String _payStatus = '';

  /// True while a poll cycle / status check is in flight.
  bool _checking = false;

  /// Polling attempts so far (capped by [_kMaxPollAttempts]).
  int _pollAttempts = 0;

  Timer? _pollTimer;

  static const int _kMaxPollAttempts = 24; // ~24 × 2.5s ≈ 1 min
  static const Duration _kPollInterval = Duration(milliseconds: 2500);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _api.dispose();
    super.dispose();
  }

  /// snake_case category key for the issue (used for the default-price fallback).
  String get _categoryKey {
    switch (widget.issue.category) {
      case IssueCategory.applianceRepair:
        return 'appliance_repair';
      default:
        return widget.issue.category.name;
    }
  }

  /// Base service price = the locked upfront fare the worker accepted
  /// (`issue.price`). Falls back to the category default only if the issue was
  /// never priced — mirrors the design's `issue.price || CAT_PRICE[cat] || 250`.
  double get _base {
    if (widget.issue.price > 0) return widget.issue.price;
    final byCategory = categoryDefaultPrice(_categoryKey);
    return (byCategory > 0 ? byCategory : 250).toDouble();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await _api.getCommissionSettings();
      final settings = CommissionSettings.fromJson(data);
      final invoice = settings.computeInvoice(base: _base);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _invoice = invoice;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  /// Step 1+2: create the MyFatoorah invoice and open its hosted payment page,
  /// then begin polling for the final status.
  Future<void> _pay() async {
    final invoice = _invoice;
    final settings = _settings;
    if (invoice == null || settings == null || _processing) return;

    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final customerId = user?.uid ?? auth.uid ?? widget.issue.customerId;

    setState(() {
      _processing = true;
      _payStatus = 'pending';
    });
    try {
      // 1) Create the invoice — server returns _id + a hosted paymentUrl.
      final created = await _api.createPayment({
        'issueId': widget.issue.id,
        'customerId': customerId,
        'customerName': user?.name ?? widget.issue.customerName,
        'customerEmail': user?.email ?? '',
        'customerPhone': user?.phone ?? '',
        'technicianId': widget.issue.assignedWorkerId ?? '',
        'method': _method,
        'base': invoice.base,
        'discount': invoice.discount,
        'currency': invoice.currency,
      });
      final payment = Payment.fromJson(created);

      if (payment.id.isEmpty) {
        throw Exception('missing payment id');
      }
      _paymentId = payment.id;

      // Already settled on creation (defensive) → finish straight away.
      if (payment.isPaid) {
        await _onPaid();
        return;
      }
      if (payment.status == 'failed') {
        _onFailed();
        return;
      }

      if (!mounted) return;
      setState(() => _payStatus = payment.status.isEmpty
          ? 'pending'
          : payment.status);

      // 2) Open the hosted Paymob payment page. On mobile we host it in an
      //    in-app WebView that auto-closes the moment Paymob redirects to our
      //    callback — so the user lands straight back here instead of being
      //    stranded in the external browser. On web (no WebView plugin) we
      //    fall back to opening the page in a new tab.
      final url = payment.paymentUrl;
      if (url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          if (kIsWeb) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (!mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PaymentWebViewScreen(paymentUrl: url),
              ),
            );
            // Back from the payment page → confirm the status immediately
            // (the WebView returns as soon as Paymob hits our callback).
            if (mounted) await _fetchStatus();
          }
        }
      }

      // 3) Keep polling for the server-confirmed status. The Paymob webhook is
      //    authoritative, so this also covers a missed/!mounted redirect.
      if (mounted && _payStatus != 'paid') {
        _startPolling();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _payStatus = '';
      });
      SfToast.show(context, tr(context, 'تعذّر إتمام الدفع، حاول مرة أخرى'),
          tone: SfTone.error);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollAttempts = 0;
    _pollTimer = Timer.periodic(_kPollInterval, (_) => _pollOnce());
  }

  /// One poll tick — fetch the payment and react to a terminal status.
  Future<void> _pollOnce() async {
    final id = _paymentId;
    if (id == null || id.isEmpty) {
      _pollTimer?.cancel();
      return;
    }
    if (_checking) return; // skip if the previous fetch is still running
    _pollAttempts++;
    await _fetchStatus();
    if (mounted && _payStatus == 'pending' && _pollAttempts >= _kMaxPollAttempts) {
      // Timed out — stop auto-polling but keep the manual check button.
      _pollTimer?.cancel();
      SfToast.show(
        context,
        tr(context, 'لم نتلقَّ تأكيد الدفع بعد، أكمل الدفع ثم اضغط «تحقّق من الحالة».'),
        tone: SfTone.warning,
      );
    }
  }

  /// Manual "I've paid / check status" handler + shared status fetch.
  Future<void> _checkStatus() async {
    if (_checking) return;
    await _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final id = _paymentId;
    if (id == null || id.isEmpty) return;
    if (mounted) setState(() => _checking = true);
    try {
      final data = await _api.getPayment(id);
      final payment = Payment.fromJson(data);
      if (!mounted) return;
      setState(() {
        _checking = false;
        _payStatus = payment.status.isEmpty ? _payStatus : payment.status;
      });
      if (payment.isPaid) {
        await _onPaid();
      } else if (payment.status == 'failed') {
        _onFailed();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
    }
  }

  Future<void> _onPaid() async {
    _pollTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _payStatus = 'paid';
      _processing = false;
    });
    SfToast.show(context, tr(context, 'تم الدفع بنجاح 🎉'),
        tone: SfTone.success);

    // Move on to rating, then close checkout reporting success.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RatingScreen(issue: widget.issue)),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _onFailed() {
    _pollTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _payStatus = 'failed';
      _processing = false;
    });
    SfToast.show(context, tr(context, 'فشل الدفع، يمكنك المحاولة مجددًا'),
        tone: SfTone.error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SfGradientHeader(
            title: tr(context, 'الدفع'),
            showBack: true,
            actions: [_secureBadge(context)],
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: const [
          SfSkeletonCard(),
          SfSkeletonCard(),
          SfSkeletonCard(),
        ],
      );
    }

    if (_hasError || _invoice == null) {
      return SfEmptyState(
        icon: Icons.receipt_long,
        title: tr(context, 'تعذّر تحميل الفاتورة'),
        body: tr(context, 'حدث خطأ أثناء جلب تفاصيل الدفع. تحقّق من اتصالك ثم حاول مجددًا.'),
        action: SmartButton(
          label: tr(context, 'إعادة المحاولة'),
          icon: Icons.refresh,
          onPressed: _load,
        ),
      );
    }

    final invoice = _invoice!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            children: [
              _amountCard(context, invoice),
              const SizedBox(height: 14),
              _invoiceCard(context, invoice),
              const SizedBox(height: 14),
              _methodsSection(context),
              const SizedBox(height: 14),
              _methodHint(context),
              if (_payStatus.isNotEmpty) ...[
                const SizedBox(height: 14),
                _statusBanner(context),
              ],
              const SizedBox(height: 14),
              _secureNote(context),
            ],
          ),
        ),
        _payBar(context, invoice),
      ],
    );
  }

  // ── Amount hero card ───────────────────────────────────────────────
  Widget _amountCard(BuildContext context, Invoice invoice) {
    final tech = widget.issue.assignedWorkerName;
    final subtitle = [
      widget.issue.title,
      if (tech != null && tech.isNotEmpty) tech,
    ].join(' · ');

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppColors.rCard),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(context, 'المبلغ المستحق'),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      color: AppColors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _egp(context, invoice.total),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                      height: 1.1,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.5,
                        color: AppColors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06, end: 0);
  }

  // ── Invoice breakdown ──────────────────────────────────────────────
  Widget _invoiceCard(BuildContext context, Invoice invoice) {
    final settings = _settings!;
    return SfSectionCard(
      icon: Icons.receipt_long,
      title: tr(context, 'تفاصيل الفاتورة'),
      child: Column(
        children: [
          _row(context, tr(context, 'أجر الخدمة'), invoice.base),
          _row(
            context,
            '${tr(context, 'رسوم المنصة')} (${_pct(context, settings.platformFeePercent)})',
            invoice.platformFee,
          ),
          _row(
            context,
            '${tr(context, 'ضريبة القيمة المضافة')} (${_pct(context, settings.vatPercent)})',
            invoice.vat,
          ),
          if (invoice.discount > 0)
            _row(context, tr(context, 'خصم'), -invoice.discount),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(height: 1, color: AppColors.lineSoft),
          ),
          _row(context, tr(context, 'الإجمالي'), invoice.total, bold: true),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, double value,
      {bool bold = false}) {
    final negative = value < 0;
    final text = negative
        ? '− ${_egp(context, value.abs())}'
        : _egp(context, value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: bold ? 15 : 13.5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: bold ? AppColors.charcoal : AppColors.darkGrey,
              ),
            ),
          ),
          Text(
            text,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: bold ? 16 : 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: bold ? AppColors.navy : AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment methods ────────────────────────────────────────────────
  Widget _methodsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 11),
          child: Text(
            tr(context, 'اختر طريقة الدفع'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
        ),
        ..._kPayMethods.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _methodTile(context, m),
            )),
      ],
    );
  }

  Widget _methodTile(BuildContext context, _PayMethod m) {
    final on = _method == m.key;
    return Material(
      color: on ? AppColors.navySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: _processing ? null : () => setState(() => _method = m.key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: on ? AppColors.navy : AppColors.line,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? AppColors.navy : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  m.icon,
                  size: 21,
                  color: on ? AppColors.white : AppColors.navy,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr(context, m.labelAr),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(context, m.subAr),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        color: AppColors.midGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 21,
                height: 21,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? AppColors.navy : Colors.transparent,
                  border: Border.all(
                    color: on ? AppColors.navy : AppColors.line,
                    width: 2,
                  ),
                ),
                child: on
                    ? const Icon(Icons.check, size: 12, color: AppColors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Contextual note shown under the method list for non-card methods.
  Widget _methodHint(BuildContext context) {
    String? hint;
    switch (_method) {
      case 'fawry':
        hint = tr(context,
            'سيتم إنشاء كود فوري بعد التأكيد، ادفع به من أقرب منفذ خلال ٢٤ ساعة.');
        break;
      case 'wallet':
        hint = tr(context,
            'سيتم تحويلك لتأكيد الدفع عبر محفظتك الإلكترونية بعد الضغط على زر الدفع.');
        break;
      case 'meeza':
        hint = tr(context, 'ادفع بأمان باستخدام بطاقة ميزة الوطنية.');
        break;
      default:
        hint = null;
    }
    if (hint == null) {
      // Card → show a saved-card style helper field (read-only placeholder).
      return SmartTextField(
        label: tr(context, 'رقم البطاقة'),
        hint: '•••• •••• •••• ••••',
        prefixIcon: Icons.credit_card,
        keyboardType: TextInputType.number,
        readOnly: _processing,
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.navy),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              hint,
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

  Widget _secureNote(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock, size: 13, color: AppColors.midGrey),
        const SizedBox(width: 6),
        Text(
          tr(context, 'دفع آمن ومشفّر عبر بوابة ماي فاتورة'),
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 11.5,
            color: AppColors.midGrey,
          ),
        ),
      ],
    );
  }

  // ── Live status banner (pending / paid / failed) ───────────────────
  Widget _statusBanner(BuildContext context) {
    late final IconData icon;
    late final Color color;
    late final Color bg;
    late final String title;
    late final String body;

    switch (_payStatus) {
      case 'paid':
        icon = Icons.check_circle;
        color = AppColors.success;
        bg = AppColors.successBg;
        title = tr(context, 'تم تأكيد الدفع');
        body = tr(context, 'تم استلام دفعتك بنجاح.');
        break;
      case 'failed':
        icon = Icons.error_outline;
        color = AppColors.error;
        bg = AppColors.warningBg;
        title = tr(context, 'فشل الدفع');
        body = tr(context, 'لم تكتمل عملية الدفع. يمكنك المحاولة مرة أخرى.');
        break;
      default: // pending
        icon = Icons.hourglass_top;
        color = AppColors.warning;
        bg = AppColors.warningBg;
        title = tr(context, 'بانتظار تأكيد الدفع');
        body = tr(context,
            'أكمل الدفع في الصفحة المفتوحة. سنؤكد الحالة تلقائيًا، أو اضغط «تحقّق من الحالة».');
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    height: 1.6,
                    color: AppColors.darkGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  // ── Bottom pay bar ─────────────────────────────────────────────────
  Widget _payBar(BuildContext context, Invoice invoice) {
    final children = <Widget>[];

    if (_payStatus == 'pending') {
      // Awaiting confirmation → manual "I've paid / check status" button.
      children.add(
        SmartButton(
          label: _checking
              ? tr(context, 'جارٍ التحقّق…')
              : tr(context, 'لقد دفعت · تحقّق من الحالة'),
          icon: _checking ? null : Icons.refresh,
          isLoading: _checking,
          width: double.infinity,
          onPressed: _checking ? null : _checkStatus,
        ),
      );
    } else if (_payStatus == 'failed') {
      // Failed → allow a fresh attempt.
      children.add(
        SmartButton(
          label: '${tr(context, 'إعادة المحاولة')} · ${_egp(context, invoice.total)}',
          icon: Icons.refresh,
          width: double.infinity,
          onPressed: _retry,
        ),
      );
    } else {
      // Initial / paid → primary pay button.
      children.add(
        SmartButton(
          label: _payStatus == 'paid'
              ? tr(context, 'تم الدفع')
              : _processing
                  ? tr(context, 'جارٍ معالجة الدفع…')
                  : '${tr(context, 'ادفع')} ${_egp(context, invoice.total)}',
          icon: (_processing || _payStatus == 'paid') ? null : Icons.lock,
          isLoading: _processing,
          width: double.infinity,
          onPressed: (_processing || _payStatus == 'paid') ? null : _pay,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  /// Reset to the initial state so the customer can pay again after a failure.
  void _retry() {
    _pollTimer?.cancel();
    setState(() {
      _paymentId = null;
      _payStatus = '';
      _processing = false;
      _checking = false;
      _pollAttempts = 0;
    });
    _pay();
  }

  // ── Header secure badge ────────────────────────────────────────────
  Widget _secureBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user, size: 14, color: AppColors.white),
          const SizedBox(width: 5),
          Text(
            tr(context, 'ماي فاتورة'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Formatting helpers ─────────────────────────────────────────────
  bool _isEn(BuildContext context) {
    try {
      return context.read<LocaleProvider>().isEn;
    } catch (_) {
      return false;
    }
  }

  String _digits(BuildContext context, String s) {
    if (_isEn(context)) return s;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (var i = 0; i < en.length; i++) {
      s = s.replaceAll(en[i], ar[i]);
    }
    return s;
  }

  String _egp(BuildContext context, double value) {
    final n = value.round();
    final grouped = n.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (m) => ',',
        );
    if (_isEn(context)) return 'EGP $grouped';
    return '${_digits(context, grouped)} ج.م';
  }

  String _pct(BuildContext context, double value) {
    final n = value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
    if (_isEn(context)) return '$n%';
    return '${_digits(context, n)}٪';
  }
}
