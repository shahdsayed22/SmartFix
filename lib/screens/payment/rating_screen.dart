import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/issue_model.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_avatar.dart';
import '../../widgets/sf_stars.dart';
import '../../widgets/smart_text_field.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/sf_feedback.dart';
import '../../widgets/verified_badge.dart';

/// Suggested review tags — mirrors the prototype's `REVIEW_TAGS`.
const List<String> _kReviewTags = [
  'ملتزم بالموعد',
  'محترف',
  'سعر عادل',
  'نظيف ومرتّب',
  'شرح المشكلة',
  'سريع',
];

/// Star labels (index = star count, 1..5). Empty at index 0.
const List<String> _kStarLabels = [
  '',
  'سيئ',
  'مقبول',
  'جيد',
  'جيد جدًا',
  'ممتاز',
];

/// RatingScreen — customer rates the technician after a completed job.
///
/// Star input + suggested tag chips + optional comment, submitted through
/// [ApiService.createReview]. The server enforces one review per `issueId`;
/// a 409 ("already rated") is handled gracefully with a toast.
class RatingScreen extends StatefulWidget {
  final Issue issue;

  const RatingScreen({super.key, required this.issue});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _commentCtrl = TextEditingController();

  int _stars = 5;
  final Set<String> _tags = <String>{};
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _api.dispose();
    super.dispose();
  }

  /// Map the issue's category enum to its API key (snake_case where needed),
  /// matching the convention used elsewhere for the backend.
  String get _categoryKey {
    if (widget.issue.category == IssueCategory.applianceRepair) {
      return 'appliance_repair';
    }
    return widget.issue.category.name;
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_tags.contains(tag)) {
        _tags.remove(tag);
      } else {
        _tags.add(tag);
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final currentUser = context.read<AuthService>().currentUser;
    if (currentUser == null) {
      SfToast.show(
        context,
        tr(context, 'يجب تسجيل الدخول لإرسال التقييم'),
        tone: SfTone.error,
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await _api.createReview({
        'issueId': widget.issue.id,
        'technicianId': widget.issue.assignedWorkerId ?? '',
        'technicianName': widget.issue.assignedWorkerName ?? '',
        'customerId': currentUser.uid,
        'customerName': currentUser.name,
        'rating': _stars,
        'tags': _tags.toList(),
        'comment': _commentCtrl.text.trim(),
        'category': _categoryKey,
      });

      if (!mounted) return;
      SfToast.show(
        context,
        tr(context, 'شكرًا على تقييمك!'),
        tone: SfTone.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      // Server returns 409 when a review already exists for this issue.
      if (msg.contains('already exists')) {
        SfToast.show(
          context,
          tr(context, 'لقد قمت بتقييم هذه الخدمة من قبل'),
          tone: SfTone.warning,
        );
        Navigator.of(context).pop(false);
      } else {
        SfToast.show(
          context,
          tr(context, 'تعذّر إرسال التقييم، حاول مرة أخرى'),
          tone: SfTone.error,
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final techName = (issue.assignedWorkerName ?? '').trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SfGradientHeader(
            title: tr(context, 'تقييم الخدمة'),
            showBack: true,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
              children: [
                // ── Technician identity ──────────────────────────────
                Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SfAvatar(
                          name: techName.isNotEmpty ? techName : '؟',
                          size: 88,
                          ring: true,
                        ),
                        const PositionedDirectional(
                          start: 0,
                          bottom: 0,
                          child: VerifiedBadge(isVerified: true, size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      techName.isNotEmpty
                          ? techName
                          : tr(context, 'الفنّي'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      issue.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13.5,
                        color: AppColors.midGrey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                // ── Star input ───────────────────────────────────────
                Text(
                  tr(context, 'كيف كانت الخدمة؟'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: SfStarInput(
                    value: _stars,
                    onChanged: (v) => setState(() => _stars = v),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 18,
                  child: Text(
                    tr(context, _kStarLabels[_stars]),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.goldDeep,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Tag chips ────────────────────────────────────────
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    tr(context, 'ما الذي أعجبك؟'),
                    textAlign: TextAlign.start,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: _kReviewTags.map((tag) {
                    final on = _tags.contains(tag);
                    return _TagChip(
                      label: tr(context, tag),
                      selected: on,
                      onTap: () => _toggleTag(tag),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 22),

                // ── Optional comment ─────────────────────────────────
                SmartTextField(
                  label: tr(context, 'أضف تعليقًا (اختياري)'),
                  hint: tr(context, 'شاركنا تجربتك مع الفني…'),
                  controller: _commentCtrl,
                  prefixIcon: Icons.chat_bubble_outline,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                ),
              ],
            ),
          ),

          // ── Submit bar ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.lineSoft, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SmartButton(
                label: tr(context, 'إرسال التقييم'),
                icon: Icons.send,
                isLoading: _submitting,
                width: double.infinity,
                onPressed: _submit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped selectable tag chip matching the prototype's review tags.
class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.navySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.line,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.navy : AppColors.darkGrey,
          ),
        ),
      ),
    );
  }
}
