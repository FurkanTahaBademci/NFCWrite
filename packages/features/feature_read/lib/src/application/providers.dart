/// Servis yer tutuculari.
///
/// Bu paket somut uygulamalari (`nfc_transport`, `tag_ops`, `storage`)
/// **gormez**. Composition root (`apps/nfc_toolkit`) bunlari
/// `overrideWithValue` ile gercek nesnelere baglar.
///
/// Override edilmezse uygulama acilista patlar — sessizce yanlis
/// calismaktansa gurultulu basarisizlik tercih edilir.
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

/// Tarama gecmisi deposu.
final Provider<HistoryRepository> historyRepositoryProvider =
    Provider<HistoryRepository>(
      (ref) => throw UnimplementedError(_overrideHint),
    );

/// Uygulama ayarlari deposu.
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (ref) => throw UnimplementedError(_overrideHint),
    );
