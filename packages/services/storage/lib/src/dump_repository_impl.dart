import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nfc_core/nfc_core.dart';
import 'package:path/path.dart' as p;
import 'package:shared_utils/shared_utils.dart';
import 'package:sqflite/sqflite.dart';

import 'database/storage_database.dart';

/// [DumpRepository] arayuzunun sqflite uygulamasi.
final class DumpRepositoryImpl implements DumpRepository {
  DumpRepositoryImpl(this._db);

  static const AppLogger _log = AppLogger('storage.dump');

  final Database _db;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Result<TagDump>> add(TagDump dump) async {
    try {
      final id = await _db.insert(StorageDatabase.tableTagDumps, _toRow(dump));
      final stored = TagDump(
        id: id,
        uidHex: dump.uidHex,
        createdAt: dump.createdAt,
        bytes: dump.bytes,
        pageSize: dump.pageSize,
        startPage: dump.startPage,
        label: dump.label,
        chipDisplayName: dump.chipDisplayName,
        reason: dump.reason,
      );
      _changes.add(null);
      return Ok(stored);
    } on Object catch (e, s) {
      _log.error('Dokum kaydedilemedi', e, s);
      return Err(StorageError('Dokum kaydedilemedi', cause: e));
    }
  }

  @override
  Future<Result<List<TagDump>>> listAll({
    String? uidHex,
    int limit = 100,
  }) async {
    try {
      final rows = await _db.query(
        StorageDatabase.tableTagDumps,
        where: uidHex == null ? null : 'uid_hex = ?',
        whereArgs: uidHex == null ? null : <Object?>[uidHex],
        orderBy: 'created_at_ms DESC',
        limit: limit,
      );
      return Ok(rows.map(_fromRow).toList(growable: false));
    } on Object catch (e, s) {
      _log.error('Dokum listesi alinamadi', e, s);
      return Err(StorageError('Dokum listesi alinamadi', cause: e));
    }
  }

  @override
  Future<Result<TagDump?>> findById(int id) async {
    try {
      final rows = await _db.query(
        StorageDatabase.tableTagDumps,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return const Ok<TagDump?>(null);
      return Ok(_fromRow(rows.first));
    } on Object catch (e, s) {
      _log.error('Dokum bulunamadi', e, s);
      return Err(StorageError('Dokum bulunamadi', cause: e));
    }
  }

  @override
  Future<Result<void>> rename({required int id, required String label}) async {
    try {
      final affected = await _db.update(
        StorageDatabase.tableTagDumps,
        <String, Object?>{'label': label},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (affected == 0) {
        return const Err(StorageError('Dokum bulunamadi'));
      }
      _changes.add(null);
      return okVoid;
    } on Object catch (e, s) {
      _log.error('Dokum yeniden adlandirilamadi', e, s);
      return Err(StorageError('Dokum yeniden adlandirilamadi', cause: e));
    }
  }

  @override
  Future<Result<void>> delete(int id) async {
    try {
      await _db.delete(
        StorageDatabase.tableTagDumps,
        where: 'id = ?',
        whereArgs: [id],
      );
      _changes.add(null);
      return okVoid;
    } on Object catch (e, s) {
      _log.error('Dokum silinemedi', e, s);
      return Err(StorageError('Dokum silinemedi', cause: e));
    }
  }

  @override
  Future<Result<void>> clear() async {
    try {
      await _db.delete(StorageDatabase.tableTagDumps);
      _changes.add(null);
      return okVoid;
    } on Object catch (e, s) {
      _log.error('Dokum arsivi temizlenemedi', e, s);
      return Err(StorageError('Dokum arsivi temizlenemedi', cause: e));
    }
  }

  @override
  Future<Result<String>> exportToFile(int id, {bool asBinary = false}) async {
    try {
      final dumpResult = await findById(id);
      if (dumpResult case Err(:final failure)) return Err(failure);
      final dump = (dumpResult as Ok<TagDump?>).value;
      if (dump == null) return const Err(StorageError('Dokum bulunamadi'));

      final exportDirectory = await _ensureExportDirectory();
      final baseName = _buildFileStem(dump);
      final extension = asBinary ? 'bin' : 'json';
      final filePath = p.join(exportDirectory.path, '$baseName.$extension');
      final file = File(filePath);

      if (asBinary) {
        await file.writeAsBytes(dump.bytes, flush: true);
      } else {
        final payload = <String, Object?>{
          'id': dump.id,
          'uidHex': dump.uidHex,
          'createdAtMs': dump.createdAt.millisecondsSinceEpoch,
          'pageSize': dump.pageSize,
          'startPage': dump.startPage,
          'label': dump.label,
          'chipDisplayName': dump.chipDisplayName,
          'reason': dump.reason.name,
          'bytesBase64': base64Encode(dump.bytes),
        };
        await file.writeAsString(jsonEncode(payload), flush: true);
      }

      return Ok(file.path);
    } on Object catch (e, s) {
      _log.error('Dokum dosyaya aktarilamadi', e, s);
      return Err(StorageError('Dokum dosyaya aktarilamadi', cause: e));
    }
  }

  @override
  Future<Result<TagDump>> importFromFile(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return const Err(StorageError('Dosya bulunamadi'));
      }

      final extension = p.extension(path).toLowerCase();
      final imported = switch (extension) {
        '.json' => await _importFromJson(file),
        '.bin' => await _importFromBin(file),
        _ => const Err<TagDump>(StorageError('Desteklenmeyen dosya turu')),
      };

      if (imported case Err(:final failure)) return Err(failure);
      final dump = (imported as Ok<TagDump>).value;
      return add(dump);
    } on Object catch (e, s) {
      _log.error('Dokum dosyadan ice aktarilamadi', e, s);
      return Err(StorageError('Dokum dosyadan ice aktarilamadi', cause: e));
    }
  }

