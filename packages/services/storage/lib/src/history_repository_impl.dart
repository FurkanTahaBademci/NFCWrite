import 'dart:async';
import 'dart:convert';

import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';
import 'package:sqflite/sqflite.dart';

import 'database/storage_database.dart';

/// [HistoryRepository] arayuzunun sqflite uygulamasi.
final class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl(this._db);

  static const AppLogger _log = AppLogger('storage.history');

  final Database _db;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Result<ScanRecord>> add(ScanRecord record) async {
    try {
      final alias = record.alias ?? await _readAlias(record.uidHex);
      final storedRecord = record.copyWith(alias: alias);
      final id = await _db.insert(
        StorageDatabase.tableScanHistory,
        _toRow(storedRecord),
      );

      final result = storedRecord.copyWith(id: id);
      _changes.add(null);
      return Ok(result);
    } on Object catch (e, s) {
      _log.error('Gecmis kaydi eklenemedi', e, s);
      return Err(StorageError('Gecmis kaydi eklenemedi', cause: e));
    }
  }

  @override
  Future<Result<List<ScanRecord>>> query(HistoryQuery query) async {
    try {
      final whereParts = <String>[];
      final args = <Object?>[];

      if (query.chipFamily != null) {
        whereParts.add('chip_family = ?');
        args.add(query.chipFamily!.name);
      }
      if (query.from != null) {
        whereParts.add('scanned_at_ms >= ?');
        args.add(query.from!.millisecondsSinceEpoch);
      }
      if (query.to != null) {
        whereParts.add('scanned_at_ms <= ?');
        args.add(query.to!.millisecondsSinceEpoch);
      }
      final term = query.searchTerm?.trim();
      if (term != null && term.isNotEmpty) {
        whereParts.add(
          '('
          'LOWER(uid_hex) LIKE ? OR '
          "LOWER(COALESCE(alias, '')) LIKE ? OR "
          "LOWER(COALESCE(chip_display_name, '')) LIKE ? OR "
          'LOWER(record_summaries_json) LIKE ?'
          ')',
        );
        final like = '%${term.toLowerCase()}%';
        args.addAll([like, like, like, like]);
      }

      final rows = await _db.query(
        StorageDatabase.tableScanHistory,
        where: whereParts.isEmpty ? null : whereParts.join(' AND '),
        whereArgs: args,
        orderBy: 'scanned_at_ms DESC',
        limit: query.limit,
        offset: query.offset,
      );
      return Ok(rows.map(_fromRow).toList(growable: false));
    } on Object catch (e, s) {
      _log.error('Gecmis sorgulanamadi', e, s);
      return Err(StorageError('Gecmis sorgulanamadi', cause: e));
    }
  }

  @override
  Future<Result<ScanRecord?>> findById(int id) async {
    try {
      final rows = await _db.query(
        StorageDatabase.tableScanHistory,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return const Ok<ScanRecord?>(null);
      return Ok(_fromRow(rows.first));
    } on Object catch (e, s) {
      _log.error('Gecmis kaydi bulunamadi', e, s);
      return Err(StorageError('Gecmis kaydi bulunamadi', cause: e));
    }
  }

  @override
  Future<Result<ScanRecord?>> findLatestByUid(String uidHex) async {
    try {
      final rows = await _db.query(
        StorageDatabase.tableScanHistory,
        where: 'uid_hex = ?',
        whereArgs: [uidHex],
        orderBy: 'scanned_at_ms DESC',
        limit: 1,
      );
      if (rows.isEmpty) return const Ok<ScanRecord?>(null);
      return Ok(_fromRow(rows.first));
    } on Object catch (e, s) {
      _log.error('UID icin en son gecmis kaydi bulunamadi', e, s);
      return Err(
        StorageError('UID icin en son gecmis kaydi bulunamadi', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> setAlias({required String uidHex, String? alias}) async {
    try {
      await _db.transaction((txn) async {
        await txn.update(
          StorageDatabase.tableScanHistory,
          <String, Object?>{'alias': alias},
          where: 'uid_hex = ?',
          whereArgs: [uidHex],
        );

        if (alias == null || alias.trim().isEmpty) {
          await txn.delete(
            StorageDatabase.tableTagAliases,
            where: 'uid_hex = ?',
            whereArgs: [uidHex],
          );
          return;
        }

        await txn.insert(
          StorageDatabase.tableTagAliases,
          <String, Object?>{
            'uid_hex': uidHex,
            'alias': alias.trim(),
            'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });

      _changes.add(null);
      return okVoid;
    } on Object catch (e, s) {
      _log.error('Takma ad guncellenemedi', e, s);
      return Err(StorageError('Takma ad guncellenemedi', cause: e));
    }
  }

  @override
  Future<Result<void>> delete(int id) async {
    try {
      await _db.delete(
        StorageDatabase.tableScanHistory,
        where: 'id = ?',
        whereArgs: [id],
      );
      _changes.add(null);
      return okVoid;
    } on Object catch (e, s) {
      _log.error('Gecmis kaydi silinemedi', e, s);
      return Err(StorageError('Gecmis kaydi silinemedi', cause: e));
    }
  }

  @override
  Future<Result<void>> deleteMany(List<int> ids) async {
    if (ids.isEmpty) return okVoid;
    try {
      final placeholders = List<String>.filled(ids.length, '?').join(',');
      await _db.delete(
        StorageDatabase.tableScanHistory,
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
      _changes.add(null);
      return okVoid;
    } on Object catch (e, s) {
      _log.error('Gecmis kayitlari silinemedi', e, s);
      return Err(StorageError('Gecmis kayitlari silinemedi', cause: e));
    }
  }

  @override
  Future<Result<void>> clear() async {
    try {
      await _db.transaction((txn) async {
        await txn.delete(StorageDatabase.tableScanHistory);
        await txn.delete(StorageDatabase.tableTagAliases);
      });
      _changes.add(null);
      return okVoid;
    } on Object catch (e, s) {
      _log.error('Gecmis temizlenemedi', e, s);
      return Err(StorageError('Gecmis temizlenemedi', cause: e));
    }
  }

  @override
  Future<Result<int>> count() async {
    try {
      final rows = await _db.rawQuery(
        'SELECT COUNT(*) AS total FROM ${StorageDatabase.tableScanHistory}',
      );
      final total = rows.first['total'];
      if (total is int) return Ok(total);
      if (total is num) return Ok(total.toInt());
      return const Ok(0);
    } on Object catch (e, s) {
      _log.error('Gecmis sayisi okunamadi', e, s);
      return Err(StorageError('Gecmis sayisi okunamadi', cause: e));
    }
  }

  /// Kaynaklari birakir. Uygulama kapanirken cagrilir.
  Future<void> dispose() => _changes.close();

  Future<String?> _readAlias(String uidHex) async {
    final rows = await _db.query(
      StorageDatabase.tableTagAliases,
      columns: const ['alias'],
      where: 'uid_hex = ?',
      whereArgs: [uidHex],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['alias'] as String?;
  }

  Map<String, Object?> _toRow(ScanRecord record) => <String, Object?>{
    'id': record.id,
    'uid_hex': record.uidHex,
    'scanned_at_ms': record.scannedAt.millisecondsSinceEpoch,
    'chip_family': record.chipFamily.name,
    'alias': record.alias,
    'chip_display_name': record.chipDisplayName,
    'technologies_json': jsonEncode(record.technologies),
    'record_summaries_json': jsonEncode(record.recordSummaries),
    'ndef_byte_length': record.ndefByteLength,
    'max_ndef_size': record.maxNdefSize,
    'was_writable': record.wasWritable == null
        ? null
        : (record.wasWritable! ? 1 : 0),
    'raw_json': record.rawJson,
  };

  ScanRecord _fromRow(Map<String, Object?> row) {
    final chipFamilyName = row['chip_family'] as String?;
    return ScanRecord(
      id: row['id'] as int,
      uidHex: row['uid_hex'] as String,
      scannedAt: DateTime.fromMillisecondsSinceEpoch(
        row['scanned_at_ms'] as int,
      ),
      chipFamily: _chipFamilyFromName(chipFamilyName),
      alias: row['alias'] as String?,
      chipDisplayName: row['chip_display_name'] as String?,
      technologies: _decodeStringList(row['technologies_json']),
      recordSummaries: _decodeStringList(row['record_summaries_json']),
      ndefByteLength: row['ndef_byte_length'] as int?,
      maxNdefSize: row['max_ndef_size'] as int?,
      wasWritable: _decodeNullableBool(row['was_writable']),
      rawJson: row['raw_json'] as String?,
    );
  }

  TagChipFamily _chipFamilyFromName(String? name) {
    if (name == null) return TagChipFamily.unknown;
    for (final family in TagChipFamily.values) {
      if (family.name == name) return family;
    }
    return TagChipFamily.unknown;
  }

  List<String> _decodeStringList(Object? raw) {
    if (raw is! String || raw.isEmpty) return const <String>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <String>[];
    return decoded.map((item) => item.toString()).toList(growable: false);
  }

  bool? _decodeNullableBool(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw != 0;
    if (raw is num) return raw != 0;
    return null;
  }
}
