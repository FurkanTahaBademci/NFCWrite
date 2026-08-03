import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:localization/localization.dart';

import '../../application/providers.dart';
import '../../domain/tool_catalog.dart';

/// "Diğer" sekmesi — araçlar risk seviyesine göre gruplanmış ızgara.
class ToolsPage extends ConsumerWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final expertMode = ref.watch(expertModeProvider);

    final groups = <(String, ToolCategory)>[
      (l10n.toolsGroupSafe, ToolCategory.safe),
      (l10n.toolsGroupContent, ToolCategory.content),
      (l10n.toolsGroupConfig, ToolCategory.configuration),
      (l10n.toolsGroupIrreversible, ToolCategory.irreversible),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.toolsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          for (final (title, category) in groups)
            ..._buildGroup(context, title, category, expertMode: expertMode),

          if (!expertMode)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: Text(l10n.toolsExpertModeRequired),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/settings'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildGroup(
    BuildContext context,
    String title,
    ToolCategory category, {
    required bool expertMode,
  }) {
    final tools = ToolCatalog.byCategory(category, expertMode: expertMode);
    if (tools.isEmpty) return const [];

    return [
      SectionHeader(title),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.25,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final tool = tools[index];
            return ToolCard(
              title: tool.title,
              description: tool.implemented
                  ? tool.description
                  : '${tool.description} · yakında',
              icon: tool.icon,
              risk: tool.risk,
              enabled: tool.implemented,
              onTap: () => context.go('/tools/${tool.id}'),
            );
          },
        ),
      ),
    ];
  }
}
