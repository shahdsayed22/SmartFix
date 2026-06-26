import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import 'sf_icons.dart';

/// Opens the multi-skill picker as a modal bottom sheet and resolves to the
/// chosen list of category keys, or `null` if the worker dismissed it without
/// saving. Selection is multi-select — a worker can have any number of skills.
Future<List<String>?> showSkillsPicker(
  BuildContext context, {
  required List<String> initial,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SkillsPickerSheet(initial: initial),
  );
}

class _SkillsPickerSheet extends StatefulWidget {
  const _SkillsPickerSheet({required this.initial});

  final List<String> initial;

  @override
  State<_SkillsPickerSheet> createState() => _SkillsPickerSheetState();
}

class _SkillsPickerSheetState extends State<_SkillsPickerSheet> {
  late final Set<String> _selected = {...widget.initial};

  void _toggle(String key) {
    setState(() {
      if (!_selected.add(key)) _selected.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            // Drag handle.
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, 'مهاراتك'),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(context, 'اختر المهارات التي تتقنها'),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.charcoal.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                shrinkWrap: true,
                itemCount: kSfCategoryOrder.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 18, color: AppColors.lineSoft),
                itemBuilder: (_, i) => _row(kSfCategoryOrder[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        tr(context, 'إلغاء'),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_selected.toList()),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        tr(context, 'حفظ'),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String key) {
    final cfg = sfCategory(key);
    final on = _selected.contains(key);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _toggle(key),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cfg.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(cfg.icon, size: 21, color: cfg.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              cfg.label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: on,
            activeThumbColor: AppColors.white,
            activeTrackColor: cfg.color,
            inactiveThumbColor: AppColors.white,
            inactiveTrackColor: AppColors.line,
            onChanged: (_) => _toggle(key),
          ),
        ],
      ),
    );
  }
}
