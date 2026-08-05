import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../entities/ndef_entities.dart';
import '../entities/nfc_tag_info.dart';
import '../entities/ntag_config.dart';
import '../entities/storage_entities.dart';
import '../entities/tag_identity.dart';
import '../entities/tag_memory.dart';
import '../result.dart';
import '../safety.dart';
import 'nfc_session_service.dart';

/// Sifre koyma parametreleri.
///
/// Yazma sirasi kritiktir; bkz. `.claude/docs/03-nfc-reference.md` §2.8.
@immutable
final class PasswordSetup {
  PasswordSetup({
    required Uint8List password,
    required Uint8List pack,
    required this.protectFromPage,
    this.scope = PasswordProtectionScope.writeOnly,
    this.authLimit = 0,
    this.protectCounter = false,
  }) : password = Uint8List.fromList(password),
       pack = Uint8List.fromList(pack) {
    if (password.length != 4) {
      throw ArgumentError.value(password, 'password', 'Sifre 4 byte olmali');
    }
    if (pack.length != 2) {
      throw ArgumentError.value(pack, 'pack', 'PACK 2 byte olmali');
    }
    if (authLimit < 0 || authLimit > 7) {
      throw ArgumentError.value(authLimit, 'authLimit', '0-7 arasi olmali');
    }
  }

  /// 4 byte sifre (PWD sayfasi).
  final Uint8List password;

  /// 2 byte dogrulama cevabi (PACK sayfasi).
  final Uint8List pack;

  /// Korumanin baslayacagi sayfa (AUTH0).
  final int protectFromPage;

  /// Koruma kapsami (PROT biti).
  final PasswordProtectionScope scope;

  /// Yanlis deneme limiti (AUTHLIM). 0 = sinirsiz.
  ///
  /// **0'dan buyuk deger tehlikelidir:** limit asilirsa etiket kalici
  /// olarak erisilemez hale gelir.
  final int authLimit;

  /// Sayac okuma da sifreyle korunsun mu?
  final bool protectCounter;
}

/// Yansitma (mirror) yapilandirma parametreleri.
@immutable
final class MirrorSetup {
  const MirrorSetup({
    required this.mode,
    required this.page,
    this.byteOffset = 0,
  });

  final MirrorMode mode;

  /// Yansitmanin yazilacagi sayfa.
  final int page;

  /// Sayfa icindeki baslangic byte'i (0-3).
  final int byteOffset;
}

/// Bir etiketin bir digerine kopyalanmasinin sonucu.
@immutable
final class CopyReport {
  const CopyReport({
    required this.sourceUidHex,
    required this.targetUidHex,
    required this.bytesWritten,
    required this.recordCount,
    this.truncated = false,
  });

  final String sourceUidHex;
  final String targetUidHex;
  final int bytesWritten;
  final int recordCount;

  /// Hedef etiket kucuk oldugu icin icerik kirpildi mi?
  ///
  /// Uygulama kirpmayi **yapmaz** — bu bayrak true olacaksa islem
  /// `InsufficientSpace` ile reddedilir. Alan yalnizca raporlama icindir.
  final bool truncated;
}

/// MIFARE Classic anahtar tarama sonucu.
@immutable
final class MifareKeyScanReport {
  const MifareKeyScanReport({
    required this.sectorKeys,
    required this.totalSectors,
  });

  /// Sektor indeksi -> (anahtar tipi, bulunan anahtar).
  final Map<int, ({MifareKeyType type, Uint8List key})> sectorKeys;

  final int totalSectors;

  int get unlockedCount => sectorKeys.length;

  bool get allUnlocked => sectorKeys.length == totalSectors;
}

/// Bir MIFARE Classic kartinin blok 0 (UID / manufacturer) yazma
/// yetenegini siniflandirir.
///
/// Standart kartlarda blok 0 fabrikada kilitlidir. "Magic" kartlar bunu
/// asar; nesillerine gore farkli yontemler kullanir.
enum MifareMagicKind {
  /// Blok 0 yazilamiyor — standart (magic olmayan) kart.
  none,

