import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Read-only 5-star rating display — mirrors the prototype's `Stars`.
///
/// Always laid out left-to-right (stars read the same in both languages).
/// Filled stars use gold; empty stars use the hairline [AppColors.line].
class SfStars extends StatelessWidget {
  final double value;
  final double size;
  final double gap;

  const SfStars({super.key, this.value = 0, this.size = 14, this.gap = 2});

  @override
  Widget build(BuildContext context) {
    final filled = value.round();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final on = (i + 1) <= filled;
          return Padding(
            padding: EdgeInsets.only(right: i < 4 ? gap : 0),
            child: Icon(
              on ? Icons.star : Icons.star_border,
              size: size,
              color: on ? AppColors.gold : AppColors.line,
            ),
          );
        }),
      ),
    );
  }
}

/// Interactive 5-star input — mirrors the prototype's `StarInput`.
///
/// Calls [onChanged] with the tapped value (1–5). Laid out left-to-right.
class SfStarInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const SfStarInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final star = i + 1;
          final on = star <= value;
          return Padding(
            padding: EdgeInsets.only(right: i < 4 ? 10 : 0),
            child: GestureDetector(
              onTap: () => onChanged(star),
              child: Icon(
                on ? Icons.star : Icons.star_border,
                size: size,
                color: on ? AppColors.gold : AppColors.line,
              ),
            ),
          );
        }),
      ),
    );
  }
}
