import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:localization/localization.dart';
import 'package:ndef_codec/ndef_codec.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/wifi_credentials.dart';

/// Kayit icerigine gore eylem dugmeleri.
///
/// URL/tel/mailto/sms/geo icin sistem uygulamasini acar, vCard'i kisi
/// olarak paylasir, Wi-Fi kaydinda SSID/parolayi gosterir (A10).
class RecordContentActions extends StatelessWidget {
  const RecordContentActions({required this.content, super.key});

  final NdefContent content;

  static const String _wifiMimeType = 'application/vnd.wfa.wsc';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chips = switch (content) {
      UriContent(:final uri, :final scheme) => [
        _ActionChip(
          label: _labelForScheme(l10n, scheme),
          icon: _iconForScheme(scheme),
          onTap: () => _launch(context, uri),
        ),
      ],
      VCardContent() => [
        _ActionChip(
          label: l10n.readActionShareContact,
          icon: Icons.person_add_alt_1_outlined,
          onTap: () => _shareVCard(content as VCardContent),
        ),
      ],
      // Cozumlenebilen WSC yukleri artik `WifiContent` olarak gelir.
      WifiContent() => [
        _ActionChip(
          label: l10n.readActionWifiInfo,
          icon: Icons.wifi,
          onTap: () => _showWifiContentDialog(context, content as WifiContent),
        ),
      ],
      // Cozumlenemeyen (bozuk ya da SSID'siz) WSC yukleri `MimeContent`
      // olarak duser — yine de ham cozumlemeyi deneriz.
      MimeContent(:final mimeType, :final data)
          when mimeType.trim().toLowerCase() == _wifiMimeType => [
        _ActionChip(
          label: l10n.readActionWifiInfo,
          icon: Icons.wifi,
          onTap: () => _showWifiDialog(context, data),
        ),
      ],
      _ => const <Widget>[],
    };

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(spacing: 8, runSpacing: 4, children: chips),
    );
  }

  static String _labelForScheme(AppStrings l10n, String scheme) =>
      switch (scheme) {
        'tel' => l10n.readActionCall,
        'mailto' => l10n.readActionEmail,
        'sms' || 'smsto' => l10n.readActionSms,
        'geo' => l10n.readActionMap,
        _ => l10n.readActionOpenLink,
      };

  static IconData _iconForScheme(String scheme) => switch (scheme) {
    'tel' => Icons.call,
    'mailto' => Icons.email_outlined,
    'sms' || 'smsto' => Icons.sms_outlined,
    'geo' => Icons.map_outlined,
    _ => Icons.open_in_new,
  };

  Future<void> _launch(BuildContext context, String uri) async {
    final parsed = Uri.tryParse(uri);
    final launched =
        parsed != null &&
        await launchUrl(parsed, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.readActionFailed)));
    }
  }

  Future<void> _shareVCard(VCardContent content) async {
    final text = NdefConverter.encodeVCardText(content);
    final bytes = Uint8List.fromList(utf8.encode(text));
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'text/vcard', path: 'contact.vcf'),
        ],
      ),
    );
  }

  /// Cozumlenmis `WifiContent` icin bilgi diyalogu.
  ///
  /// Otomatik baglanma yapilamaz: Android bunun icin sistem izni ister ve
  /// Flutter tarafinda karsiligi yok. Kullanici bilgileri gorup elle
  /// baglanir (bkz. T2.12).
  void _showWifiContentDialog(BuildContext context, WifiContent wifi) {
    final l10n = AppLocalizations.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.readWifiDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WifiRow(label: l10n.readWifiSsid, value: wifi.ssid),
            if (wifi.password.isNotEmpty)
              _WifiRow(label: l10n.readWifiPassword, value: wifi.password),
            _WifiRow(label: l10n.readWifiSecurity, value: wifi.auth.label),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionClose),
          ),
        ],
      ),
    );
  }

  void _showWifiDialog(BuildContext context, Uint8List data) {
    final l10n = AppLocalizations.of(context);
    final credentials = WifiCredentials.tryParse(data);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.readWifiDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WifiRow(label: l10n.readWifiSsid, value: credentials?.ssid),
            _WifiRow(
              label: l10n.readWifiPassword,
              value: credentials?.password,
            ),
            _WifiRow(
              label: l10n.readWifiSecurity,
              value: credentials?.securityLabel,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionClose),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 18),
    label: Text(label),
    onPressed: onTap,
  );
}

class _WifiRow extends StatelessWidget {
  const _WifiRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(value!)),
        ],
      ),
    );
  }
}
