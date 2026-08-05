import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localization/localization.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_utils/shared_utils.dart';

import '../../application/continuous_read_controller.dart';
import '../../application/read_controller.dart';
import '../../domain/tag_info_json.dart';
import '../widgets/tag_info_view.dart';

/// Okuma sekmesi.
class ReadPage extends ConsumerStatefulWidget {
  const ReadPage({super.key});

  @override
  ConsumerState<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends ConsumerState<ReadPage> {
  static const MethodChannel _systemChannel = MethodChannel(
    'nfc_toolkit/system',
  );

  @override
  void initState() {
    super.initState();
    _systemChannel.setMethodCallHandler(_handleSystemCall);
  }

  @override
  void dispose() {
    _systemChannel.setMethodCallHandler(null);
    super.dispose();
  }

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
          if (state is ReadSuccess) ...[
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: l10n.readShareJson,
              onPressed: () => _shareJson(state.info),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.actionScan,
              onPressed: () => ref.read(readControllerProvider.notifier).scan(),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.repeat),
              tooltip: l10n.readContinuousStart,
              onPressed: _openContinuousSheet,
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

  Future<void> _shareJson(NfcTagInfo info) async {
    final l10n = AppLocalizations.of(context);
    await SharePlus.instance.share(
      ShareParams(text: tagInfoToJsonString(info), subject: l10n.readShareResult),
    );
  }

  void _openContinuousSheet() {
    ref.read(continuousReadControllerProvider.notifier).start();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final l10n = AppLocalizations.of(context);
          final state = ref.watch(continuousReadControllerProvider);
          final results = switch (state) {
            ContinuousReadActive(:final results) => results,
            ContinuousReadFailure(:final results) => results,
            ContinuousReadIdle() => const <NfcTagInfo>[],
          };

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            builder: (context, scrollController) => SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.readContinuousCount(results.length),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(continuousReadControllerProvider.notifier)
                                .stop();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          child: Text(l10n.actionDone),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: results.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Text(
                                l10n.readContinuousHint,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: results.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final info = results[index];
                              return ListTile(
                                leading: const Icon(Icons.nfc),
                                title: Text(
                                  info.identity.displayName ??
                                      info.identity.family.name,
                                ),
                                subtitle: Text(formatUid(info.uid)),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      ref.read(continuousReadControllerProvider.notifier).stop();
    });
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

  Future<void> _handleSystemCall(MethodCall call) async {
    if (call.method != 'onNfcIntent' || !mounted) {
      return;
    }

    await ref.read(readControllerProvider.notifier).scan();
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
