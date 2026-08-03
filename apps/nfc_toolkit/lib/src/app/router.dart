import 'package:feature_history/feature_history.dart';
import 'package:feature_read/feature_read.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:feature_tools/feature_tools.dart';
import 'package:feature_write/feature_write.dart';
import 'package:go_router/go_router.dart';

import 'shell_page.dart';

/// Uygulamanin yonlendiricisi.
///
/// Her feature kendi rotalarini ihrac eder; burasi yalnizca onlari
/// birlestirir. Yeni bir feature eklerken: import et, ilgili dala ekle.
///
/// Sahibi: **T1** (`.claude/docs/06-parallel-workflow.md` — ortak dosya)
GoRouter createRouter() => GoRouter(
  initialLocation: readRoutePath,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ShellPage(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: readRoutes),
        StatefulShellBranch(routes: writeRoutes),
        StatefulShellBranch(routes: toolsRoutes),
        StatefulShellBranch(routes: historyRoutes),
      ],
    ),

    // Ayarlar kabugun disinda — tam ekran acilir, alt cubuk gorunmez.
    ...settingsRoutes,
  ],
);