  /// Gen1a: arka kapi (backdoor) komutlariyla yazilir. Cogu Android
  /// yongasi bu 7-bitlik ham komutlari **gonderemez**.
  gen1a,

  /// Gen2 / CUID / "Direct Write": blok 0 normal yazma komutuyla yazilir.
  /// Android'de calisan pratik yontem budur.
  gen2,

  /// Yazilabilirlik belirlenemedi (orn. sektor 0 anahtari bulunamadi).
  unknown,
}

/// Bir MIFARE Classic kartinin blok 0 yazilabilirlik testinin sonucu.
///
/// [TagOperations.probeMifareMagic] tarafindan uretilir. Test **tahrip
/// edici degildir**:
/// yalnizca mevcut blok 0 icerigi ayni sekilde geri yazilmayi dener.
@immutable
final class MifareMagicProbe {
  const MifareMagicProbe({
    required this.isBlockZeroWritable,
    required this.kind,
    required this.detail,
  });

  /// Blok 0 (UID) degistirilebiliyor mu?
  final bool isBlockZeroWritable;

  /// Tespit edilen magic kart nesli.
  final MifareMagicKind kind;

  /// Kullaniciya gosterilebilecek aciklama.
  final String detail;
}

/// Bir MIFARE Classic kartinin baska bir karta klonlanmasinin sonucu.
@immutable
final class MifareCloneReport {
  const MifareCloneReport({
    required this.sourceUidHex,
    required this.targetUidHex,
    required this.blocksWritten,
    required this.blocksSkipped,
    required this.blocksFailed,
    required this.blockZeroWritten,
    required this.trailersWritten,
  });

  final String sourceUidHex;
  final String targetUidHex;

  /// Basariyla yazilan blok sayisi.
  final int blocksWritten;

  /// Bilerek atlanan blok sayisi (okunamayan kaynak bloklari veya
  /// [TagOperations.cloneMifareClassicTo] cagrisinda yazilmayan sektor
  /// fragmanlari).
  final int blocksSkipped;

  /// Yazmasi denenip basarisiz olan blok sayisi.
  final int blocksFailed;

  /// Blok 0 (UID) yazilabildi mi?
  final bool blockZeroWritten;

  /// Sektor fragmanlari (anahtar/erisim byte'lari) da yazildi mi?
  final bool trailersWritten;
}

/// Etiket uzerindeki yuksek seviye islemler.
///
/// `tag_ops` paketi tarafindan uygulanir. Feature katmani yalnizca bu
/// arayuzu gorur; somut uygulama composition root'ta baglanir.
///
/// **Guvenlik:** Yikici islemler [DangerAck] ister. Bu tip yalnizca
/// kullanici onayindan sonra arayuz katmaninda uretilebilir.
/// Bkz. `.claude/docs/adr/ADR-0005-safety-gates.md`
abstract interface class TagOperations {
  // ---------------------------------------------------------------------
  // Okuma — risk yok
  // ---------------------------------------------------------------------

  /// Yongayi tanimlar (GET_VERSION + ATQA/SAK).
  Future<Result<TagIdentity>> identify(NfcTagHandle tag);

  /// Etiketten okunabilecek her seyi toplar.
  ///
  /// [deep] true ise tam bellek dokumu, yapilandirma, kilit durumu, sayac
  /// ve imza da okunur. Yavastir; varsayilan olarak kapali.
  Future<Result<NfcTagInfo>> inspect(NfcTagHandle tag, {bool deep = false});

  /// Tam bellek dokumu alir.
  ///
  /// Etiket okuma korumaliysa [password] gerekir; verilmezse korumali
  /// sayfalar `TagMemory.unreadablePages` icinde isaretlenir.
  Future<Result<TagMemory>> readMemory(NfcTagHandle tag, {Uint8List? password});

  /// Yapilandirma sayfalarini cozumler. NTAG/UL EV1 disinda
  /// `TagNotSupported` doner.
  Future<Result<NtagConfig>> readConfig(NfcTagHandle tag);

  /// Kilit byte'larini cozumler.
  Future<Result<LockStatus>> readLockStatus(NfcTagHandle tag);

  /// NFC sayac degerini okur.
  Future<Result<int>> readCounter(NfcTagHandle tag);

