import 'package:meta/meta.dart';

/// Bir islemin ne kadar tehlikeli oldugu.
enum OperationRisk {
  /// Etiketi degistirmez.
  safe,

  /// NDEF icerigini degistirir; uzerine yeniden yazilabilir.
  content,

  /// Yapilandirma byte'larini degistirir; dikkatli olunmali.
  config,

  /// **Geri alinamaz.** Etiket kalici olarak degisir ya da kullanilamaz olur.
  irreversible,
}

/// Yikici bir islemin kullanici tarafindan onaylandiginin kaniti.
///
/// `tag_ops` icindeki tehlikeli islemler bu tipi **zorunlu parametre** olarak
/// ister. Boylece onay diyalogundan gecmeyen bir cagri derlenemez.
/// Gerekce: `.claude/docs/adr/ADR-0005-safety-gates.md`
///
/// Bu nesne yalnizca arayuz katmaninda, kullanici onayindan **sonra**
/// olusturulmalidir. Servis katmaninda uretmek kurali delmek demektir.
@immutable
final class DangerAck {
  const DangerAck._({
    required this.risk,
    required this.operationId,
    required this.acknowledgedAt,
    required this.backupTaken,
    required this.targetUidHex,
  });

  /// Kullanici onayindan sonra arayuz katmaninda olusturulur.
  ///
  /// [operationId] islemi tanimlayan sabit anahtar (orn. `set_password`).
  /// [targetUidHex] onayin hangi etiket icin verildigi.
  /// [backupTaken] islem oncesi yedek alinip alinmadigi.
  factory DangerAck.userConfirmed({
    required OperationRisk risk,
    required String operationId,
    required String targetUidHex,
    required bool backupTaken,
  }) {
    if (risk == OperationRisk.safe) {
      throw ArgumentError.value(
        risk,
        'risk',
        'Guvenli islemler DangerAck gerektirmez',
      );
    }
    return DangerAck._(
      risk: risk,
      operationId: operationId,
      acknowledgedAt: DateTime.now(),
      backupTaken: backupTaken,
      targetUidHex: targetUidHex,
    );
  }

  /// Yalnizca testlerde kullanilir.
  @visibleForTesting
  factory DangerAck.forTest({
    OperationRisk risk = OperationRisk.irreversible,
    String operationId = 'test',
    String targetUidHex = '00000000',
    bool backupTaken = true,
  }) => DangerAck._(
    risk: risk,
    operationId: operationId,
    acknowledgedAt: DateTime.now(),
    backupTaken: backupTaken,
    targetUidHex: targetUidHex,
  );

  final OperationRisk risk;
  final String operationId;
  final DateTime acknowledgedAt;
  final bool backupTaken;
  final String targetUidHex;

  /// Onay bu etiket icin mi verildi?
  ///
  /// `tag_ops` islemi yapmadan once bunu kontrol etmelidir — kullanici
  /// bir etiket icin onay verip baska bir etiketi yaklastirmis olabilir.
  bool isFor(String uidHex) =>
      targetUidHex.toUpperCase() == uidHex.toUpperCase();

  /// Onay hala gecerli mi? Varsayilan olarak 5 dakika.
  bool isFresh({Duration maxAge = const Duration(minutes: 5)}) =>
      DateTime.now().difference(acknowledgedAt) <= maxAge;

  @override
  String toString() =>
      'DangerAck($operationId, ${risk.name}, hedef: $targetUidHex)';
}
