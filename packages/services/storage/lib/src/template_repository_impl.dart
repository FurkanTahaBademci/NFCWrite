import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';
import 'package:sqflite/sqflite.dart';

import 'database/storage_database.dart';

/// [TemplateRepository] arayuzunun sqflite uygulamasi.
final class TemplateRepositoryImpl implements TemplateRepository {
  TemplateRepositoryImpl(this._db);

  static const AppLogger _log = AppLogger('storage.template');

  final Database _db;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Result<WriteTemplate>> add(WriteTemplate template) async {
    try {
      final id = await _db.insert(
        StorageDatabase.tableWriteTemplates,
        _toRow(template),
      );
      final stored = template.copyWith(id: id);
      _changes.add(null);
      return Ok(stored);
    } on Object catch (e, s) {
      _log.error('Sablon kaydedilemedi', e, s);
      return Err(StorageError('Sablon kaydedilemedi', cause: e));
    }
  }

  @override
  Future<Result<List<WriteTemplate>>> listAll() async {
    try {
      final rows = await _db.query(
        StorageDatabase.tableWriteTemplates,
        orderBy: 'use_count DESC, updated_at_ms DESC, created_at_ms DESC',
      );
      return Ok(rows.map(_fromRow).toList(growable: false));
    } on Object catch (e, s) {
      _log.error('Sablon listesi alinamadi', e, s);
      return Err(StorageError('Sablon listesi alinamadi', cause: e));
    }
  }

  @override
  Future<Result<WriteTemplate?>> findById(int id) async {
    try {
      final rows = await _db.query(
        StorageDatabase.tableWriteTemplates,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return const Ok<WriteTemplate?>(null);
      return Ok(_fromRow(rows.first));
    } on Object catch (e, s) {
      _log.error('Sablon bulunamadi', e, s);
      return Err(StorageError('Sablon bulunamadi', cause: e));
    }
  }

  @override
  Future<Result<void>> update(WriteTemplate template) async {
    try {
      final updated = template.copyWith(updatedAt: DateTime.now());
      final affected = await _db.update(
        StorageDatabase.tableWriteTemplates,
        <String, Object?>{
          'name': updated.name,
          'message_json': jsonEncode(_messageToJson(updated.message)),
          'created_at_ms': updated.createdAt.millisecondsSinceEpoch,
          'updated_at_ms': updated.updatedAt?.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [template.id],
      );
      if (affected == 0) {
        return const Err(StorageError('Sablon bulunamadi'));
      }
      _changes.add(null);
      return okVoid;
    } on Object catch (e, s) {
      _log.error('Sablon guncellenemedi', e, s);
      return Err(StorageError('Sablon guncellenemedi', cause: e));
    }
  }

  @override
  Future<Result<void>> markUsed(int id) async {
    try {
      final affected = await _db.rawUpdate(
        'UPDATE ${StorageDatabase.tableWriteTemplates} '
        'SET use_count = use_count + 1, updated_at_ms = ? '
        'WHERE id = ?',
        [DateTime.now().millisecondsSinceEpoch, id],
      );
      if (affected == 0) {
        return const Err(StorageError('Sablon bulunamadi'));
      }
      _changes.add(null);
      return okVoid;
    } on Object catch (e, s) {
      _log.error('Sablon kullanim sayisi artirilamadi', e, s);
      return Err(StorageError('Sablon kullanim sayisi artirilamadi', cause: e));
    }
  }

  @override
  Future<Result<void>> delete(int id) async {
    try {
      await _db.delete(
        StorageDatabase.tableWriteTemplates,
        where: 'id = ?',
        whereArgs: [id],
      );
      _changes.add(null);
      return okVoid;
    } on Object catch (e, s) {
      _log.error('Sablon silinemedi', e, s);
      return Err(StorageError('Sablon silinemedi', cause: e));
    }
  }

  /// Kaynaklari birakir. Uygulama kapanirken cagrilir.
  Future<void> dispose() => _changes.close();

  Map<String, Object?> _toRow(WriteTemplate template) => <String, Object?>{
    'id': template.id,
    'name': template.name,
    'message_json': jsonEncode(_messageToJson(template.message)),
    'created_at_ms': template.createdAt.millisecondsSinceEpoch,
    'updated_at_ms': template.updatedAt?.millisecondsSinceEpoch,
    'use_count': template.useCount,
  };

  WriteTemplate _fromRow(Map<String, Object?> row) {
    final messageJson = row['message_json'] as String;
    return WriteTemplate(
      id: row['id'] as int,
      name: row['name'] as String,
      message: _messageFromJson(jsonDecode(messageJson)),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at_ms'] as int,
      ),
      updatedAt: _decodeEpoch(row['updated_at_ms']),
      useCount: row['use_count'] as int,
    );
  }

  Map<String, Object?> _messageToJson(NdefMessageEntity message) =>
      <String, Object?>{
        'records': message.records.map(_recordToJson).toList(growable: false),
      };

  NdefMessageEntity _messageFromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return NdefMessageEntity.empty();
    final recordsRaw = raw['records'];
    if (recordsRaw is! List) return NdefMessageEntity.empty();
    final records = recordsRaw
        .map(_recordFromJson)
        .whereType<NdefRecordEntity>()
        .toList(growable: false);
    if (records.isEmpty) return NdefMessageEntity.empty();
    return NdefMessageEntity(records);
  }

  Map<String, Object?> _recordToJson(NdefRecordEntity record) =>
      <String, Object?>{
        'tnf': record.typeNameFormat.name,
        'typeBase64': base64Encode(record.type),
        'identifierBase64': base64Encode(record.identifier),
        'payloadBase64': base64Encode(record.payload),
      };

  NdefRecordEntity? _recordFromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final tnfName = raw['tnf'] as String?;
    final tnf = _decodeTnf(tnfName);
    final type = _decodeBase64Field(raw['typeBase64']);
    final identifier = _decodeBase64Field(raw['identifierBase64']);
    final payload = _decodeBase64Field(raw['payloadBase64']);
    return NdefRecordEntity(
      typeNameFormat: tnf,
      type: type,
      identifier: identifier,
      payload: payload,
    );
  }

  NdefTypeNameFormat _decodeTnf(String? name) {
    if (name == null) return NdefTypeNameFormat.unknown;
    for (final tnf in NdefTypeNameFormat.values) {
      if (tnf.name == name) return tnf;
    }
    return NdefTypeNameFormat.unknown;
  }

  Uint8List _decodeBase64Field(Object? raw) {
    if (raw is! String || raw.isEmpty) return Uint8List(0);
    try {
      return base64Decode(raw);
    } on FormatException {
      return Uint8List(0);
    }
  }

  DateTime? _decodeEpoch(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }
}
