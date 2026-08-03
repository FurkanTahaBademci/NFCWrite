/// Servis yer tutuculari — composition root override eder.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_core/nfc_core.dart';

const String _overrideHint =
    'apps/nfc_toolkit/lib/src/di/providers.dart icinde override edilmeli';

/// NFC oturum servisi.
final Provider<NfcSessionService> nfcSessionServiceProvider =
    Provider<NfcSessionService>(
      (ref) => throw UnimplementedError(_overrideHint),
    );

/// Etiket islemleri.
final Provider<TagOperations> tagOperationsProvider = Provider<TagOperations>(
  (ref) => throw UnimplementedError(_overrideHint),
);

/// Dokum arsivi — yikici islem oncesi otomatik yedek buraya yazilir.
final Provider<DumpRepository> dumpRepositoryProvider =
    Provider<DumpRepository>((ref) => throw UnimplementedError(_overrideHint));

/// Uygulama ayarlari — uzman modu buradan okunur.
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (ref) => throw UnimplementedError(_overrideHint),
    );

/// Uzman modu acik mi?
final Provider<bool> expertModeProvider = Provider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).current.expertMode,
);
