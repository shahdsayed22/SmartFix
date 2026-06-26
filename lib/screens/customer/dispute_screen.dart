import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/issue_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_cards.dart';
import '../../widgets/sf_feedback.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/smart_text_field.dart';

/// Report-a-problem / dispute screen for a completed order.
///
/// The customer picks a complaint reason, describes what happened, and may
/// attach an evidence note. Submitting opens a support ticket through
/// [ApiService.createTicket] (category `complaint`) linked to the related
/// [Issue]. After a successful submit we reveal a short list of suggested
/// next steps (request a revisit / contact support / wait for review).
///
/// Launched from a completed issue's detail screen via "report a problem".
class DisputeScreen extends StatefulWidget {
  const DisputeScreen({super.key, required this.issue});

  final Issue issue;

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen> {
  final ApiService _api = ApiService();

  // The complaint reasons offered to the customer (Arabic source keys).
  static const List<String> _reasons = [
    'العمل غير مكتمل',
    'جودة غير مرضية',
    'سعر مختلف عن المتفق عليه',
    'سلوك غير لائق',
    'سبب آخر',
  ];

  final TextEditingController _detailsCtrl = TextEditingController();
  final TextEditingController _evidenceCtrl = TextEditingController();

  String? _reason;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    _evidenceCtrl.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _submitting) return;

    setState(() => _submitting = true);

    final auth = context.read<AuthService>();
    final uid = auth.uid ?? widget.issue.customerId;
    final name = auth.currentUser?.name ?? widget.issue.customerName;
    final now = DateTime.now().toIso8601String();

    final details = _detailsCtrl.text.trim();
    final evidence = _evidenceCtrl.text.trim();

    final body = StringBuffer()
      ..writeln('${tr(context, 'سبب المشكلة')}: ${tr(context, reason)}');
    if (details.isNotEmpty) {
      body.writeln('${tr(context, 'التفاصيل')}: $details');
    }
    if (evidence.isNotEmpty) {
      body.writeln('${tr(context, 'إثبات')}: $evidence');
    }

    final ticketData = <String, dynamic>{
      'customerId': uid,
      'customerName': name,
      'subject':
          '${tr(context, 'شكوى على الطلب')}: ${widget.issue.title.isNotEmpty ? widget.issue.title : widget.issue.categoryLabel}',
      'category': 'complaint',
      'priority': 'high',
      'status': 'open',
      'source': 'dispute',
      'issueId': widget.issue.id,
      'messages': [
        {
          'senderId': uid,
          'senderRole': 'customer',
          'senderName': name,
          'text': body.toString().trim(),
          'attachments': const <String>[],
          'at': now,
        },
      ],
    };

