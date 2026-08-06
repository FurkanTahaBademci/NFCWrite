import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndef_codec/ndef_codec.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';

import 'providers.dart';
import 'write_draft_store.dart';

/// Yazma ekraninin durumu.
final class WriteState {
  const WriteState({
    this.records = const <NdefContent>[],
    this.phase = WritePhase.editing,
    this.failure,
    this.lockAfterWrite = false,
    this.targetCapacityBytes,
    this.isRestoringDraft = false,
  });

  /// Etikete yazilacak kayitlar, sirasiyla.
  final List<NdefContent> records;

  final WritePhase phase;
  final NfcFailure? failure;

  /// Yazdiktan sonra etiket kalici olarak kilitlensin mi?
  final bool lockAfterWrite;

  /// Taranan hedef etiketin NDEF kapasitesi (byte). Henuz taranmadiysa null.
  final int? targetCapacityBytes;

  /// Diskteki taslak henuz okunuyor mu?
  ///
  /// Uygulama acilisinda kisa bir sure true olur; bu sirada ekran "kayit yok"
  /// yerine yukleniyor gostergesi cizer (aksi halde liste bir an bos gorunup
  /// sonra dolar).
  final bool isRestoringDraft;

  /// Kayitlarin etikette kaplayacagi toplam byte (TLV zarfi dahil).
  int get byteLength =>
      records.isEmpty ? 0 : NdefConverter.encodeAll(records).byteLengthOnTag;

  bool get isEmpty => records.isEmpty;

  WriteState copyWith({
    List<NdefContent>? records,
    WritePhase? phase,
    NfcFailure? failure,
    bool clearFailure = false,
    bool? lockAfterWrite,
    int? targetCapacityBytes,
    bool clearTargetCapacity = false,
    bool? isRestoringDraft,
  }) => WriteState(
    records: records ?? this.records,
    phase: phase ?? this.phase,
    failure: clearFailure ? null : (failure ?? this.failure),
    lockAfterWrite: lockAfterWrite ?? this.lockAfterWrite,
    targetCapacityBytes: clearTargetCapacity
        ? null
        : (targetCapacityBytes ?? this.targetCapacityBytes),
    isRestoringDraft: isRestoringDraft ?? this.isRestoringDraft,
  );
}

/// Yazma akisinin evresi.
enum WritePhase {
  editing,
  probingTag,
  waitingForTag,
  writing,

  /// Kayitlar yazildi, etiket kalici olarak salt-okunur yapiliyor.
  ///
  /// Yalnizca [WriteState.lockAfterWrite] acikken gorulur.
  locking,
  success,
  failure,
}

/// Yazma ekraninin denetleyicisi.
///
/// Su an yalnizca temel akis vardir (kayit ekle → yaz → dogrula).
/// Coklu yazma, sablonlar ve sihirbazlar T3'un isi.
///
/// **Kalicilik:** Kayit listesi her degisiklikte [WriteDraftStore] uzerinden
/// diske yazilir ve uygulama yeniden acildiginda geri yuklenir. Kullanici
/// listeyi acikca temizlemedikce (bkz. [clear]) taslak kaybolmaz.
final class WriteController extends Notifier<WriteState> {
  static const AppLogger _log = AppLogger('write.controller');

  /// Kalici taslak deposu. Depo baglanmamissa (orn. bazi testler) null olur
  /// ve otomatik kayit sessizce devre disi kalir.
  WriteDraftStore? _draftStore;

  /// Taslak islerinin sirali kuyrugu: once yukleme, sonra her kayit.
  ///
  /// Zincir sayesinde iki kayit birbirinin ustune binmez ve yukleme bitmeden
  /// kayit yazilmaz.
  Future<void> _draftQueue = Future<void>.value();

  /// Taslak diskten okunmadan once kullanici listeye dokundu mu?
  ///
  /// Dokunduysa okuma sonucu **uygulanmaz** — kullanicinin o anki islemi
  /// (orn. gecmisten yukleme) daha guncel.
  bool _touched = false;

  bool _disposed = false;

