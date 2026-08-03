import 'package:go_router/go_router.dart';

import 'presentation/pages/tool_detail_page.dart';
import 'presentation/pages/tools_page.dart';

/// Araclar sekmesinin rota yolu.
const String toolsRoutePath = '/tools';

/// Araclar ozelliginin rotalari.
final List<RouteBase> toolsRoutes = <RouteBase>[
  GoRoute(
    path: toolsRoutePath,
    name: 'tools',
    builder: (context, state) => const ToolsPage(),
    routes: [
      GoRoute(
        path: ':toolId',
        name: 'tool-detail',
        builder: (context, state) =>
            ToolDetailPage(toolId: state.pathParameters['toolId'] ?? ''),
      ),
    ],
  ),
];
