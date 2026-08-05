import 'ecc/secp128r1.dart';

/// NXP orijinallik imzasi dogrulamasi icin ureticinin genel anahtarlari.
///
/// ⚠️ **DOGRULANMADI.** Bu anahtarlarin degeri NXP AN11350 ("NTAG21x
/// Originality Signature Validation") uygulama notu ile karsilastirilip
/// onaylanmadan `verifySignature` gercek bir sonuc uretemez.
///
/// Anahtar bilerek `null` birakildi: yanlis bir sabitle "gecerli" ya da
/// "gecersiz" sonucu uretmek, sahte etiketleri tespit etme ozelliginin
/// tum amacini bosa cikarir — sessizce yanlis calismaktansa acikca
/// `TagNotSupported` donmek tercih edildi (bkz. `.claude/docs/05-conventions.md`
/// "gurultulu basarisizlik" ilkesi).
///
/// Datasheet ile dogrulandiktan sonra buraya gercek nokta yazilmali ve
/// `.claude/state/progress.md` -> "Dogrulanacak teknik noktalar"
/// listesinden ilgili madde kaldirilmalidir.
abstract final class NxpOriginalityKeys {
  /// NTAG213/215/216 ve MIFARE Ultralight EV1 icin ortak genel anahtar.
  static const EccPoint? ntag21x = null;
}
