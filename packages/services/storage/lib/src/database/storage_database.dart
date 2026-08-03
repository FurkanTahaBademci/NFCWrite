import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Sqflite veritabani acilisi ve sema migration yonetimi.
final class StorageDatabase {
  StorageDatabase._();

  static const String databaseName = 'nfc_toolkit.db';
  static const int currentVersion = 1;

  static const String tableScanHistory = 'scan_history';
  static const String tableTagDumps = 'tag_dumps';
  static const String tableWriteTemplates = 'write_templates';
  static const String tableTagAliases = 'tag_aliases';

  static final List<_Migration> _migrations = [const _CreateSchemaV1Migration()];

  /// Uygulamanin kalici veritabanini acar.
  ///
  /// [databasePathOverride] testlerde gecici yol vermek icin kullanilir.
  static Future<Database> open({String? databasePathOverride}) async {
    final basePath = databasePathOverride ?? await getDatabasesPath();
    final path = p.join(basePath, databaseName);

    return openDatabase(
      path,
      version: currentVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _runMigrations(db, 0, version);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _runMigrations(db, oldVersion, newVersion);
      },
    );
  }

  static Future<void> _runMigrations(
    Database db,
    int fromVersion,
    int toVersion,
  ) async {
    for (final migration in _migrations) {
      if (migration.fromVersion >= fromVersion &&
          migration.toVersion <= toVersion) {
        await migration.apply(db);
      }
    }
  }
}

abstract interface class _Migration {
  int get fromVersion;
  int get toVersion;

  Future<void> apply(Database db);
}

final class _CreateSchemaV1Migration implements _Migration {
  const _CreateSchemaV1Migration();

  @override
  int get fromVersion => 0;

  @override
  int get toVersion => 1;

  @override
  Future<void> apply(Database db) async {
    await db.execute('''
      CREATE TABLE ${StorageDatabase.tableScanHistory} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid_hex TEXT NOT NULL,
        scanned_at_ms INTEGER NOT NULL,
        chip_family TEXT NOT NULL,
        alias TEXT,
        chip_display_name TEXT,
        technologies_json TEXT NOT NULL,
        record_summaries_json TEXT NOT NULL,
        ndef_byte_length INTEGER,
        max_ndef_size INTEGER,
        was_writable INTEGER,
        raw_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${StorageDatabase.tableTagDumps} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid_hex TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        bytes_blob BLOB NOT NULL,
        page_size INTEGER NOT NULL,
        start_page INTEGER NOT NULL,
        label TEXT,
        chip_display_name TEXT,
        reason TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${StorageDatabase.tableWriteTemplates} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        message_json TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        updated_at_ms INTEGER,
        use_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${StorageDatabase.tableTagAliases} (
        uid_hex TEXT PRIMARY KEY,
        alias TEXT NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_scan_history_scanned_at '
      'ON ${StorageDatabase.tableScanHistory}(scanned_at_ms DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_scan_history_uid '
      'ON ${StorageDatabase.tableScanHistory}(uid_hex)',
    );
    await db.execute(
      'CREATE INDEX idx_tag_dumps_created_at '
      'ON ${StorageDatabase.tableTagDumps}(created_at_ms DESC)',
    );
  }
}