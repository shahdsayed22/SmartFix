import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_strings.dart';
import '../../models/commission_settings.dart';
import '../../models/issue_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_cards.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_states.dart';
import '../../widgets/smart_button.dart';

/// Customer completion-approval screen.
///
/// Opened from the customer issue detail when the job status is
/// `awaitingApproval`, and from the approval notification. Shows the
/// technician's completion evidence (work photos, work summary, and the
/// final/estimated price breakdown), then offers two actions:
///   • approve  → [ApiService.approveCompletion] (status → awaitingPayment)
///   • reject   → [ApiService.rejectCompletion] with a reason dialog
///                (status returns to inProgress).
///
/// The completion evidence is the authoritative server copy: it's fetched by
/// matching this issue inside [ApiService.getIssues] (there is no single-issue
/// GET), with loading (skeleton), error (retry), and graceful empty states.
class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key, required this.issue});

  final Issue issue;

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _error = false;
  bool _submitting = false;

  CommissionSettings _settings = CommissionSettings();

  String _completionSummary = '';
  List<String> _completionPhotos = const [];
  double? _finalPrice;
  String _techName = '';

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

  /// Estimated base price when the dashboard hasn't priced the job yet.
  double _baseFor(Issue issue) {
    switch (issue.urgency) {
      case IssueUrgency.low:
        return 200;
      case IssueUrgency.medium:
        return 320;
      case IssueUrgency.high:
        return 480;
      case IssueUrgency.emergency:
        return 650;
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }

    try {
      // Commission settings drive the invoice breakdown; fall back to defaults.
      CommissionSettings settings = CommissionSettings();
      try {
        settings = CommissionSettings.fromJson(
          await _api.getCommissionSettings(),
        );
      } catch (_) {
        // keep defaults on a missing/disabled settings endpoint
      }

      // No single-issue GET — find the authoritative copy in the customer list.
      final issues = await _api.getIssues(customerId: widget.issue.customerId);
      Map<String, dynamic>? raw;
      for (final m in issues) {
        final mid = (m['id'] ?? m['_id'])?.toString();
        if (mid == widget.issue.id) {
          raw = m;
          break;
        }
      }

      final photos = <String>[
        ...List<String>.from(raw?['completionPhotos'] ?? const []),
      ];
      final finalPrice = (raw?['finalPrice'] as num?)?.toDouble();

      if (mounted) {
        setState(() {
          _settings = settings;
          _completionSummary =
              raw?['completionSummary']?.toString().trim() ?? '';
          _completionPhotos = photos;
          _finalPrice = finalPrice;
          _techName =
              raw?['assignedTechnicianName']?.toString() ??
              widget.issue.assignedWorkerName ??
              '';
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

  Invoice get _invoice {
    final base = _finalPrice ?? _baseFor(widget.issue);
    return _settings.computeInvoice(base: base);
  }

  Future<void> _approve() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _api.approveCompletion(widget.issue.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            tr(context, 'تمت الموافقة على العمل'),
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
            tr(context, 'تعذّر إتمام الموافقة. حاول مرة أخرى.'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _reject() async {
    if (_submitting) return;
    final reason = await _askReason();
    if (reason == null || reason.trim().isEmpty) return;

    setState(() => _submitting = true);
    try {
      await _api.rejectCompletion(widget.issue.id, rejectionReason: reason.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.info,
          content: Text(
            tr(context, 'تم إرسال طلب التعديل للفني'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ),
      );
      Navigator.of(context).pop(false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            tr(context, 'تعذّر إرسال طلب التعديل. حاول مرة أخرى.'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ),
      );
    }
  }

  Future<String?> _askReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.rCard),
            ),
            title: Text(
              tr(context, 'طلب تعديل؟'),
              textAlign: TextAlign.start,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    context,
                    'سيتم إخطار الفني بأن العمل يحتاج إلى تعديل قبل الموافقة النهائية. اذكر سبب طلب التعديل:',
                  ),
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.midGrey,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    color: AppColors.charcoal,
                  ),
                  decoration: InputDecoration(
                    hintText: tr(context, 'مثال: لم يتم إصلاح التسريب بالكامل…'),
                    hintStyle: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      color: AppColors.midGrey,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppColors.rField),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppColors.rField),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppColors.rField),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  tr(context, 'تراجع'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.midGrey,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.rBtn),
                  ),
                ),
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text),
                child: Text(
                  tr(context, 'طلب تعديل'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
              title: tr(context, 'مراجعة العمل المُنجز'),
              subtitle: tr(context, 'راجع الأدلة قبل الموافقة والانتقال للدفع'),
              showBack: true,
            ),
            Expanded(child: _body()),
            if (!_loading && !_error) _actionBar(),
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
        title: tr(context, 'تعذّر تحميل تفاصيل العمل'),
        body: tr(context, 'تحقّق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
        action: SmartButton(
          label: tr(context, 'إعادة المحاولة'),
          icon: Icons.refresh,
          width: 200,
          onPressed: _load,
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 24),
        children: [
          _hero(),
          const SizedBox(height: 16),
          _photosCard(),
          const SizedBox(height: 14),
          _summaryCard(),
          const SizedBox(height: 14),
          _costCard(),
        ],
      ),
    );
  }

  Widget _hero() {
    final who = _techName.trim().isNotEmpty
        ? '${tr(context, 'أنهى')} ${_techName.trim()} ${tr(context, 'العمل')}'
        : tr(context, 'أنهى الفني العمل');
    return Column(
      children: [
        const SizedBox(height: 4),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.approvalBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.fact_check_outlined,
            size: 34,
            color: AppColors.approval,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          who,
          textAlign: TextAlign.center,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            tr(
              context,
              'راجع ملخّص العمل والصور قبل الموافقة والانتقال إلى الدفع.',
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.5,
              height: 1.6,
              color: AppColors.midGrey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _photosCard() {
    return SfSectionCard(
      icon: Icons.image_outlined,
      title: tr(context, 'صور العمل'),
      child: _completionPhotos.isEmpty
          ? _photoEmpty()
          : GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.25,
              children: [
                for (final url in _completionPhotos) _photoTile(url),
              ],
            ),
    );
  }

  Widget _photoTile(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: AppColors.surfaceVariant,
        child: url.isEmpty
            ? _photoPlaceholder()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _photoPlaceholder(),
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return _photoPlaceholder();
                },
              ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: AppColors.surfaceVariant,
      alignment: Alignment.center,
      child: const Icon(
        Icons.camera_alt_outlined,
        size: 22,
        color: AppColors.midGrey,
      ),
    );
  }

  Widget _photoEmpty() {
    return Container(
      height: 90,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            size: 24,
            color: AppColors.midGrey,
          ),
          const SizedBox(height: 6),
          Text(
            tr(context, 'لم يُرفق الفني أي صور'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              color: AppColors.midGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final hasSummary = _completionSummary.isNotEmpty;
    return SfSectionCard(
      icon: Icons.assignment_outlined,
      title: tr(context, 'ملخّص العمل'),
      child: Text(
        hasSummary
            ? _completionSummary
            : tr(context, 'لم يضف الفني ملخّصًا للعمل المُنجز.'),
        textAlign: TextAlign.start,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 14,
          height: 1.7,
          color: hasSummary ? AppColors.darkGrey : AppColors.midGrey,
        ),
      ),
    );
  }

  Widget _costCard() {
    final inv = _invoice;
    final estimated = _finalPrice == null;
    return SfSectionCard(
      icon: Icons.receipt_long_outlined,
      title: estimated
          ? tr(context, 'التكلفة المتوقّعة')
          : tr(context, 'التكلفة النهائية'),
      child: Column(
        children: [
          _costRow(tr(context, 'أجر الخدمة'), _egp(inv.base)),
          _costRow(tr(context, 'رسوم المنصة'), _egp(inv.platformFee)),
          _costRow(tr(context, 'ضريبة القيمة المضافة'), _egp(inv.vat)),
          const SizedBox(height: 10),
          Container(height: 1, color: AppColors.lineSoft),
          const SizedBox(height: 10),
          _costRow(tr(context, 'الإجمالي'), _egp(inv.total), bold: true),
        ],
      ),
    );
  }

  Widget _costRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.start,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: bold ? 15 : 13.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: bold ? AppColors.charcoal : AppColors.darkGrey,
              ),
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: bold ? 16 : 13.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                color: bold ? AppColors.primary : AppColors.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 18),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 18,
            spreadRadius: -10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 10,
              child: _reviseButton(),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 14,
              child: _approveButton(),
            ),
          ],
        ),
      ),
    );
  }

  /// Danger-toned outlined "request revision" button (design: outlineDanger).
  Widget _reviseButton() {
    final disabled = _submitting;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: GestureDetector(
        onTap: disabled ? null : _reject,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppColors.rBtn),
            border: Border.all(color: AppColors.error, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.rotate_left, size: 19, color: AppColors.error),
              const SizedBox(width: 9),
              Text(
                tr(context, 'طلب تعديل'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Primary "approve & continue" button in the approval brand (purple),
  /// matching the hero accent (design: background #7A5AE0 with purple glow).
  Widget _approveButton() {
    final disabled = _submitting;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: GestureDetector(
        onTap: disabled ? null : _approve,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.approval,
            borderRadius: BorderRadius.circular(AppColors.rBtn),
            boxShadow: _submitting
                ? null
                : [
                    BoxShadow(
                      color: AppColors.approval.withValues(alpha: 0.5),
                      blurRadius: 16,
                      spreadRadius: -6,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 19,
                      color: AppColors.white,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      tr(context, 'موافقة ومتابعة'),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
