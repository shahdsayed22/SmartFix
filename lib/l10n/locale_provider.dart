import 'package:flutter/material.dart';

/// Holds the app locale (Arabic-first). Drives RTL/LTR + the [tr] helper.
///
/// Default is Arabic (`ar`); flip to English (`en`) via [toggle]/[setLocale].
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('ar');

  Locale get locale => _locale;

  /// True when the current language is English (LTR).
  bool get isEn => _locale.languageCode == 'en';

  /// Switch between Arabic and English.
  void toggle() {
    setLocale(isEn ? const Locale('ar') : const Locale('en'));
  }

  /// Set the locale explicitly (only `ar`/`en` are supported; others ignored).
  void setLocale(Locale locale) {
    if (locale.languageCode != 'ar' && locale.languageCode != 'en') return;
    if (locale.languageCode == _locale.languageCode) return;
    _locale = Locale(locale.languageCode);
    notifyListeners();
  }
}
