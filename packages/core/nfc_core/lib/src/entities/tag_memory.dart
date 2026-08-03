import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Etiketin ham bellek icerigi.
///
/// Type 2 etiketlerde (NTAG, Ultralight) sayfa boyutu 4 byte'tir ve
/// [startPage] genelde 0'dir. MIFARE Classic'te blok boyutu 16 byte'tir.
@immutable
final class TagMemory {
  TagMemory({
    required Uint8List bytes,
    this.pageSize = 4,
    this.startPage = 0,
    this.unreadablePages = const <int>{},
  }) : bytes = Uint8List.fromList(bytes);

  /// Tum bellek, kesintisiz byte dizisi.
  final Uint8List bytes;

  /// Sayfa/blok boyutu (byte).
  final int pageSize;

  /// [bytes] icindeki ilk sayfanin gercek sayfa numarasi.
  final int startPage;

  /// Okunamayan sayfalar (sifre korumali ya da hatali).
  ///
  /// Bu sayfalarin [bytes] icindeki karsiligi sifirdir; gercek icerik degildir.
  final Set<int> unreadablePages;

  /// Toplam sayfa sayisi.
  int get pageCount => (bytes.length / pageSize).ceil();

  /// Son sayfanin numarasi (dahil).
  int get endPage => startPage + pageCount - 1;

  /// Verilen sayfayi dondurur. Aralik disindaysa null.
  Uint8List? page(int pageNumber) {
    final index = (pageNumber - startPage) * pageSize;
    if (index < 0 || index + pageSize > bytes.length) return null;
    return Uint8List.sublistView(bytes, index, index + pageSize);
  }

  /// Verilen sayfa araligini dondurur (her iki uc dahil).
  Uint8List? range(int fromPage, int toPage) {
    final start = (fromPage - startPage) * pageSize;
    final end = (toPage - startPage + 1) * pageSize;
    if (start < 0 || end > bytes.length || start >= end) return null;
    return Uint8List.sublistView(bytes, start, end);
  }

  /// Bu sayfa okunabildi mi?
  bool isPageReadable(int pageNumber) => !unreadablePages.contains(pageNumber);

  /// Belirtilen sayfayi degistirilmis bir kopya dondurur.
  TagMemory withPage(int pageNumber, Uint8List data) {
    if (data.length != pageSize) {
      throw ArgumentError.value(
        data,
        'data',
        'Sayfa verisi tam $pageSize byte olmali',
      );
    }
    final index = (pageNumber - startPage) * pageSize;
    if (index < 0 || index + pageSize > bytes.length) {
      throw RangeError.value(
        pageNumber,
        'pageNumber',
        'Bellek araligi disinda',
      );
    }
    final copy = Uint8List.fromList(bytes)
      ..setRange(index, index + pageSize, data);
    return TagMemory(
      bytes: copy,
      pageSize: pageSize,
      startPage: startPage,
      unreadablePages: unreadablePages,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TagMemory &&
      other.pageSize == pageSize &&
      other.startPage == startPage &&
      const ListEquality<int>().equals(other.bytes, bytes);

  @override
  int get hashCode =>
      Object.hash(pageSize, startPage, const ListEquality<int>().hash(bytes));

  @override
  String toString() =>
      'TagMemory(${bytes.length} byte, sayfa $startPage-$endPage)';
}
