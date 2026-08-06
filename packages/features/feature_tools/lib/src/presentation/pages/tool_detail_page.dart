import 'dart:typed_data';

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
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _mirrorPageController;
  late final TextEditingController _mirrorByteController;
  late final TextEditingController _mifareBlockController;
  late final TextEditingController _mifareDataController;
  late final TextEditingController _mifareKeyController;
  MifareKeyType _mifareKeyType = MifareKeyType.keyA;
  TransceiveChannel _rawChannel = TransceiveChannel.nfcA;
  MirrorMode _mirrorMode = MirrorMode.none;
  bool _counterEnabled = false;
  bool _counterPasswordProtected = false;
  bool _passwordInputIsDecimal = false;
  bool _currentPasswordInputIsDecimal = false;
  List<TagDump> _availableDumps = const <TagDump>[];
  TagDump? _selectedDump;

  @override
  void initState() {
    super.initState();
    _rawCommandController = TextEditingController();
    _passwordController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _mirrorPageController = TextEditingController(text: '6');
    _mirrorByteController = TextEditingController(text: '0');
    _mifareBlockController = TextEditingController(text: '0');
    _mifareDataController = TextEditingController();
    _mifareKeyController = TextEditingController(text: 'FFFFFFFFFFFF');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailableDumps();
    });
  }

  @override
  void dispose() {
    _rawCommandController.dispose();
    _passwordController.dispose();
    _currentPasswordController.dispose();
    _mirrorPageController.dispose();
    _mirrorByteController.dispose();
    _mifareBlockController.dispose();
    _mifareDataController.dispose();
    _mifareKeyController.dispose();
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
              isDecimal: _passwordInputIsDecimal,
              onDecimalChanged: (value) {
                setState(() {
                  _passwordInputIsDecimal = value;
                });
              },
            ),
          ],

          if (tool.id == 'remove_password') ...[
            const SizedBox(height: AppSpacing.xl),
            _RemovePasswordForm(
              controller: _currentPasswordController,
              isDecimal: _currentPasswordInputIsDecimal,
              onDecimalChanged: (value) {
                setState(() {
                  _currentPasswordInputIsDecimal = value;
                });
              },
            ),
          ],

          if (tool.id == 'restore_dump') ...[
            const SizedBox(height: AppSpacing.xl),
            _RestoreDumpForm(
              dumps: _availableDumps,
              selectedDump: _selectedDump,
              onRefresh: _loadAvailableDumps,
              onChanged: (dump) {
                setState(() {
                  _selectedDump = dump;
                });
              },
            ),
          ],

          if (tool.id == 'configure_mirror') ...[
            const SizedBox(height: AppSpacing.xl),
            _MirrorForm(
              pageController: _mirrorPageController,
              byteController: _mirrorByteController,
              mode: _mirrorMode,
              onModeChanged: (value) {
                if (value == null) return;
                setState(() {
                  _mirrorMode = value;
                });
              },
            ),
          ],

          if (tool.id == 'mifare_write_block') ...[
            const SizedBox(height: AppSpacing.xl),
            _MifareWriteBlockForm(
              blockController: _mifareBlockController,
              dataController: _mifareDataController,
              keyController: _mifareKeyController,
              keyType: _mifareKeyType,
              onKeyTypeChanged: (value) {
                if (value == null) return;
                setState(() {
                  _mifareKeyType = value;
                });
              },
            ),
          ],

          if (tool.id == 'mifare_clone') ...[
            const SizedBox(height: AppSpacing.xl),
            const _MifareCloneInfo(),
          ],

          if (tool.id == 'configure_counter') ...[
            const SizedBox(height: AppSpacing.xl),
            _CounterForm(
              enabled: _counterEnabled,
              passwordProtected: _counterPasswordProtected,
              onEnabledChanged: (value) {
                setState(() {
                  _counterEnabled = value;
                });
              },
              onPasswordProtectedChanged: (value) {
                setState(() {
                  _counterPasswordProtected = value;
                });
              },
            ),
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

    if (tool.id == 'copy_tag') {
      setState(() {
        _busy = true;
        _resultMessage = null;
      });
      final result = await _runCopyTag(session, operations);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _resultMessage = switch (result) {
          Ok(:final value) => value,
          Err(:final failure) => l10n.messageFor(failure),
        };
      });
      return;
    }

    if (tool.id == 'mifare_clone') {
      setState(() {
        _busy = true;
        _resultMessage = null;
      });
      final result = await _runCloneMifare(session, operations);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _resultMessage = switch (result) {
          Ok(:final value) => value,
          Err(:final failure) => l10n.messageFor(failure),
        };
      });
      return;
    }

    if (tool.id == 'mifare_write_block') {
      final parsed = _parseMifareBlockInputs();
      if (parsed case Err(:final failure)) {
        setState(() {
          _resultMessage = l10n.messageFor(failure);
        });
        return;
      }
    }

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
      final passwordResult = _parsePasswordInput(
        _passwordController.text.trim(),
        isDecimal: _passwordInputIsDecimal,
        fieldLabel: 'Şifre',
      );
      if (passwordResult case Err(:final failure)) {
        setState(() {
          _resultMessage = l10n.messageFor(failure);
        });
        return;
      }
    }

    if (tool.id == 'remove_password') {
      final passwordResult = _parsePasswordInput(
        _currentPasswordController.text.trim(),
        isDecimal: _currentPasswordInputIsDecimal,
        fieldLabel: 'Mevcut şifre',
      );
      if (passwordResult case Err(:final failure)) {
        setState(() {
          _resultMessage = l10n.messageFor(failure);
        });
        return;
      }
    }

    if (tool.id == 'restore_dump' && _selectedDump == null) {
      setState(() {
        _resultMessage = 'Lütfen bir döküm seçin.';
      });
      return;
    }

    if (tool.id == 'configure_mirror') {
      final pageText = _mirrorPageController.text.trim();
      final byteText = _mirrorByteController.text.trim();
      final page = int.tryParse(pageText);
      final byteOffset = int.tryParse(byteText);
      if (_mirrorMode != MirrorMode.none) {
        if (page == null || page < 0 || page > 255) {
          setState(() {
            _resultMessage = 'Mirror sayfası 0-255 arasında olmalı.';
          });
          return;
        }
        if (byteOffset == null || byteOffset < 0 || byteOffset > 3) {
          setState(() {
            _resultMessage = 'Mirror byte değeri 0-3 arasında olmalı.';
          });
          return;
        }
      }
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
          offerBackup: _autoBackupEnabled,
          warning: tool.risk == RiskLevel.danger
              ? 'Bu işlem geri alınamaz. Etiket kalıcı olarak değişecek.'
              : null,
        );
        if (confirmation == null || !confirmation.confirmed) {
          return const Err(OperationCancelled());
        }

        // ADR-0005 2. kapi: yikici islemden once otomatik yedek.
        final backup = await _ensureBackup(
          tag: tag,
          operations: operations,
          label: tool.title,
          requested: confirmation.takeBackup,
        );
        if (backup case Err(:final failure)) return Err(failure);

        final ack = DangerAck.userConfirmed(
          risk: switch (tool.risk) {
            RiskLevel.safe => OperationRisk.safe,
            RiskLevel.caution => OperationRisk.content,
            RiskLevel.warning => OperationRisk.config,
            RiskLevel.danger => OperationRisk.irreversible,
          },
          operationId: tool.id,
          targetUidHex: uidHex,
          backupTaken: (backup as Ok<bool>).value,
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

    // Islem sirasinda otomatik yedek alinmis olabilir — arsiv listesi
    // (ve "Dokumu geri yukle" secicisi) guncel kalsin.
    await _loadAvailableDumps();
  }

  /// Anahtar tarama raporunu okunabilir metne cevirir.
  ///
  /// Acilamayan sektorler de listelenir — kullanicinin hangi sektorde
  /// ozel anahtar oldugunu gormesi tarama sonucunun asil degeridir.
  String _formatKeyScanReport(MifareKeyScanReport report) {
    final lines = <String>[
      '${report.unlockedCount}/${report.totalSectors} sektör açıldı',
      '',
    ];

    for (var sector = 0; sector < report.totalSectors; sector++) {
      final entry = report.sectorKeys[sector];
      if (entry == null) {
        lines.add('S$sector: — (bilinen anahtar yok)');
        continue;
      }
      final keyName = entry.type == MifareKeyType.keyA ? 'A' : 'B';
      lines.add('S$sector: $keyName ${bytesToHex(entry.key)}');
    }

    if (report.allUnlocked) {
      lines
        ..add('')
        ..add('Tüm sektörler varsayılan anahtarlarla açıldı — '
            'bu kart korumasız.');
    }

    return lines.join('\n');
  }

  /// Ayarlardan "yikici islem oncesi otomatik yedek" acik mi?
  bool get _autoBackupEnabled => ref
      .read(settingsRepositoryProvider)
      .current
      .autoBackupBeforeDestructive;

  /// ADR-0005'in **2. kapisi**: yikici islemden once tam bellek dokumu alip
  /// dokum arsivine yazar.
  ///
  /// - Ayar kapaliysa ya da kullanici onay diyalogunda yedegi kapattiysa
  ///   hic denenmez, `Ok(false)` doner.
  /// - Yedek basariyla alinirsa `Ok(true)`.
  /// - Yedek **alinamazsa** islem varsayilan olarak iptal edilir; kullanici
  ///   acikca "yedeksiz devam et" derse `Ok(false)` ile gecilir, aksi halde
  ///   `Err(OperationCancelled())`.
  ///
  /// Donen bool dogrudan [DangerAck.backupTaken] alanina yazilir — bu alan
  /// gercegi soylemek zorunda, aksi halde kayit yaniltici olur.
  Future<Result<bool>> _ensureBackup({
    required NfcTagHandle tag,
    required TagOperations operations,
    required String label,
    required bool requested,
  }) async {
    if (!requested || !_autoBackupEnabled) return const Ok(false);

    final failure = await _saveBackup(
      tag: tag,
      operations: operations,
      label: label,
    );
    if (failure == null) return const Ok(true);

    if (!mounted) return const Err(OperationCancelled());
    final proceed = await _confirmWithoutBackup(failure);
    return proceed ? const Ok(false) : const Err(OperationCancelled());
  }

  /// Dokumu alip arsive yazar. Basariliysa `null`, aksi halde sebebi doner.
  Future<NfcFailure?> _saveBackup({
    required NfcTagHandle tag,
    required TagOperations operations,
    required String label,
  }) async {
    final memoryResult = await operations.readMemory(tag);
    if (memoryResult case Err(:final failure)) return failure;
    final memory = (memoryResult as Ok<TagMemory>).value;

    // Yonga adi yalnizca etiketleme icin — okunamazsa yedegi engellemez.
    final identity = (await operations.identify(tag)).valueOrNull;

    final saveResult = await ref
        .read(dumpRepositoryProvider)
        .add(
          TagDump(
            id: null,
            uidHex: bytesToHex(tag.uid),
            createdAt: DateTime.now(),
            bytes: memory.bytes,
            pageSize: memory.pageSize,
            startPage: memory.startPage,
            label: '$label öncesi yedek',
            chipDisplayName: identity?.displayName,
            reason: DumpReason.automaticBackup,
          ),
        );

    return switch (saveResult) {
      Ok() => null,
      Err(:final failure) => failure,
    };
  }

  /// Yedek alinamadiginda kullaniciya sorar. Varsayilan cevap **hayir**.
  Future<bool> _confirmWithoutBackup(NfcFailure failure) async {
    final l10n = AppLocalizations.of(context);
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.backup_outlined),
        title: const Text('Yedek alınamadı'),
        content: Text(
          '${l10n.messageFor(failure)}\n\n'
          'Yedek olmadan devam ederseniz bu işlemi geri almanız '
          'mümkün olmayabilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yedeksiz devam et'),
          ),
        ],
      ),
    );
    return proceed ?? false;
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
      case 'mifare_keys':
        final result = await operations.scanMifareClassicKeys(tag);
        return result.map(_formatKeyScanReport);
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
      case 'factory_reset':
        final result = await operations.factoryReset(tag, ack: ack);
        return result.map((_) => 'Etiket fabrika ayarlarına döndürüldü');
      case 'restore_dump':
        final dump = _selectedDump;
        if (dump == null) {
          return const Err(InvalidArgument('Döküm seçilmedi'));
        }
        final result = await operations.restoreDump(tag, dump, ack: ack);
        return result.map((_) => 'Döküm geri yüklendi');
      case 'set_password':
        final passwordResult = _parsePasswordInput(
          _passwordController.text.trim(),
          isDecimal: _passwordInputIsDecimal,
          fieldLabel: 'Şifre',
        );
        if (passwordResult case Err(:final failure)) return Err(failure);
        final password = (passwordResult as Ok<Uint8List>).value;
        final result = await operations.setPassword(
          tag,
          setup: PasswordSetup(
            password: password,
            pack: Uint8List.fromList([0x00, 0x00]),
            protectFromPage: 0x04,
            scope: PasswordProtectionScope.writeOnly,
            authLimit: 0,
            protectCounter: false,
          ),
          ack: ack,
        );
        return result.map((_) => 'Şifre koruması etkinleştirildi');
      case 'remove_password':
        final passwordResult = _parsePasswordInput(
          _currentPasswordController.text.trim(),
          isDecimal: _currentPasswordInputIsDecimal,
          fieldLabel: 'Mevcut şifre',
        );
        if (passwordResult case Err(:final failure)) return Err(failure);
        final result = await operations.removePassword(
          tag,
          currentPassword: (passwordResult as Ok<Uint8List>).value,
          ack: ack,
        );
        return result.map((_) => 'Şifre koruması kaldırıldı');
      case 'configure_mirror':
        final page = _mirrorMode == MirrorMode.none
            ? 0
            : int.parse(_mirrorPageController.text.trim());
        final byteOffset = _mirrorMode == MirrorMode.none
            ? 0
            : int.parse(_mirrorByteController.text.trim());
        final result = await operations.configureMirror(
          tag,
          setup: MirrorSetup(
            mode: _mirrorMode,
            page: page,
            byteOffset: byteOffset,
          ),
          ack: ack,
        );
        return result.map((_) => 'UID / sayaç yansıtma ayarlandı');
      case 'configure_counter':
        final result = await operations.configureCounter(
          tag,
          enabled: _counterEnabled,
          passwordProtected: _counterPasswordProtected,
          ack: ack,
        );
        return result.map((_) => 'Sayaç ayarları güncellendi');
      case 'make_read_only':
        final result = await operations.makeReadOnly(tag, ack: ack);
        return result.map((_) => 'Etiket kalıcı olarak salt-okunur yapıldı');
      case 'mifare_write_block':
        final parsed = _parseMifareBlockInputs();
        if (parsed case Err(:final failure)) return Err(failure);
        final inputs =
            (parsed as Ok<({int block, Uint8List data, Uint8List key})>).value;
        final result = await operations.writeMifareClassicBlock(
          tag,
          blockIndex: inputs.block,
          data: inputs.data,
          key: inputs.key,
          keyType: _mifareKeyType,
          ack: ack,
        );
        return result.map(
          (_) => inputs.block == 0
              ? 'Blok 0 (UID) yazıldı'
              : 'Blok ${inputs.block} yazıldı',
        );
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

  Future<Result<String>> _runCopyTag(
    NfcSessionService session,
    TagOperations operations,
  ) async {
    final sourceResult = await session
        .runOnce<({String uidHex, NdefMessageEntity message})>(
          onTag: (sourceTag) async {
            final readResult = await sourceTag.readNdef();
            return switch (readResult) {
              Err(:final failure) => Err(failure),
              Ok(:final value) when value == null => const Err(
                TagNotSupported(detail: 'Kaynak etiket NDEF değil'),
              ),
              Ok(:final value) => Ok((
                uidHex: bytesToHex(sourceTag.uid),
                message: value!,
              )),
            };
          },
        );

    if (sourceResult case Err(:final failure)) return Err(failure);
    final sourceData =
        (sourceResult as Ok<({String uidHex, NdefMessageEntity message})>)
            .value;

    final targetResult = await session.runOnce<String>(
      onTag: (targetTag) async {
        if (!mounted) return const Err(OperationCancelled());
        final confirmation = await DangerDialog.show(
          context,
          title: 'Etiketi kopyala',
          description: 'Kaynak etiketin NDEF içeriği bu etikete yazılacak.',
          risk: RiskLevel.caution,
          targetUid: formatUid(targetTag.uid),
          offerBackup: _autoBackupEnabled,
        );
        if (confirmation == null || !confirmation.confirmed) {
          return const Err(OperationCancelled());
        }

        // Hedef etiketin mevcut icerigi uzerine yazilacak — once yedekle.
        final backup = await _ensureBackup(
          tag: targetTag,
          operations: operations,
          label: 'Etiketi kopyala',
          requested: confirmation.takeBackup,
        );
        if (backup case Err(:final failure)) return Err(failure);

        final ack = DangerAck.userConfirmed(
          risk: OperationRisk.content,
          operationId: 'copy_tag',
          targetUidHex: bytesToHex(targetTag.uid),
          backupTaken: (backup as Ok<bool>).value,
        );

        final result = await operations.copyNdefTo(
          targetTag,
          message: sourceData.message,
          sourceUidHex: sourceData.uidHex,
          ack: ack,
        );
        return result.map(
          (report) =>
              'Kopyalandı: ${report.recordCount} kayıt, ${report.bytesWritten} byte',
        );
      },
    );

    return switch (targetResult) {
      Ok(:final value) => Ok(value),
      Err(:final failure) => Err(failure),
    };
  }

  /// Magic kart klonlama: önce kaynak Classic kartı tam okunur, sonra
  /// magic hedef karta blok 0 dahil yazılır (iki ayrı dokunuş).
  Future<Result<String>> _runCloneMifare(
    NfcSessionService session,
    TagOperations operations,
  ) async {
    final sourceResult = await session
        .runOnce<({String uidHex, TagMemory memory})>(
          onTag: (sourceTag) async {
            if (sourceTag.mifareClassicInfo == null) {
              return const Err(
                TagNotSupported(detail: 'Kaynak etiket MIFARE Classic değil'),
              );
            }
            final memResult = await operations.readMemory(sourceTag);
            return memResult.map(
              (memory) =>
                  (uidHex: bytesToHex(sourceTag.uid), memory: memory),
            );
          },
        );

    if (sourceResult case Err(:final failure)) return Err(failure);
    final source =
        (sourceResult as Ok<({String uidHex, TagMemory memory})>).value;

    if (!mounted) return const Err(OperationCancelled());

    return session.runOnce<String>(
      onTag: (targetTag) async {
        if (targetTag.mifareClassicInfo == null) {
          return const Err(
            TagNotSupported(detail: 'Hedef etiket MIFARE Classic değil'),
          );
        }
        if (!mounted) return const Err(OperationCancelled());
        final confirmation = await DangerDialog.show(
          context,
          title: 'Magic kart klonla',
          description:
              'Kaynak kartın tüm blokları (blok 0 dahil) bu karta yazılacak. '
              'Hedef, blok 0 yazılabilir bir magic (Gen2/CUID) kart olmalı.',
          risk: RiskLevel.warning,
          targetUid: formatUid(targetTag.uid),
          offerBackup: _autoBackupEnabled,
        );
        if (confirmation == null || !confirmation.confirmed) {
          return const Err(OperationCancelled());
        }

        // Hedef magic kartin mevcut icerigi tamamen ezilecek — once yedekle.
        final backup = await _ensureBackup(
          tag: targetTag,
          operations: operations,
          label: 'Magic kart klonla',
          requested: confirmation.takeBackup,
        );
        if (backup case Err(:final failure)) return Err(failure);

        final ack = DangerAck.userConfirmed(
          risk: OperationRisk.config,
          operationId: 'mifare_clone',
          targetUidHex: bytesToHex(targetTag.uid),
          backupTaken: (backup as Ok<bool>).value,
        );

        final result = await operations.cloneMifareClassicTo(
          targetTag,
          source: source.memory,
          sourceUidHex: source.uidHex,
          ack: ack,
        );
        return result.map(
          (report) =>
              'Klon tamamlandı: ${report.blocksWritten} blok yazıldı, '
              '${report.blocksSkipped} atlandı, ${report.blocksFailed} başarısız.\n'
              'Blok 0 (UID): ${report.blockZeroWritten ? "yazıldı" : "yazılamadı"}.',
        );
      },
    );
  }

  /// `mifare_write_block` formundaki blok / veri / anahtar alanlarını çözer.
  Result<({int block, Uint8List data, Uint8List key})>
  _parseMifareBlockInputs() {
    final block = int.tryParse(_mifareBlockController.text.trim());
    if (block == null || block < 0) {
      return const Err(InvalidArgument('Blok numarası 0 veya daha büyük olmalı'));
    }

    final dataText = _mifareDataController.text.trim();
    if (!isValidHex(dataText)) {
      return const Err(InvalidArgument('Veri hex değeri geçersiz'));
    }
    final data = hexToBytes(dataText);
    if (data.length != 16) {
      return const Err(
        InvalidArgument('Blok verisi tam 16 byte (32 hex karakter) olmalı'),
      );
    }

    final keyText = _mifareKeyController.text.trim();
    if (!isValidHex(keyText)) {
      return const Err(InvalidArgument('Anahtar hex değeri geçersiz'));
    }
    final key = hexToBytes(keyText);
    if (key.length != 6) {
      return const Err(
        InvalidArgument('Anahtar tam 6 byte (12 hex karakter) olmalı'),
      );
    }

    return Ok((block: block, data: data, key: key));
  }

  Future<void> _loadAvailableDumps() async {
    final repo = ref.read(dumpRepositoryProvider);
    final result = await repo.listAll(limit: 25);
    if (!mounted) return;

    setState(() {
      _availableDumps = switch (result) {
        Ok(:final value) => value,
        Err() => const <TagDump>[],
      };
      if (_selectedDump == null && _availableDumps.isNotEmpty) {
        _selectedDump = _availableDumps.first;
      }
      if (_availableDumps.isEmpty) {
        _selectedDump = null;
      }
    });
  }

  Result<Uint8List> _parsePasswordInput(
    String value, {
    required bool isDecimal,
    required String fieldLabel,
  }) {
    if (value.isEmpty) {
      return Err(InvalidArgument('$fieldLabel girin'));
    }

    if (isDecimal) {
      final parsed = int.tryParse(value);
      if (parsed == null || parsed < 0 || parsed > 0xFFFFFFFF) {
        return Err(
          InvalidArgument(
            '$fieldLabel ondalık değeri 0-4294967295 arasında olmalı',
          ),
        );
      }
      return Ok(intToBytesBigEndian(parsed, 4));
    }

    if (!isValidHex(value)) {
      return Err(InvalidArgument('$fieldLabel hex değeri geçersiz'));
    }
    final bytes = hexToBytes(value);
    if (bytes.length != 4) {
      return Err(InvalidArgument('$fieldLabel 4 byte (8 hex karakter) olmalı'));
    }
    return Ok(bytes);
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
          Text('Komut', style: Theme.of(context).textTheme.titleSmall),
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
    required this.isDecimal,
    required this.onDecimalChanged,
  });

  final TextEditingController passwordController;
  final bool isDecimal;
  final ValueChanged<bool> onDecimalChanged;

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
              labelText: 'Şifre (4 byte)',
              hintText: '01020304',
              prefixIcon: Icon(Icons.password),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: isDecimal,
            onChanged: onDecimalChanged,
            title: const Text('Ondalık giriş'),
            subtitle: const Text(
              'Kapalıysa hex, açıksa 0-4294967295 arası sayı girilir.',
            ),
          ),
        ],
      ),
    ),
  );
}

