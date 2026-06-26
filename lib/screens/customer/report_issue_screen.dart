import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../services/location_service.dart';
import '../../services/category_service.dart';
import '../../services/api_service.dart';
import '../map/location_picker_screen.dart';
import '../../models/issue_model.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/smart_text_field.dart';
import '../../widgets/sf_cat_tile.dart';
import '../../widgets/sf_icons.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_feedback.dart';

class ReportIssueScreen extends StatefulWidget {
  /// Optional category to preselect in the form (e.g. when arriving from the
  /// service-category screen's "request service" CTA). Null = no preselection.
  final IssueCategory? initialCategory;

  const ReportIssueScreen({super.key, this.initialCategory});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _jobService = JobService();
  final _locationService = LocationService();
  final _api = ApiService();

  IssueCategory? _selectedCategory;
  IssueUrgency _selectedUrgency = IssueUrgency.medium;
  // True once the user manually picks an urgency — stops the AI auto-fill from
  // overriding their choice as they keep typing.
  bool _urgencyTouched = false;
  double? _latitude;
  double? _longitude;
  bool _isSubmitting = false;
  bool _isFetchingLocation = false;

  // ── NLP auto-detection (presentation aid only — does NOT change submit) ──
  // Suggested category derived from the title/description via the local
  // category_service.detectCategory mirror; tapping the chip pre-selects it.
  IssueCategory? _suggestedCategory;
  bool _suggestionDismissed = false;
  // Full local detection (category + confidence + matched keywords) powering the
  // prominent "AI Triage" card. This is the heuristic/keyword BASELINE — the
  // trained-ensemble metrics live on the dashboard's AI Insights page.
  CategoryDetection? _detection;
  // Which classifier produced [_detection]: 'heuristic' (instant on-device
  // baseline) or the trained server model id (e.g. 'nb-arabic-v1') after the
  // debounced /api/nlp/classify call returns. Drives the honest label + uses
  // the server's calibrated confidence when available.
  String _detMethod = 'heuristic';
  Timer? _debounce;

  // Wizard step (0=Category, 1=Details, 2=Urgency, 3=Location). Purely a
  // presentation concern — the underlying Form + submit logic is unchanged.
  int _step = 0;
  static const List<String> _stepTitles = [
    'التصنيف',
    'التفاصيل',
    'الأولوية',
    'الموقع',
  ];

  @override
  void initState() {
    super.initState();
    // Preselect the category passed by the caller (e.g. from the
    // service-category screen). The user can still change it in step 0.
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ── NLP: map a snake_case category key to the IssueCategory enum ──────
  IssueCategory? _categoryFromKey(String? key) {
    if (key == null) return null;
    if (key == 'appliance_repair') return IssueCategory.applianceRepair;
    for (final c in IssueCategory.values) {
      if (c.name == key) return c;
    }
    return null;
  }

  IssueUrgency? _urgencyFromKey(String? key) {
    if (key == null) return null;
    for (final u in IssueUrgency.values) {
      if (u.name == key) return u;
    }
    return null;
  }

  /// snake_case key of the currently-selected category (null if none), used to
  /// pick the per-category description placeholder.
  String? get _selectedCategoryKey {
    final c = _selectedCategory;
    if (c == null) return null;
    return c == IssueCategory.applianceRepair ? 'appliance_repair' : c.name;
  }

  bool _localeIsEn(BuildContext context) {
    try {
      return context.read<LocaleProvider>().isEn;
    } catch (_) {
      return false;
    }
  }

  // ── NLP: run the local detector on the current title + description and
  // surface a suggestion chip. Re-detection re-opens a dismissed chip when
  // the best guess changes. Never mutates the user's chosen category. ──
  void _runDetection() {
    final text =
        '${_titleController.text} ${_descriptionController.text}'.trim();
    if (text.isEmpty) {
      if (_suggestedCategory != null || _detection != null) {
        setState(() {
          _suggestedCategory = null;
          _detection = null;
          _suggestionDismissed = false;
        });
      }
      return;
    }

    final det = detectCategory(text);
    final detected = _categoryFromKey(det.category);
    setState(() {
      _detection = det;
      _detMethod = 'heuristic';
      if (detected != _suggestedCategory) {
        _suggestedCategory = detected;
        _suggestionDismissed = false; // a fresh guess re-opens the card
      }
    });

    // Debounced upgrade: ask the server's TRAINED classifier and, when it
    // answers, show its category + calibrated confidence + method label. The
    // on-device heuristic above stays as the instant, offline-safe fallback —
    // which also keeps the displayed confidence in sync with the server.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final result = await _api.classifyText(text);
        if (!mounted) return;
        final cat = result['category'] as String?;
        if (cat == null) return;
        final conf = (result['confidence'] as num?)?.toDouble() ?? det.confidence;
        final matched = (result['matched'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            det.matched;
        final mapped = _categoryFromKey(cat);
        setState(() {
          _detection = CategoryDetection(
            category: cat,
            confidence: conf.clamp(0.0, 1.0),
            scores: const {},
            matched: matched,
          );
          _detMethod = (result['method'] as String?) ?? 'heuristic';
          if (!_suggestionDismissed &&
              mapped != null &&
              mapped != _suggestedCategory) {
            _suggestedCategory = mapped;
          }
          // AI urgency: pre-fill from the Arabic severity detector unless the
          // user has already chosen an urgency themselves.
          final urg = _urgencyFromKey(result['urgency'] as String?);
          if (!_urgencyTouched && urg != null) {
            _selectedUrgency = urg;
          }
        });
      } catch (_) {
        // offline / mock — keep the instant on-device heuristic result.
      }
    });
  }