  @override
  WriteState build() {
    _touched = false;
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    _draftStore = _resolveDraftStore();
    if (_draftStore == null) return const WriteState();

    // microtask: build() bitmeden state'e dokunmayalim.
    _draftQueue = Future<void>.microtask(_restoreDraft);
    return const WriteState(isRestoringDraft: true);
  }

  /// Bekleyen taslak islerinin (yukleme + kayit) bitmesini bekler.
  ///
  /// Testler icindir; UI bunu beklemek zorunda degildir.
  Future<void> get draftSettled => _draftQueue;

  /// Listeye kayit ekler.
  void addRecord(NdefContent content) {
    state = state.copyWith(records: [...state.records, content]);
    _persistDraft();
  }

  /// Verilen sirdaki kaydi gunceller.
  void updateRecord({required int index, required NdefContent content}) {
    if (index < 0 || index >= state.records.length) return;
    final records = [...state.records];
    records[index] = content;
    state = state.copyWith(records: records);
    _persistDraft();
  }

  /// Verilen sirdaki kaydi siler.
  void removeRecord(int index) {
    final records = [...state.records]..removeAt(index);
    state = state.copyWith(records: records);
    _persistDraft();
  }

  /// Kaydin yerini degistirir (surukle-birak siralama).
  ///
  /// [newIndex] cikarilan ogeye gore duzeltilmis olmalidir —
  /// `ReorderableListView.onReorderItem` bunu kendisi yapar.
  void reorder(int oldIndex, int newIndex) {
    final records = [...state.records];
    records.insert(newIndex, records.removeAt(oldIndex));
    state = state.copyWith(records: records);
    _persistDraft();
  }

  /// Tumunu temizler — kayitli taslak da silinir.
  ///
  /// Kalici veri gittigi icin ekran bunu onaysiz cagirmaz.
  void clear() {
    state = const WriteState();
    _persistDraft();
  }

  /// "Yazdiktan sonra kilitle" anahtarini degistirir.
  void setLockAfterWrite({required bool value}) =>
      state = state.copyWith(lockAfterWrite: value);

  /// Hedef etiketin kapasitesini okur.
  Future<void> probeTargetCapacity() async {
    if (state.phase != WritePhase.editing) return;

    final session = ref.read(nfcSessionServiceProvider);
    final operations = ref.read(tagOperationsProvider);

    state = state.copyWith(phase: WritePhase.probingTag, clearFailure: true);

    final result = await session.runOnce<NfcTagInfo>(
      onTag: (tag) => operations.inspect(tag, deep: false),
      polling: const {NfcPollingMode.iso14443, NfcPollingMode.iso15693},
    );

    state = switch (result) {
      Ok(:final value) => state.copyWith(
        phase: WritePhase.editing,
        targetCapacityBytes: value.maxNdefSize,
      ),
      Err(:final failure) => state.copyWith(
        phase: WritePhase.failure,
        failure: failure,
      ),
    };
  }

  /// Etikete yazar.
  Future<void> write() async {
    if (state.isEmpty || state.phase != WritePhase.editing) return;

    final session = ref.read(nfcSessionServiceProvider);
    final operations = ref.read(tagOperationsProvider);
    final message = NdefConverter.encodeAll(state.records);

    state = state.copyWith(phase: WritePhase.waitingForTag, clearFailure: true);

    final result = await session.runOnce<void>(
      onTag: (tag) async {
        state = state.copyWith(phase: WritePhase.writing);
        final writeResult = await operations.writeNdef(tag, message);
        if (writeResult case Err()) return writeResult;
        if (!state.lockAfterWrite) return writeResult;

        // GERI ALINAMAZ. Kullanici onayi yazma baslatilmadan once
        // `WritePage` icinde `DangerDialog` ile alinir (ADR-0005).
        state = state.copyWith(phase: WritePhase.locking);
        _log.info('Yazma sonrasi kalici kilitleme uygulaniyor');
        return operations.makeReadOnly(
          tag,
          ack: DangerAck.userConfirmed(
            risk: OperationRisk.irreversible,
            operationId: 'write_lock_after_write',
            targetUidHex: bytesToHex(tag.uid),
            backupTaken: false,
          ),
        );
      },
    );

    state = switch (result) {
      Ok() => state.copyWith(phase: WritePhase.success),
      Err(:final failure) => state.copyWith(
        phase: WritePhase.failure,
        failure: failure,
      ),
    };
  }

