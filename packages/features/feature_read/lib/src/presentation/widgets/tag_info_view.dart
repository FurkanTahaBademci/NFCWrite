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
      ],
    );
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
    MimeContent() => Icons.description_outlined,
    ExternalContent() => Icons.extension_outlined,
    EmptyContent() => Icons.crop_free,
    RawContent() => Icons.data_object,
  };

  static String _titleFor(NdefContent content) => switch (content) {
    TextContent() => 'Metin',
    UriContent() => 'Baglanti',
    VCardContent() => 'vCard',
    MimeContent(:final mimeType) => mimeType,
    ExternalContent() => 'Harici tip',
    EmptyContent() => 'Bos',
    RawContent() => 'Ham veri',
  };
}
