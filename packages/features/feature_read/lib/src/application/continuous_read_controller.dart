import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';

import 'providers.dart';

/// Surekli tarama ekraninin durumu (T2.21).
///
/// Tek seferlik okumadan (`ReadState`) bilerek ayri tutulur: farkli bir
/// akis (liste + sayaç, modal kapanmadan devam eder) ve ayri bir yasam
/// dongusu (oturum durdurulana kadar acik kalir) gerektirir.
sealed class ContinuousReadState {
  const ContinuousReadState();
}

/// Henuz baslamadi.
final class ContinuousReadIdle extends ContinuousReadState {
  const ContinuousReadIdle();
}

/// Tarama suruyor; su ana kadar okunanlar [results] icinde.
final class ContinuousReadActive extends ContinuousReadState {
  const ContinuousReadActive(this.results);

  final List<NfcTagInfo> results;
}

/// Oturum bir hatayla durdu (ör. NFC kapatildi). O ana kadarki sonuclar
/// korunur — kullanici listeyi kaybetmez.
final class ContinuousReadFailure extends ContinuousReadState {
  const ContinuousReadFailure(this.failure, this.results);

  final NfcFailure failure;
  final List<NfcTagInfo> results;
}

/// Surekli tarama denetleyicisi.
final class ContinuousReadController extends Notifier<ContinuousReadState> {
  static const AppLogger _log = AppLogger('feature_read');

  StreamSubscription<Result<NfcTagInfo>>? _subscription;
  final List<NfcTagInfo> _results = [];
  String? _lastUidHex;

  @override
  ContinuousReadState build() {
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
    });
    return const ContinuousReadIdle();
  }

  /// Surekli taramayi baslatir. Ayni etiket arka arkaya okunursa
  /// (etiket alandan ayrilmadiginda nfc_manager tekrar tetikleyebilir)
  /// listeye ikinci kez eklenmez.
  void start() {
    _results.clear();
    _lastUidHex = null;

    final session = ref.read(nfcSessionServiceProvider);
    final operations = ref.read(tagOperationsProvider);

    state = const ContinuousReadActive(<NfcTagInfo>[]);

    unawaited(_subscription?.cancel());
    _subscription =
        session
            .runContinuous<NfcTagInfo>(
              onTag: operations.inspect,
              polling: const {
                NfcPollingMode.iso14443,
                NfcPollingMode.iso15693,
              },
            )
            .listen((result) {
              switch (result) {
                case Ok(:final value):
                  if (value.uidHex != _lastUidHex) {
                    _lastUidHex = value.uidHex;
                    _results.insert(0, value);
                  }
                  state = ContinuousReadActive(List.unmodifiable(_results));
                case Err(:final failure):
                  _log.debug('Surekli tarama hatasi: $failure');
                  state = ContinuousReadFailure(
                    failure,
                    List.unmodifiable(_results),
                  );
              }
            });
  }

  /// Taramayi durdurur; su ana kadarki sonuclar ekranda kalir.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await ref.read(nfcSessionServiceProvider).stopSession();
    state = ContinuousReadActive(List.unmodifiable(_results));
  }

  /// Listeyi ve durumu sifirlar.
  void reset() {
    _results.clear();
    _lastUidHex = null;
    state = const ContinuousReadIdle();
  }
}

/// Surekli tarama denetleyicisi.
final NotifierProvider<ContinuousReadController, ContinuousReadState>
continuousReadControllerProvider =
    NotifierProvider<ContinuousReadController, ContinuousReadState>(
      ContinuousReadController.new,
    );
