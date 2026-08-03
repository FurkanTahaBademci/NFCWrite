import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localization/localization.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';

import '../../application/providers.dart';
import '../../domain/tool_catalog.dart';

/// Tek bir aracın ekranı.
///
/// Ortak akış burada kuruldu: açıklama → uyarı → onay → yürütme → sonuç.
class ToolDetailPage extends ConsumerStatefulWidget {
  const ToolDetailPage({required this.toolId, super.key});

  final String toolId;

  @override
  ConsumerState<ToolDetailPage> createState() => _ToolDetailPageState();
}

class _ToolDetailPageState extends ConsumerState<ToolDetailPage> {
  String? _resultMessage;
  bool _busy = false;
  late final TextEditingController _rawCommandController;
  late final TextEditingController _passwordController;
  late final TextEditingController _packController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _protectFromPageController;
  late final TextEditingController _authLimitController;
  TransceiveChannel _rawChannel = TransceiveChannel.nfcA;
  PasswordProtectionScope _passwordScope = PasswordProtectionScope.writeOnly;
  bool _protectCounter = false;

  @override
  void initState() {
    super.initState();
    _rawCommandController = TextEditingController();
    _passwordController = TextEditingController();
    _packController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _protectFromPageController = TextEditingController(text: '4');
    _authLimitController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _rawCommandController.dispose();
    _passwordController.dispose();
    _packController.dispose();
    _currentPasswordController.dispose();
    _protectFromPageController.dispose();
    _authLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tool = ToolCatalog.byId(widget.toolId);
    if (tool == null) {
      return const Scaffold(
        body: EmptyState(icon: Icons.help_outline, title: 'Araç bulunamadı'),
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
              RiskLevel.safe => 'Güvenli — etiketi değiştirmez',
              RiskLevel.caution => 'İçeriği değiştirir',
              RiskLevel.warning => 'Yapılandırmayı değiştirir',
              RiskLevel.danger => 'GERİ ALINAMAZ',
            },
            icon: tool.risk.icon,
            risk: tool.risk,
          ),

          if (tool.id == 'raw_console') ...[
            const SizedBox(height: AppSpacing.xl),
            _RawCommandForm(
              controller: _rawCommandController,
              selectedChannel: _rawChannel,
              onChannelChanged: (value) {
                if (value == null) return;
                setState(() {
                  _rawChannel = value;
                });
              },
            ),
          ],

          if (tool.id == 'set_password') ...[
            const SizedBox(height: AppSpacing.xl),
            _SetPasswordForm(
              passwordController: _passwordController,
              packController: _packController,
              protectFromPageController: _protectFromPageController,
              authLimitController: _authLimitController,
              scope: _passwordScope,
              protectCounter: _protectCounter,
              onScopeChanged: (value) {
                if (value == null) return;
                setState(() {
                  _passwordScope = value;
                });
              },
              onProtectCounterChanged: (value) {
                setState(() {
                  _protectCounter = value;
                });
              },
            ),
          ],

          if (tool.id == 'remove_password') ...[
            const SizedBox(height: AppSpacing.xl),
            _RemovePasswordForm(controller: _currentPasswordController),
          ],

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
            label: const Text('Çalıştır'),
          ),

          const SizedBox(height: AppSpacing.xl),
          Text(
            'Görev: ${tool.taskId} · .claude/tracks/T4-tools.md',
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

    if (tool.id == 'raw_console') {
      final commandHex = _rawCommandController.text.trim();
      if (commandHex.isEmpty || !isValidHex(commandHex)) {
        setState(() {
          _resultMessage = 'Geçerli bir hex komut girin (ör: 30 04).';
        });
        return;
      }
    }

    if (tool.id == 'set_password') {
      final passwordHex = _passwordController.text.trim();
      final packHex = _packController.text.trim();
      final protectFromPageText = _protectFromPageController.text.trim();
      final authLimitText = _authLimitController.text.trim();

      if (!isValidHex(passwordHex) || hexToBytes(passwordHex).length != 4) {
        setState(() {
          _resultMessage =
              'Şifre 4 byte (8 hex karakter) olmalı. Örnek: 01020304';
        });
        return;
      }
      if (!isValidHex(packHex) || hexToBytes(packHex).length != 2) {
        setState(() {
          _resultMessage =
              'PACK 2 byte (4 hex karakter) olmalı. Örnek: A1B2';
        });
        return;
      }

      final protectFromPage = int.tryParse(protectFromPageText);
      if (protectFromPage == null || protectFromPage < 0 || protectFromPage > 255) {
        setState(() {
          _resultMessage = 'Koruma başlangıç sayfası 0-255 arasında olmalı.';
        });
        return;
      }

      final authLimit = int.tryParse(authLimitText);
      if (authLimit == null || authLimit < 0 || authLimit > 7) {
        setState(() {
          _resultMessage = 'AUTHLIM değeri 0-7 arasında olmalı.';
        });
        return;
      }

      // Parametreler dogrulandi; gercek olusturma asagida islem aninda yapilir.
    }

    if (tool.id == 'remove_password') {
      final passwordHex = _currentPasswordController.text.trim();
      if (!isValidHex(passwordHex) || hexToBytes(passwordHex).length != 4) {
        setState(() {
          _resultMessage =
              'Mevcut şifre 4 byte (8 hex karakter) olmalı. Örnek: 01020304';
        });
        return;
      }
      // Parametre dogrulandi; gercek kullanim asagida islem aninda yapilir.
    }

    setState(() {
      _busy = true;
      _resultMessage = null;
    });

    // Yıkıcı araçlarda önce etiketi tanımlayıp onay isteriz: onay hangi
    // etiket için verildiyse işlem yalnızca o etikete uygulanır (ADR-0005).
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
              ? 'Bu işlem geri alınamaz. Etiket kalıcı olarak değişecek.'
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
        return result.map((value) => 'Sayaç: $value');
      case 'verify_signature':
        final result = await operations.verifySignature(tag);
        return result.map(
          (valid) => valid ? 'İmza geçerli' : 'İmza doğrulanamadı',
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
      case 'format_tag':
        final result = await operations.formatNdef(tag, ack: ack);
        return result.map((_) => 'Etiket NDEF olarak biçimlendirildi');
      case 'set_password':
        final passwordHex = _passwordController.text.trim();
        final packHex = _packController.text.trim();
        final protectFromPage = int.parse(_protectFromPageController.text.trim());
        final authLimit = int.parse(_authLimitController.text.trim());
        final result = await operations.setPassword(
          tag,
          setup: PasswordSetup(
            password: hexToBytes(passwordHex),
            pack: hexToBytes(packHex),
            protectFromPage: protectFromPage,
            scope: _passwordScope,
            authLimit: authLimit,
            protectCounter: _protectCounter,
          ),
          ack: ack,
        );
        return result.map((_) => 'Şifre koruması etkinleştirildi');
      case 'remove_password':
        final result = await operations.removePassword(
          tag,
          currentPassword: hexToBytes(_currentPasswordController.text.trim()),
          ack: ack,
        );
        return result.map((_) => 'Şifre koruması kaldırıldı');
      case 'make_read_only':
        final result = await operations.makeReadOnly(tag, ack: ack);
        return result.map((_) => 'Etiket kalıcı olarak salt-okunur yapıldı');
      case 'raw_console':
        final command = hexToBytes(_rawCommandController.text.trim());
        final result = await operations.sendRawCommand(
          tag,
          command: command,
          channel: _rawChannel,
        );
        return result.map((bytes) {
          final hex = bytesToHex(bytes, separator: ' ');
          final ascii = bytesToAscii(bytes);
          return 'Cevap (${bytes.length} byte)\nHEX: $hex\nASCII: $ascii';
        });
      default:
        return Err(NotImplementedYet(tool.taskId));
    }
  }
}

