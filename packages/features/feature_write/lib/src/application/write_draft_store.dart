import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndef_codec/ndef_codec.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';

import 'providers.dart';

/// Yazma ekranindaki taslagin kalici deposu.
///
/// Kullanici bir kayit ekledigi/degistirdigi anda liste diske yazilir;
/// uygulama kapatilip yeniden acildiginda ayni liste geri yuklenir.
///
/// Ayri bir tablo acmak yerine `TemplateRepository` icinde **ayrilmis adli**
/// tek bir satir kullanilir ([draftTemplateName]). Boylece `feature_write`
/// mimari kurali bozmadan (feature → `storage` importu YASAK) kalici veri
/// yazabilir — bkz. `.claude/docs/01-architecture.md`.
///
/// > Sablon listesi UI'si (T3.41) yazilirken bu satir listeden gizlenmelidir;
/// > [isDraft] yardimcisini kullan.
final class WriteDraftStore {
  WriteDraftStore(this._repository);

  /// Taslak satirinin ayrilmis adi.
  ///
  /// Kullanicinin ayni adi vermesi pratikte imkansiz olsun diye bilerek
  /// tuhaf secildi.
  static const String draftTemplateName = '__nfc_toolkit_auto_draft__';

  static const AppLogger _log = AppLogger('write.draft');

  final TemplateRepository _repository;

  /// Bulunan taslak satiri — her kayitta yeniden aramamak icin onbellek.
  WriteTemplate? _cached;

  /// Verilen sablon, kullanicinin kaydettigi bir sablon degil de otomatik
  /// taslak mi?
  static bool isDraft(WriteTemplate template) =>
      template.name == draftTemplateName;

  /// Diskteki taslagi okur. Taslak yoksa ya da okunamazsa bos liste doner.
  Future<List<NdefContent>> load() async {
    final template = await _find();
    if (template == null) return const <NdefContent>[];

    final message = template.message;
    if (message.isEmpty) return const <NdefContent>[];

    try {
      return NdefConverter.decodeAll(message);
    } on Object catch (e, s) {
      _log.error('Taslak cozumlenemedi', e, s);
      return const <NdefContent>[];
    }
  }

  /// Taslagi diske yazar. [records] bossa kayitli taslak silinir.
  ///
  /// Hicbir kosulda firlatmaz — taslak kaydi kullanicinin isini bolmemeli.
  Future<void> save(List<NdefContent> records) async {
    if (records.isEmpty) {
      await _deleteDraft();
      return;
    }

    final NdefMessageEntity message;
    try {
      message = NdefConverter.encodeAll(records);
    } on Object catch (e, s) {
      _log.error('Taslak kodlanamadi', e, s);
      return;
    }

    final existing = await _find();
    final existingId = existing?.id;
    if (existing == null || existingId == null) {
      await _insertDraft(message);
      return;
    }

    final updated = existing.copyWith(message: message, updatedAt: _now());
    switch (await _repository.update(updated)) {
      case Ok():
        _cached = updated;
      case Err(:final failure):
        // Satir baska bir yerden silinmis olabilir — yeniden ekle.
        _log.warning('Taslak guncellenemedi, yeniden ekleniyor', failure);
        _cached = null;
        await _insertDraft(message);
    }
  }

  /// Kayitli taslagi siler. Kullanici listeyi temizleyince cagrilir.
  Future<void> clear() => _deleteDraft();

  Future<void> _insertDraft(NdefMessageEntity message) async {
    final now = _now();
    final result = await _repository.add(
      WriteTemplate(
        id: null,
        name: draftTemplateName,
        message: message,
        createdAt: now,
        updatedAt: now,
      ),
    );
    switch (result) {
      case Ok(:final value):
        _cached = value;
      case Err(:final failure):
        _cached = null;
        _log.warning('Taslak kaydedilemedi', failure);
    }
  }

  Future<void> _deleteDraft() async {
    final id = (await _find())?.id;
    _cached = null;
    if (id == null) return;

    if (await _repository.delete(id) case Err(:final failure)) {
      _log.warning('Taslak silinemedi', failure);
    }
  }

  Future<WriteTemplate?> _find() async {
    final cached = _cached;
    if (cached != null) return cached;

    switch (await _repository.listAll()) {
      case Ok(:final value):
        for (final template in value) {
          if (isDraft(template)) return _cached = template;
        }
        return null;
      case Err(:final failure):
        _log.warning('Taslak okunamadi', failure);
        return null;
    }
  }

  DateTime _now() => DateTime.now();
}

/// Taslak deposu — [templateRepositoryProvider] uzerine kuruludur.
///
/// Composition root `templateRepositoryProvider`'i override ettigi icin
/// burada ekstra baglama gerekmez.
final Provider<WriteDraftStore> writeDraftStoreProvider =
    Provider<WriteDraftStore>(
      (ref) => WriteDraftStore(ref.watch(templateRepositoryProvider)),
    );
