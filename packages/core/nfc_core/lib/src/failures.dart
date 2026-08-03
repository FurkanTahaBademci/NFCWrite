import 'package:meta/meta.dart';

/// Bir NFC isleminin basarisizlik sebebi.
///
/// Bu tip **kullaniciya gosterilecek metni tasimaz** — yalnizca makine
/// okunur bir sebep tasir. Ceviri `localization` paketinde yapilir.
/// Boylece `nfc_core` Flutter'a bagimli kalmaz.
///
/// `sealed` oldugu icin, yeni bir alt tip eklendiginde onu ele almayan her
/// `switch` derleme hatasi verir. Bu istenen davranistir.
@immutable
sealed class NfcFailure {
  const NfcFailure();
}

/// NFC donanimi yok ya da kapali.
final class NfcUnavailable extends NfcFailure {
  const NfcUnavailable(this.reason);

  final NfcUnavailableReason reason;

  @override
  bool operator ==(Object other) =>
      other is NfcUnavailable && other.reason == reason;

  @override
  int get hashCode => Object.hash(NfcUnavailable, reason);

  @override
  String toString() => 'NfcUnavailable(${reason.name})';
}

/// [NfcUnavailable] sebebi.
enum NfcUnavailableReason {
  /// Cihazda NFC yongasi yok.
  unsupported,

  /// NFC var ama sistem ayarlarindan kapatilmis.
  disabled,
}

/// Etiket islem ortasinda alandan cikti.
final class TagLost extends NfcFailure {
  const TagLost();

  @override
  bool operator ==(Object other) => other is TagLost;

  @override
  int get hashCode => (TagLost).hashCode;

  @override
  String toString() => 'TagLost()';
}

/// Bu islem bu etiket tipinde desteklenmiyor.
final class TagNotSupported extends NfcFailure {
  const TagNotSupported({this.detail});

  /// Hangi yetenegin eksik oldugu (hata ayiklama icin, ceviri degil).
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is TagNotSupported && other.detail == detail;

  @override
  int get hashCode => Object.hash(TagNotSupported, detail);

  @override
  String toString() => 'TagNotSupported($detail)';
}

/// Etiket yazma korumali ya da kalici olarak kilitli.
final class TagReadOnly extends NfcFailure {
  const TagReadOnly();

  @override
  bool operator ==(Object other) => other is TagReadOnly;

  @override
  int get hashCode => (TagReadOnly).hashCode;

  @override
  String toString() => 'TagReadOnly()';
}

/// Icerik etikete sigmiyor.
final class InsufficientSpace extends NfcFailure {
  const InsufficientSpace({required this.needed, required this.available});

  /// Gereken byte.
  final int needed;

  /// Etikette bulunan byte.
  final int available;

  @override
  bool operator ==(Object other) =>
      other is InsufficientSpace &&
      other.needed == needed &&
      other.available == available;

  @override
  int get hashCode => Object.hash(InsufficientSpace, needed, available);

  @override
  String toString() =>
      'InsufficientSpace(needed: $needed, available: $available)';
}

/// Islem icin once sifre dogrulamasi gerekiyor.
final class AuthenticationRequired extends NfcFailure {
  const AuthenticationRequired();

  @override
  bool operator ==(Object other) => other is AuthenticationRequired;

  @override
  int get hashCode => (AuthenticationRequired).hashCode;

  @override
  String toString() => 'AuthenticationRequired()';
}

/// Sifre yanlis.
final class AuthenticationFailed extends NfcFailure {
  const AuthenticationFailed({this.remainingAttempts});

  /// Kalan deneme hakki. Etiket bildirmiyorsa null.
  ///
  /// AUTHLIM ayarli etiketlerde bu sayi 0'a indiginde etiket kalici olarak
  /// erisilemez hale gelir.
  final int? remainingAttempts;

  @override
  bool operator ==(Object other) =>
      other is AuthenticationFailed &&
      other.remainingAttempts == remainingAttempts;