  // ── NLP: accept the suggestion → pre-select it as the chosen category and
  // optionally confirm with the backend classifier (best-effort, silent). ──
  Future<void> _acceptSuggestion(IssueCategory suggestion) async {
    setState(() {
      _selectedCategory = suggestion;
      _suggestionDismissed = true;
    });

    // Best-effort server confirmation: if the backend disagrees and is more
    // confident, adopt its category. Failures are ignored (offline / mock).
    try {
      final text =
          '${_titleController.text} ${_descriptionController.text}'.trim();
      if (text.isEmpty) return;
      final result = await _api.classifyText(text);
      final confirmed = _categoryFromKey(result['category'] as String?);
      if (confirmed != null && confirmed != suggestion && mounted) {
        setState(() => _selectedCategory = confirmed);
      }
    } catch (_) {
      // Local detection already applied — nothing more to do.
    }
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      _latitude = position.latitude;
      _longitude = position.longitude;
      final address = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (mounted) _addressController.text = address;
      if (mounted) setState(() => _isFetchingLocation = false);
    } else {
      // GPS unavailable — e.g. iOS Safari blocks geolocation over plain HTTP
      // (it needs HTTPS), or permission was denied. Fall back to the manual
      // map picker (drag the pin / type the address) which works everywhere.
      if (!mounted) return;
      setState(() => _isFetchingLocation = false);
      SfToast.show(
        context,
        tr(
          context,
          'تعذّر تحديد موقعك تلقائياً — حدّده على الخريطة أو اكتب العنوان.',
        ),
        tone: SfTone.warning,
      );
      await _openMapPicker();
    }
  }

  /// Opens the map picker (best-effort GPS + manual drag/address entry) and
  /// fills the address + coordinates from its result. This is the reliable path
  /// on the web PWA / iOS where direct geolocation is blocked over HTTP.
  Future<void> _openMapPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: _latitude,
          initialLng: _longitude,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        final lat = result['lat'];
        final lng = result['lng'];
        if (lat is num) _latitude = lat.toDouble();
        if (lng is num) _longitude = lng.toDouble();
        final addr = (result['address'] as String?)?.trim() ?? '';
        if (addr.isNotEmpty) _addressController.text = addr;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      SfToast.show(
        context,
        tr(context, 'يرجى اختيار التصنيف'),
        tone: SfTone.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final issue = Issue(
      id: const Uuid().v4(),
      customerId: user.uid,
      customerName: user.name,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory!,
      urgency: _selectedUrgency,
      latitude: _latitude ?? 0.0,
      longitude: _longitude ?? 0.0,
      address: _addressController.text.trim(),
    );

    try {
      await _jobService.createIssue(
        issue,
        customerEmail: user.email,
        customerPhone: user.phone,
      );

      // Learning hook: log the text + final labels to grow the training corpus
      // (fire-and-forget — never blocks or fails the report). `corrected` marks
      // the high-value rows where the customer overrode the AI's suggestion.
      String catKey(IssueCategory c) =>
          c == IssueCategory.applianceRepair ? 'appliance_repair' : c.name;
      _api.logTrainingSample(
        text:
            '${_titleController.text.trim()} ${_descriptionController.text.trim()}'
                .trim(),
        category: catKey(_selectedCategory!),
        urgency: _selectedUrgency.name,
        aiSuggestedCategory:
            _suggestedCategory == null ? '' : catKey(_suggestedCategory!),
        aiMethod: _detMethod,
        corrected: _suggestedCategory != null &&
            _suggestedCategory != _selectedCategory,
      ).catchError((_) {});

      if (mounted) {
        SfToast.show(
          context,
          tr(context, 'تم تقديم البلاغ بنجاح!'),
          tone: SfTone.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        SfToast.show(
          context,
          '${tr(context, 'خطأ')}: $e',
          tone: SfTone.error,
        );
      }
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  // ── wizard navigation (presentation only) ──────────────────────────
  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _selectedCategory != null;
      case 1:
        return _titleController.text.trim().isNotEmpty &&
            _descriptionController.text.trim().isNotEmpty;
      case 2:
        return true;
      case 3:
        return _addressController.text.trim().isNotEmpty;
      default:
        return false;
    }
  }

  void _onBack() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step -= 1);
    }
  }

  void _next() {
    FocusScope.of(context).unfocus();
    setState(() => _step += 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SfGradientHeader(
            title: tr(context, 'تقديم بلاغ'),
            showBack: true,
            onBack: _onBack,
            child: _ProgressBar(step: _step, total: _stepTitles.length),
          ),
          // The Form wraps ALL steps so the single _formKey still validates
          // every TextFormField at submit time, regardless of visible step.
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(22, 18, 22, 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  transitionBuilder:
                      (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                  layoutBuilder:
                      (currentChild, previousChildren) => Stack(
                        alignment: AlignmentDirectional.topStart,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      ),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    // Keep every field mounted across steps via Offstage so
                    // controllers/validators retain state; only the active
                    // step is laid out and interactive.
                    child: _buildStepBody(),
                  ),
                ),
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildStepBody() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── step heading ──
        Row(
          children: [
            Text(
              '${tr(context, 'الخطوة')} ${_step + 1} ${tr(context, 'من')} ${_stepTitles.length}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            Text(
              tr(context, _stepTitles[_step]),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Mount all step contents; show only the active one. This preserves
        // controller text & validator wiring across navigation.
        Offstage(offstage: _step != 0, child: _stepCategory()),
        Offstage(offstage: _step != 1, child: _stepDetails()),
        Offstage(offstage: _step != 2, child: _stepUrgency()),
        Offstage(offstage: _step != 3, child: _stepLocation()),
      ],
    );
  }

  TextStyle? get _hintStyle => Theme.of(context).textTheme.bodyMedium?.copyWith(
    height: 1.5,
    color: AppColors.midGrey,
  );

  // ── Step 0: Category ───────────────────────────────────────────────
  Widget _stepCategory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, 'ما نوع المشكلة التي تريد الإبلاغ عنها؟'),
          style: _hintStyle,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              IssueCategory.values.map((cat) {
                return SfCategoryChip(
                  category: cat,
                  selected: _selectedCategory == cat,
                  onTap: () => setState(() => _selectedCategory = cat),
                );
              }).toList(),
        ).animate().fadeIn(duration: 350.ms),
      ],
    );
  }

  // ── Step 1: Details ────────────────────────────────────────────────
  Widget _stepDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, 'اكتب عنوانًا مختصرًا واشرح المشكلة.'),
          style: _hintStyle,
        ),
        const SizedBox(height: 16),
        SmartTextField(
          label: tr(context, 'العنوان'),
          hint: tr(context, 'مثال: تسريب في حنفية المطبخ'),
          controller: _titleController,
          prefixIcon: Icons.title_rounded,
          onChanged: (_) {
            setState(() {});
            _runDetection();
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return tr(context, 'يرجى إدخال عنوان');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        SmartTextField(
          label: tr(context, 'الوصف'),
          // Per-category example so each trade gets a relevant prompt.
          hint: categoryDescriptionHint(_selectedCategoryKey, _localeIsEn(context)),
          controller: _descriptionController,
          maxLines: 4,
          prefixIcon: Icons.description_outlined,
          onChanged: (_) {
            setState(() {});
            _runDetection();
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return tr(context, 'يرجى وصف المشكلة');
            }
            return null;
          },
        ),
        _buildAiTriage(),
      ],
    );
  }

  // ── "🤖 التحليل الذكي" — prominent AI Triage card shown beneath the details.
  // Surfaces the local heuristic BASELINE: detected category + confidence +
  // matched keywords. Tapping the category pre-selects it. ─────────────────
  Widget _buildAiTriage() {
    final det = _detection;
    final suggestion = _suggestedCategory;
    // Show only once the detector has something to say.
    if (det == null || suggestion == null || _suggestionDismissed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cfg = sfCategory(suggestion);
    final confidencePct = (det.confidence.clamp(0.0, 1.0) * 100).round();
    final isApplied = suggestion == _selectedCategory;
    // Confidence tone: green ≥66%, amber ≥33%, grey below.
    final Color confColor = det.confidence >= 0.66
        ? AppColors.success
        : det.confidence >= 0.33
            ? AppColors.warning
            : AppColors.midGrey;
    // De-duplicate matched keywords, cap the displayed set.
    final matched = det.matched.toSet().take(6).toList();

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              AppColors.primary.withValues(alpha: 0.10),
              AppColors.primary.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── header: robot + title + "أساس استرشادي" baseline pill ──
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.smart_toy_outlined,
                      size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    tr(context, 'التحليل الذكي للبلاغ'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    _detMethod != 'heuristic'
                        ? tr(context, 'نموذج مُدرَّب')
                        : tr(context, 'أساس استرشادي'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _detMethod != 'heuristic'
                          ? AppColors.primary
                          : AppColors.midGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            // ── detected category (tap to select) ──
            GestureDetector(
              onTap: isApplied ? null : () => _acceptSuggestion(suggestion),
              child: Row(
                children: [
                  Icon(cfg.icon, size: 20, color: cfg.color),
                  const SizedBox(width: 8),
                  Text(
                    cfg.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cfg.color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isApplied)
                    Row(
                      children: [
                        Icon(Icons.check_circle,
                            size: 15, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          tr(context, 'مُطبّق'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      tr(context, '— اضغط للاختيار'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.midGrey),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── confidence bar ──
            Row(
              children: [
                Text(
                  tr(context, 'الثقة'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.darkGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: det.confidence.clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: AppColors.line,
                      valueColor: AlwaysStoppedAnimation<Color>(confColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$confidencePct%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: confColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            // ── matched keywords ──
            if (matched.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                tr(context, 'الكلمات المطابقة'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.midGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: matched
                    .map((kw) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Text(
                            kw,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.darkGrey,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              tr(context,
                  'تصنيف مبدئي بنموذج الكلمات المفتاحية — مقاييس النموذج الكامل في لوحة التحكم.'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.midGrey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms),
    );
  }

  // ── Step 2: Urgency ────────────────────────────────────────────────
  Widget _stepUrgency() {
    const colors = {
      IssueUrgency.low: AppColors.success,
      IssueUrgency.medium: AppColors.warning,
      IssueUrgency.high: AppColors.error,
      IssueUrgency.emergency: Color(0xFFB71C1C),
    };
    const labels = {
      IssueUrgency.low: 'منخفضة',
      IssueUrgency.medium: 'متوسطة',
      IssueUrgency.high: 'عالية',
      IssueUrgency.emergency: 'طارئة',
    };
    const blurbs = {
      IssueUrgency.low: 'يمكن الانتظار — لا داعي للعجلة',
      IssueUrgency.medium: 'يُفضّل معالجتها قريبًا',
      IssueUrgency.high: 'تحتاج اهتمامًا اليوم',
      IssueUrgency.emergency: 'خطر على السلامة — تصرّف الآن',
    };
    const icons = {
      IssueUrgency.low: Icons.check_circle_outline,
      IssueUrgency.medium: Icons.info_outline,
      IssueUrgency.high: Icons.warning_amber_rounded,
      IssueUrgency.emergency: Icons.emergency,
    };

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, 'ما مدى إلحاح هذه المشكلة؟'),
          style: _hintStyle,
        ),
        const SizedBox(height: 16),
        ...IssueUrgency.values.map((urgency) {
          final isSelected = _selectedUrgency == urgency;
          final color = colors[urgency]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedUrgency = urgency;
                _urgencyTouched = true;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? Color.alphaBlend(
                            color.withValues(alpha: 0.10),
                            AppColors.surface,
                          )
                          : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : AppColors.line,
                    width: 1.5,
                  ),
                  boxShadow:
                      isSelected
                          ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.30),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ]
                          : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icons[urgency], size: 22, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, labels[urgency]!),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            tr(context, blurbs[urgency]!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.midGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? color : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? color : AppColors.line,
                          width: 2,
                        ),
                      ),
                      child:
                          isSelected
                              ? const Icon(
                                Icons.check,
                                size: 13,
                                color: AppColors.white,
                              )
                              : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Step 3: Location ───────────────────────────────────────────────
  Widget _stepLocation() {
    final categoryLabel =
        _selectedCategory != null
            ? sfCategory(_selectedCategory!).label
            : tr(context, 'الخدمة');
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, 'أين تقع المشكلة؟'),
          style: _hintStyle,
        ),
        const SizedBox(height: 16),
        SmartButton(
          label:
              _isFetchingLocation
                  ? tr(context, 'جارٍ تحديد الموقع…')
                  : tr(context, 'استخدم موقعي الحالي'),
          icon: Icons.my_location,
          isOutlined: true,
          isLoading: _isFetchingLocation,
          width: double.infinity,
          onPressed: _fetchCurrentLocation,
        ),
        const SizedBox(height: 10),
        SmartButton(
          label: tr(context, 'حدّد على الخريطة'),
          icon: Icons.map_outlined,
          isOutlined: true,
          width: double.infinity,
          onPressed: _isFetchingLocation ? null : _openMapPicker,
        ),
        const SizedBox(height: 14),
        SmartTextField(
          label: tr(context, 'العنوان'),
          hint: tr(context, 'الشارع، الحي، المدينة'),
          controller: _addressController,
          prefixIcon: sfIcon('map-pin'),
          onChanged: (_) => setState(() {}),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return tr(context, 'يرجى إدخال الموقع');
            }
            return null;
          },
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(sfIcon('info'), size: 18, color: AppColors.primary),
              const SizedBox(width: 11),
              Expanded(
                child: RichText(
                  textDirection: Directionality.of(context),
                  text: TextSpan(
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.6,
                      color: AppColors.darkGrey,
                    ),
                    children: [
                      TextSpan(
                        text: '${tr(context, 'سيتم مطابقتك مع فني موثّق متخصص في')} ',
                      ),
                      TextSpan(
                        text: categoryLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.6,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                      TextSpan(
                        text: ' ${tr(context, 'بالقرب منك.')}',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── sticky footer: Continue / Submit ───────────────────────────────
  Widget _buildFooter() {
    final isLast = _step == _stepTitles.length - 1;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(22, 12, 22, 16),
          child:
              isLast
                  ? SmartButton(
                    label: tr(context, 'إرسال البلاغ'),
                    icon: sfIcon('send'),
                    isLoading: _isSubmitting,
                    width: double.infinity,
                    onPressed: _canAdvance ? _submit : null,
                  )
                  : SmartButton(
                    label: tr(context, 'متابعة'),
                    icon: sfIcon('arrow-left'),
                    width: double.infinity,
                    onPressed: _canAdvance ? _next : null,
                  ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;

  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final filled = i <= step;
        return Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              end: i == total - 1 ? 0 : 6,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 5,
              decoration: BoxDecoration(
                color:
                    filled
                        ? AppColors.white
                        : AppColors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}
