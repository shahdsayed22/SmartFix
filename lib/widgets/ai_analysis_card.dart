import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../l10n/app_strings.dart';
import '../models/issue_model.dart';
import 'sf_icons.dart';
import 'sf_cards.dart';

/// "🤖 تحليل الذكاء الاصطناعي" — shared issue-detail panel surfacing the triage
/// workflow's heuristic/anomaly BASELINE: suggested category, classifier
/// confidence, and urgency/anomaly scores. Used by the customer issue-detail
/// and the worker job-detail screens.
///
/// This is deliberately framed as the keyword/anomaly baseline — the trained
/// ensemble metrics live on the dashboard's AI Insights page, not here.
/// Renders nothing until the workflow has produced any AI signal.
class AiAnalysisCard extends StatelessWidget {
  final Issue issue;

  const AiAnalysisCard({super.key, required this.issue});

  IssueCategory? _categoryFromKey(String? key) {
    if (key == null || key.isEmpty) return null;
    if (key == 'appliance_repair') return IssueCategory.applianceRepair;
    for (final c in IssueCategory.values) {
      if (c.name == key) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!issue.hasAiTriage) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final suggested = _categoryFromKey(issue.aiSuggestedCategory);

    final rows = <Widget>[];

    // Suggested category.
    if (suggested != null) {
      final cfg = sfCategory(suggested);
      rows.add(Row(
        children: [
          Text(
            tr(context, 'الفئة المقترحة'),
            style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.darkGrey, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Icon(cfg.icon, size: 17, color: cfg.color),
          const SizedBox(width: 6),
          Text(
            tr(context, cfg.label),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cfg.color, fontWeight: FontWeight.w700),
          ),
        ],
      ));
    }

    // Classifier method + confidence.
    if (issue.aiMethod != null || issue.aiConfidence != null) {
      final method = issue.aiMethod == 'heuristic'
          ? tr(context, 'كلمات مفتاحية')
          : (issue.aiMethod ?? '—');
      final conf = issue.aiConfidence != null
          ? '${(issue.aiConfidence!.clamp(0.0, 1.0) * 100).round()}%'
          : null;
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Text(
              tr(context, 'الطريقة'),
              style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.darkGrey, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              conf != null ? '$method · $conf' : method,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.charcoal, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ));
    }

    // Urgency score.
    if (issue.aiUrgencyScore != null) {
      rows.add(_ScoreBar(
        label: tr(context, 'درجة الأولوية'),
        value: issue.aiUrgencyScore!.clamp(0.0, 1.0),
        color: AppColors.warning,
      ));
    }
    // Anomaly score.
    if (issue.aiAnomalyScore != null) {
      rows.add(_ScoreBar(
        label: tr(context, 'درجة الانحراف'),
        value: issue.aiAnomalyScore!.clamp(0.0, 1.0),
        color: AppColors.error,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SfSectionCard(
          icon: Icons.smart_toy_outlined,
          title: tr(context, 'تحليل الذكاء الاصطناعي'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...rows,
              const SizedBox(height: 10),
              Text(
                tr(context,
                    'أساس استرشادي (كلمات مفتاحية + كشف الشذوذ). مقاييس النموذج المُدرَّب في لوحة التحكم.'),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppColors.midGrey, height: 1.4),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),
        const SizedBox(height: 14),
      ],
    );
  }
}

/// A labelled 0..1 score bar used inside [AiAnalysisCard].
class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ScoreBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.darkGrey, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${(value * 100).round()}%',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 7,
              backgroundColor: AppColors.line,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
