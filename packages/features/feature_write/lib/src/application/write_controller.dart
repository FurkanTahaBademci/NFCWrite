import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndef_codec/ndef_codec.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';

import 'providers.dart';

/// Yazma ekraninin durumu.
final class WriteState {
  const WriteState({
    this.records = const <NdefContent>[],
    this.phase = WritePhase.editing,
    this.failure,
    this.lockAfterWrite = false,
    this.targetCapacityBytes,
  });

  /// Etikete yazilacak kayitlar, sirasiyla.
  final List<NdefContent> records;

  final WritePhase phase;
  final NfcFailure? failure;

  /// Yazdiktan sonra etiket kalici olarak kilitlensin mi?
  final bool lockAfterWrite;

  /// Taranan hedef etiketin NDEF kapasitesi (byte). Henuz taranmadiysa null.
  final int? targetCapacityBytes;

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
  }) => WriteState(
    records: records ?? this.records,
    phase: phase ?? this.phase,
    failure: clearFailure ? null : (failure ?? this.failure),
    lockAfterWrite: lockAfterWrite ?? this.lockAfterWrite,
    targetCapacityBytes: clearTargetCapacity
        ? null
        : (targetCapacityBytes ?? this.targetCapacityBytes),
  );
}

/// Yazma akisinin evresi.
enum WritePhase {
  editing,
  probingTag,
  waitingForTag,
  writing,
  success,
  failure,
}

/// Yazma ekraninin denetleyicisi.
///
/// Su an yalnizca temel akis vardir (kayit ekle → yaz → dogrula).
/// Coklu yazma, sablonlar ve sihirbazlar T3'un isi.
final class WriteController extends Notifier<WriteState> {
  @override
  WriteState build() => const WriteState();

  /// Listeye kayit ekler.
  void addRecord(NdefContent content) {
    state = state.copyWith(records: [...state.records, content]);
  }

  /// Verilen sirdaki kaydi gunceller.
  void updateRecord({required int index, required NdefContent content}) {
    if (index < 0 || index >= state.records.length) return;
    final records = [...state.records];
    records[index] = content;
    state = state.copyWith(records: records);
  }

  /// Verilen sirdaki kaydi siler.
  void removeRecord(int index) {
    final records = [...state.records]..removeAt(index);
    state = state.copyWith(records: records);
  }

  /// Kaydin yerini degistirir (surukle-birak siralama).
  ///
  /// [newIndex] cikarilan ogeye gore duzeltilmis olmalidir —
  /// `ReorderableListView.onReorderItem` bunu kendisi yapar.
  void reorder(int oldIndex, int newIndex) {
    final records = [...state.records];
    records.insert(newIndex, records.removeAt(oldIndex));
    state = state.copyWith(records: records);
  }

  /// Tumunu temizler.
  void clear() => state = const WriteState();

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
        return operations.writeNdef(tag, message);
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

    state = state.copyWith(records: NdefConverter.decodeAll(message));
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
