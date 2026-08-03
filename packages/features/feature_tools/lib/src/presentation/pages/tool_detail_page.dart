import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localization/localization.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';

import '../../application/providers.dart';
import '../../domain/tool_catalog.dart';

/// Tek bir aracin ekrani.
///
/// **Iskelet.** Ortak akis burada kuruldu: aciklama → uyari → onay →
/// yurutme → sonuc. Her aracin kendi parametre formu ve calistirma
/// mantigi T4 tarafindan eklenecek (bkz. `.claude/tracks/T4-tools.md`).
class ToolDetailPage extends ConsumerStatefulWidget {
  const ToolDetailPage({required this.toolId, super.key});

  final String toolId;

  @override
  ConsumerState<ToolDetailPage> createState() => _ToolDetailPageState();
}

class _ToolDetailPageState extends ConsumerState<ToolDetailPage> {
  String? _resultMessage;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final tool = ToolCatalog.byId(widget.toolId);
    if (tool == null) {
      return const Scaffold(
        body: EmptyState(icon: Icons.help_outline, title: 'Arac bulunamadi'),
      );
    }

    final theme = Theme.of(context);
    final riskColor = AppColors.forRisk(tool.risk, theme.brightness);

    return Scaffold(
      appBar: AppBar(title: Text(tool.title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Icon(tool.icon, color: riskColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(tool.description)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TagBadge(
            label: switch (tool.risk) {
              RiskLevel.safe => 'Guvenli — etiketi degistirmez',
              RiskLevel.caution => 'Icerigi degistirir',
              RiskLevel.warning => 'Yapilandirmayi degistirir',
              RiskLevel.danger => 'GERI ALINAMAZ',
            },
            icon: tool.risk.icon,
            risk: tool.risk,
          ),

          if (_resultMessage != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(_resultMessage!),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xxl),
          FilledButton.icon(
            style: tool.risk == RiskLevel.danger
                ? FilledButton.styleFrom(backgroundColor: riskColor)
                : null,
            onPressed: _busy ? null : () => _run(tool),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: const Text('Calistir'),
          ),

          const SizedBox(height: AppSpacing.xl),
          Text(
            'Gorev: ${tool.taskId} · .claude/tracks/T4-tools.md',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _run(ToolDefinition tool) async {
    final l10n = AppLocalizations.of(context);
    final session = ref.read(nfcSessionServiceProvider);
    final operations = ref.read(tagOperationsProvider);

    setState(() {
      _busy = true;
      _resultMessage = null;
    });

    // Yikici araclarda once etiketi tanimlayip onay isteriz: onay hangi
    // etiket icin verildiyse islem yalnizca o etikete uygulanir (ADR-0005).
    final result = await session.runOnce<String>(
      onTag: (tag) async {
        final uidHex = bytesToHex(tag.uid);

        if (tool.risk == RiskLevel.safe) {
          return _runSafeTool(tool, tag, operations);
        }

        if (!mounted) return const Err(OperationCancelled());
        final confirmation = await DangerDialog.show(
          context,
          title: tool.title,
          description: tool.description,
          risk: tool.risk,
          targetUid: formatUid(tag.uid),
          warning: tool.risk == RiskLevel.danger
              ? 'Bu islem geri alinamaz. Etiket kalici olarak degisecek.'
              : null,
        );
        if (confirmation == null || !confirmation.confirmed) {
          return const Err(OperationCancelled());
        }

        final ack = DangerAck.userConfirmed(
          risk: switch (tool.risk) {
            RiskLevel.safe => OperationRisk.safe,
            RiskLevel.caution => OperationRisk.content,
            RiskLevel.warning => OperationRisk.config,
            RiskLevel.danger => OperationRisk.irreversible,
          },
          operationId: tool.id,
          targetUidHex: uidHex,
          backupTaken: confirmation.takeBackup,
        );

        return _runDestructiveTool(tool, tag, operations, ack);
      },
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _resultMessage = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => l10n.messageFor(failure),
      };
    });
  }

  Future<Result<String>> _runSafeTool(
    ToolDefinition tool,
    NfcTagHandle tag,
    TagOperations operations,
  ) async {
    switch (tool.id) {
      case 'memory_dump':
        final result = await operations.readMemory(tag);
        return result.map(
          (memory) =>
              '${memory.bytes.length} byte okundu '
              '(${memory.pageCount} sayfa)',
        );
      case 'read_counter':
        final result = await operations.readCounter(tag);
        return result.map((value) => 'Sayac: $value');
      case 'verify_signature':
        final result = await operations.verifySignature(tag);
        return result.map(
          (valid) => valid ? 'Imza gecerli' : 'Imza dogrulanamadi',
        );
      default:
        return Err(NotImplementedYet(tool.taskId));
    }
  }

  Future<Result<String>> _runDestructiveTool(
    ToolDefinition tool,
    NfcTagHandle tag,
    TagOperations operations,
    DangerAck ack,
  ) async {
    switch (tool.id) {
      case 'erase_tag':
        final result = await operations.eraseNdef(tag, ack: ack);
        return result.map((_) => 'Etiket temizlendi');
      case 'make_read_only':
        final result = await operations.makeReadOnly(tag, ack: ack);
        return result.map((_) => 'Etiket kalici olarak salt-okunur yapildi');
      default:
        return Err(NotImplementedYet(tool.taskId));
    }
  }
}