  /// Yazma oturumunu iptal eder.
  Future<void> cancel() async {
    await ref.read(nfcSessionServiceProvider).stopSession();
    state = state.copyWith(phase: WritePhase.editing, clearFailure: true);
  }

  /// Sonuc gosterildikten sonra duzenleme moduna doner.
  void acknowledge() =>
      state = state.copyWith(phase: WritePhase.editing, clearFailure: true);

  /// Gecmisteki bir taramanin NDEF icerigini duzenleme listesine yukler.
  ///
  /// `ScanRecord.rawJson`, okuma sirasinda ham NDEF kayitlarinin hex
  /// serilestirilmis hali olarak kaydedilir (bkz. `feature_read`). Burada
  /// geri cozumlenip [NdefContent] listesine cevrilir. Kayit bulunamazsa
  /// ya da yuklenebilir veri yoksa sessizce hicbir sey yapmaz.
  Future<void> loadFromHistory(int historyId) async {
    final repository = ref.read(historyRepositoryProvider);
    final result = await repository.findById(historyId);
    if (result case Err()) return;
    final record = (result as Ok<ScanRecord?>).value;
    if (record == null) return;

    final message = _decodeNdefMessage(record.rawJson);
    if (message == null || message.records.isEmpty) return;

    state = state.copyWith(
      records: NdefConverter.decodeAll(message),
      isRestoringDraft: false,
    );
    _persistDraft();
  }

  // -------------------------------------------------------------------
  // Taslak kaliciligi
  // -------------------------------------------------------------------

  WriteDraftStore? _resolveDraftStore() {
    try {
      return ref.read(writeDraftStoreProvider);
    } on Object catch (e) {
      // Depo baglanmamis (composition root disi bir kullanim). Ekran
      // calismaya devam etsin, yalnizca otomatik kayit olmasin.
      _log.warning('Taslak deposu yok — otomatik kayit devre disi', e);
      return null;
    }
  }

  Future<void> _restoreDraft() async {
    final store = _draftStore;
    if (store == null) return;

    final records = await store.load();
    if (_disposed) return;

    // Yukleme suresi icinde kullanici bir sey yaptiysa uzerine yazma.
    if (_touched || records.isEmpty) {
      state = state.copyWith(isRestoringDraft: false);
      return;
    }
    state = state.copyWith(records: records, isRestoringDraft: false);
  }

  void _persistDraft() {
    _touched = true;
    final store = _draftStore;
    if (store == null) return;

    final snapshot = List<NdefContent>.unmodifiable(state.records);
    _draftQueue = _draftQueue
        .then((_) => store.save(snapshot))
        .catchError((Object error, StackTrace stackTrace) {
          _log.error('Taslak kaydedilemedi', error, stackTrace);
        });
  }

  NdefMessageEntity? _decodeNdefMessage(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return null;
    try {
      final map = jsonDecode(rawJson);
      if (map is! Map<String, Object?> || map['records'] is! List) {
        return null;
      }
      final records = <NdefRecordEntity>[];
      for (final item in map['records']! as List) {
        if (item is! Map) continue;
        final entry = item.cast<String, Object?>();
        records.add(
          NdefRecordEntity(
            typeNameFormat: NdefTypeNameFormat.fromValue(
              entry['tnf'] as int? ?? 0,
            ),
            type: hexToBytes(entry['type'] as String? ?? ''),
            identifier: hexToBytes(entry['id'] as String? ?? ''),
            payload: hexToBytes(entry['payload'] as String? ?? ''),
          ),
        );
      }
      return records.isEmpty ? null : NdefMessageEntity(records);
    } on Object {
      return null;
    }
  }
}

/// Yazma ekrani denetleyicisi.
final NotifierProvider<WriteController, WriteState> writeControllerProvider =
    NotifierProvider<WriteController, WriteState>(WriteController.new);
