/// Servis yer tutuculari — composition root override eder.
///
/// Bkz. `packages/features/feature_read/lib/src/application/providers.dart`
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

/// Yazma sablonlari deposu.
final Provider<TemplateRepository> templateRepositoryProvider =
    Provider<TemplateRepository>(
      (ref) => throw UnimplementedError(_overrideHint),
    );

/// Tarama gecmisi deposu — "gecmisten yukle" akisi icin (bkz. T2.31).
final Provider<HistoryRepository> historyRepositoryProvider =
    Provider<HistoryRepository>(
      (ref) => throw UnimplementedError(_overrideHint),
    );
