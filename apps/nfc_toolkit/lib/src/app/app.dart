import 'package:design_system/design_system.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localization/localization.dart';
import 'package:nfc_core/nfc_core.dart';

import 'router.dart';

/// Uygulamanin kok widget'i.
///
/// Tema ve dil `settingsProvider`'dan gelir; ayar degisince aninda yansir.
class NfcToolkitApp extends ConsumerStatefulWidget {
  const NfcToolkitApp({super.key});

  @override
  ConsumerState<NfcToolkitApp> createState() => _NfcToolkitAppState();
}

class _NfcToolkitAppState extends ConsumerState<NfcToolkitApp> {
  // Router'i state icinde tutuyoruz ki tema/dil degisikliginde yeniden
  // olusturulup gezinme yiginini sifirlamasin.
  late final GoRouterConfigHolder _router = GoRouterConfigHolder();

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'NFC Toolkit',
      debugShowCheckedModeBanner: false,
      routerConfig: _router.value,

      // TODO(T5.15): Android 12+ dinamik renk icin `dynamic_color` paketi
      // eklenecek. `settings.useDynamicColor` degeri o zaman kullanilacak.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (settings.theme) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },

      locale: settings.language.languageCode == null
          ? null
          : Locale(settings.language.languageCode!),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    );
  }
}

/// Router'i tek sefer olusturup tutan kucuk sarmalayici.
final class GoRouterConfigHolder {
  GoRouterConfigHolder() : value = createRouter();

  /// Uygulamanin yonlendirici yapilandirmasi.
  final RouterConfig<Object> value;
}
