import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:localization/localization.dart';
import 'package:nfc_core/nfc_core.dart';

import '../../application/history_controller.dart';

/// Gecmis sekmesi — taramalar + dokum arsivi.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tabHistory),
          actions: [
            IconButton(
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: l10n.historyExportAll,
              onPressed: () => _exportHistory(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: l10n.historyImportAll,
              onPressed: () => _importHistory(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.actionDelete,
              onPressed: () => _confirmClear(context, ref),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.historyTabScans),
              Tab(text: l10n.historyTabDumps),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ScanHistoryTab(), _DumpArchiveTab()],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.actionDelete),
        content: const Text('Tum gecmis silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(historyRepositoryProvider).clear();
    }
  }

  Future<void> _exportHistory(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(historyRepositoryProvider).exportAllToFile();
    switch (result) {
      case Ok(:final value):
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.historyExportSuccess(value))),
        );
      case Err(:final failure):
        messenger.showSnackBar(SnackBar(content: Text(l10n.messageFor(failure))));
    }
  }

  Future<void> _importHistory(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(historyRepositoryProvider);

    final listResult = await repository.listExportedFiles();
    if (listResult case Err(:final failure)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.messageFor(failure))));
      return;
    }
    final files = (listResult as Ok<List<String>>).value;
    if (!context.mounted) return;

    if (files.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.historyNoExportsFound)));
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final path in files)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(path.split(RegExp(r'[\\/]')).last),
                onTap: () => Navigator.of(context).pop(path),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;

    final importResult = await repository.importAllFromFile(selected);
    if (!context.mounted) return;
    switch (importResult) {
      case Ok(:final value):
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.historyImportSuccess(value))),
        );
      case Err(:final failure):
        messenger.showSnackBar(SnackBar(content: Text(l10n.messageFor(failure))));
    }
  }
}

class _ScanHistoryTab extends ConsumerWidget {
  const _ScanHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final records = ref.watch(historyListProvider);
    final query = ref.watch(historyQueryProvider);
    final families = ref.watch(historyAvailableFamiliesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.historySearchHint,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => ref
                .read(historyQueryProvider.notifier)
                .search(value.trim().isEmpty ? null : value.trim()),
          ),
        ),
        families.maybeWhen(
          data: (values) => values.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(l10n.historyFilterAll),
                            selected: query.chipFamily == null,
                            onSelected: (_) => ref
                                .read(historyQueryProvider.notifier)
                                .filterByChip(null),
                          ),
                        ),
                        for (final family in values)
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: ChoiceChip(
                              label: Text(family.name),
                              selected: query.chipFamily == family,
                              onSelected: (_) => ref
                                  .read(historyQueryProvider.notifier)
                                  .filterByChip(
                                    query.chipFamily == family ? null : family,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
          orElse: () => const SizedBox.shrink(),
        ),
        Expanded(
          child: records.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyState(
              icon: Icons.error_outline,
              title: l10n.errorStorage,
              description: '$error',
            ),
            data: (list) => list.isEmpty
                ? EmptyState(
                    icon: Icons.history,
                    title: l10n.historyEmptyTitle,
                    description: l10n.historyEmptyDescription,
                  )
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _HistoryTile(
                      record: list[index],
                      onTap: () => _showDetails(context, ref, list[index]),
                      onLongPress: () =>
                          _showAliasDialog(context, ref, list[index]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    WidgetRef ref,
    ScanRecord record,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HistoryDetailSheet(
        record: record,
        onSetAlias: () => _showAliasDialog(context, ref, record),
        onLoadToWrite: record.rawJson == null || record.rawJson!.isEmpty
            ? null
            : () => context.go('/write?fromHistory=${record.id}'),
      ),
    );
  }
}

Future<void> _showAliasDialog(
  BuildContext context,
  WidgetRef ref,
  ScanRecord record,
) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: record.alias ?? '');
  final alias = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.historyAliasDialogTitle),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.historyAliasHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(l10n.actionSave),
        ),
      ],
    ),
  );
  if (alias == null) return;
  await ref
      .read(historyRepositoryProvider)
      .setAlias(uidHex: record.uidHex, alias: alias.isEmpty ? null : alias);
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.record,
    required this.onTap,
    required this.onLongPress,
  });

  final ScanRecord record;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = record.recordSummaries.isEmpty
        ? (record.chipDisplayName ?? record.chipFamily.name)
        : record.recordSummaries.first;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: const CircleAvatar(child: Icon(Icons.nfc, size: 20)),
      title: Text(record.displayTitle),
      subtitle: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        _formatTime(record.scannedAt),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

