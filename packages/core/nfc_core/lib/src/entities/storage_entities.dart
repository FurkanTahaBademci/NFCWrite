import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'ndef_entities.dart';
import 'tag_identity.dart';

/// Gecmise kaydedilmis bir tarama.
@immutable
final class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.uidHex,
    required this.scannedAt,
    required this.chipFamily,
    this.alias,
    this.chipDisplayName,
    this.technologies = const <String>[],
    this.recordSummaries = const <String>[],
    this.ndefByteLength,
    this.maxNdefSize,
    this.wasWritable,
    this.rawJson,
  });

  /// Veritabani kimligi. Henuz kaydedilmediyse null.
  final int? id;

  final String uidHex;
  final DateTime scannedAt;
  final TagChipFamily chipFamily;

  /// Kullanicinin verdigi takma ad ("Ofis kapisi").
  final String? alias;

  /// Model adi, orn. "NTAG215".
  final String? chipDisplayName;

  /// Teknoloji adlari.
  final List<String> technologies;

  /// Her NDEF kaydinin kisa ozeti — listede gostermek icin.
  final List<String> recordSummaries;

  final int? ndefByteLength;
  final int? maxNdefSize;
  final bool? wasWritable;

  /// Tam okuma sonucunun JSON hali — detay ekrani icin.
  final String? rawJson;

  /// Listede gosterilecek baslik.
  String get displayTitle => alias ?? uidHex;

  ScanRecord copyWith({
    int? id,
    String? uidHex,
    DateTime? scannedAt,
    TagChipFamily? chipFamily,
    String? alias,
    String? chipDisplayName,
    List<String>? technologies,
    List<String>? recordSummaries,
    int? ndefByteLength,
    int? maxNdefSize,
    bool? wasWritable,
    String? rawJson,
  }) => ScanRecord(
    id: id ?? this.id,
    uidHex: uidHex ?? this.uidHex,
    scannedAt: scannedAt ?? this.scannedAt,
    chipFamily: chipFamily ?? this.chipFamily,
    alias: alias ?? this.alias,
    chipDisplayName: chipDisplayName ?? this.chipDisplayName,
    technologies: technologies ?? this.technologies,
    recordSummaries: recordSummaries ?? this.recordSummaries,
    ndefByteLength: ndefByteLength ?? this.ndefByteLength,
    maxNdefSize: maxNdefSize ?? this.maxNdefSize,
    wasWritable: wasWritable ?? this.wasWritable,
    rawJson: rawJson ?? this.rawJson,
  );

  @override
  bool operator ==(Object other) =>
      other is ScanRecord &&
      other.id == id &&
      other.uidHex == uidHex &&
      other.scannedAt == scannedAt;

  @override
  int get hashCode => Object.hash(id, uidHex, scannedAt);

  @override
  String toString() => 'ScanRecord($displayTitle, $scannedAt)';
}

/// Kaydedilmis bir bellek dokumu.
///
/// Yikici islemlerden once otomatik olarak alinir (ADR-0005).
@immutable
final class TagDump {
  TagDump({
    required this.id,
    required this.uidHex,
    required this.createdAt,
    required Uint8List bytes,
    required this.pageSize,
    required this.startPage,
    this.label,
    this.chipDisplayName,
    this.reason = DumpReason.manual,
  }) : bytes = Uint8List.fromList(bytes);

  final int? id;
  final String uidHex;
  final DateTime createdAt;
  final Uint8List bytes;
  final int pageSize;
  final int startPage;

  /// Kullanicinin verdigi ad.
  final String? label;

  final String? chipDisplayName;

  /// Bu dokumun neden alindigi.
  final DumpReason reason;

  int get pageCount => (bytes.length / pageSize).ceil();

  @override
  bool operator ==(Object other) => other is TagDump && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TagDump(${label ?? uidHex}, ${bytes.length} byte, ${reason.name})';
}

/// Bir dokumun alinma sebebi.
enum DumpReason {
  /// Kullanici acikca istedi.
  manual,

  /// Yikici bir islem oncesi otomatik yedek.
  automaticBackup,

  /// Disaridan ice aktarildi.
  imported,
}

/// Kaydedilmis yazma sablonu.
@immutable
final class WriteTemplate {
  const WriteTemplate({
    required this.id,
    required this.name,
    required this.message,
    required this.createdAt,
    this.updatedAt,
    this.useCount = 0,
  });

  final int? id;
  final String name;
  final NdefMessageEntity message;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Kac kez kullanildi — sik kullanilanlari one almak icin.
  final int useCount;

  WriteTemplate copyWith({
    int? id,
    String? name,
    NdefMessageEntity? message,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? useCount,
  }) => WriteTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    message: message ?? this.message,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    useCount: useCount ?? this.useCount,
  );

  @override
  bool operator ==(Object other) => other is WriteTemplate && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'WriteTemplate($name)';
}

/// Gecmis sorgusu icin filtre.
@immutable
final class HistoryQuery {
  const HistoryQuery({
    this.searchTerm,
    this.chipFamily,
    this.from,
    this.to,
    this.limit = 100,
    this.offset = 0,
  });

  /// UID, takma ad ya da icerik ozetinde aranacak metin.
  final String? searchTerm;

  final TagChipFamily? chipFamily;
  final DateTime? from;
  final DateTime? to;
  final int limit;
  final int offset;

  HistoryQuery copyWith({
    String? searchTerm,
    TagChipFamily? chipFamily,
    DateTime? from,
    DateTime? to,
    int? limit,
    int? offset,
  }) => HistoryQuery(
    searchTerm: searchTerm ?? this.searchTerm,
    chipFamily: chipFamily ?? this.chipFamily,
    from: from ?? this.from,
    to: to ?? this.to,
    limit: limit ?? this.limit,
    offset: offset ?? this.offset,
  );

  @override
  bool operator ==(Object other) =>
      other is HistoryQuery &&
      other.searchTerm == searchTerm &&
      other.chipFamily == chipFamily &&
      other.from == from &&
      other.to == to &&
      other.limit == limit &&
      other.offset == offset;

  @override
  int get hashCode =>
      Object.hash(searchTerm, chipFamily, from, to, limit, offset);
}
