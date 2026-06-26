import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../models/issue_model.dart';

/// Internal description of one timeline step.
class _Step {
  final String title;
  final String sub;
  final Color color;
  const _Step(this.title, this.sub, this.color);
}

/// Vertical 4-step progress timeline (Reported → Assigned → In Progress →
/// Completed). Steps up to and including [currentStatus] render as "done"
/// (filled dot with a check + colored connector); later steps render muted.
///
/// A `cancelled` status is treated like `pending` for positioning.
class SfTimeline extends StatelessWidget {
  final IssueStatus currentStatus;

  /// Optional technician name shown under the "Assigned" step.
  final String? assignedName;

  /// Pre-formatted relative time the issue was reported (under step 1).
  final String? reportedAgo;

  /// Pre-formatted relative time of the last update (under "Completed").
  final String? updatedAgo;

  const SfTimeline(
    this.currentStatus, {
    super.key,
    this.assignedName,
    this.reportedAgo,
    this.updatedAgo,
  });

  @override
  Widget build(BuildContext context) {
    final steps = <_Step>[
      _Step('تم استلام البلاغ', reportedAgo ?? '', AppColors.navy),
      _Step('تم تعيين فني', assignedName ?? '', AppColors.info),
      _Step('العمل جارٍ', 'الفني في الموقع', AppColors.secondary),
      _Step('مكتمل', updatedAgo ?? '', AppColors.success),
    ];

    const order = [
      IssueStatus.pending,
      IssueStatus.assigned,
      IssueStatus.inProgress,
      IssueStatus.completed,
    ];
    final effective =
        currentStatus == IssueStatus.cancelled
            ? IssueStatus.pending
            : currentStatus;
    final curIdx = order.indexOf(effective);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final done = i <= curIdx;
        final active = i == curIdx;
        final isLast = i == steps.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: done ? step.color : AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done ? step.color : AppColors.line,
                        width: 2,
                      ),
                      boxShadow:
                          active
                              ? [
                                BoxShadow(
                                  color: step.color.withValues(alpha: 0.13),
                                  blurRadius: 0,
                                  spreadRadius: 4,
                                ),
                              ]
                              : null,
                    ),
                    child:
                        done
                            ? const Icon(
                              Icons.check,
                              size: 10,
                              color: AppColors.white,
                            )
                            : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        constraints: const BoxConstraints(minHeight: 26),
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color:
                            i < curIdx
                                ? step.color.withValues(alpha: 0.4)
                                : AppColors.line,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, step.title),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: done ? AppColors.charcoal : AppColors.midGrey,
                        ),
                      ),
                      if (done && step.sub.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          tr(context, step.sub),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            color: AppColors.midGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
