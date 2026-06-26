import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/smart_button.dart';
import 'login_screen.dart';

/// A single value-proposition slide shown in the onboarding carousel.
class _OnboardSlide {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _OnboardSlide({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

/// Static design content for the onboarding pages.
// NOTE: static design data, ready for backend wiring
const List<_OnboardSlide> _kOnboardSlides = [
  _OnboardSlide(
    icon: Icons.search_rounded,
    color: AppColors.primary,
    title: 'اطلب أي خدمة منزلية',
    body: 'سباكة، كهرباء، تكييف، تنظيف والمزيد — فنيون موثوقون بضغطة زر.',
  ),
  _OnboardSlide(
    icon: Icons.groups_rounded,
    color: AppColors.teal,
    title: 'قارن العروض واختر الأنسب',
    body: 'تصلك عروض من عدة فنيين، قارن الأسعار والتقييمات واختر بثقة.',
  ),
  _OnboardSlide(
    icon: Icons.verified_user_rounded,
    color: AppColors.goldDeep,
    title: 'ادفع بأمان وتابع لحظيًا',
    body: 'دفع آمن عبر ماي فاتورة، تتبّع الفني مباشرة، وضمان لجودة العمل.',
  ),
];

/// Value-proposition onboarding carousel shown once after the splash screen
/// and before login. A swipeable [PageView] of icon/title/subtitle pages with
/// a dots indicator, a skip action, and a primary next / get-started CTA.
///
/// Pure UI — no network. Launched from the splash screen on first run.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _kOnboardSlides.length - 1;

  void _onNext() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _kOnboardSlides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _slide(_kOnboardSlides[i]),
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 14, 22, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: _finish,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                tr(context, 'تخطّي'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.midGrey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slide(_OnboardSlide s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _DashedRingPainter(
                      color: s.color.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Icon(s.icon, size: 62, color: s.color),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text(
            tr(context, s.title),
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              tr(context, s.body),
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                height: 1.7,
                color: AppColors.midGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(30, 0, 30, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_kOnboardSlides.length, (k) {
              final active = k == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 7,
                width: active ? 26 : 7,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
          const SizedBox(height: 26),
          SmartButton(
            label: _isLast ? tr(context, 'ابدأ الآن') : tr(context, 'التالي'),
            icon: _isLast ? Icons.arrow_back_rounded : null,
            width: double.infinity,
            onPressed: _onNext,
          ),
        ],
      ),
    );
  }
}

/// Paints the dashed inner ring around the onboarding slide icon,
/// matching the design's `2px dashed` circular border.
class _DashedRingPainter extends CustomPainter {
  final Color color;

  const _DashedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 2) / 2;

    const dash = 5.0;
    const gap = 6.0;
    final circumference = 2 * math.pi * radius;
    final step = (dash + gap) / radius;
    final dashSweep = dash / radius;
    final count = (circumference / (dash + gap)).floor();

    for (var k = 0; k < count; k++) {
      final start = k * step;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