  /// ECC orijinallik imzasini okur (32 byte).
  Future<Result<Uint8List>> readSignature(NfcTagHandle tag);

  /// Imzayi ureticinin acik anahtariyla dogrular.
  ///
  /// `Ok(true)` = imza gecerli, etiket muhtemelen orijinal.
  /// `Ok(false)` = imza gecersiz.
  /// `TagNotSupported` = bu yonga icin acik anahtar bilinmiyor.
  Future<Result<bool>> verifySignature(NfcTagHandle tag);

  // ---------------------------------------------------------------------
  // Kimlik dogrulama
  // ---------------------------------------------------------------------

  /// Sifre ile kimlik dogrular. Basariliysa PACK cevabini dondurur.
  ///
  /// Dikkat: AUTHLIM ayarli etiketlerde yanlis deneme sayaci artar.
  Future<Result<Uint8List>> authenticate(NfcTagHandle tag, Uint8List password);

  // ---------------------------------------------------------------------
  // Icerik islemleri — geri yazilabilir
  // ---------------------------------------------------------------------

  /// NDEF mesaji yazar ve geri okuyup dogrular.
  Future<Result<void>> writeNdef(
    NfcTagHandle tag,
    NdefMessageEntity message, {
    bool verify = true,
  });

  /// Etiketin NDEF icerigini temizler (bos mesaj yazar).
  Future<Result<void>> eraseNdef(NfcTagHandle tag, {required DangerAck ack});

  /// Tum kullanici sayfalarini 0x00 yapar.
  Future<Result<void>> factoryReset(NfcTagHandle tag, {required DangerAck ack});

  /// Onceden okunmus bir NDEF mesajini bu etikete yazar.
  ///
  /// Kapasite yetmezse `InsufficientSpace` doner — icerik **kirpilmaz**.
  Future<Result<CopyReport>> copyNdefTo(
    NfcTagHandle target, {
    required NdefMessageEntity message,
    required String sourceUidHex,
    required DangerAck ack,
  });

  /// Kaydedilmis bir dokumu etikete geri yazar.
  ///
  /// Dokum bu etiketle uyumsuzsa (farkli yonga, farkli boyut)
  /// `TagNotSupported` doner.
  Future<Result<void>> restoreDump(
    NfcTagHandle tag,
    TagDump dump, {
    required DangerAck ack,
  });

  // ---------------------------------------------------------------------
  // Yapilandirma islemleri
  // ---------------------------------------------------------------------

  /// Etiketi NDEF'e bicimlendirir (CC yazar + bos mesaj).
  Future<Result<void>> formatNdef(NfcTagHandle tag, {required DangerAck ack});

  /// Sifre korumasi koyar.
  ///
  /// Yazma sirasi: PWD -> PACK -> CFG1 -> CFG0(AUTH0).
  /// AUTH0 **en son** yazilir; aksi halde etiket parolayi kaydedemeden
  /// kilitlenir.
  Future<Result<void>> setPassword(
    NfcTagHandle tag, {
    required PasswordSetup setup,
    required DangerAck ack,
  });

  /// Sifre korumasini kaldirir.
  ///
  /// Once [currentPassword] ile dogrulanir, sonra AUTH0 0xFF yapilir.
  Future<Result<void>> removePassword(
    NfcTagHandle tag, {
    required Uint8List currentPassword,
    required DangerAck ack,
  });

  /// Sifreyi degistirir.
  Future<Result<void>> changePassword(
    NfcTagHandle tag, {
    required Uint8List currentPassword,
    required PasswordSetup newSetup,
    required DangerAck ack,
  });

  /// UID / sayac yansitmasini yapilandirir.
  Future<Result<void>> configureMirror(
    NfcTagHandle tag, {
    required MirrorSetup setup,
    required DangerAck ack,
  });

  /// NFC sayacini acar/kapatir.
  Future<Result<void>> configureCounter(
    NfcTagHandle tag, {
    required bool enabled,
    required bool passwordProtected,
    required DangerAck ack,
  });

  // ---------------------------------------------------------------------
  // GERI ALINAMAZ islemler — uzman modu + sert onay
  // ---------------------------------------------------------------------

