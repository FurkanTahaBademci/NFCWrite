/// Gecmis ozelliginin durumu ve servis yer tutuculari.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_core/nfc_core.dart';

const String _overrideHint =
    'apps/nfc_toolkit/lib/src/di/providers.dart icinde override edilmeli';

/// Tarama gecmisi deposu.
final Provider<HistoryRepository> historyRepositoryProvider =
    Provider<HistoryRepository>(
      (ref) => throw UnimplementedError(_overrideHint),
    );

/// Dokum arsivi.
final Provider<DumpRepository> dumpRepositoryProvider =
    Provider<DumpRepository>((ref) => throw UnimplementedError(_overrideHint));

/// Aktif filtre.
final NotifierProvider<HistoryQueryController, HistoryQuery>
historyQueryProvider = NotifierProvider<HistoryQueryController, HistoryQuery>(
  HistoryQueryController.new,
);

/// Filtreyi tutan denetleyici.
final class HistoryQueryController extends Notifier<HistoryQuery> {
  @override
  HistoryQuery build() => const HistoryQuery();

  /// Arama terimini gunceller.
  void search(String? term) =>
      state = state.copyWith(searchTerm: term, offset: 0);

  /// Yonga tipine gore filtreler.
  void filterByChip(TagChipFamily? family) =>
      state = state.copyWith(chipFamily: family, offset: 0);

  /// Filtreyi sifirlar.
  void reset() => state = const HistoryQuery();
}

/// Filtreye uyan gecmis kayitlari.
///
/// Depo degistikce kendini yeniler.
final FutureProvider<List<ScanRecord>> historyListProvider =
    FutureProvider<List<ScanRecord>>((ref) async {
      final repository = ref.watch(historyRepositoryProvider);
      final query = ref.watch(historyQueryProvider);

      // Depo degisimlerini dinle — silme/ekleme sonrasi liste tazelensin.
      final subscription = repository.changes.listen((_) {
        ref.invalidateSelf();
      });
      ref.onDispose(subscription.cancel);

      final result = await repository.query(query);
      return switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(failure.toString()),
      };
    });
