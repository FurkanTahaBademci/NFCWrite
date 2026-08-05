import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storage/storage.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('storage repositories', () {
    late Directory tempDir;
    late Database db;

    late HistoryRepositoryImpl historyRepository;
    late DumpRepositoryImpl dumpRepository;
    late TemplateRepositoryImpl templateRepository;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('storage_test_');
      db = await StorageDatabase.open(databasePathOverride: tempDir.path);

      historyRepository = HistoryRepositoryImpl(db);
      dumpRepository = DumpRepositoryImpl(db);
      templateRepository = TemplateRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('history add/query/setAlias and count work', () async {
      final addResult = await historyRepository.add(
        ScanRecord(
          id: null,
          uidHex: '04A1B2C3D4',
          scannedAt: DateTime.now(),
          chipFamily: TagChipFamily.ntag215,
          chipDisplayName: 'NTAG215',
          technologies: const ['nfcA', 'mifareUltralight'],
          recordSummaries: const ['wellKnown: U (12 byte)'],
          ndefByteLength: 12,
          maxNdefSize: 504,
          wasWritable: true,
        ),
      );

      expect(addResult, isA<Ok<ScanRecord>>());
      final stored = (addResult as Ok<ScanRecord>).value;
      expect(stored.id, isNotNull);

      final aliasResult = await historyRepository.setAlias(
        uidHex: stored.uidHex,
        alias: 'Ofis Karti',
      );
      expect(aliasResult, okVoid);

      final listResult = await historyRepository.query(
        const HistoryQuery(searchTerm: 'ofis', limit: 10),
      );
      expect(listResult, isA<Ok<List<ScanRecord>>>());
      final records = (listResult as Ok<List<ScanRecord>>).value;
      expect(records.length, 1);
      expect(records.first.alias, 'Ofis Karti');

      final count = await historyRepository.count();
      expect(count, const Ok<int>(1));
    });

    test('history exportAllToFile/listExportedFiles/importAllFromFile work',
        () async {
      await historyRepository.add(
        ScanRecord(
          id: null,
          uidHex: '04AABBCCDD',
          scannedAt: DateTime.now(),
          chipFamily: TagChipFamily.ntag213,
          chipDisplayName: 'NTAG213',
          recordSummaries: const ['wellKnown: T (5 byte)'],
        ),
      );

      final exportResult = await historyRepository.exportAllToFile();
      expect(exportResult, isA<Ok<String>>());
      final exportPath = (exportResult as Ok<String>).value;
      expect(File(exportPath).existsSync(), isTrue);

      final listResult = await historyRepository.listExportedFiles();
      expect(listResult, isA<Ok<List<String>>>());
      expect((listResult as Ok<List<String>>).value, contains(exportPath));

      final importResult = await historyRepository.importAllFromFile(
        exportPath,
      );
      expect(importResult, const Ok<int>(1));

      final count = await historyRepository.count();
      expect(count, const Ok<int>(2));
    });

    test('dump add/export/import cycle works', () async {
      final addResult = await dumpRepository.add(
        TagDump(
          id: null,
          uidHex: '0488776655',
          createdAt: DateTime.now(),
          bytes: Uint8List.fromList(List<int>.generate(16, (i) => i)),
          pageSize: 4,
          startPage: 4,
          label: 'ilk-dokum',
          chipDisplayName: 'NTAG213',
          reason: DumpReason.manual,
        ),
      );
      expect(addResult, isA<Ok<TagDump>>());
      final stored = (addResult as Ok<TagDump>).value;

      final exportResult = await dumpRepository.exportToFile(stored.id!);
      expect(exportResult, isA<Ok<String>>());
      final exportPath = (exportResult as Ok<String>).value;
      expect(File(exportPath).existsSync(), isTrue);

      final importResult = await dumpRepository.importFromFile(exportPath);
      expect(importResult, isA<Ok<TagDump>>());

      final allDumps = await dumpRepository.listAll();
      expect(allDumps, isA<Ok<List<TagDump>>>());
      expect((allDumps as Ok<List<TagDump>>).value.length, 2);
    });

    test('template add/update/markUsed/list work', () async {
      final template = WriteTemplate(
        id: null,
        name: 'URL Sablonu',
        message: NdefMessageEntity([
          NdefRecordEntity(
            typeNameFormat: NdefTypeNameFormat.wellKnown,
            type: Uint8List.fromList('U'.codeUnits),
            identifier: Uint8List(0),
            payload: Uint8List.fromList('https://ornek.com'.codeUnits),
          ),
        ]),
        createdAt: DateTime.now(),
      );

      final added = await templateRepository.add(template);
      expect(added, isA<Ok<WriteTemplate>>());
      final stored = (added as Ok<WriteTemplate>).value;

      final markUsed = await templateRepository.markUsed(stored.id!);
      expect(markUsed, okVoid);

      final update = await templateRepository.update(
        stored.copyWith(name: 'URL Sablonu v2'),
      );
      expect(update, okVoid);

      final list = await templateRepository.listAll();
      expect(list, isA<Ok<List<WriteTemplate>>>());
      final templates = (list as Ok<List<WriteTemplate>>).value;
      expect(templates.single.name, 'URL Sablonu v2');
      expect(templates.single.useCount, 1);
    });
  });
}
