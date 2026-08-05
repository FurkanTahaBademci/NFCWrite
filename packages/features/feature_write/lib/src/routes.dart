import 'package:go_router/go_router.dart';

import 'presentation/pages/write_page.dart';

/// Yazma ozelliginin rota yolu.
const String writeRoutePath = '/write';

/// Yazma ozelliginin rotalari.
final List<RouteBase> writeRoutes = <RouteBase>[
  GoRoute(
    path: writeRoutePath,
    name: 'write',
    builder: (context, state) {
      final fromHistory = state.uri.queryParameters['fromHistory'];
      return WritePage(fromHistoryId: int.tryParse(fromHistory ?? ''));
    },
  ),
];