class _RemovePasswordForm extends StatelessWidget {
  const _RemovePasswordForm({
    required this.controller,
    required this.isDecimal,
    required this.onDecimalChanged,
  });

  final TextEditingController controller;
  final bool isDecimal;
  final ValueChanged<bool> onDecimalChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Şifre kaldır', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Mevcut şifre (4 byte)',
              hintText: '01020304',
              prefixIcon: Icon(Icons.lock_open_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: isDecimal,
            onChanged: onDecimalChanged,
            title: const Text('Ondalık giriş'),
            subtitle: const Text(
              'Kapalıysa hex, açıksa 0-4294967295 arası sayı girilir.',
            ),
          ),
        ],
      ),
    ),
  );
}

class _RestoreDumpForm extends StatelessWidget {
  const _RestoreDumpForm({
    required this.dumps,
    required this.selectedDump,
    required this.onRefresh,
    required this.onChanged,
  });

  final List<TagDump> dumps;
  final TagDump? selectedDump;
  final VoidCallback onRefresh;
  final ValueChanged<TagDump?> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Döküm seç',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Yenile',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (dumps.isEmpty)
            const Text('Kayıtlı döküm bulunamadı.')
          else
            DropdownButtonFormField<TagDump>(
              initialValue: selectedDump,
              items: dumps
                  .map(
                    (dump) => DropdownMenuItem(
                      value: dump,
                      child: Text(
                        '${dump.label ?? dump.uidHex} · ${dump.bytes.length} byte',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onChanged,
              decoration: const InputDecoration(
                labelText: 'Geri yüklenecek döküm',
              ),
            ),
        ],
      ),
    ),
  );
}

