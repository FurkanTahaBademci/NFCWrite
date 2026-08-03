import 'failures.dart';

/// Bir islemin sonucu: ya [Ok] ya [Err].
///
/// Beklenen hatalar (etiket kayboldu, sifre yanlis, yer yetmedi) exception
/// yerine bu tiple tasinir. Boylece derleyici hata yollarini zorlar.
/// Gerekce: `.claude/docs/adr/ADR-0004-result-type.md`
sealed class Result<T> {
  const Result();

  /// Basarili sonuc olustur.
  const factory Result.ok(T value) = Ok<T>;

  /// Hatali sonuc olustur.
  const factory Result.err(NfcFailure failure) = Err<T>;

  /// Senkron bir isi calistirir, beklenmeyen hatayi [TransportError] yapar.
  static Result<T> guard<T>(T Function() body) {
    try {
      return Ok<T>(body());
    } on Object catch (e, s) {
      return Err<T>(TransportError(e.toString(), cause: e, stackTrace: s));
    }
  }

  /// Asenkron bir isi calistirir, beklenmeyen hatayi [TransportError] yapar.
  static Future<Result<T>> guardAsync<T>(Future<T> Function() body) async {
    try {
      return Ok<T>(await body());
    } on Object catch (e, s) {
      return Err<T>(TransportError(e.toString(), cause: e, stackTrace: s));
    }
  }

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// Basariliysa deger, degilse null.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// Hataliysa hata, degilse null.
  NfcFailure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Basarili degeri donusturur; hata oldugu gibi gecer.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok<R>(transform(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// Zincirleme: basariliysa yeni bir [Result] uretir.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => transform(value),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// Asenkron zincirleme.
  Future<Result<R>> flatMapAsync<R>(
    Future<Result<R>> Function(T value) transform,
  ) async => switch (this) {
    Ok<T>(:final value) => await transform(value),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// Hata durumunda yedek deger uretir.
  T getOrElse(T Function(NfcFailure failure) orElse) => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>(:final failure) => orElse(failure),
  };

  /// Iki dalli tuketim.
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(NfcFailure failure) onErr,
  }) => switch (this) {
    Ok<T>(:final value) => onOk(value),
    Err<T>(:final failure) => onErr(failure),
  };
}

/// Basarili sonuc.
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ok<T> &&
          runtimeType == other.runtimeType &&
          value == other.value);

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => 'Ok($value)';
}

/// Hatali sonuc.
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final NfcFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Err<T> &&
          runtimeType == other.runtimeType &&
          failure == other.failure);

  @override
  int get hashCode => Object.hash(runtimeType, failure);

  @override
  String toString() => 'Err($failure)';
}

/// `Result<void>` icin kisayol.
const Result<void> okVoid = Ok<void>(null);
