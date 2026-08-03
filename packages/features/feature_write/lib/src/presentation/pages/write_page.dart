import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localization/localization.dart';
import 'package:ndef_codec/ndef_codec.dart';

import '../../application/write_controller.dart';
import '../widgets/record_type_sheet.dart';

/// Yazma sekmesi.
///
/// **Iskelet.** Su an yalnizca metin ve baglanti kaydi eklenebiliyor;
/// 26 kayit tipinin sihirbazlari T3'un isi (bkz. `.claude/tracks/T3-write.md`).
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
          previous?.phase == WritePhase.waitingForTag ||
          previous?.phase == WritePhase.writing;
      final isBusy =
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
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: CapacityBar(
                    used: state.byteLength,
                    // Hedef etiket henuz bilinmiyor; en yaygin kapasiteyi
                    // (NTAG213 = 144 byte) referans aliyoruz. Gercek kontrol
                    // yazma aninda `InsufficientSpace` ile yapilir.
                    total: 144,
                  ),
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
                            leading: const Icon(Icons.drag_indicator),
                            title: Text(_labelFor(record)),
                            subtitle: Text(
                              record.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
              WritePhase.waitingForTag => NfcScanPhase.scanning,
              WritePhase.writing => NfcScanPhase.working,
              WritePhase.success => NfcScanPhase.success,
              WritePhase.failure => NfcScanPhase.failure,
              WritePhase.editing => NfcScanPhase.idle,
            },
            title: l10n.scanTitle,
            message: state.phase == WritePhase.writing
                ? l10n.scanWorking
                : l10n.scanHint,
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
    } else if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.messageFor(failure))));
    }
    ref.read(writeControllerProvider.notifier).acknowledge();
  }

  static String _labelFor(NdefContent content) => switch (content) {
    TextContent() => 'Metin',
    UriContent() => 'Baglanti',
    VCardContent() => 'vCard',
    MimeContent(:final mimeType) => mimeType,
    ExternalContent() => 'Harici tip',
    EmptyContent() => 'Bos kayit',
    RawContent() => 'Ham veri',
  };
}