class _MirrorForm extends StatelessWidget {
  const _MirrorForm({
    required this.pageController,
    required this.byteController,
    required this.mode,
    required this.onModeChanged,
  });

  final TextEditingController pageController;
  final TextEditingController byteController;
  final MirrorMode mode;
  final ValueChanged<MirrorMode?> onModeChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UID / sayaç yansıtma',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<MirrorMode>(
            initialValue: mode,
            onChanged: onModeChanged,
            items: const [
              DropdownMenuItem(value: MirrorMode.none, child: Text('Kapalı')),
              DropdownMenuItem(value: MirrorMode.uid, child: Text('UID')),
              DropdownMenuItem(value: MirrorMode.counter, child: Text('Sayaç')),
              DropdownMenuItem(
                value: MirrorMode.uidAndCounter,
                child: Text('UID + sayaç'),
              ),
            ],
            decoration: const InputDecoration(labelText: 'Yansıtma modu'),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: pageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Yansıtma sayfası',
                    hintText: '6',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: byteController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Yansıtma byte',
                    hintText: '0',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _CounterForm extends StatelessWidget {
  const _CounterForm({
    required this.enabled,
    required this.passwordProtected,
    required this.onEnabledChanged,
    required this.onPasswordProtectedChanged,
  });

  final bool enabled;
  final bool passwordProtected;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onPasswordProtectedChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sayaç ayarları', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            onChanged: onEnabledChanged,
            title: const Text('Sayaç etkin'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: passwordProtected,
            onChanged: onPasswordProtectedChanged,
            title: const Text('Sayaç şifre korumalı'),
          ),
        ],
      ),
    ),
  );
}

