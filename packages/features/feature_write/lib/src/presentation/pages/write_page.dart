import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localization/localization.dart';
import 'package:ndef_codec/ndef_codec.dart';

import '../../application/write_controller.dart';
import '../widgets/record_type_sheet.dart';

/// Yazma sekmesi.
class WritePage extends ConsumerStatefulWidget {
  const WritePage({super.key});

  @override
  ConsumerState<WritePage> createState() => _WritePageState();
}

class _WritePageState extends ConsumerState<WritePage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(writeControllerProvider);
    final controller = ref.read(writeControllerProvider.notifier);

    ref.listen<WriteState>(writeControllerProvider, (previous, next) {
      final wasBusy =
          previous?.phase == WritePhase.probingTag ||
          previous?.phase == WritePhase.waitingForTag ||
          previous?.phase == WritePhase.writing;
      final isBusy =
          next.phase == WritePhase.probingTag ||
          next.phase == WritePhase.waitingForTag ||
          next.phase == WritePhase.writing;

      if (!wasBusy && isBusy) {
        _openScanSheet();
      } else if (wasBusy && !isBusy) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        _showResult(next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabWrite),
        actions: [
          if (!state.isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: l10n.actionDelete,
              onPressed: controller.clear,
            ),
        ],
      ),
      body: state.isEmpty
          ? EmptyState(
              icon: Icons.edit_note_outlined,
              title: l10n.writeEmptyTitle,
              description: l10n.writeEmptyDescription,
            )
          : Column(
              children: [
                _CapacitySection(
                  used: state.byteLength,
                  total: state.targetCapacityBytes,
                  onProbe: controller.probeTargetCapacity,
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    itemCount: state.records.length,
                    onReorderItem: controller.reorder,
                    itemBuilder: (context, index) {
                      final record = state.records[index];
                      return Dismissible(
                        key: ValueKey('record-$index-${record.hashCode}'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => controller.removeRecord(index),
                        background: ColoredBox(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: const Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: EdgeInsets.only(right: AppSpacing.lg),
                              child: Icon(Icons.delete_outline),
                            ),
                          ),
                        ),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            onTap: () => _editRecord(index: index, record: record),
                            leading: const Icon(Icons.drag_indicator),
                            title: Text(_labelFor(record)),
                            subtitle: Text(
                              record.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Düzenle',
                              onPressed: () =>
                                  _editRecord(index: index, record: record),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: controller.write,
                        icon: const Icon(Icons.nfc),
                        label: Text(l10n.writeAction),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: state.isEmpty
          ? FloatingActionButton.extended(
              onPressed: _addRecord,
              icon: const Icon(Icons.add),
              label: Text(l10n.writeAddRecord),
            )
          : FloatingActionButton(
              onPressed: _addRecord,
              child: const Icon(Icons.add),
            ),
      floatingActionButtonLocation: state.isEmpty
          ? FloatingActionButtonLocation.centerFloat
          : FloatingActionButtonLocation.endFloat,
    );
  }

  Future<void> _addRecord() async {
    final content = await RecordTypeSheet.show(context);
    if (content == null || !mounted) return;
    ref.read(writeControllerProvider.notifier).addRecord(content);
  }

  Future<void> _editRecord({
    required int index,
    required NdefContent record,
  }) async {
    final updated = await RecordTypeSheet.edit(context, record);
    if (updated == null || !mounted) return;
    ref
        .read(writeControllerProvider.notifier)
        .updateRecord(index: index, content: updated);
  }

  void _openScanSheet() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(writeControllerProvider);
          return NfcScanSheet(
            phase: switch (state.phase) {
              WritePhase.probingTag => NfcScanPhase.scanning,
              WritePhase.waitingForTag => NfcScanPhase.scanning,
              WritePhase.writing => NfcScanPhase.working,
              WritePhase.success => NfcScanPhase.success,
              WritePhase.failure => NfcScanPhase.failure,
              WritePhase.editing => NfcScanPhase.idle,
            },
            title: l10n.scanTitle,
            message: switch (state.phase) {
              WritePhase.writing => l10n.scanWorking,
              WritePhase.probingTag => 'Kart kapasitesi okunuyor...',
              _ => l10n.scanHint,
            },
            onCancel: () => ref.read(writeControllerProvider.notifier).cancel(),
          );
        },
      ),
    );
  }

  void _showResult(WriteState state) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final failure = state.failure;

    if (state.phase == WritePhase.success) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.scanSuccess)));
    } else if (state.phase == WritePhase.editing && state.targetCapacityBytes != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Kart kapasitesi okundu: ${state.targetCapacityBytes} byte',
          ),
        ),
      );
    } else if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.messageFor(failure))));
    }
    ref.read(writeControllerProvider.notifier).acknowledge();
  }

  static String _labelFor(NdefContent content) => switch (content) {
    TextContent() => 'Metin',
    UriContent() => 'Bağlantı',
    VCardContent() => 'vCard',
    MimeContent(:final mimeType) => mimeType,
    ExternalContent() => 'Harici tip',
    EmptyContent() => 'Boş kayıt',
    RawContent() => 'Ham veri',
  };
}

class _CapacitySection extends StatelessWidget {
  const _CapacitySection({
    required this.used,
    required this.total,
    required this.onProbe,
  });

  final int used;
  final int? total;
  final Future<void> Function() onProbe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (total != null)
            CapacityBar(used: used, total: total!)
          else
            Text(
              'Mevcut veri boyutu: $used byte\n'
              'Kart kapasitesi bilinmiyor. Kart okunmadan limit gösterilmez.',
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _handleProbeTap,
            icon: const Icon(Icons.nfc),
            label: Text(total == null ? 'Kart kapasitesini tara' : 'Tekrar tara'),
          ),
        ],
      ),
    );
  }

  void _handleProbeTap() {
    onProbe();
  }
}
