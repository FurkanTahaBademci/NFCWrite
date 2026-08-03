import 'package:go_router/go_router.dart';

import 'presentation/pages/settings_page.dart';

/// Ayarlar rota yolu.
const String settingsRoutePath = '/settings';

/// Ayarlar ozelliginin rotalari.
///
/// Ayarlar bir sekme degildir; kabuk rotasinin **disinda** durur ki
/// tam ekran acilsin ve alt gezinme cubugu gorunmesin.
final List<RouteBase> settingsRoutes = <RouteBase>[
  GoRoute(
    path: settingsRoutePath,
    name: 'settings',
    builder: (context, state) => const SettingsPage(),
  ),
];
