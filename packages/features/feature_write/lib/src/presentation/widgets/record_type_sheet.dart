import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:ndef_codec/ndef_codec.dart';

/// Kayit tipi secici + basit sihirbaz.
///
/// **Iskelet.** Su an yalnizca metin ve baglanti kaydi olusturulabiliyor.
/// 26 kayit tipinin tamami ve kategorili/aranabilir secici T3'un isi:
/// `.claude/tracks/T3-write.md` gorev T3.35 ve T3.36.
abstract final class RecordTypeSheet {
  /// Secici sayfayi acar. Kullanici vazgecerse null doner.
  static Future<NdefContent?> show(BuildContext context) =>
      showModalBottomSheet<NdefContent>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _RecordTypePicker(),
      );
}

class _RecordTypePicker extends StatelessWidget {
  const _RecordTypePicker();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SectionHeader('Kayit tipi secin'),
        ListTile(
          leading: const Icon(Icons.text_fields),
          title: const Text('Metin'),
          subtitle: const Text('Duz metin kaydi'),
          onTap: () async {
            final content = await _showTextEditor(context);
            if (content != null && context.mounted) {
              Navigator.of(context).pop(content);
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.link),
          title: const Text('Baglanti / URL'),
          subtitle: const Text('Web adresi, telefon, e-posta'),
          onTap: () async {
            final content = await _showUriEditor(context);
            if (content != null && context.mounted) {
              Navigator.of(context).pop(content);
            }
          },
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Diger 24 kayit tipi (WiFi, vCard, Bluetooth, konum, uygulama…) '
            'T3 is kolunda ekleniyor.',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ),
  );

  static Future<NdefContent?> _showTextEditor(BuildContext context) =>
      _showSingleFieldDialog(
        context,
        title: 'Metin kaydi',
        label: 'Metin',
        icon: Icons.text_fields,
        build: (value) => TextContent(text: value),
      );

  static Future<NdefContent?> _showUriEditor(BuildContext context) =>
      _showSingleFieldDialog(
        context,
        title: 'Baglanti kaydi',
        label: 'URL',
        hint: 'https://ornek.com',
        icon: Icons.link,
        keyboardType: TextInputType.url,
        build: UriContent.new,
      );

  static Future<NdefContent?> _showSingleFieldDialog(
    BuildContext context, {
    required String title,
    required String label,
    required IconData icon,
    required NdefContent Function(String value) build,
    String? hint,
    TextInputType? keyboardType,
  }) {
    final controller = TextEditingController();

    return showDialog<NdefContent>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(icon),
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: keyboardType == TextInputType.url ? 1 : 4,
          minLines: 1,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(context).pop(build(value));
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}
