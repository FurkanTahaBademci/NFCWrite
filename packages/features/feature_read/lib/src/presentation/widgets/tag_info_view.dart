import 'dart:typed_data';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:localization/localization.dart';
import 'package:ndef_codec/ndef_codec.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';

import 'record_content_actions.dart';

/// Okunan etiketin detay gorunumu — sekmeli.
class TagInfoView extends StatelessWidget {
  const TagInfoView({required this.info, super.key});

  final NfcTagInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasMemory = info.memory != null;

    return DefaultTabController(
      length: hasMemory ? 3 : 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.readSectionIdentity),
              Tab(text: l10n.readSectionNdef),
              if (hasMemory) Tab(text: l10n.readSectionMemory),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _IdentityTab(info: info),
                _NdefTab(info: info),
                if (hasMemory)
                  HexDumpView(
                    bytes: info.memory!.bytes,
                    bytesPerRow: info.memory!.pageSize,
                    startPage: info.memory!.startPage,
                    unreadablePages: info.memory!.unreadablePages,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityTab extends StatelessWidget {
  const _IdentityTab({required this.info});

  final NfcTagInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final identity = info.identity;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              TagBadge(
                label: info.isNdefFormatted
                    ? l10n.readFormatted
                    : l10n.readNotFormatted,
                icon: info.isNdefFormatted
                    ? Icons.check_circle_outline
                    : Icons.help_outline,
                risk: info.isNdefFormatted ? RiskLevel.safe : RiskLevel.caution,
              ),
              TagBadge(
                label: info.isWritable ? l10n.readWritable : l10n.readReadOnly,
                icon: info.isWritable
                    ? Icons.edit_outlined
                    : Icons.lock_outline,
                risk: info.isWritable ? RiskLevel.safe : RiskLevel.warning,
              ),
              if (info.isPasswordProtected)
                TagBadge(
                  label: l10n.readPasswordProtected,
                  icon: Icons.password,
                  risk: RiskLevel.warning,
                ),
            ],
          ),
        ),

        if (info.maxNdefSize != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: CapacityBar(
              used: info.currentNdefSize ?? 0,
              total: info.maxNdefSize!,
              label: l10n.readCapacity,
            ),
          ),

        const SizedBox(height: AppSpacing.sm),
        const Divider(),

        InfoRow(
          label: l10n.readUid,
          value: formatUid(info.uid),
          icon: Icons.fingerprint,
          monospace: true,
        ),
        InfoRow(
          label: l10n.readUidReversed,
          value: reverseUidHex(info.uid),
          icon: Icons.swap_horiz,
          monospace: true,
        ),
        InfoRow(
          label: l10n.readUidDecimal,
          value: formatUidDecimal(info.uid),
          icon: Icons.pin_outlined,
          monospace: true,
        ),
        InfoRow(
          label: l10n.readChip,
          value: identity.displayName ?? identity.family.name,
          icon: Icons.memory,
        ),
        InfoRow(
          label: l10n.readManufacturer,
          value: identity.manufacturer.displayName,
          icon: Icons.factory_outlined,
        ),
        if (identity.totalBytes != null)
          InfoRow(
            label: 'Toplam bellek',
            value: '${identity.totalBytes} byte',
            icon: Icons.sd_storage_outlined,
          ),
        if (identity.userBytes != null)
          InfoRow(
            label: 'Kullanici alani',
            value: '${identity.userBytes} byte',
            icon: Icons.storage_outlined,
          ),
        if (info.atqa != null)
          InfoRow(
            label: 'ATQA',
            value: bytesToHex(info.atqa!, separator: ' '),
            icon: Icons.badge_outlined,
            monospace: true,
          ),
        if (info.sak != null)
          InfoRow(
            label: 'SAK',
            value: '0x${info.sak!.toHexByte()}',
            icon: Icons.badge_outlined,
            monospace: true,
          ),
        if (info.counterValue != null)
          InfoRow(
            label: 'NFC sayacı',
            value: '${info.counterValue}',
            icon: Icons.numbers,
          ),

        SectionHeader(l10n.readTechnologies),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final tech in info.technologies)
                TagBadge(label: tech.name, icon: Icons.settings_input_antenna),
            ],
          ),
        ),

        // Asagidaki uc bolum yalnizca DERIN okumada (inspect deep) dolar.
        // Ayarlardan "okurken tam dokum al" acilirsa her taramada gorunur.
        if (info.config != null) ..._configSection(info.config!),
        if (info.lockStatus != null) ..._lockSection(info.lockStatus!),
        if (info.signature != null) ..._signatureSection(info.signature!),
      ],
    );
  }

  /// Yapilandirma sayfalarinin insan-okunur dokumu (AUTH0, PROT, CFGLCK,
  /// AUTHLIM, MIRROR).
  List<Widget> _configSection(NtagConfig config) => [
    const SectionHeader('Yapılandırma'),

    if (config.configLocked)
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: TagBadge(
          label: 'CFGLCK — yapılandırma kalıcı olarak dondurulmuş',
          icon: Icons.ac_unit,
          risk: RiskLevel.danger,
        ),
      ),

    InfoRow(
      label: 'Şifre koruması (AUTH0)',
      value: config.isPasswordProtected
          ? 'Sayfa 0x${config.auth0.toHexByte()} ve sonrası'
          : 'Kapalı (0xFF)',
      icon: config.isPasswordProtected ? Icons.lock_outline : Icons.lock_open,
      monospace: true,
    ),
    if (config.isPasswordProtected)
      InfoRow(
        label: 'Koruma kapsamı (PROT)',
        value: config.isReadProtected
            ? 'Okuma + yazma korumalı'
            : 'Yalnızca yazma korumalı',
        icon: Icons.shield_outlined,
      ),
    InfoRow(
      label: 'Deneme limiti (AUTHLIM)',
      value: config.authLimit == 0
          ? 'Sınırsız'
          : '${config.authLimit} yanlış deneme sonrası kilitlenir',
      icon: Icons.repeat,
    ),
    InfoRow(
      label: 'NFC sayacı',
      value: config.counterEnabled
          ? (config.counterPasswordProtected ? 'Açık (şifreli)' : 'Açık')
          : 'Kapalı',
      icon: Icons.numbers,
    ),
    InfoRow(
      label: 'Yansıtma (MIRROR)',
      value: switch (config.mirrorMode) {
        MirrorMode.none => 'Kapalı',
        MirrorMode.uid =>
          'UID → sayfa ${config.mirrorPage}, byte ${config.mirrorByte}',
        MirrorMode.counter =>
          'Sayaç → sayfa ${config.mirrorPage}, byte ${config.mirrorByte}',
        MirrorMode.uidAndCounter =>
          'UID + sayaç → sayfa ${config.mirrorPage}, byte ${config.mirrorByte}',
      },
      icon: Icons.flip_to_front,
    ),
    InfoRow(
      label: 'Güçlü modülasyon',
      value: config.strongModulation ? 'Açık' : 'Kapalı',
      icon: Icons.graphic_eq,
    ),
  ];

  /// Kilit byte'larinin cozumu — hangi sayfalar yazmaya kapali.
  List<Widget> _lockSection(LockStatus lock) {
    final locked = lock.lockedPages.toList()..sort();
    final blockLocked = lock.blockLockedPages.toList()..sort();

    return [
      const SectionHeader('Kilit durumu'),

      if (lock.permanentlyReadOnly)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: TagBadge(
            label: 'Etiket kalıcı olarak salt-okunur',
            icon: Icons.lock,
            risk: RiskLevel.danger,
          ),
        ),

      InfoRow(
        label: 'Kilitli sayfalar',
        value: locked.isEmpty ? 'Yok' : _formatPageList(locked),
        icon: Icons.grid_off,
        monospace: locked.isNotEmpty,
      ),
      if (blockLocked.isNotEmpty)
        InfoRow(
          label: 'Kilit bitleri dondurulmuş (block-lock)',
          value: _formatPageList(blockLocked),
          icon: Icons.lock_clock,
          monospace: true,
        ),
      InfoRow(
        label: 'Capability Container (sayfa 3)',
        value: lock.capabilityContainerLocked ? 'Kilitli' : 'Açık',
        icon: Icons.inventory_2_outlined,
      ),
    ];
  }

  /// ECC orijinallik imzasi.
  ///
  /// Dogrulama sonucu simdilik gosterilmiyor: NXP genel anahtari
  /// (`NxpOriginalityKeys`) datasheet ile dogrulanamadigi icin bilerek
  /// bos birakildi — bkz. T4.12. Imzanin kendisi yine de degerlidir.
  List<Widget> _signatureSection(Uint8List signature) => [
    const SectionHeader('Orijinallik imzası'),
    InfoRow(
      label: 'ECC imzası (${signature.length} byte)',
      value: bytesToHex(signature, separator: ' '),
      icon: Icons.verified_outlined,
      monospace: true,
    ),
    const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Text(
        'İmza okundu ancak doğrulanamadı: üreticinin genel anahtarı '
        'uygulamada henüz tanımlı değil.',
      ),
    ),
  ];

  /// Sayfa listesini araliklara kisaltir: `4-9, 12, 15-16`.
  String _formatPageList(List<int> pages) {
    final parts = <String>[];
    var start = pages.first;
    var previous = start;

    for (final page in pages.skip(1)) {
      if (page == previous + 1) {
        previous = page;
        continue;
      }
      parts.add(start == previous ? '$start' : '$start-$previous');
      start = page;
      previous = page;
    }
    parts.add(start == previous ? '$start' : '$start-$previous');

    return parts.join(', ');
  }
}

