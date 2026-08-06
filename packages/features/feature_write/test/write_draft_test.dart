import 'package:feature_write/src/application/providers.dart';
import 'package:feature_write/src/application/write_controller.dart';
import 'package:feature_write/src/application/write_draft_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndef_codec/ndef_codec.dart';
import 'package:nfc_core/nfc_core.dart';

/// Bellekte yasayan sahte sablon deposu.
///
/// Gercek `TemplateRepositoryImpl` (sqflite) ile ayni sozlesmeyi uygular;
/// feature katmani somut depoyu gormedigi icin test burada yeter.
final class _FakeTemplateRepository implements TemplateRepository {
  final Map<int, WriteTemplate> rows = <int, WriteTemplate>{};
  int _nextId = 1;

  @override
  Stream<void> get changes => Stream<void>.fromIterable(const <void>[]);

  @override
  Future<Result<WriteTemplate>> add(WriteTemplate template) async {
    final stored = template.copyWith(id: _nextId++);
    rows[stored.id!] = stored;
    return Ok<WriteTemplate>(stored);
  }

  @override
  Future<Result<List<WriteTemplate>>> listAll() async =>
      Ok<List<WriteTemplate>>(rows.values.toList(growable: false));

  @override
  Future<Result<WriteTemplate?>> findById(int id) async =>
      Ok<WriteTemplate?>(rows[id]);

  @override
  Future<Result<void>> update(WriteTemplate template) async {
    final id = template.id;
    if (id == null || !rows.containsKey(id)) {
      return const Err<void>(StorageError('Sablon bulunamadi'));
    }
    rows[id] = template;
    return okVoid;
  }

  @override
  Future<Result<void>> markUsed(int id) async => okVoid;

  @override
  Future<Result<void>> delete(int id) async {
    rows.remove(id);
    return okVoid;
  }
}

/// Uygulamanin bir "oturumunu" temsil eden kapsayici.
ProviderContainer _session(_FakeTemplateRepository repository) =>
    ProviderContainer(
      overrides: [templateRepositoryProvider.overrideWithValue(repository)],
    );

void main() {
  group('WriteDraftStore', () {
    test('kaydedilen taslak ayni icerikle geri okunur', () async {
      final repository = _FakeTemplateRepository();
      final store = WriteDraftStore(repository);

      await store.save(const [
        TextContent(text: 'merhaba'),
        UriContent('https://example.com'),
      ]);

      expect(await WriteDraftStore(repository).load(), [
        const TextContent(text: 'merhaba'),
        const UriContent('https://example.com'),
      ]);
    });

    test('tekrar kaydetmek yeni satir acmaz, mevcut satiri gunceller', () async {
      final repository = _FakeTemplateRepository();
      final store = WriteDraftStore(repository);

      await store.save(const [TextContent(text: 'ilk')]);
      await store.save(const [TextContent(text: 'ikinci')]);

      expect(repository.rows, hasLength(1));
      expect(await WriteDraftStore(repository).load(), [
        const TextContent(text: 'ikinci'),
      ]);
    });

    test('bos liste kaydedilince taslak silinir', () async {
      final repository = _FakeTemplateRepository();
      final store = WriteDraftStore(repository);

      await store.save(const [TextContent(text: 'merhaba')]);
      await store.save(const <NdefContent>[]);

      expect(repository.rows, isEmpty);
      expect(await WriteDraftStore(repository).load(), isEmpty);
    });

    test('taslak satiri kullanici sablonlarindan ayirt edilebilir', () async {
      final repository = _FakeTemplateRepository();
      await WriteDraftStore(repository).save(const [TextContent(text: 'x')]);

      final userTemplate = WriteTemplate(
        id: null,
        name: 'Ofis kartviziti',
        message: NdefConverter.encodeAll(const [TextContent(text: 'y')]),
        createdAt: DateTime(2026),
      );

      expect(repository.rows.values.where(WriteDraftStore.isDraft), hasLength(1));
      expect(WriteDraftStore.isDraft(userTemplate), isFalse);
    });
  });

  group('WriteController taslak kaliciligi', () {
    test('kayitlar uygulama yeniden acildiginda geri yuklenir', () async {
      final repository = _FakeTemplateRepository();

      final first = _session(repository);
      final firstController = first.read(writeControllerProvider.notifier);
      await firstController.draftSettled;
      firstController.addRecord(const TextContent(text: 'kalici not'));
      await firstController.draftSettled;
      first.dispose();

      final second = _session(repository);
      final secondController = second.read(writeControllerProvider.notifier);
      expect(
        second.read(writeControllerProvider).isRestoringDraft,
        isTrue,
        reason: 'yukleme bitene kadar bos durum gosterilmemeli',
      );

      await secondController.draftSettled;

      final restored = second.read(writeControllerProvider);
      expect(restored.records, [const TextContent(text: 'kalici not')]);
      expect(restored.isRestoringDraft, isFalse);
      second.dispose();
    });

    test('kayit silmek taslagi da gunceller', () async {
      final repository = _FakeTemplateRepository();

      final first = _session(repository);
      final firstController = first.read(writeControllerProvider.notifier);
      await firstController.draftSettled;
      firstController
        ..addRecord(const TextContent(text: 'bir'))
        ..addRecord(const TextContent(text: 'iki'))
        ..removeRecord(0);
      await firstController.draftSettled;
      first.dispose();

      final second = _session(repository);
      final secondController = second.read(writeControllerProvider.notifier);
      await secondController.draftSettled;

      expect(second.read(writeControllerProvider).records, [
        const TextContent(text: 'iki'),
      ]);
      second.dispose();
    });

    test('temizlemek kayitli taslagi siler', () async {
      final repository = _FakeTemplateRepository();

      final first = _session(repository);
      final firstController = first.read(writeControllerProvider.notifier);
      await firstController.draftSettled;
      firstController
        ..addRecord(const TextContent(text: 'silinecek'))
        ..clear();
      await firstController.draftSettled;
      first.dispose();

      expect(repository.rows, isEmpty);

      final second = _session(repository);
      final secondController = second.read(writeControllerProvider.notifier);
      await secondController.draftSettled;

      expect(second.read(writeControllerProvider).records, isEmpty);
      second.dispose();
    });

    test('yukleme bitmeden eklenen kayit taslakla ezilmez', () async {
      final repository = _FakeTemplateRepository();

      final first = _session(repository);
      final firstController = first.read(writeControllerProvider.notifier);
      await firstController.draftSettled;
      firstController.addRecord(const TextContent(text: 'eski'));
      await firstController.draftSettled;
      first.dispose();

      // Yeni oturum: taslak diskten okunurken kullanici yeni kayit ekliyor.
      final second = _session(repository);
      final secondController = second.read(writeControllerProvider.notifier);
      secondController.addRecord(const TextContent(text: 'yeni'));
      await secondController.draftSettled;

      expect(second.read(writeControllerProvider).records, [
        const TextContent(text: 'yeni'),
      ]);
      second.dispose();
    });
  });
}
