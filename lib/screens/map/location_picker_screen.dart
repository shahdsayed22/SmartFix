import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_icons.dart';
import '../../widgets/smart_button.dart';

/// Location picker with a styled (non-Google-tile) backdrop.
///
/// GPS is best-effort: it tries the device location + reverse-geocoding, but
/// always falls back to manual selection so it works everywhere — including the
/// web PWA over plain HTTP, where the browser blocks geolocation (it needs a
/// secure HTTPS/localhost context). In the manual case the user can drag the
/// pin and/or type an address; the result returns { lat, lng, address }.
class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // Default fallback center (Cairo) used when GPS is unavailable.
  static const double _kDefaultLat = 30.0444;
  static const double _kDefaultLng = 31.2357;

  double _selectedLat = 0;
  double _selectedLng = 0;
  final TextEditingController _addrCtrl = TextEditingController();

  bool _loading = true;
  bool _hasFix = false; // true once we have usable coords (GPS or fallback)
  String? _hint; // soft, non-blocking note (e.g. GPS unavailable)

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLat = widget.initialLat!;
      _selectedLng = widget.initialLng!;
      _hasFix = true;
      _reverseGeocode();
    } else {
      _locate();
    }
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    super.dispose();
  }

  /// Best-effort GPS. On any failure (denied / disabled / web-insecure / hang)
  /// we drop into manual mode instead of a dead-end error.
  Future<void> _locate() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _hint = null;
      });
    }
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _manualFallback('خدمة الموقع غير مُفعّلة — اسحب الدبوس أو اكتب عنوانك.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _manualFallback('تعذّر الحصول على إذن الموقع — اسحب الدبوس أو اكتب عنوانك.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      setState(() {
        _selectedLat = pos.latitude;
        _selectedLng = pos.longitude;
        _hasFix = true;
        _hint = null;
      });
      await _reverseGeocode();
    } catch (_) {
      _manualFallback('تعذّر تحديد موقعك تلقائياً — اسحب الدبوس أو اكتب عنوانك.');
    }
  }

  void _manualFallback(String hint) {
    if (!mounted) return;
    setState(() {
      if (!_hasFix) {
        _selectedLat = widget.initialLat ?? _kDefaultLat;
        _selectedLng = widget.initialLng ?? _kDefaultLng;
        _hasFix = true;
      }
      _loading = false;
      _hint = hint;
    });
  }

  /// Reverse-geocode current coords into an address (best-effort; on web this
  /// often isn't supported, so we just leave the field for manual entry).
  Future<void> _reverseGeocode() async {
    try {
      final placemarks = await placemarkFromCoordinates(
        _selectedLat,
        _selectedLng,
      );
      String addr = '';
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
          if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
          if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
          if ((p.administrativeArea ?? '').trim().isNotEmpty)
            p.administrativeArea!.trim(),
          if ((p.country ?? '').trim().isNotEmpty) p.country!.trim(),
        ];
        addr = parts.join('، ');
      }
      if (!mounted) return;
      setState(() {
        if (addr.isNotEmpty) _addrCtrl.text = addr;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Drag-to-nudge the pin over the styled backdrop (no real tiles to align to,
  /// so this is approximate — ~2 m per logical pixel).
  void _nudge(Offset delta) {
    if (!_hasFix) return;
    const perPixel = 0.00002;
    setState(() {
      _selectedLat -= delta.dy * perPixel;
      _selectedLng += delta.dx * perPixel;
    });
  }

  void _confirm() {
    Navigator.pop(context, {
      'lat': _selectedLat,
      'lng': _selectedLng,
      'address': _addrCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.surfaceVariant,
        body: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => _nudge(d.delta),
              child: const _MapBackdrop(),
            ),
            const _CenterPin(),

            if (_loading)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.92),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.navy),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr(context, 'جارٍ تحديد موقعك...'),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.charcoal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Top bar (back + title)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                child: Row(
                  children: [
                    _RoundIconButton(
                      icon: sfIcon('arrow-right'),
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        padding:
                            const EdgeInsetsDirectional.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppColors.rField),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.cardShadow,
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(sfIcon('map-pin'),
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                tr(context, 'تحديد الموقع'),
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.charcoal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom card: address entry + coords + actions
            Positioned(
              left: 14,
              right: 14,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppColors.rCard),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.navyShadow,
                          blurRadius: 34,
                          spreadRadius: -10,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4.5,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: AppColors.line,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        Text(
                          tr(context, 'الموقع المحدد'),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                        ),
                        if (_hint != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            tr(context, _hint!),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11.5,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextField(
                          controller: _addrCtrl,
                          textDirection: TextDirection.rtl,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 14,
                            color: AppColors.charcoal,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: tr(
                              context,
                              'اكتب عنوانك أو اسحب الدبوس على الخريطة',
                            ),
                            hintStyle: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12.5,
                              color: AppColors.midGrey,
                            ),
                            prefixIcon: Icon(sfIcon('map-pin'),
                                size: 18, color: AppColors.teal),
                            filled: true,
                            fillColor: AppColors.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(sfIcon('map'),
                                size: 15, color: AppColors.darkGrey),
                            const SizedBox(width: 8),
                            Text(
                              '${_selectedLat.toStringAsFixed(4)}, ${_selectedLng.toStringAsFixed(4)}',
                              textDirection: TextDirection.ltr,
                              style: GoogleFonts.robotoMono(
                                fontSize: 12.5,
                                color: AppColors.darkGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _loading ? null : _locate,
                              icon: Icon(Icons.my_location,
                                  size: 16, color: AppColors.primary),
                              label: Text(
                                tr(context, 'موقعي'),
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SmartButton(
                          label: tr(context, 'تأكيد هذا الموقع'),
                          icon: sfIcon('check'),
                          width: double.infinity,
                          onPressed: (_hasFix && !_loading) ? _confirm : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft navy-tinted "map" backdrop with a faint grid and brand watermark.
class _MapBackdrop extends StatelessWidget {
  const _MapBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceVariant,
            AppColors.lineSoft,
            AppColors.surfaceVariant,
          ],
        ),
      ),
      child: CustomPaint(
        painter: _GridPainter(),
        size: Size.infinite,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: Opacity(
              opacity: 0.35,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(sfIcon('map'), size: 56, color: AppColors.navy),
                  const SizedBox(height: 10),
                  Text(
                    tr(context, 'اسحب لتحديد الموقع'),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Centered location pin with a soft halo, matching the navy/teal brand.
class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.navy,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.navyShadow,
                    blurRadius: 16,
                    spreadRadius: -2,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(sfIcon('map-pin'), color: AppColors.white, size: 24),
            ),
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.rField),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.charcoal),
      ),
    );
  }
}
