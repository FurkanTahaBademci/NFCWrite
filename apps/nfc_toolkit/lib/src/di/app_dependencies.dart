import 'package:feature_history/feature_history.dart' as history;
import 'package:feature_read/feature_read.dart' as read;
import 'package:feature_settings/feature_settings.dart' as settings;
import 'package:feature_tools/feature_tools.dart' as tools;
import 'package:feature_write/feature_write.dart' as write;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:nfc_transport/nfc_transport.dart';
import 'package:storage/storage.dart';
import 'package:tag_ops/tag_ops.dart';

/// ---------------------------------------------------------------------
/// COMPOSITION ROOT
///
/// Somut uygulamalarin soyutlamalara baglandigi **tek** yer. Feature
/// paketleri `nfc_transport`, `tag_ops` ve `storage` paketlerini gormez;
/// yalnizca `nfc_core` arayuslerini bilir.
///
/// Yeni bir feature paketi eklerken:
///   1. Paketi `pubspec.yaml` ve kok `workspace:` listesine ekle
///   2. Buraya `import ... as <ad>` satirini ekle
///   3. `wrap` icindeki override listesine yeni provider'lari ekle
///
/// Bkz. `.claude/docs/01-architecture.md`
/// ---------------------------------------------------------------------
final class AppDependencies {
  const AppDependencies._({
    required this.session,
    required this.operations,
    required this.historyRepository,
    required this.dumpRepository,
    required this.templateRepository,
    required this.settingsRepository,
  });

  /// Tum bagimliliklari kurar. Uygulama acilisinda bir kez cagrilir.
  static Future<AppDependencies> bootstrap() async {
    final database = await StorageDatabase.open();
    final settingsRepository = await SettingsRepositoryImpl.open();
    final historyRepository = HistoryRepositoryImpl(database);
    final dumpRepository = DumpRepositoryImpl(database);
    final templateRepository = TemplateRepositoryImpl(database);

    return AppDependencies._(
      session: AndroidNfcSessionService(),
      operations: const TagOperationsImpl(),
      historyRepository: historyRepository,
      dumpRepository: dumpRepository,
      templateRepository: templateRepository,
      settingsRepository: settingsRepository,
    );
  }

  final NfcSessionService session;
  final TagOperations operations;
  final HistoryRepository historyRepository;
  final DumpRepository dumpRepository;
  final TemplateRepository templateRepository;
  final SettingsRepository settingsRepository;

  /// Uygulamayi bagimliliklarin baglandigi bir [ProviderScope] icine sarar.
  ///
  /// Her feature kendi provider yer tutucusunu ilan eder; hepsi ayni
  /// nesneye baglanir. Bu tekrar bilinclidir — feature'lar arasi
  /// bagimlilik olusmasin diye.
  Widget wrap(Widget child) => ProviderScope(
    overrides: [
      // --- feature_read ---
      read.nfcSessionServiceProvider.overrideWithValue(session),
      read.tagOperationsProvider.overrideWithValue(operations),
      read.historyRepositoryProvider.overrideWithValue(historyRepository),
      read.settingsRepositoryProvider.overrideWithValue(settingsRepository),

      // --- feature_write ---
      write.nfcSessionServiceProvider.overrideWithValue(session),
      write.tagOperationsProvider.overrideWithValue(operations),
      write.templateRepositoryProvider.overrideWithValue(templateRepository),

      // --- feature_tools ---
      tools.nfcSessionServiceProvider.overrideWithValue(session),
      tools.tagOperationsProvider.overrideWithValue(operations),
      tools.dumpRepositoryProvider.overrideWithValue(dumpRepository),
      tools.settingsRepositoryProvider.overrideWithValue(settingsRepository),

      // --- feature_history ---
      history.historyRepositoryProvider.overrideWithValue(historyRepository),
      history.dumpRepositoryProvider.overrideWithValue(dumpRepository),

      // --- feature_settings ---
      settings.settingsRepositoryProvider.overrideWithValue(settingsRepository),
    ],
    child: child,
  );
}
