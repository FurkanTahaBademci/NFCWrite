import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localization/localization.dart';
import 'package:ndef_codec/ndef_codec.dart';

import '../../application/write_controller.dart';
import '../widgets/record_type_sheet.dart';

/// Yazma sekmesi.
class WritePage extends ConsumerStatefulWidget {
  const WritePage({super.key, this.fromHistoryId});

  /// Verilirse, ekran acilirken bu gecmis kaydinin NDEF icerigi
  /// duzenleme listesine yuklenir (bkz. `HistoryPage` — "Yazma ekranına
  /// yükle").
  final int? fromHistoryId;

  @override
  ConsumerState<WritePage> createState() => _WritePageState();
}

class _WritePageState extends ConsumerState<WritePage> {
  @override
  void initState() {
    super.initState();
    final fromHistoryId = widget.fromHistoryId;
    if (fromHistoryId != null) {
      Future.microtask(
        () => ref.read(writeControllerProvider.notifier).loadFromHistory(
          fromHistoryId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(writeControllerProvider);
    final controller = ref.read(writeControllerProvider.notifier);

    ref.listen<WriteState>(writeControllerProvider, (previous, next) {
      final wasBusy =
          previous?.phase == WritePhase.probingTag ||
          previous?.phase == WritePhase.waitingForTag ||
          previous?.phase == WritePhase.writing ||
          previous?.phase == WritePhase.locking;
      final isBusy =
          next.phase == WritePhase.probingTag ||
          next.phase == WritePhase.waitingForTag ||
          next.phase == WritePhase.writing ||
          next.phase == WritePhase.locking;

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
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: state.isRestoringDraft
          ? const _DraftLoading()
          : state.isEmpty
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
                            onTap: () =>
                                _editRecord(index: index, record: record),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LockAfterWriteSwitch(
                          value: state.lockAfterWrite,
                          onChanged: (value) =>
                              controller.setLockAfterWrite(value: value),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _startWrite,
                            icon: Icon(
                              state.lockAfterWrite ? Icons.lock_outline : Icons.nfc,
                            ),
                            label: Text(l10n.writeAction),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: state.isRestoringDraft
          ? null
          : state.isEmpty
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

  /// Yazmayi baslatir.
  ///
  /// "Yazdiktan sonra kilitle" acikken islem **geri alinamaz** hale gelir;
  /// bu yuzden yazma baslamadan once `DangerDialog` ile onay alinir
  /// (ADR-0005 3. kapi). Kullanici vazgecerse hicbir sey yazilmaz.
  Future<void> _startWrite() async {
    final controller = ref.read(writeControllerProvider.notifier);

    if (ref.read(writeControllerProvider).lockAfterWrite) {
      final confirmation = await DangerDialog.show(
        context,
        title: 'Yazdıktan sonra kilitle',
        description:
            'Kayıtlar yazıldıktan hemen sonra etiket kalıcı olarak '
            'salt-okunur yapılacak.',
        risk: RiskLevel.danger,
        warning:
            'Bu işlem GERİ ALINAMAZ. Etiketin içeriğini bir daha '
            'değiştiremez, silemez ve biçimlendiremezsiniz.',
        // Kilitlemeden once yedek almak anlamsiz: NDEF icerigi zaten
        // bu ekranda duruyor ve kilit sonrasi geri yazilamaz.
        offerBackup: false,
      );
      if (confirmation == null || !confirmation.confirmed) return;
    }

    await controller.write();
  }

  /// Listeyi temizlemeden once onay ister.
  ///
  /// Kayitlar artik diske yazildigi icin "temizle" kalici veriyi siler —
  /// tek dokunusla olmamali.
  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_outlined),
        title: const Text('Kayıtları sil'),
        content: const Text(
          'Listedeki tüm kayıtlar ve kaydedilmiş taslak silinecek. '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    ref.read(writeControllerProvider.notifier).clear();
  }

  Future<void> _addRecord() async {
    final contents = await RecordTypeSheet.show(context);
    if (contents == null || !mounted) return;
    final controller = ref.read(writeControllerProvider.notifier);
    for (final content in contents) {
      controller.addRecord(content);
    }
  }

  Future<void> _editRecord({
    required int index,
    required NdefContent record,
  }) async {
    final updated = await RecordTypeSheet.edit(context, record);
    if (updated == null || !mounted) return;
    final controller = ref.read(writeControllerProvider.notifier);
    controller.updateRecord(index: index, content: updated);

    // vCard değiştiyse iPhone uyumluluk bağlantısı bayatlamasın: listedeki
    // ilk VCardShareLink kaydını yeni içerikle güncelle. Tanıma eski çözücü
    // adreslerini de kapsamalı — diskten geri yüklenen taslak eski adresli
    // bir kayıt taşıyorsa, kaçırılırsa karta bayat kişi verisi yazılır.
    if (updated is VCardContent) {
      final records = ref.read(writeControllerProvider).records;
      final linkIndex = records.indexWhere(
        (r) => r is UriContent && VCardShareLink.isShareLink(r.uri),
      );
      if (linkIndex >= 0) {
        controller.updateRecord(
          index: linkIndex,
          content: UriContent(VCardShareLink.build(updated)),
        );
      }
    }
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
              WritePhase.locking => NfcScanPhase.working,
              WritePhase.success => NfcScanPhase.success,
              WritePhase.failure => NfcScanPhase.failure,
              WritePhase.editing => NfcScanPhase.idle,
            },
            title: l10n.scanTitle,
            message: switch (state.phase) {
              WritePhase.writing => l10n.scanWorking,
              WritePhase.locking => 'Etiket kalıcı olarak kilitleniyor...',
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
    } else if (state.phase == WritePhase.editing &&
        state.targetCapacityBytes != null) {
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
    UriContent(:final uri) when VCardShareLink.isShareLink(uri) =>
      'iPhone kişi bağlantısı',
    UriContent() => 'Bağlantı',
    VCardContent() => 'vCard',
    WifiContent(:final ssid) => 'Wi-Fi · $ssid',
    MimeContent(:final mimeType) => mimeType,
    ExternalContent() => 'Harici tip',
    EmptyContent() => 'Boş kayıt',
    RawContent() => 'Ham veri',
  };
}

/// "Yazdiktan sonra kilitle" anahtari.
///
/// Acikken yazma islemi **geri alinamaz** hale gelir; anahtar bu yuzden
/// tehlike rengiyle ve acik uyariyla gosterilir. Asil onay yazma
/// baslatilirken `DangerDialog` ile alinir.
class _LockAfterWriteSwitch extends StatelessWidget {
  const _LockAfterWriteSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dangerColor = AppColors.forRisk(RiskLevel.danger, theme.brightness);

    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      secondary: Icon(
        value ? Icons.lock_outline : Icons.lock_open_outlined,
        color: value ? dangerColor : theme.colorScheme.onSurfaceVariant,
      ),
      title: const Text('Yazdıktan sonra kilitle'),
      subtitle: Text(
        value
            ? 'GERİ ALINAMAZ — etiket bir daha değiştirilemez'
            : 'Etiket yazılabilir kalır',
        style: theme.textTheme.bodySmall?.copyWith(
          color: value ? dangerColor : theme.colorScheme.onSurfaceVariant,
          fontWeight: value ? FontWeight.w600 : null,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
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
            label: Text(
              total == null ? 'Kart kapasitesini tara' : 'Tekrar tara',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.cloud_done_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Kayıtlar otomatik saklanır — uygulamayı kapatsanız da '
                  'kaybolmaz.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleProbeTap() {
    onProbe();
  }
}

/// Kaydedilmis taslak diskten okunurken gosterilir.
class _DraftLoading extends StatelessWidget {
  const _DraftLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Kayıtlı taslak yükleniyor...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