  /// Etiketi kalici olarak salt-okunur yapar.
  ///
  /// **GERI ALINAMAZ.**
  Future<Result<void>> makeReadOnly(NfcTagHandle tag, {required DangerAck ack});

  /// Belirtilen sayfalari kalici olarak kilitler.
  ///
  /// **GERI ALINAMAZ.**
  Future<Result<void>> lockPages(
    NfcTagHandle tag, {
    required Set<int> pages,
    required DangerAck ack,
  });

  /// CFGLCK bitini yazar — yapilandirma sonsuza dek dondurulur.
  ///
  /// **GERI ALINAMAZ.** Bundan sonra sifre, AUTH0, mirror ve sayac
  /// ayarlarinin hicbiri degistirilemez.
  Future<Result<void>> lockConfiguration(
    NfcTagHandle tag, {
    required DangerAck ack,
  });

  // ---------------------------------------------------------------------
  // Uzman araclari
  // ---------------------------------------------------------------------

  /// Ham komut gonderir.
  ///
  /// Ne gonderildigi tamamen cagirana baglidir; uygulama icerigi
  /// dogrulamaz. Uzman modu disinda arayuzde gorunmez.
  Future<Result<Uint8List>> sendRawCommand(
    NfcTagHandle tag, {
    required Uint8List command,
    required TransceiveChannel channel,
  });

  /// MIFARE Classic sektorlerini bilinen anahtarlarla dener.
  ///
  /// [keyDictionary] verilmezse yaygin varsayilan anahtarlar kullanilir.
  Future<Result<MifareKeyScanReport>> scanMifareClassicKeys(
    NfcTagHandle tag, {
    List<Uint8List>? keyDictionary,
  });

  /// MIFARE Classic kartinin blok 0 (UID) yazilabilirligini test eder.
  ///
  /// **Tahrip edici degildir:** mevcut blok 0 icerigi ayni sekilde geri
  /// yazilmayi dener. Basarili olursa kart "magic" (Gen2/CUID) demektir ve
  /// UID degistirilebilir. Bkz. [MifareMagicProbe].
  Future<Result<MifareMagicProbe>> probeMifareMagic(NfcTagHandle tag);

  /// Tek bir MIFARE Classic blogunu yazar (blok 0 dahil).
  ///
  /// Once blogun ait oldugu sektore [key] / [keyType] ile kimlik dogrular,
  /// sonra 16 byte'lik [data]'yi yazar. Blok 0 icin BCC dogrulanir; hatali
  /// BCC `InvalidArgument` ile reddedilir (karti olu hale getirmemek icin).
  ///
  /// Standart kartlarda blok 0 yazma donanim tarafindan reddedilir; bu
  /// islem yalnizca magic kartlarda basarili olur.
  Future<Result<void>> writeMifareClassicBlock(
    NfcTagHandle tag, {
    required int blockIndex,
    required Uint8List data,
    required Uint8List key,
    MifareKeyType keyType,
    required DangerAck ack,
  });

  /// Onceden okunmus bir MIFARE Classic dokumunu [target] karta klonlar.
  ///
  /// Hedef karta once [probeMifareMagic] uygulanir; blok 0 yazilamiyorsa
  /// `TagNotSupported` doner (yarim klon yapilmaz). Okunamayan kaynak
  /// bloklari atlanir. [writeSectorTrailers] varsayilan olarak `false`'tur:
  /// anahtar/erisim byte'larini yazmak sektoru olu hale getirebilecegi icin
  /// yalnizca acikca istenirse yazilir.
  Future<Result<MifareCloneReport>> cloneMifareClassicTo(
    NfcTagHandle target, {
    required TagMemory source,
    required String sourceUidHex,
    bool writeSectorTrailers,
    required DangerAck ack,
  });

  /// ISO 15693 blok okur.
  Future<Result<Uint8List>> readIso15693Block(
    NfcTagHandle tag, {
    required int blockNumber,
  });

  /// ISO 15693 bloga yazar.
  Future<Result<void>> writeIso15693Block(
    NfcTagHandle tag, {
    required int blockNumber,
    required Uint8List data,
    required DangerAck ack,
  });
}