    try {
      await _api.createTicket(ticketData);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
      SfToast.show(
        context,
        tr(context, 'تم استلام شكواك، سيتواصل معك الدعم'),
        tone: SfTone.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      SfToast.show(
        context,
        tr(context, 'تعذّر إرسال الشكوى، حاول مرة أخرى'),
        tone: SfTone.error,
      );
    }
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
              title: tr(context, 'الإبلاغ عن مشكلة'),
              subtitle: _submitted
                  ? tr(context, 'تم استلام شكواك')
                  : tr(context, 'أخبرنا بما حدث في طلبك'),
              showBack: true,
            ),
            Expanded(child: _submitted ? _resultBody() : _formBody()),
          ],
        ),
        bottomNavigationBar: _submitted ? null : _submitBar(),
      ),
    );
  }

  // ─── Form ────────────────────────────────────────────────────────

  Widget _formBody() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 24),
      children: [
        _reassuranceCard(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 11, start: 2),
          child: Text(
            tr(context, 'ما سبب المشكلة؟'),
            textAlign: TextAlign.start,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
        ),
        ..._reasons.map(_reasonTile),
        const SizedBox(height: 18),
        SmartTextField(
          label: tr(context, 'تفاصيل إضافية'),
          hint: tr(context, 'اشرح ما حدث…'),
          controller: _detailsCtrl,
          prefixIcon: Icons.chat_bubble_outline,
          maxLines: 4,
        ),
        const SizedBox(height: 14),
        SmartTextField(
          label: tr(context, 'إثبات (اختياري)'),
          hint: tr(context, 'رابط صورة أو ملاحظة تدعم شكواك'),
          controller: _evidenceCtrl,
          prefixIcon: Icons.attach_file,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _reassuranceCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              tr(
                context,
                'فريق الدعم سيراجع طلبك خلال ٢٤ ساعة. مدفوعاتك محميّة حتى يتم الحل.',
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

  Widget _reasonTile(String reason) {
    final selected = _reason == reason;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: selected ? AppColors.navySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _reason = reason),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.line,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.line,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 12, color: AppColors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr(context, reason),
                    textAlign: TextAlign.start,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
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

  Widget _submitBar() {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: SafeArea(
        top: false,
        child: _DangerButton(
          label: tr(context, 'إرسال الشكوى'),
          icon: Icons.flag_outlined,
          isLoading: _submitting,
          onPressed: _reason == null ? null : _submit,
        ),
      ),
    );
  }

  // ─── Result (suggested solutions) ────────────────────────────────

  Widget _resultBody() {
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(AppColors.rCard),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 30,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr(context, 'تم استلام شكواك'),
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  context,
                  'سيراجع فريق الدعم طلبك خلال ٢٤ ساعة ويتواصل معك. إليك ما يمكنك فعله الآن:',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.darkGrey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SfSectionCard(
          icon: Icons.tips_and_updates_outlined,
          title: tr(context, 'حلول مقترحة'),
          child: Column(
            children: [
              _solutionTile(
                icon: Icons.event_repeat,
                color: AppColors.primary,
                bg: AppColors.secondaryBg,
                title: tr(context, 'طلب إعادة زيارة'),
                body: tr(context, 'اطلب من الفني العودة لإتمام العمل أو إصلاحه.'),
              ),
              const SizedBox(height: 11),
              _solutionTile(
                icon: Icons.headset_mic_outlined,
                color: AppColors.teal,
                bg: AppColors.infoBg,
                title: tr(context, 'التواصل مع الدعم'),
                body: tr(context, 'تحدّث مباشرة مع فريق الدعم لمتابعة شكواك.'),
              ),
              const SizedBox(height: 11),
              _solutionTile(
                icon: Icons.hourglass_bottom,
                color: AppColors.warning,
                bg: AppColors.warningBg,
                title: tr(context, 'انتظار المراجعة'),
                body: tr(context, 'سنراجع الطلب ونعود إليك خلال ٢٤ ساعة.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SmartButton(
          label: tr(context, 'تم'),
          icon: Icons.check,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }

  Widget _solutionTile({
    required IconData icon,
    required Color color,
    required Color bg,
    required String title,
    required String body,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                textAlign: TextAlign.start,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                textAlign: TextAlign.start,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.5,
                  height: 1.55,
                  color: AppColors.midGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Full-width danger (red) action button — ports the design's
/// `Btn variant="danger"` look (red fill, radius, soft shadow, loading
/// spinner) since the shared [SmartButton] only offers navy / outlined.
class _DangerButton extends StatefulWidget {
  const _DangerButton({
    required this.label,
    this.icon,
    this.isLoading = false,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  State<_DangerButton> createState() => _DangerButtonState();
}

class _DangerButtonState extends State<_DangerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;

    final content = widget.isLoading
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
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 19, color: AppColors.white),
                const SizedBox(width: 9),
              ],
              Text(
                widget.label,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: AppColors.white,
                ),
              ),
            ],
          );

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: disabled ? null : () => setState(() => _pressed = false),
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(AppColors.rBtn),
              boxShadow: _pressed
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.30),
                        blurRadius: 16,
                        spreadRadius: -6,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
