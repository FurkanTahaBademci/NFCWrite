import 'dart:async';

import 'package:flutter/services.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:nfc_manager/nfc_manager.dart' as platform;
import 'package:shared_utils/shared_utils.dart';

import 'android_tag_handle.dart';
import 'error_mapper.dart';

/// Sistem ayarlarini acmak icin kullanilan kanal.
///
/// Yerel tarafi `apps/nfc_toolkit/android/.../MainActivity.kt` icinde
/// karsilanir. Eklenti yoksa cagri sessizce yok sayilir.
const MethodChannel _systemChannel = MethodChannel('nfc_toolkit/system');

/// [NfcSessionService] arayuzunun Android uygulamasi.
///
/// `nfc_manager` oturum yasam dongusunu sarmalar ve callback tabanli
/// API'yi `Future` / `Stream` tabanli bir API'ye cevirir.
final class AndroidNfcSessionService implements NfcSessionService {
  AndroidNfcSessionService();

  static const AppLogger _log = AppLogger('nfc_transport');

  bool _sessionActive = false;

  @override
  bool get isSessionActive => _sessionActive;

  @override
  Future<NfcAvailabilityStatus> checkAvailability() async {
    try {
      final availability = await platform.NfcManager.instance
          .checkAvailability();
      return switch (availability) {
        platform.NfcAvailability.enabled => NfcAvailabilityStatus.enabled,
        platform.NfcAvailability.disabled => NfcAvailabilityStatus.disabled,
        platform.NfcAvailability.unsupported =>
          NfcAvailabilityStatus.unsupported,
      };
    } on Object catch (e) {
      _log.warning('NFC uygunlugu sorgulanamadi', e);
      return NfcAvailabilityStatus.unsupported;
    }
  }

  @override
  Future<void> openNfcSettings() async {
    try {
      await _systemChannel.invokeMethod<void>('openNfcSettings');
    } on MissingPluginException {
      // Yerel taraf bagli degil (orn. birim testi). Sessiz gec.
      _log.debug('openNfcSettings: yerel kanal yok');
    } on PlatformException catch (e) {
      _log.warning('NFC ayarlari acilamadi', e);
    }
  }

  @override
  Future<Result<T>> runOnce<T>({
    required Future<Result<T>> Function(NfcTagHandle tag) onTag,
    Set<NfcPollingMode> polling = const {NfcPollingMode.iso14443},
    Duration? timeout,
  }) async {
    final availability = await checkAvailability();
    if (availability != NfcAvailabilityStatus.enabled) {
      return Err<T>(NfcUnavailable(_reasonFor(availability)));
    }

    // Onceki oturum acik kalmis olabilir; temiz baslat.
    await stopSession();

    final completer = Completer<Result<T>>();

    // Yerel taraf sessiz nobeti kaldirsin — reader mode'u artik eklenti
    // yonetecek (bkz. MainActivity.applyNfcClaim).
    await _setNativeSessionActive(active: true);

    try {
      await platform.NfcManager.instance.startSession(
        pollingOptions: _toPollingOptions(polling),
        noPlatformSoundsAndroid: false,
        onDiscovered: (tag) async {
          if (completer.isCompleted) return;
          final result = await _runHandler(tag, onTag);
          if (!completer.isCompleted) completer.complete(result);
        },
      );
      _sessionActive = true;
    } on Object catch (e, s) {
      _log.error('Oturum baslatilamadi', e, s);
      await _setNativeSessionActive(active: false);
      return Err<T>(ErrorMapper.map(e, s));
    }

    try {
      if (timeout == null) return await completer.future;
      return await completer.future.timeout(
        timeout,
        onTimeout: () => Err<T>(OperationTimeout(timeout)),
      );
    } finally {
      await stopSession();
    }
  }

  @override
  Stream<Result<T>> runContinuous<T>({
    required Future<Result<T>> Function(NfcTagHandle tag) onTag,
    Set<NfcPollingMode> polling = const {NfcPollingMode.iso14443},
  }) {
    late final StreamController<Result<T>> controller;

    Future<void> start() async {
      final availability = await checkAvailability();
      if (availability != NfcAvailabilityStatus.enabled) {
        controller.add(Err<T>(NfcUnavailable(_reasonFor(availability))));
        unawaited(controller.close());
        return;
      }

      await stopSession();
      await _setNativeSessionActive(active: true);

      try {
        await platform.NfcManager.instance.startSession(
          pollingOptions: _toPollingOptions(polling),
          onDiscovered: (tag) async {
            if (controller.isClosed) return;
            final result = await _runHandler(tag, onTag);
            if (!controller.isClosed) controller.add(result);
          },
        );
        _sessionActive = true;
      } on Object catch (e, s) {
        _log.error('Surekli oturum baslatilamadi', e, s);
        await _setNativeSessionActive(active: false);
        controller.add(Err<T>(ErrorMapper.map(e, s)));
        unawaited(controller.close());
      }
    }

    controller = StreamController<Result<T>>(
      onListen: () => unawaited(start()),
      onCancel: stopSession,
    );

    return controller.stream;
  }

  @override
  Future<void> stopSession() async {
    if (_sessionActive) {
      _sessionActive = false;
      try {
        await platform.NfcManager.instance.stopSession();
      } on Object catch (e) {
        // Oturum zaten kapanmis olabilir; kapatma hatasi cagirani
        // ilgilendirmez.
        _log.debug('stopSession yok sayildi: $e');
      }
    }

    // Oturum bittiginde reader mode'u eklenti kapatir ve etiketi hicbir
    // katman sahiplenmez olur. Yerel tarafa haber ver ki sessiz nobeti
    // yeniden kursun — yoksa sistem "uygulama secin" bildirimi cikarir.
    await _setNativeSessionActive(active: false);
  }

  /// Yerel tarafa oturum durumunu bildirir.
  ///
  /// Bu bayrak `MainActivity`'nin on plan NFC sahiplenmesini yonetir;
  /// bkz. `apps/nfc_toolkit/android/.../MainActivity.kt`.
  Future<void> _setNativeSessionActive({required bool active}) async {
    try {
      await _systemChannel.invokeMethod<void>('setNfcSessionActive', active);
    } on MissingPluginException {
      // Yerel taraf bagli degil (orn. birim testi). Sessiz gec.
    } on PlatformException catch (e) {
      _log.warning('NFC nobeti guncellenemedi', e);
    }
  }

  /// Etiket isleyicisini calistirir; beklenmeyen hatalari yakalar.
  Future<Result<T>> _runHandler<T>(
    platform.NfcTag tag,
    Future<Result<T>> Function(NfcTagHandle tag) onTag,
  ) async {
    try {
      return await onTag(AndroidTagHandle(tag));
    } on Object catch (e, s) {
      _log.error('Etiket isleyicisi hata verdi', e, s);
      return Err<T>(ErrorMapper.map(e, s));
    }
  }

  static NfcUnavailableReason _reasonFor(NfcAvailabilityStatus status) =>
      status == NfcAvailabilityStatus.disabled
      ? NfcUnavailableReason.disabled
      : NfcUnavailableReason.unsupported;

  static Set<platform.NfcPollingOption> _toPollingOptions(
    Set<NfcPollingMode> modes,
  ) => modes
      .map(
        (mode) => switch (mode) {
          NfcPollingMode.iso14443 => platform.NfcPollingOption.iso14443,
          NfcPollingMode.iso15693 => platform.NfcPollingOption.iso15693,
          NfcPollingMode.iso18092 => platform.NfcPollingOption.iso18092,
        },
      )
      .toSet();
}
