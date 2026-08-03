import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';

import 'providers.dart';

/// Okuma ekraninin durumu.
sealed class ReadState {
  const ReadState();
}

/// Henuz tarama yapilmadi.
final class ReadIdle extends ReadState {
  const ReadIdle();
}

/// Etiket bekleniyor.
final class ReadScanning extends ReadState {
  const ReadScanning();
}

/// Etiket okundu.
final class ReadSuccess extends ReadState {
  const ReadSuccess(this.info);

  final NfcTagInfo info;
}

/// Okuma basarisiz.
final class ReadFailure extends ReadState {
  const ReadFailure(this.failure);

  final NfcFailure failure;
}

/// Okuma ekraninin denetleyicisi.
final class ReadController extends Notifier<ReadState> {
  static const AppLogger _log = AppLogger('feature_read');

  @override
  ReadState build() => const ReadIdle();

  /// Tek seferlik tarama baslatir.
  ///
  /// [deep] true ise tam bellek dokumu, yapilandirma ve kilit durumu da
  /// okunur — yavastir ama teknik sekme icin gereklidir.
  Future<void> scan({bool? deep}) async {
    if (state is ReadScanning) return;

    final session = ref.read(nfcSessionServiceProvider);
    final operations = ref.read(tagOperationsProvider);
    final settings = ref.read(settingsRepositoryProvider).current;
    final deepRead = deep ?? settings.readDeepByDefault;

    state = const ReadScanning();

    final result = await session.runOnce<NfcTagInfo>(
      onTag: (tag) => operations.inspect(tag, deep: deepRead),
      polling: const {NfcPollingMode.iso14443, NfcPollingMode.iso15693},
    );

    switch (result) {
      case Ok(:final value):
        state = ReadSuccess(value);
        if (settings.autoSaveHistory) {
          await _saveToHistory(value);
        }
      case Err(:final failure):
        _log.debug('Okuma basarisiz: $failure');
        state = ReadFailure(failure);
    }
  }

  /// Devam eden taramayi durdurur.
  Future<void> cancel() async {
    await ref.read(nfcSessionServiceProvider).stopSession();
    state = const ReadIdle();
  }

  /// Ekrani bosaltir.
  void reset() => state = const ReadIdle();

  /// Sistem NFC ayarlarini acar (NFC kapaliysa).
  Future<void> openNfcSettings() =>
      ref.read(nfcSessionServiceProvider).openNfcSettings();

  Future<void> _saveToHistory(NfcTagInfo info) async {
    final repository = ref.read(historyRepositoryProvider);
    final result = await repository.add(
      ScanRecord(
        id: null,
        uidHex: info.uidHex,
        scannedAt: info.scannedAt,
        chipFamily: info.identity.family,
        chipDisplayName: info.identity.displayName,
        technologies: info.technologies
            .map((tech) => tech.name)
            .toList(growable: false),
        recordSummaries: _summarize(info),
        ndefByteLength: info.currentNdefSize,
        maxNdefSize: info.maxNdefSize,
        wasWritable: info.isWritable,
      ),
    );
    if (result case Err(:final failure)) {
      // Gecmise yazamamak okumayi gecersiz kilmaz; kullaniciyi rahatsiz etme.
      _log.warning('Gecmise kaydedilemedi', failure);
    }
  }

  List<String> _summarize(NfcTagInfo info) {
    final message = info.ndefMessage;
    if (message == null) return const [];
    return message.records
        .map(
          (record) =>
              '${record.typeNameFormat.name}: ${record.typeAsString} '
              '(${record.payload.length} byte)',
        )
        .toList(growable: false);
  }
}

/// Okuma ekrani denetleyicisi.
final NotifierProvider<ReadController, ReadState> readControllerProvider =
    NotifierProvider<ReadController, ReadState>(ReadController.new);

/// NFC donaniminin durumu — ekran acilirken kontrol edilir.
final FutureProvider<NfcAvailabilityStatus> nfcAvailabilityProvider =
    FutureProvider<NfcAvailabilityStatus>(
      (ref) => ref.read(nfcSessionServiceProvider).checkAvailability(),
    );
