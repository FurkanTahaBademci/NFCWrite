import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// Ham bellek dokumunu sayfa/blok numarali hex olarak gosterir.
///
/// Uzun dokumlarda (NTAG216 = 231 sayfa) `ListView.builder` ile tembel
/// olusturur; tum satirlari birden yaratmaz.
///
/// Erisilebilirlik: her satir ekran okuyucuya "sayfa 4: 01 02 03 04"
/// seklinde okunur, byte byte degil.
class HexDumpView extends StatelessWidget {
  const HexDumpView({
    required this.bytes,
    this.bytesPerRow = 4,
    this.startPage = 0,
    this.highlightedPages = const <int>{},
    this.unreadablePages = const <int>{},
    this.showAscii = true,
    this.onPageTap,
    super.key,
  });

  final Uint8List bytes;

  /// Satir basina byte — Type 2 etiketlerde 4, MIFARE Classic'te 16.
  final int bytesPerRow;

  /// Ilk satirin sayfa numarasi.
  final int startPage;

  /// Vurgulanacak sayfalar (orn. yapilandirma sayfalari).
  final Set<int> highlightedPages;

  /// Okunamayan sayfalar — icerigi gercek veri degildir.
  final Set<int> unreadablePages;

  final bool showAscii;

  final void Function(int page)? onPageTap;

  int get _rowCount => (bytes.length / bytesPerRow).ceil();

  @override
  Widget build(BuildContext context) {
    if (bytes.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView.builder(
      itemCount: _rowCount,
      itemExtent: 28,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemBuilder: (context, index) => _HexRow(
        page: startPage + index,
        data: _rowBytes(index),
        bytesPerRow: bytesPerRow,
        highlighted: highlightedPages.contains(startPage + index),
        unreadable: unreadablePages.contains(startPage + index),
        showAscii: showAscii,
        onTap: onPageTap,
      ),
    );
  }

  Uint8List _rowBytes(int index) {
    final start = index * bytesPerRow;
    final end = (start + bytesPerRow).clamp(0, bytes.length);
    return Uint8List.sublistView(bytes, start, end);
  }
}

class _HexRow extends StatelessWidget {
  const _HexRow({
    required this.page,
    required this.data,
    required this.bytesPerRow,
    required this.highlighted,
    required this.unreadable,
    required this.showAscii,
    this.onTap,
  });

  final int page;
  final Uint8List data;
  final int bytesPerRow;
  final bool highlighted;
  final bool unreadable;
  final bool showAscii;
  final void Function(int page)? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppTypography.monospace(context);
    final hex = _hexString();

    return Semantics(
      label: 'Sayfa $page: ${hex.split('').join(' ')}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(page),
        onLongPress: () async {
          await Clipboard.setData(ClipboardData(text: hex));
        },
        child: Container(
          color: highlighted
              ? scheme.primaryContainer.withValues(alpha: 0.35)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  page.toRadixString(16).padLeft(3, '0').toUpperCase(),
                  style: style.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  unreadable ? _maskedString() : _spacedHex(),
                  style: style.copyWith(
                    color: unreadable ? scheme.onSurfaceVariant : null,
                    fontStyle: unreadable ? FontStyle.italic : null,
                  ),
                ),
              ),
              if (showAscii) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  unreadable ? '' : _asciiString(),
                  style: style.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _hexString() =>
      data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();

  String _spacedHex() => data
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');

  String _maskedString() => List.filled(data.length, '??').join(' ');

  String _asciiString() => data
      .map((b) => b >= 0x20 && b <= 0x7E ? String.fromCharCode(b) : '.')
      .join();
}