class _NdefTab extends StatelessWidget {
  const _NdefTab({required this.info});

  final NfcTagInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = info.ndefMessage;

    if (message == null || message.isEmpty) {
      return EmptyState(icon: Icons.inbox_outlined, title: l10n.readNoRecords);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: message.records.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => _RecordCard(
        index: index,
        record: message.records[index],
        content: NdefConverter.decode(message.records[index]),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.index,
    required this.record,
    required this.content,
  });

  final int index;
  final NdefRecordEntity record;
  final NdefContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 16,
          child: Icon(_iconFor(content), size: 18),
        ),
        title: Text(_titleFor(content)),
        subtitle: Text(
          content.summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        children: [
          InfoRow(
            label: 'TNF',
            value: record.typeNameFormat.name,
            copyable: false,
          ),
          if (record.type.isNotEmpty)
            InfoRow(label: 'Tip', value: record.typeAsString, monospace: true),
          if (record.identifier.isNotEmpty)
            InfoRow(
              label: 'Id',
              value: bytesToHex(record.identifier, separator: ' '),
              monospace: true,
            ),
          InfoRow(
            label: 'Yük (${record.payload.length} byte)',
            value: bytesToHex(record.payload, separator: ' '),
            monospace: true,
          ),
          RecordContentActions(content: content),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Kayıt ${index + 1} · ${record.byteLength} byte',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(NdefContent content) => switch (content) {
    TextContent() => Icons.text_fields,
    UriContent(:final scheme) => switch (scheme) {
      'tel' => Icons.phone,
      'mailto' => Icons.email_outlined,
      'sms' => Icons.sms_outlined,
      'geo' => Icons.place_outlined,
      _ => Icons.link,
    },
    VCardContent() => Icons.badge_outlined,
    WifiContent() => Icons.wifi,
    MimeContent() => Icons.description_outlined,
    ExternalContent() => Icons.extension_outlined,
    EmptyContent() => Icons.crop_free,
    RawContent() => Icons.data_object,
  };

  static String _titleFor(NdefContent content) => switch (content) {
    TextContent() => 'Metin',
    UriContent() => 'Baglanti',
    VCardContent() => 'vCard',
    WifiContent() => 'Wi-Fi ağı',
    MimeContent(:final mimeType) => mimeType,
    ExternalContent() => 'Harici tip',
    EmptyContent() => 'Bos',
    RawContent() => 'Ham veri',
  };
}
