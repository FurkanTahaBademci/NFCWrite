import 'package:nfc_core/nfc_core.dart';

import 'app_strings.dart';

/// [NfcFailure] tiplerini kullaniciya gosterilecek metne cevirir.
///
/// `NfcFailure` sealed oldugu icin buradaki `switch` **exhaustive**'dir:
/// yeni bir hata tipi eklendiginde bu dosya derlenmez ve ceviri
/// unutulamaz. Bu kasitlidir.
extension FailureMessages on AppStrings {
  /// Hatanin kullaniciya gosterilecek hali.
  String messageFor(NfcFailure failure) => switch (failure) {
    NfcUnavailable(:final reason) => switch (reason) {
      NfcUnavailableReason.unsupported => errorNfcUnsupported,
      NfcUnavailableReason.disabled => errorNfcDisabled,
    },
    TagLost() => errorTagLost,
    TagNotSupported() => errorTagNotSupported,
    TagReadOnly() => errorTagReadOnly,
    InsufficientSpace(:final needed, :final available) =>
      errorInsufficientSpace(needed, available),
    AuthenticationRequired() => errorAuthRequired,
    AuthenticationFailed() => errorAuthFailed,
    InvalidArgument() => errorUnknown,
    OperationCancelled() => errorCancelled,
    OperationTimeout() => errorTimeout,
    VerificationFailed() => errorVerificationFailed,
    MalformedData() => errorMalformedData,
    StorageError() => errorStorage,
    NotImplementedYet() => errorNotImplemented,
    TransportError() => errorUnknown,
  };

  /// Hatanin kullanicinin yapabilecegi bir eylemi var mi?
  ///
  /// Orn. NFC kapaliysa "NFC ayarlarini ac" dugmesi gosterilir.
  String? actionLabelFor(NfcFailure failure) => switch (failure) {
    NfcUnavailable(reason: NfcUnavailableReason.disabled) =>
      errorNfcDisabledAction,
    TagLost() || OperationTimeout() => actionRetry,
    _ => null,
  };
}