class _HistoryDetailSheet extends StatelessWidget {
  const _HistoryDetailSheet({
    required this.record,
    required this.onSetAlias,
    required this.onLoadToWrite,
  });

  final ScanRecord record;
  final VoidCallback onSetAlias;
  final VoidCallback? onLoadToWrite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final readable = record.wasWritable;
    final writableText = switch (readable) {
      true => 'Yazilabilir',
      false => 'Salt-okunur',
      null => 'Bilinmiyor',
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              record.displayTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${record.scannedAt.day.toString().padLeft(2, '0')}.'
              '${record.scannedAt.month.toString().padLeft(2, '0')}.'
              '${record.scannedAt.year} '
              '${record.scannedAt.hour.toString().padLeft(2, '0')}:'
              '${record.scannedAt.minute.toString().padLeft(2, '0')}',
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onSetAlias();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.historySetAlias),
                ),
                FilledButton.icon(
                  onPressed: onLoadToWrite == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          onLoadToWrite!();
                        },
                  icon: const Icon(Icons.edit_note_outlined),
                  label: Text(l10n.historyLoadToWrite),
                ),
              ],
            ),
            if (record.rawJson == null || record.rawJson!.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l10n.historyLoadToWriteUnavailable,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            InfoRow(label: 'UID', value: record.uidHex, monospace: true),
            InfoRow(
              label: 'Yonga',
              value: record.chipDisplayName ?? record.chipFamily.name,
            ),
            InfoRow(label: 'Yazma durumu', value: writableText),
            if (record.ndefByteLength != null)
              InfoRow(
                label: 'NDEF boyutu',
                value: '${record.ndefByteLength} byte',
              ),
            if (record.maxNdefSize != null)
              InfoRow(
                label: 'Maksimum kapasite',
                value: '${record.maxNdefSize} byte',
              ),
            if (record.technologies.isNotEmpty) ...[
              const SectionHeader('Teknolojiler'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final tech in record.technologies)
                    TagBadge(label: tech, icon: Icons.settings_input_antenna),
                ],
              ),
            ],
            if (record.recordSummaries.isNotEmpty) ...[
              const SectionHeader('NDEF kayıtları'),
              for (final summary in record.recordSummaries)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(summary),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DumpArchiveTab extends ConsumerWidget {
  const _DumpArchiveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dumps = ref.watch(dumpListProvider);

    return dumps.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        icon: Icons.error_outline,
        title: l10n.errorStorage,
        description: '$error',
      ),
      data: (list) => list.isEmpty
          ? EmptyState(
              icon: Icons.sd_storage_outlined,
              title: l10n.dumpArchiveEmptyTitle,
              description: l10n.dumpArchiveEmptyDescription,
            )
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _DumpTile(dump: list[index]),
            ),
    );
  }
}

class _DumpTile extends ConsumerWidget {
  const _DumpTile({required this.dump});

  final TagDump dump;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.memory, size: 20)),
      title: Text(dump.label ?? dump.uidHex),
      subtitle: Text(
        '${dump.bytes.length} byte · ${dump.pageCount} sayfa · ${dump.reason.name}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) => _handleAction(context, ref, action),
        itemBuilder: (context) => [
          PopupMenuItem(value: 'rename', child: Text(l10n.dumpRename)),
          PopupMenuItem(value: 'export', child: Text(l10n.dumpExport)),
          PopupMenuItem(value: 'delete', child: Text(l10n.actionDelete)),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(dumpRepositoryProvider);

    switch (action) {
      case 'rename':
        final controller = TextEditingController(text: dump.label ?? '');
        final label = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.dumpRename),
            content: TextField(controller: controller, autofocus: true),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.actionCancel),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
                child: Text(l10n.actionSave),
              ),
            ],
          ),
        );
        if (label == null || label.isEmpty || dump.id == null) return;
        await repository.rename(id: dump.id!, label: label);
      case 'export':
        if (dump.id == null) return;
        final result = await repository.exportToFile(dump.id!);
        if (!context.mounted) return;
        switch (result) {
          case Ok(:final value):
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.dumpExportSuccess(value))),
            );
          case Err(:final failure):
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.messageFor(failure))),
            );
        }
      case 'delete':
        if (dump.id == null) return;
        await repository.delete(dump.id!);
    }
  }
}
