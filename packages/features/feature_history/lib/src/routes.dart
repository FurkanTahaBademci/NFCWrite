import 'package:go_router/go_router.dart';

import 'presentation/pages/history_page.dart';

/// Gecmis sekmesinin rota yolu.
const String historyRoutePath = '/history';

/// Gecmis ozelliginin rotalari.
final List<RouteBase> historyRoutes = <RouteBase>[
  GoRoute(
    path: historyRoutePath,
    name: 'history',
    builder: (context, state) => const HistoryPage(),
  ),
];
