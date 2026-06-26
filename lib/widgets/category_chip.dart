import 'package:flutter/material.dart';
import '../models/issue_model.dart';
import 'sf_cat_tile.dart';

/// Selectable category chip.
///
/// Restyled to the new design by delegating to [SfCategoryChip], while
/// preserving the existing public API (`CategoryChip({category, isSelected,
/// onTap})`) used by the report-issue flow.
class CategoryChip extends StatelessWidget {
  final IssueCategory category;
  final bool isSelected;
  final VoidCallback? onTap;

  const CategoryChip({
    super.key,
    required this.category,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SfCategoryChip(
      category: category,
      selected: isSelected,
      onTap: onTap,
    );
  }
}
