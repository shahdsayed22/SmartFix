import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'locale_provider.dart';
import 'strings_ar_en.dart';

/// Tiny Arabic-first translation helper (mirrors the design's `t()`).
///
/// Arabic is the source of truth: pass the Arabic string and it is returned
/// as-is by default. When the active [LocaleProvider] is English, the Arabic
/// key is looked up in [kEnDict]; if missing, the Arabic falls through safely.
///
/// Usage:
///   Text(tr(context, 'تسجيل الدخول'))
///   Text(trOf(isEn, 'تسجيل الدخول'))

/// Returns [ar] in Arabic mode, or its English translation in English mode.
String trOf(bool isEn, String ar) {
  if (!isEn) return ar;
  return kEnDict[ar] ?? ar;
}

/// Reads `isEn` from the nearest [LocaleProvider], defaulting to Arabic (false)
/// when no provider is in scope (e.g. isolated tests / previews).
bool _isEnglish(BuildContext context) {
  try {
    return Provider.of<LocaleProvider>(context, listen: false).isEn;
  } catch (_) {
    return false;
  }
}

/// Context-aware translation: reads [LocaleProvider] from the widget tree.
///
/// Falls back to Arabic when no provider is available (e.g. in isolated tests).
String tr(BuildContext context, String ar) => trOf(_isEnglish(context), ar);

/// Sugar for `tr(context, ar)` so call sites can read `context.tr('...')`.
extension TrExtension on BuildContext {
  String tr(String ar) => trOf(_isEnglish(this), ar);
}
