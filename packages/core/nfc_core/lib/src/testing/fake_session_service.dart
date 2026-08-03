import 'dart:async';

import '../contracts/nfc_session_service.dart';
import '../failures.dart';
import '../result.dart';
import 'fake_tag_handle.dart';

/// Testlerde kullanilan, donanim gerektirmeyen [NfcSessionService].
///
/// Sirayla dondurulecek etiketler verilir; her [runOnce] cagrisinda
/// siradaki etiket kullanilir. Etiket kalmadiginda [whenExhausted] hatasi
/// dondurulur.
///
/// ```dart
/// final service = FakeNfcSessionService(tags: [FakeTagHandle(uid: ...)]);
/// final result = await service.runOnce(onTag: (tag) => ops.identify(tag));
/// ```
final class FakeNfcSessionService implements NfcSessionService {
  FakeNfcSessionService({
    List<FakeTagHandle> tags = const [],
    this.availability = NfcAvailabilityStatus.enabled,
    this.whenExhausted = const TagLost(),
    this.discoveryDelay = Duration.zero,
  }) : _tags = List.of(tags);

  final List<FakeTagHandle> _tags;

  /// Servisin bildirecegi NFC durumu.
  NfcAvailabilityStatus availability;

  /// Etiket kuyrugu bittiginde donecek hata.
  final NfcFailure whenExhausted;

  /// Etiketin "bulunmasi" icin beklenecek sure — zaman asimi testleri icin.
  final Duration discoveryDelay;

  int _index = 0;
  bool _sessionActive = false;

  /// [openNfcSettings] kac kez cagrildi?
  int openSettingsCallCount = 0;

  /// [stopSession] kac kez cagrildi?
  int stopSessionCallCount = 0;

  /// Kuyruga yeni etiket ekler.
  void enqueue(FakeTagHandle tag) => _tags.add(tag);

  /// Kuyrugu basa sarar.
  void rewind() => _index = 0;

  @override
  bool get isSessionActive => _sessionActive;

  @override
  Future<NfcAvailabilityStatus> checkAvailability() async => availability;

  @override
  Future<void> openNfcSettings() async => openSettingsCallCount++;

  @override
  Future<Result<T>> runOnce<T>({
    required Future<Result<T>> Function(NfcTagHandle tag) onTag,
    Set<NfcPollingMode> polling = const {NfcPollingMode.iso14443},
    Duration? timeout,
  }) async {
    if (availability != NfcAvailabilityStatus.enabled) {
      return Err<T>(
        NfcUnavailable(
          availability == NfcAvailabilityStatus.disabled
              ? NfcUnavailableReason.disabled
              : NfcUnavailableReason.unsupported,
        ),
      );
    }
    if (_index >= _tags.length) return Err<T>(whenExhausted);

    _sessionActive = true;
    try {
      if (discoveryDelay > Duration.zero) {
        if (timeout != null && discoveryDelay >= timeout) {
          await Future<void>.delayed(timeout);
          return Err<T>(OperationTimeout(timeout));
        }
        await Future<void>.delayed(discoveryDelay);
      }
      return await onTag(_tags[_index++]);
    } finally {
      await stopSession();
    }
  }

  @override
  Stream<Result<T>> runContinuous<T>({
    required Future<Result<T>> Function(NfcTagHandle tag) onTag,
    Set<NfcPollingMode> polling = const {NfcPollingMode.iso14443},
  }) async* {
    _sessionActive = true;
    try {
      while (_index < _tags.length) {
        if (discoveryDelay > Duration.zero) {
          await Future<void>.delayed(discoveryDelay);
        }
        yield await onTag(_tags[_index++]);
      }
    } finally {
      await stopSession();
    }
  }

  @override
  Future<void> stopSession() async {
    stopSessionCallCount++;
    _sessionActive = false;
  }
}
