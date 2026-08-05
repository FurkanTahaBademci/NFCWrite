import 'package:meta/meta.dart';

/// `secp128r1` egrisi uzerinde bir afin nokta.
///
/// NXP NTAG21x / MIFARE Ultralight EV1 orijinallik imzasi bu egri
/// uzerinde ECDSA kullanir (bkz. NXP AN11350).
@immutable
final class EccPoint {
  const EccPoint(this.x, this.y);

  /// Sonsuzdaki nokta (toplamsal birim eleman).
  static const EccPoint infinity = EccPoint(null, null);

  final BigInt? x;
  final BigInt? y;

  bool get isInfinity => x == null || y == null;

  @override
  bool operator ==(Object other) =>
      other is EccPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// `secp128r1` (SEC 2) egri parametreleri ve nokta aritmetigi.
///
/// Parametreler SEC 2 "Recommended Elliptic Curve Domain Parameters"
/// standardindan alinmistir — egrinin kendisi genel/standarttir, yalnizca
/// dogrulamada kullanilan **genel anahtar** yongaya ozeldir
/// (bkz. `NxpOriginalityKeys`).
abstract final class Secp128r1 {
  static final BigInt p = BigInt.parse(
    'FFFFFFFDFFFFFFFFFFFFFFFFFFFFFFFF',
    radix: 16,
  );
  static final BigInt a = BigInt.parse(
    'FFFFFFFDFFFFFFFFFFFFFFFFFFFFFFFC',
    radix: 16,
  );
  static final BigInt b = BigInt.parse(
    'E87579C11079F43DD824993C2CEE5ED3',
    radix: 16,
  );

  /// Egrinin mertebesi (order) — imza dogrulamasinda modulo alinir.
  static final BigInt n = BigInt.parse(
    'FFFFFFFE0000000075A30D1B9038A115',
    radix: 16,
  );

  /// Uretici (base) nokta.
  static final EccPoint g = EccPoint(
    BigInt.parse('161FF7528B899B2D0C28607CA52C5B86', radix: 16),
    BigInt.parse('CF5AC8395BAFEB13C02DA292DDED7A83', radix: 16),
  );

  /// Iki noktayi toplar (P + Q).
  static EccPoint add(EccPoint p1, EccPoint p2) {
    if (p1.isInfinity) return p2;
    if (p2.isInfinity) return p1;

    if (p1.x == p2.x) {
      if (_mod(p1.y! + p2.y!) == BigInt.zero) return EccPoint.infinity;
      return _double(p1);
    }

    final lambda = (_mod(p2.y! - p1.y!) * _inverse(_mod(p2.x! - p1.x!))) % p;
    final x3 = _mod(lambda * lambda - p1.x! - p2.x!);
    final y3 = _mod(lambda * (p1.x! - x3) - p1.y!);
    return EccPoint(x3, y3);
  }

  /// Skaler carpim: `k * P` (cift-ve-topla algoritmasi).
  static EccPoint multiply(BigInt k, EccPoint point) {
    var result = EccPoint.infinity;
    var addend = point;
    var scalar = k;

    while (scalar > BigInt.zero) {
      if (scalar.isOdd) {
        result = add(result, addend);
      }
      addend = _double(addend);
      scalar >>= 1;
    }

    return result;
  }

  static EccPoint _double(EccPoint point) {
    if (point.isInfinity) return EccPoint.infinity;
    if (point.y == BigInt.zero) return EccPoint.infinity;

    final lambda =
        (_mod(BigInt.from(3) * point.x! * point.x! + a) *
            _inverse(_mod(BigInt.two * point.y!))) %
        p;
    final x3 = _mod(lambda * lambda - BigInt.two * point.x!);
    final y3 = _mod(lambda * (point.x! - x3) - point.y!);
    return EccPoint(x3, y3);
  }

  static BigInt _inverse(BigInt value) => value.modInverse(p);

  static BigInt _mod(BigInt value) {
    final result = value % p;
    return result.isNegative ? result + p : result;
  }
}
