import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndef_codec/ndef_codec.dart';
import 'package:nfc_core/nfc_core.dart';

import 'providers.dart';

/// Yazma ekraninin durumu.
final class WriteState {
  const WriteState({
    this.records = const <NdefContent>[],
    this.phase = WritePhase.editing,
    this.failure,
    this.lockAfterWrite = false,
  });

  /// Etikete yazilacak kayitlar, sirasiyla.
  final List<NdefContent> records;

  final WritePhase phase;
  final NfcFailure? failure;

  /// Yazdiktan sonra etiket kalici olarak kilitlensin mi?
  final bool lockAfterWrite;

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
  }) => WriteState(
    records: records ?? this.records,
    phase: phase ?? this.phase,
    failure: clearFailure ? null : (failure ?? this.failure),
    lockAfterWrite: lockAfterWrite ?? this.lockAfterWrite,
  );
}

/// Yazma akisinin evresi.
enum WritePhase { editing, waitingForTag, writing, success, failure }

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
}

/// Yazma ekrani denetleyicisi.
final NotifierProvider<WriteController, WriteState> writeControllerProvider =
    NotifierProvider<WriteController, WriteState>(WriteController.new);
