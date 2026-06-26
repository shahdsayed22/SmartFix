import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../../models/issue_model.dart';
import '../../services/api_service.dart';
import '../../services/category_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_cards.dart';
import '../../widgets/sf_cat_tile.dart';
import '../../widgets/sf_feedback.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_icons.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/smart_text_field.dart';

/// AI photo-diagnosis flow. The customer attaches up to three problem
/// photos (placeholder picker tiles — no real image_picker is invoked,
/// just a selected-count state) and types a short description. Tapping
/// "Analyze" runs the description through [ApiService.classifyText] to
/// detect the most likely service category, then renders a detected
/// category card plus a "Suggested Solutions" (الحلول المقترحة) list.
///
/// The analysis is the only network call; the suggested-solutions content
/// is static design copy keyed by category, ready for backend wiring.
class PhotoDiagnosisScreen extends StatefulWidget {
  final IssueCategory? category;

  const PhotoDiagnosisScreen({super.key, this.category});

  @override
  State<PhotoDiagnosisScreen> createState() => _PhotoDiagnosisScreenState();
}

enum _Phase { capture, analyzing, result }

class _PhotoDiagnosisScreenState extends State<PhotoDiagnosisScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _descCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  static const int _maxPhotos = 3;

  _Phase _phase = _Phase.capture;
  // Real picked photos (gallery/camera), kept as bytes so they preview + upload
  // on both mobile and the web PWA.
  final List<Uint8List> _photos = [];
  bool _failed = false;

  IssueCategory _detected = IssueCategory.plumbing;
  int _confidence = 0;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) _detected = widget.category!;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _api.dispose();
    super.dispose();
  }

  /// Pick a real photo from the camera or gallery and keep its bytes.
  Future<void> _pickPhoto() async {
    if (_photos.length >= _maxPhotos) return;
    final source = await _chooseSource();
    if (source == null) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1400,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _photos.add(bytes));
    } catch (e) {
      if (!mounted) return;
      SfToast.show(
        context,
        '${tr(context, 'تعذّر اختيار الصورة')}: $e',
        tone: SfTone.error,
      );
    }
  }

  /// Bottom sheet to choose between the camera and the gallery.
  Future<ImageSource?> _chooseSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary),
              title: Text(tr(context, 'التقاط صورة'),
                  textAlign: TextAlign.start),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: Text(tr(context, 'اختيار من المعرض'),
                  textAlign: TextAlign.start),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  bool get _canAnalyze =>
      _photos.isNotEmpty || _descCtrl.text.trim().isNotEmpty;

  Future<void> _analyze() async {
    final text = _descCtrl.text.trim();
    setState(() {
      _phase = _Phase.analyzing;
      _failed = false;
    });

    IssueCategory detected = widget.category ?? _detected;
    int confidence = 0;

    // Use the typed description to detect the category when available.
    if (text.isNotEmpty) {
      try {
        final res = await _api.classifyText(text);
        detected = _categoryFromKey(res['category']) ?? detected;
        final conf = res['confidence'];
        if (conf is num) {
          confidence = conf <= 1 ? (conf * 100).round() : conf.round();
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _phase = _Phase.capture;
            _failed = true;
          });
        }
        return;
      }
    } else {
      // No text to classify — keep the passed-in / default category.
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }

    // No fabricated confidence — show only what the classifier actually
    // returned (0 when there was no description to analyze).

    if (!mounted) return;
    setState(() {
      _detected = detected;
      _confidence = confidence;
      _phase = _Phase.result;
    });
  }

  void _reset() {
    setState(() {
      _photos.clear();
      _confidence = 0;
      _failed = false;
      _descCtrl.clear();
      _detected = widget.category ?? IssueCategory.plumbing;
      _phase = _Phase.capture;
    });
  }

  IssueCategory? _categoryFromKey(Object? value) {
    if (value == null) return null;
    final key = value.toString();
    if (key == 'appliance_repair') return IssueCategory.applianceRepair;
    for (final c in IssueCategory.values) {
      if (c.name == key) return c;
    }
    return null;
  }

  bool _localeIsEn(BuildContext context) {
    try {
      return context.read<LocaleProvider>().isEn;
    } catch (_) {
      return false;
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
              title: tr(context, 'تشخيص بالصور'),
              subtitle: tr(context, 'تحليل مبدئي من وصفك — الصور تُرفَق للفنّي'),
              showBack: true,
              actions: [_aiChip()],
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 24),
                children: [
                  if (_phase == _Phase.capture) ..._captureBody(),
                  if (_phase == _Phase.analyzing) _analyzingBody(),
                  if (_phase == _Phase.result) ..._resultBody(),
                ],
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _aiChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 13, color: AppColors.white),
          const SizedBox(width: 5),
          Text(
            tr(context, 'تحليل مبدئي'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Capture phase ────────────────────────────────────────────────

  List<Widget> _captureBody() {
    return [
      Text(
        tr(
          context,
          'اكتب وصف مشكلتك وأرفق صورًا للفنّي؛ يحلّل المساعد الوصف ليقترح السبب المرجّح وما يجب فعله.',
        ),
        textAlign: TextAlign.start,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 13.5,
          height: 1.6,
          color: AppColors.midGrey,
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          for (int i = 0; i < _maxPhotos; i++) ...[
            Expanded(child: _photoTile(i)),
            if (i < _maxPhotos - 1) const SizedBox(width: 10),
          ],
        ],
      ),
      const SizedBox(height: 8),
      Text(
        '${tr(context, 'الصور المحددة')}: ${_photos.length} / $_maxPhotos',
        textAlign: TextAlign.start,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.midGrey,
        ),
      ),
      const SizedBox(height: 16),
      SmartTextField(
        label: tr(context, 'وصف المشكلة'),
        hint: categoryDescriptionHint(
          _detected == IssueCategory.applianceRepair ? 'appliance_repair' : _detected.name,
          _localeIsEn(context),
        ),
        controller: _descCtrl,
        maxLines: 4,
        prefixIcon: Icons.description_outlined,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      if (_failed) ...[
        _noticeBox(
          icon: Icons.wifi_off_rounded,
          color: AppColors.error,
          bg: AppColors.dangerBg,
          text: tr(
            context,
            'تعذّر تحليل الوصف. تحقّق من اتصالك بالإنترنت ثم حاول مرة أخرى.',
          ),
        ),
        const SizedBox(height: 12),
      ],
      _noticeBox(
        icon: Icons.verified_user_outlined,
        color: AppColors.teal,
        bg: AppColors.secondaryBg,
        text: tr(
          context,
          'تُعالَج الصور بأمان لأغراض التشخيص فقط، ولن تُنشَر دون إذنك.',
        ),
      ),
    ];
  }

  Widget _photoTile(int index) {
    final filled = index < _photos.length;
    final enabled = index <= _photos.length && index < _maxPhotos;
    final isFirst = index == 0;

    final tile = AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: filled
              ? () => _removePhoto(index)
              : (enabled ? _pickPhoto : null),
          child: filled
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_photos[index], fit: BoxFit.cover),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 13, color: AppColors.white),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Opacity(
                    opacity: enabled ? 1 : 0.4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFirst
                              ? Icons.photo_camera_outlined
                              : Icons.add,
                          size: 24,
                          color: AppColors.primary,
                        ),
                        if (isFirst) ...[
                          const SizedBox(height: 5),
                          Text(
                            tr(context, 'التقط صورة'),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10,
                              color: AppColors.midGrey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );

    if (filled) return tile;

    // Empty tiles get the design's 1.5px dashed border in --line.
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: enabled ? AppColors.line : AppColors.lineSoft,
        radius: 16,
      ),
      child: tile,
    );
  }

  Widget _noticeBox({
    required IconData icon,
    required Color color,
    required Color bg,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
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

  // ── Analyzing phase ──────────────────────────────────────────────

  Widget _analyzingBody() {
    return Padding(
      padding: const EdgeInsets.only(top: 36, bottom: 24),
      child: Column(
        children: [
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.image_outlined,
              size: 44,
              color: AppColors.midGrey,
            ),
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 11),
              Text(
                tr(context, 'يحلّل المساعد وصف مشكلتك…'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Result phase ─────────────────────────────────────────────────

  List<Widget> _resultBody() {
    final diag =
        _kDiagnoses[_detected] ?? _kDiagnoses[IssueCategory.plumbing]!;
    return [
      _detectedCard(),
      if (diag.safety) ...[
        const SizedBox(height: 14),
        _noticeBox(
          icon: Icons.emergency_share,
          color: AppColors.error,
          bg: AppColors.dangerBg,
          text: tr(
            context,
            'انتبه للسلامة: قد تكون هذه المشكلة خطرة. اتبع خطوات الأمان ولا تحاول إصلاحها بنفسك.',
          ),
        ),
      ],
      const SizedBox(height: 14),
      SfSectionCard(
        icon: Icons.search,
        title: tr(context, 'السبب المرجّح'),
        child: Text(
          tr(context, diag.cause),
          textAlign: TextAlign.start,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            height: 1.7,
            color: AppColors.darkGrey,
          ),
        ),
      ),
      const SizedBox(height: 14),
      SfSectionCard(
        icon: Icons.checklist_rtl,
        title: tr(context, 'الحلول المقترحة'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < diag.steps.length; i++) ...[
              if (i > 0) const SizedBox(height: 11),
              _stepRow(i + 1, tr(context, diag.steps[i])),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline,
                size: 13,
                color: AppColors.midGrey,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  tr(
                    context,
                    'تقدير بالذكاء الاصطناعي، يؤكّده الفني عند المعاينة في الموقع.',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    color: AppColors.midGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _detectedCard() {
    final cfg = sfCategory(_detected);
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
      child: Row(
        children: [
          SfCatTile(_detected, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'الفئة المكتشفة'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: AppColors.midGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cfg.label,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(
                '$_confidence٪',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.teal,
                ),
              ),
              Text(
                tr(context, 'ثقة'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 10,
                  color: AppColors.midGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepRow(int n, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.navySoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$n',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            textAlign: TextAlign.start,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13.5,
              height: 1.6,
              color: AppColors.darkGrey,
            ),
          ),
        ),
      ],
    );
  }

  // ── Bottom action bar ────────────────────────────────────────────

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: SafeArea(
        top: false,
        child: _bottomContent(),
      ),
    );
  }

  Widget _bottomContent() {
    switch (_phase) {
      case _Phase.capture:
        return SmartButton(
          label: tr(context, 'تحليل الصور'),
          icon: Icons.auto_awesome,
          onPressed: _canAnalyze ? _analyze : null,
        );
      case _Phase.analyzing:
        return SmartButton(
          label: tr(context, 'يحلّل المساعد وصف مشكلتك…'),
          isLoading: true,
          onPressed: () {},
        );
      case _Phase.result:
        return Row(
          children: [
            Expanded(
              child: SmartButton(
                label: tr(context, 'إعادة'),
                icon: Icons.refresh,
                isOutlined: true,
                onPressed: _reset,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              flex: 2,
              child: SmartButton(
                label: tr(context, 'إنشاء بلاغ بهذه التفاصيل'),
                icon: Icons.arrow_back,
                onPressed: () => Navigator.of(context).pop(_detected),
              ),
            ),
          ],
        );
    }
  }
}

/// Paints a 1.5px dashed rounded-rectangle border, matching the design's
/// empty photo-picker tiles (`1.5px dashed var(--line)`).
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        canvas.drawPath(
          metric.extractPath(dist, dist + dash),
          paint,
        );
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// A static diagnosis block: likely cause + suggested-solution steps,
/// with a safety flag for hazardous categories.
class _Diagnosis {
  final String cause;
  final List<String> steps;
  final bool safety;

  const _Diagnosis({
    required this.cause,
    required this.steps,
    this.safety = false,
  });
}

// NOTE: static design data, ready for backend wiring.
const Map<IssueCategory, _Diagnosis> _kDiagnoses = {
  IssueCategory.plumbing: _Diagnosis(
    cause: 'تسريب محتمل في وصلة المواسير أو تلف في الحشوة المطاطية.',
    steps: [
      'أغلق محبس المياه الرئيسي لإيقاف التسريب.',
      'جفّف المنطقة وضع وعاءً لتجميع المياه المتساقطة.',
      'صوّر الوصلة المتضررة لمساعدة الفني على تحديد القطعة.',
      'اطلب فنّي سباكة لإحكام أو استبدال الوصلة.',
    ],
  ),
  IssueCategory.electrical: _Diagnosis(
    safety: true,
    cause: 'تماس كهربائي محتمل أو حمل زائد على الدائرة الكهربائية.',
    steps: [
      'افصل القاطع الرئيسي فورًا لتفادي الخطر.',
      'لا تلمس الأسلاك المكشوفة أو المقابس المتضررة.',
      'أبعد أي مواد قابلة للاشتعال عن مصدر المشكلة.',
      'اطلب فنّي كهرباء معتمدًا لفحص الدائرة وإصلاحها.',
    ],
  ),
  IssueCategory.carpentry: _Diagnosis(
    cause: 'تآكل في المفصلات أو ارتخاء في تثبيت الخشب.',
    steps: [
      'تجنّب استخدام القطعة المتضررة لمنع تفاقم التلف.',
      'اجمع المسامير أو القطع المفكوكة في مكان آمن.',
      'صوّر الجزء المتضرر من زوايا مختلفة.',
      'اطلب نجّارًا لإحكام التثبيت أو استبدال القطعة.',
    ],
  ),
  IssueCategory.painting: _Diagnosis(
    cause: 'تقشّر أو رطوبة في الطبقة الخارجية للدهان.',
    steps: [
      'تحقّق من مصدر الرطوبة خلف الجدار إن وُجد.',
      'هوِّ الغرفة جيدًا لتجفيف السطح.',
      'صوّر المساحة المتضررة لتقدير كمية الدهان.',
      'اطلب فنّي دهانات لمعالجة السطح وإعادة الطلاء.',
    ],
  ),
  IssueCategory.hvac: _Diagnosis(
    cause: 'انخفاض كفاءة التبريد بسبب اتساخ الفلتر أو نقص غاز التبريد.',
    steps: [
      'أوقف تشغيل الوحدة لتفادي إجهاد الضاغط.',
      'نظّف الفلتر إن كان متّسخًا بشكل واضح.',
      'دوّن أي أصوات أو روائح غير معتادة.',
      'اطلب فنّي تكييف لفحص الغاز وكفاءة التبريد.',
    ],
  ),
  IssueCategory.cleaning: _Diagnosis(
    cause: 'تراكم أوساخ أو بقع تحتاج إلى تنظيف عميق متخصّص.',
    steps: [
      'أزل الأغراض القابلة للحركة من المنطقة.',
      'هوِّ المكان جيدًا قبل بدء التنظيف.',
      'صوّر البقع الصعبة لتحديد المواد المناسبة.',
      'اطلب خدمة تنظيف متخصّصة للمساحة المطلوبة.',
    ],
  ),
  IssueCategory.applianceRepair: _Diagnosis(
    cause: 'عطل محتمل في وحدة التحكم أو أحد المكونات الداخلية للجهاز.',
    steps: [
      'افصل الجهاز عن الكهرباء قبل أي فحص.',
      'تأكّد من سلامة الكابل والمقبس الكهربائي.',
      'دوّن رقم الموديل وأي رسالة خطأ تظهر.',
      'اطلب فنّي صيانة أجهزة لفحص العطل واستبدال القطعة.',
    ],
  ),
  IssueCategory.welding: _Diagnosis(
    safety: true,
    cause: 'ضعف أو كسر في وصلة معدنية ملحومة يحتاج إعادة لحام.',
    steps: [
      'أبعِد أي مواد قابلة للاشتعال عن منطقة العمل.',
      'لا تستخدم الهيكل المعدني المتضرر لتفادي انهياره.',
      'صوّر موضع الكسر من زوايا واضحة.',
      'اطلب فنّي لحام مزوّدًا بمعدّات السلامة المناسبة.',
    ],
  ),
  IssueCategory.tiling: _Diagnosis(
    cause: 'تشقّق أو ارتخاء في البلاط بسبب ضعف مادة التثبيت.',
    steps: [
      'تجنّب المشي على البلاط المتضرر لمنع تفاقم الكسر.',
      'أزل الشظايا الحادة بحذر إن وُجدت.',
      'صوّر المساحة المتأثرة لتقدير عدد القطع.',
      'اطلب فنّي سيراميك لإعادة التثبيت أو استبدال البلاط.',
    ],
  ),
};
