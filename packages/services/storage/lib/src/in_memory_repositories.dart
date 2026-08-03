/// GECICI depo uygulamalari.
///
/// Bunlar uygulamanin **calisir durumda** kalmasi icin konuldu; veri
/// uygulama kapaninca kaybolur. Kalici sqflite uygulamalari T1'in
/// 2. asamasinda yazilacak:
///   * T1.1 — sqflite sema
///   * T1.2 — HistoryRepositoryImpl
///   * T1.3 — DumpRepositoryImpl
///   * T1.4 — TemplateRepositoryImpl
///
/// Bkz. `.claude/tracks/T1-core.md`
///
/// Degistirirken composition root'taki override'i guncellemeyi unutma.
library;

import 'dart:async';

import 'package:nfc_core/nfc_core.dart';

/// Bellekte tutulan gecmis deposu.
final class InMemoryHistoryRepository implements HistoryRepository {
  final List<ScanRecord> _records = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextId = 1;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Result<ScanRecord>> add(ScanRecord record) async {
    final stored = record.copyWith(id: _nextId++);
    _records.insert(0, stored);
    _changes.add(null);
    return Ok(stored);
  }

  @override
  Future<Result<List<ScanRecord>>> query(HistoryQuery query) async {
    var results = _records.where((record) {
      if (query.chipFamily != null && record.chipFamily != query.chipFamily) {
        return false;
      }
      if (query.from != null && record.scannedAt.isBefore(query.from!)) {
        return false;
      }
      if (query.to != null && record.scannedAt.isAfter(query.to!)) {
        return false;
      }
      final term = query.searchTerm?.toLowerCase();
      if (term != null && term.isNotEmpty) {
        final haystack = [
          record.uidHex,
          record.alias ?? '',
          record.chipDisplayName ?? '',
          ...record.recordSummaries,
        ].join(' ').toLowerCase();
        if (!haystack.contains(term)) return false;
      }
      return true;
    }).toList();

    results = results.skip(query.offset).take(query.limit).toList();
    return Ok(results);
  }

  @override
  Future<Result<ScanRecord?>> findById(int id) async =>
      Ok(_records.where((r) => r.id == id).firstOrNull);

  @override
  Future<Result<ScanRecord?>> findLatestByUid(String uidHex) async =>
      Ok(_records.where((r) => r.uidHex == uidHex).firstOrNull);

  @override
  Future<Result<void>> setAlias({required String uidHex, String? alias}) async {
    for (var i = 0; i < _records.length; i++) {
      if (_records[i].uidHex == uidHex) {
        _records[i] = _records[i].copyWith(alias: alias);
      }
    }
    _changes.add(null);
    return okVoid;
  }

  @override
  Future<Result<void>> delete(int id) async {
    _records.removeWhere((r) => r.id == id);
    _changes.add(null);
    return okVoid;
  }

  @override
  Future<Result<void>> deleteMany(List<int> ids) async {
    _records.removeWhere((r) => ids.contains(r.id));
    _changes.add(null);
    return okVoid;
  }

  @override
  Future<Result<void>> clear() async {
    _records.clear();
    _changes.add(null);
    return okVoid;
  }

  @override
  Future<Result<int>> count() async => Ok(_records.length);
}

/// Bellekte tutulan dokum arsivi.
final class InMemoryDumpRepository implements DumpRepository {
  final List<TagDump> _dumps = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextId = 1;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Result<TagDump>> add(TagDump dump) async {
    final stored = TagDump(
      id: _nextId++,
      uidHex: dump.uidHex,
      createdAt: dump.createdAt,
      bytes: dump.bytes,
      pageSize: dump.pageSize,
      startPage: dump.startPage,
      label: dump.label,
      chipDisplayName: dump.chipDisplayName,
      reason: dump.reason,
    );
    _dumps.insert(0, stored);
    _changes.add(null);
    return Ok(stored);
  }

  @override
  Future<Result<List<TagDump>>> listAll({
    String? uidHex,
    int limit = 100,
  }) async => Ok(
    _dumps
        .where((d) => uidHex == null || d.uidHex == uidHex)
        .take(limit)
        .toList(),
  );

  @override
  Future<Result<TagDump?>> findById(int id) async =>
      Ok(_dumps.where((d) => d.id == id).firstOrNull);

  @override
  Future<Result<void>> rename({required int id, required String label}) async {
    final index = _dumps.indexWhere((d) => d.id == id);
    if (index < 0) return const Err(StorageError('Dokum bulunamadi'));
    final old = _dumps[index];
    _dumps[index] = TagDump(
      id: old.id,
      uidHex: old.uidHex,
      createdAt: old.createdAt,
      bytes: old.bytes,
      pageSize: old.pageSize,
      startPage: old.startPage,
      label: label,
      chipDisplayName: old.chipDisplayName,
      reason: old.reason,
    );
    _changes.add(null);
    return okVoid;
  }

  @override
  Future<Result<void>> delete(int id) async {
    _dumps.removeWhere((d) => d.id == id);
    _changes.add(null);
    return okVoid;
  }

  @override
  Future<Result<void>> clear() async {
    _dumps.clear();
    _changes.add(null);
    return okVoid;
  }

  @override
  Future<Result<String>> exportToFile(int id, {bool asBinary = false}) async =>
      const Err(NotImplementedYet('T1.3'));

  @override
  Future<Result<TagDump>> importFromFile(String path) async =>
      const Err(NotImplementedYet('T1.3'));
}

/// Bellekte tutulan sablon deposu.
final class InMemoryTemplateRepository implements TemplateRepository {
  final List<WriteTemplate> _templates = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _nextId = 1;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Result<WriteTemplate>> add(WriteTemplate template) async {
    final stored = template.copyWith(id: _nextId++);
    _templates.add(stored);
    _changes.add(null);
    return Ok(stored);
  }

  @override
  Future<Result<List<WriteTemplate>>> listAll() async {
    final sorted = List<WriteTemplate>.of(_templates)
      ..sort((a, b) => b.useCount.compareTo(a.useCount));
    return Ok(sorted);
  }

  @override
  Future<Result<WriteTemplate?>> findById(int id) async =>
      Ok(_templates.where((t) => t.id == id).firstOrNull);

  @override
  Future<Result<void>> update(WriteTemplate template) async {
    final index = _templates.indexWhere((t) => t.id == template.id);
    if (index < 0) return const Err(StorageError('Sablon bulunamadi'));
    _templates[index] = template.copyWith(updatedAt: DateTime.now());
    _changes.add(null);
    return okVoid;
  }

  @override
  Future<Result<void>> markUsed(int id) async {
    final index = _templates.indexWhere((t) => t.id == id);
    if (index < 0) return const Err(StorageError('Sablon bulunamadi'));
    _templates[index] = _templates[index].copyWith(
      useCount: _templates[index].useCount + 1,
    );
    _changes.add(null);
    return okVoid;
  }

  @override
  Future<Result<void>> delete(int id) async {
    _templates.removeWhere((t) => t.id == id);
    _changes.add(null);
    return okVoid;
  }
}
