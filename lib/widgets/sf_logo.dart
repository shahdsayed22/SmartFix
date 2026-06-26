import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// SmartFix brand mark — a gold wrench centered in a navy→teal gradient
/// circle, with an optional dashed inner ring. Used on splash, login, and
/// profile headers.
class SfLogoMark extends StatelessWidget {
  final double size;

  /// When true draws the subtle dashed inner ring.
  final bool ring;

  const SfLogoMark({super.key, this.size = 64, this.ring = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.teal],
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 28,
            spreadRadius: -10,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (ring)
            Padding(
              padding: EdgeInsets.all(size * 0.13),
              child: CustomPaint(
                size: Size.square(size * 0.74),
                painter: _DashedRingPainter(
                  strokeWidth: (size * 0.02).clamp(1.5, 4.0),
                ),
              ),
            ),
          Icon(Icons.build, size: size * 0.44, color: AppColors.gold),
        ],
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  final double strokeWidth;

  _DashedRingPainter({required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.white.withValues(alpha: 0.32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const dashCount = 28;
    const sweep = 0.42; // radians filled per dash gap unit
    final step = (2 * 3.141592653589793) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      final start = i * step;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        step * sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth;
}
