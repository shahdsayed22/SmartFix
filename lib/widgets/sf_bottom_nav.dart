import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// One entry in [SfBottomNav]. [key] is the value reported to `onChange`;
/// [label] is shown beneath the [icon].
class SfNavItem {
  final String key;
  final String label;
  final IconData icon;

  const SfNavItem({required this.key, required this.label, required this.icon});
}

/// Bottom navigation bar with a pill-highlight behind the active item's
/// icon. White surface, hairline top border, soft upward navy shadow.
/// Includes bottom safe-area padding for gesture-nav devices.
class SfBottomNav extends StatelessWidget {
  final List<SfNavItem> items;
  final String activeKey;
  final ValueChanged<String> onChange;

  const SfBottomNav({
    super.key,
    required this.items,
    required this.activeKey,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 20,
            spreadRadius: -12,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children:
                items.map((it) {
                  final on = it.key == activeKey;
                  final color = on ? AppColors.navy : AppColors.midGrey;
                  return Expanded(
                    child: InkWell(
                      onTap: () => onChange(it.key),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    on
                                        ? AppColors.navySoft
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Icon(it.icon, size: 22, color: color),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              it.label,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                fontWeight:
                                    on ? FontWeight.w600 : FontWeight.w500,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }
}
