import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_strings.dart';
import 'strings_en.dart';
import 'strings_tr.dart';

/// Metinlere widget agacindan erisim.
///
/// ```dart
/// final l10n = AppLocalizations.of(context);
/// Text(l10n.tabRead);
/// ```
abstract final class AppLocalizations {
  /// Desteklenen diller.
  static const List<Locale> supportedLocales = [Locale('tr'), Locale('en')];

  /// `MaterialApp.localizationsDelegates` icin.
  static const List<LocalizationsDelegate<Object>> localizationsDelegates = [
    _AppStringsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Baglamdan metinleri alir.
  ///
  /// Delegate kayitli degilse Turkce'ye duser — arayuz asla bos kalmaz.
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ?? const AppStringsTr();

  /// Dil kodundan metin setini secer.
  static AppStrings forLanguageCode(String? code) => switch (code) {
    'en' => const AppStringsEn(),
    _ => const AppStringsTr(),
  };
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppStrings> load(Locale locale) async =>
      AppLocalizations.forLanguageCode(locale.languageCode);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