class _MifareWriteBlockForm extends StatelessWidget {
  const _MifareWriteBlockForm({
    required this.blockController,
    required this.dataController,
    required this.keyController,
    required this.keyType,
    required this.onKeyTypeChanged,
  });

  final TextEditingController blockController;
  final TextEditingController dataController;
  final TextEditingController keyController;
  final MifareKeyType keyType;
  final ValueChanged<MifareKeyType?> onKeyTypeChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MIFARE Classic blok yazma',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Blok 0, kartın UID/üretici bloğudur; yalnızca magic '
            '(Gen2/CUID) kartlarda yazılabilir. Blok 0 için BCC (5. byte) '
            'otomatik doğrulanır — hatalıysa yazma reddedilir.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: blockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Blok numarası',
              hintText: '0',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: dataController,
            decoration: const InputDecoration(
              labelText: 'Veri (16 byte / 32 hex)',
              hintText: '04A1B2C3D4080400...',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: keyController,
            decoration: const InputDecoration(
              labelText: 'Sektör anahtarı (6 byte)',
              hintText: 'FFFFFFFFFFFF',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<MifareKeyType>(
            initialValue: keyType,
            onChanged: onKeyTypeChanged,
            items: const [
              DropdownMenuItem(
                value: MifareKeyType.keyA,
                child: Text('Anahtar A'),
              ),
              DropdownMenuItem(
                value: MifareKeyType.keyB,
                child: Text('Anahtar B'),
              ),
            ],
            decoration: const InputDecoration(labelText: 'Anahtar tipi'),
          ),
        ],
      ),
    ),
  );
}

class _MifareCloneInfo extends StatelessWidget {
  const _MifareCloneInfo();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'İki aşamalı klonlama',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            '1) Önce kaynak kartı okutun (varsayılan anahtarlarla tam döküm).\n'
            '2) Sonra magic (Gen2/CUID) hedef kartı okutun; blok 0 dahil tüm '
            'veri blokları yazılır. Sektör fragmanları (anahtar/erişim '
            'byte\'ları) güvenlik için yazılmaz.\n\n'
            'Hedef standart bir kartsa blok 0 yazılamaz ve işlem reddedilir. '
            'Kaynağın anahtarları varsayılan değilse okunamayan bloklar '
            'atlanır.',
          ),
        ],
      ),
    ),
  );
}
