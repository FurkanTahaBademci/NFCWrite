import 'package:go_router/go_router.dart';

import 'presentation/pages/read_page.dart';

/// Okuma ozelliginin rota yolu.
const String readRoutePath = '/read';

/// Okuma ozelliginin rotalari.
///
/// Composition root (`apps/nfc_toolkit/lib/src/app/router.dart`) bunlari
/// kabuk rotasi icine yerlestirir.
final List<RouteBase> readRoutes = <RouteBase>[
  GoRoute(
    path: readRoutePath,
    name: 'read',
    builder: (context, state) => const ReadPage(),
  ),
];
