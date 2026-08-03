import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localization/localization.dart';
import 'package:nfc_core/nfc_core.dart';

import '../../application/history_controller.dart';

/// Gecmis sekmesi.
///
/// **Iskelet.** Zaman gruplama, coklu secim, takma ad ve dokum arsivi
/// T2'nin isi (bkz. `.claude/tracks/T2-read.md` Asama 5).
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final records = ref.watch(historyListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabHistory),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.actionDelete,
            onPressed: () => _confirmClear(context, ref),
          ),
        ],
      ),
      body: records.when(
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
                itemBuilder: (context, index) =>
                    _HistoryTile(record: list[index]),
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
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final ScanRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = record.recordSummaries.isEmpty
        ? (record.chipDisplayName ?? record.chipFamily.name)
        : record.recordSummaries.first;

    return ListTile(
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
