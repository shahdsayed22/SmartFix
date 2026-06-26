import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/issue_model.dart';
import 'sf_cards.dart';

/// Issue summary card.
///
/// Restyled to the new design by delegating to [SfIssueCard], while keeping
/// the existing public API (`SmartCard({issue, onTap})`) so every screen
/// that already passes an [Issue] keeps working unchanged.
class SmartCard extends StatelessWidget {
  final Issue issue;
  final VoidCallback? onTap;

  const SmartCard({super.key, required this.issue, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SfIssueCard(
      title: issue.title,
      categoryName: issue.category,
      urgency: issue.urgency,
      status: issue.status,
      description: issue.description,
      address: issue.address,
      timeAgo: timeago.format(issue.createdAt),
      onTap: onTap,
    );
  }
}