class _RawCommandForm extends StatelessWidget {
  const _RawCommandForm({
    required this.controller,
    required this.selectedChannel,
    required this.onChannelChanged,
  });

  final TextEditingController controller;
  final TransceiveChannel selectedChannel;
  final ValueChanged<TransceiveChannel?> onChannelChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Komut',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'HEX APDU / komut',
              hintText: '30 04',
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<TransceiveChannel>(
            initialValue: selectedChannel,
            items: TransceiveChannel.values
                .map(
                  (channel) => DropdownMenuItem(
                    value: channel,
                    child: Text(_channelLabel(channel)),
                  ),
                )
                .toList(growable: false),
            onChanged: onChannelChanged,
            decoration: const InputDecoration(labelText: 'Kanal'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Boşluk, :, -, 0x yazımı kabul edilir.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );

  static String _channelLabel(TransceiveChannel channel) => switch (channel) {
    TransceiveChannel.nfcA => 'NfcA',
    TransceiveChannel.nfcV => 'NfcV',
    TransceiveChannel.mifareUltralight => 'Mifare Ultralight',
    TransceiveChannel.mifareClassic => 'Mifare Classic',
    TransceiveChannel.isoDep => 'IsoDep',
  };
}

class _SetPasswordForm extends StatelessWidget {
  const _SetPasswordForm({
    required this.passwordController,
    required this.packController,
    required this.protectFromPageController,
    required this.authLimitController,
    required this.scope,
    required this.protectCounter,
    required this.onScopeChanged,
    required this.onProtectCounterChanged,
  });

  final TextEditingController passwordController;
  final TextEditingController packController;
  final TextEditingController protectFromPageController;
  final TextEditingController authLimitController;
  final PasswordProtectionScope scope;
  final bool protectCounter;
  final ValueChanged<PasswordProtectionScope?> onScopeChanged;
  final ValueChanged<bool> onProtectCounterChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Şifre ayarları', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(
              labelText: 'Şifre (4 byte, hex)',
              hintText: '01020304',
              prefixIcon: Icon(Icons.password),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: packController,
            decoration: const InputDecoration(
              labelText: 'PACK (2 byte, hex)',
              hintText: 'A1B2',
              prefixIcon: Icon(Icons.verified_user_outlined),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: protectFromPageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Koruma başlangıç sayfası (AUTH0)',
                    hintText: '4',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: authLimitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'AUTHLIM (0-7)',
                    hintText: '0',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<PasswordProtectionScope>(
            initialValue: scope,
            onChanged: onScopeChanged,
            items: const [
              DropdownMenuItem(
                value: PasswordProtectionScope.writeOnly,
                child: Text('Sadece yazmayı koru'),
              ),
              DropdownMenuItem(
                value: PasswordProtectionScope.readAndWrite,
                child: Text('Okuma + yazmayı koru'),
              ),
            ],
            decoration: const InputDecoration(labelText: 'Koruma kapsamı'),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: protectCounter,
            onChanged: onProtectCounterChanged,
            title: const Text('Sayaç okumayı da şifreyle koru'),
          ),
        ],
      ),
    ),
  );
}

class _RemovePasswordForm extends StatelessWidget {
  const _RemovePasswordForm({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mevcut şifre doğrulaması',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Mevcut şifre (4 byte, hex)',
              hintText: '01020304',
              prefixIcon: Icon(Icons.lock_open_outlined),
            ),
          ),
        ],
      ),
    ),
  );
}
