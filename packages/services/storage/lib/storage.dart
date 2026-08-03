/// Kalici veri katmani.
///
/// `nfc_core` icindeki repository sozlesmelerini uygular.
///
/// **Bu paketi yalnizca composition root (`apps/nfc_toolkit`) import eder.**
///
/// Sahibi: **T1** (bkz. `.claude/tracks/T1-core.md`)
library;

export 'src/database/storage_database.dart';
export 'src/dump_repository_impl.dart';
export 'src/history_repository_impl.dart';
export 'src/in_memory_repositories.dart';
export 'src/settings_repository_impl.dart';
export 'src/template_repository_impl.dart';