  @override
  int get hashCode => Object.hash(AuthenticationFailed, remainingAttempts);

  @override
  String toString() => 'AuthenticationFailed($remainingAttempts)';
}

/// Gecersiz parametre (sayfa sinirlari disi, yanlis uzunluk vb.).
final class InvalidArgument extends NfcFailure {
  const InvalidArgument(this.detail);

  final String detail;

  @override
  bool operator ==(Object other) =>
      other is InvalidArgument && other.detail == detail;

  @override
  int get hashCode => Object.hash(InvalidArgument, detail);

  @override
  String toString() => 'InvalidArgument($detail)';
}

/// Kullanici islemi iptal etti.
final class OperationCancelled extends NfcFailure {
  const OperationCancelled();

  @override
  bool operator ==(Object other) => other is OperationCancelled;

  @override
  int get hashCode => (OperationCancelled).hashCode;

  @override
  String toString() => 'OperationCancelled()';
}

/// Islem zaman asimina ugradi.
final class OperationTimeout extends NfcFailure {
  const OperationTimeout(this.duration);

  final Duration duration;

  @override
  bool operator ==(Object other) =>
      other is OperationTimeout && other.duration == duration;

  @override
  int get hashCode => Object.hash(OperationTimeout, duration);

  @override
  String toString() => 'OperationTimeout($duration)';
}

/// Yazma sonrasi dogrulama basarisiz — etikete yazilan veri geri okunanla
/// eslesmedi. Etiket bozuk ya da yazma tamamlanmamis olabilir.
final class VerificationFailed extends NfcFailure {
  const VerificationFailed({this.page});

  /// Uyusmazligin bulundugu sayfa. Bilinmiyorsa null.
  final int? page;

  @override
  bool operator ==(Object other) =>
      other is VerificationFailed && other.page == page;

  @override
  int get hashCode => Object.hash(VerificationFailed, page);

  @override
  String toString() => 'VerificationFailed(page: $page)';
}

/// Etiketten gelen cevap beklenen bicimde degil (bozuk NDEF, gecersiz TLV).
final class MalformedData extends NfcFailure {
  const MalformedData(this.detail);

  final String detail;

  @override
  bool operator ==(Object other) =>
      other is MalformedData && other.detail == detail;

  @override
  int get hashCode => Object.hash(MalformedData, detail);

  @override
  String toString() => 'MalformedData($detail)';
}

/// Kalici depolama hatasi (veritabani, dosya).
final class StorageError extends NfcFailure {
  const StorageError(this.detail, {this.cause});

  final String detail;
  final Object? cause;

  @override
  bool operator ==(Object other) =>
      other is StorageError && other.detail == detail;

  @override
  int get hashCode => Object.hash(StorageError, detail);

  @override
  String toString() => 'StorageError($detail)';
}

/// Bu islem henuz uygulanmadi.
///
/// Iskelet asamasindaki islemler icin kullanilir. Kullaniciya "bu ozellik
/// henuz hazir degil" olarak gosterilir; sessizce basarili gorunmekten
/// ya da anlamsiz bir hata vermekten iyidir.
///
/// [taskId] ilgili track gorevinin kodu (orn. `T4.21`) — gelistirici
/// nereye bakacagini bilsin diye.
final class NotImplementedYet extends NfcFailure {
  const NotImplementedYet(this.taskId);

  /// `.claude/tracks/` icindeki gorev kodu.
  final String taskId;

  @override
  bool operator ==(Object other) =>
      other is NotImplementedYet && other.taskId == taskId;

  @override
  int get hashCode => Object.hash(NotImplementedYet, taskId);

  @override
  String toString() => 'NotImplementedYet($taskId)';
}

/// Alt katmandan gelen, siniflandirilamayan hata.
final class TransportError extends NfcFailure {
  const TransportError(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  bool operator ==(Object other) =>
      other is TransportError && other.message == message;

  @override
  int get hashCode => Object.hash(TransportError, message);

  @override
  String toString() => 'TransportError($message)';
}
