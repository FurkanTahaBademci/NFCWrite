import 'secp128r1.dart';

/// `secp128r1` uzerinde ECDSA imza dogrulamasi.
///
/// Saf matematik — hangi genel anahtarin, hangi mesaj icin kullanildigi
/// cagirana aittir. NXP orijinallik imzasi baglami icin
/// `NxpOriginalityKeys` ve `TagOperationsImpl.verifySignature`'a bakin.
abstract final class Ecdsa {
  /// Imzayi dogrular.
  ///
  /// [message] imzalanan verinin buyuk-endian tam sayi karsiligidir.
  /// NXP orijinallik imzasinda bu bir hash degil, dogrudan etiketin
  /// UID'idir (bkz. NXP AN11350 "NTAG21x Originality Signature
  /// Validation").
  static bool verify({
    required BigInt message,
    required BigInt r,
    required BigInt s,
    required EccPoint publicKey,
  }) {
    final n = Secp128r1.n;
    if (r <= BigInt.zero || r >= n) return false;
    if (s <= BigInt.zero || s >= n) return false;

    final w = s.modInverse(n);
    final u1 = (message * w) % n;
    final u2 = (r * w) % n;

    final point = Secp128r1.add(
      Secp128r1.multiply(u1, Secp128r1.g),
      Secp128r1.multiply(u2, publicKey),
    );

    if (point.isInfinity) return false;
    return (point.x! % n) == r;
  }
}