  /// Kaynaklari birakir. Uygulama kapanirken cagrilir.
  Future<void> dispose() => _changes.close();

  Map<String, Object?> _toRow(TagDump dump) => <String, Object?>{
    'id': dump.id,
    'uid_hex': dump.uidHex,
    'created_at_ms': dump.createdAt.millisecondsSinceEpoch,
    'bytes_blob': dump.bytes,
    'page_size': dump.pageSize,
    'start_page': dump.startPage,
    'label': dump.label,
    'chip_display_name': dump.chipDisplayName,
    'reason': dump.reason.name,
  };

  TagDump _fromRow(Map<String, Object?> row) => TagDump(
    id: row['id'] as int,
    uidHex: row['uid_hex'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at_ms'] as int),
    bytes: _decodeBytes(row['bytes_blob']),
    pageSize: row['page_size'] as int,
    startPage: row['start_page'] as int,
    label: row['label'] as String?,
    chipDisplayName: row['chip_display_name'] as String?,
    reason: _decodeReason(row['reason'] as String?),
  );

  Uint8List _decodeBytes(Object? raw) {
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    if (raw is List) {
      return Uint8List.fromList(raw.map((item) => item as int).toList());
    }
    return Uint8List(0);
  }

  DumpReason _decodeReason(String? name) {
    if (name == null) return DumpReason.manual;
    for (final reason in DumpReason.values) {
      if (reason.name == name) return reason;
    }
    return DumpReason.manual;
  }

  String _buildFileStem(TagDump dump) {
    final createdAtMs = dump.createdAt.millisecondsSinceEpoch;
    final idPart = dump.id ?? 0;
    return '${dump.uidHex}_${idPart}_$createdAtMs';
  }

  Future<Directory> _ensureExportDirectory() async {
    final root = Directory(p.join(p.dirname(_db.path), 'dump_exports'));
    if (root.existsSync()) return root;
    root.createSync(recursive: true);
    return root;
  }

  Future<Result<TagDump>> _importFromJson(File file) async {
    final content = await file.readAsString();
    final raw = jsonDecode(content);
    if (raw is! Map<String, Object?>) {
      return const Err(StorageError('Gecersiz JSON dump formati'));
    }

    final bytesBase64 = raw['bytesBase64'];
    if (bytesBase64 is! String || bytesBase64.isEmpty) {
      return const Err(StorageError('JSON dump icinde byte verisi yok'));
    }

    final uid = (raw['uidHex'] as String?) ?? 'UNKNOWN';
    final createdAtMs = raw['createdAtMs'];
    final pageSize = raw['pageSize'];
    final startPage = raw['startPage'];
    final reason = raw['reason'] as String?;

    return Ok(
      TagDump(
        id: null,
        uidHex: uid,
        createdAt: _decodeEpoch(createdAtMs) ?? DateTime.now(),
        bytes: base64Decode(bytesBase64),
        pageSize: pageSize is int ? pageSize : 4,
        startPage: startPage is int ? startPage : 0,
        label: raw['label'] as String?,
        chipDisplayName: raw['chipDisplayName'] as String?,
        reason: _decodeReason(reason),
      ),
    );
  }

  Future<Result<TagDump>> _importFromBin(File file) async {
    final bytes = await file.readAsBytes();
    final stem = p.basenameWithoutExtension(file.path);
    return Ok(
      TagDump(
        id: null,
        uidHex: 'UNKNOWN',
        createdAt: DateTime.now(),
        bytes: bytes,
        pageSize: 4,
        startPage: 0,
        label: stem,
        reason: DumpReason.imported,
      ),
    );
  }

  DateTime? _decodeEpoch(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }
}
