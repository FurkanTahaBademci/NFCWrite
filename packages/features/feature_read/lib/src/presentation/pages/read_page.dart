import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localization/localization.dart';
import 'package:nfc_core/nfc_core.dart';

import '../../application/read_controller.dart';
import '../widgets/tag_info_view.dart';

/// Okuma sekmesi.
class ReadPage extends ConsumerStatefulWidget {
  const ReadPage({super.key});

  @override
  ConsumerState<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends ConsumerState<ReadPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(readControllerProvider);

    // Tarama basladiginda alt sayfayi ac, bitince kapat.
    ref.listen<ReadState>(readControllerProvider, (previous, next) {
      final wasScanning = previous is ReadScanning;
      final isScanning = next is ReadScanning;
      if (!wasScanning && isScanning) {
        _openScanSheet();
      } else if (wasScanning && !isScanning) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        if (next is ReadFailure) _showFailure(next.failure);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabRead),
        actions: [
          if (state is ReadSuccess)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.actionScan,
              onPressed: () => ref.read(readControllerProvider.notifier).scan(),
            ),
        ],
      ),
      body: switch (state) {
        ReadSuccess(:final info) => TagInfoView(info: info),
        _ => _ReadEmptyView(
          onScan: () => ref.read(readControllerProvider.notifier).scan(),
        ),
      },
      floatingActionButton: state is ReadSuccess
          ? null
          : FloatingActionButton.extended(
              onPressed: () => ref.read(readControllerProvider.notifier).scan(),
              icon: const Icon(Icons.nfc),
              label: Text(l10n.actionScan),
            ),
    );
  }

  void _openScanSheet() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(readControllerProvider);
          return NfcScanSheet(
            phase: switch (state) {
              ReadScanning() => NfcScanPhase.scanning,
              ReadSuccess() => NfcScanPhase.success,
              ReadFailure() => NfcScanPhase.failure,
              ReadIdle() => NfcScanPhase.idle,
            },
            title: l10n.scanTitle,
            message: l10n.scanHint,
            onCancel: () => ref.read(readControllerProvider.notifier).cancel(),
          );
        },
      ),
    );
  }

  void _showFailure(NfcFailure failure) {
    final l10n = AppLocalizations.of(context);
    final actionLabel = l10n.actionLabelFor(failure);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.messageFor(failure)),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                onPressed: () => _handleFailureAction(failure),
              ),
      ),
    );
  }

  void _handleFailureAction(NfcFailure failure) {
    switch (failure) {
      case NfcUnavailable(reason: NfcUnavailableReason.disabled):
        ref.read(readControllerProvider.notifier).openNfcSettings();
      default:
        ref.read(readControllerProvider.notifier).scan();
    }
  }
}

class _ReadEmptyView extends StatelessWidget {
  const _ReadEmptyView({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.nfc_outlined,
      title: l10n.readEmptyTitle,
      description: l10n.readEmptyDescription,
    );
  }
}
