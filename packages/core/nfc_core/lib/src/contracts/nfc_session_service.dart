import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../entities/ndef_entities.dart';
import '../entities/tag_technology.dart';
import '../result.dart';

/// NFC donaniminin durumu.
enum NfcAvailabilityStatus {
  /// NFC var ve acik.
  enabled,

  /// NFC var ama kapali — kullanici ayarlardan acmali.
  disabled,

  /// Cihazda NFC yok.
  unsupported,
}

/// Oturumun hangi etiket tiplerini arayacagi.
enum NfcPollingMode {
  /// ISO 14443 (NTAG, MIFARE, banka karti tipi).
  iso14443,

  /// ISO 15693 (ICODE, vicinity).
  iso15693,

  /// ISO 18092 (FeliCa).
  iso18092,
}

/// Ham komutun hangi teknoloji kanalindan gonderilecegi.
///
/// Ayni etiket birden fazla teknolojiyi destekleyebilir; komut setine gore
/// dogru kanal secilmelidir.
enum TransceiveChannel { nfcA, nfcV, mifareUltralight, mifareClassic, isoDep }

/// MIFARE Classic sektor anahtari tipi.
enum MifareKeyType { keyA, keyB }

/// Etiketin NDEF yetenekleri.
@immutable
final class NdefCapabilities {
  const NdefCapabilities({
    required this.maxSize,
    required this.isWritable,
    required this.canMakeReadOnly,
    required this.typeName,
  });

  /// NDEF mesaji icin kullanilabilir toplam alan (byte).
  final int maxSize;

  final bool isWritable;
  final bool canMakeReadOnly;

  /// Platformun bildirdigi NDEF tipi, orn. `org.nfcforum.ndef.type2`.
  final String typeName;
}

/// MIFARE Classic yapisal bilgisi.
@immutable
final class MifareClassicInfo {
  const MifareClassicInfo({
    required this.sectorCount,
    required this.blockCount,
    required this.sizeInBytes,
  });

  final int sectorCount;
  final int blockCount;
  final int sizeInBytes;
}

/// Kesfedilen bir etikete acilan tutamak (handle).
///
/// Yalnizca oturum suresince gecerlidir. Oturum kapandiktan sonra bu nesne
/// uzerinden yapilan cagrilar `TagLost` dondurur.
///
/// Bu arayuz `nfc_transport` tarafindan uygulanir. Ust katmanlar
/// `nfc_manager` tiplerini asla gormez.
abstract interface class NfcTagHandle {
  /// Etiketin benzersiz kimligi.
  Uint8List get uid;

  /// Etiketin destekledigi teknolojiler.
  List<TagTechnology> get technologies;

  /// ISO 14443-3A ATQA (2 byte). Desteklenmiyorsa null.
  Uint8List? get atqa;

  /// ISO 14443-3A SAK. Desteklenmiyorsa null.
  int? get sak;

  /// ISO 15693 DSFID. Desteklenmiyorsa null.
  int? get dsfId;

  /// MIFARE Classic yapisal bilgisi. Baska etiket tipinde null.
  MifareClassicInfo? get mifareClassicInfo;

  // --- NDEF ---

  /// Etiket NDEF olarak okunabilir mi?
  bool get hasNdef;

  /// Etiket NDEF'e bicimlendirilebilir mi?
  bool get canFormatNdef;

  /// NDEF yetenekleri. [hasNdef] false ise null.
  NdefCapabilities? get ndefCapabilities;

  /// Etiketi kesfederken onbellege alinan NDEF mesaji.
  ///
  /// Ek bir okuma yapmadan doner. Guncel veri icin [readNdef] kullan.
  NdefMessageEntity? get cachedNdefMessage;

  /// NDEF mesajini okur. Etiket bicimlendirilmemisse `Ok(null)` doner.
  Future<Result<NdefMessageEntity?>> readNdef();

  /// NDEF mesajini yazar.
  Future<Result<void>> writeNdef(NdefMessageEntity message);

  /// Etiketi kalici olarak salt-okunur yapar.
  ///
  /// **Geri alinamaz.** Cagiran taraf onay akisindan gectiginden emin olmali.
  Future<Result<void>> makeNdefReadOnly();

  /// Etiketi NDEF'e bicimlendirir ve ilk mesaji yazar.
  ///
  /// [readOnly] true ise bicimlendirme sonrasi etiket kalici olarak
  /// salt-okunur olur. **Geri alinamaz.**
  Future<Result<void>> formatNdef(
    NdefMessageEntity firstMessage, {
    bool readOnly = false,
  });

  // --- Ham komut ---

  /// Bu kanal uzerinden ham komut gonderilebilir mi?
  bool supportsChannel(TransceiveChannel channel);

  /// Ham komut gonderir ve cevabi dondurur.
  Future<Result<Uint8List>> transceive(
    Uint8List command, {
    required TransceiveChannel channel,
  });

  /// Bu kanalda tek seferde gonderilebilecek en fazla byte.
  ///
  /// `FAST_READ` gibi toplu komutlari parcalarken bu deger kullanilir.
  Future<Result<int>> maxTransceiveLength(TransceiveChannel channel);

  /// Kanal zaman asimini ayarlar (ms). Desteklenmeyen kanalda yok sayilir.
  Future<Result<void>> setTimeout(TransceiveChannel channel, int milliseconds);

  // --- MIFARE Ultralight kisayollari ---

  /// [pageOffset] sayfasindan baslayarak 4 sayfa (16 byte) okur.
  Future<Result<Uint8List>> readUltralightPages(int pageOffset);

  /// Tek bir sayfaya (4 byte) yazar.
  Future<Result<void>> writeUltralightPage(int pageOffset, Uint8List data);

  // --- MIFARE Classic kisayollari ---

  /// Sektore kimlik dogrular. Anahtar yanlissa `Ok(false)` doner.
  Future<Result<bool>> authenticateSector({
    required int sectorIndex,
    required Uint8List key,
    required MifareKeyType keyType,
  });

  /// 16 byte'lik blok okur. Once sektore kimlik dogrulanmali.
  Future<Result<Uint8List>> readClassicBlock(int blockIndex);

  /// 16 byte'lik bloga yazar. Once sektore kimlik dogrulanmali.
  Future<Result<void>> writeClassicBlock(int blockIndex, Uint8List data);
}

/// NFC oturumlarini yoneten servis.
///
/// `nfc_transport` tarafindan uygulanir; composition root'ta baglanir.
abstract interface class NfcSessionService {
  /// NFC donaniminin durumunu sorgular.
  Future<NfcAvailabilityStatus> checkAvailability();

  /// Sistem NFC ayarlarini acar (NFC kapaliysa kullaniciyi yonlendirmek icin).
  Future<void> openNfcSettings();

  /// Su anda acik bir oturum var mi?
  bool get isSessionActive;

  /// Bir etiket bekler, bulununca [onTag] calistirir ve oturumu kapatir.
  ///
  /// [onTag] icinde atilan beklenmeyen hatalar `TransportError` olarak
  /// yakalanir. [timeout] verilirse ve etiket bulunamazsa
  /// `OperationTimeout` doner.
  ///
  /// Zaten acik bir oturum varsa once o kapatilir.
  Future<Result<T>> runOnce<T>({
    required Future<Result<T>> Function(NfcTagHandle tag) onTag,
    Set<NfcPollingMode> polling = const {NfcPollingMode.iso14443},
    Duration? timeout,
  });

  /// Surekli tarama. Her etikette [onTag] calistirilir ve sonuc yayinlanir.
  ///
  /// Akis (stream) iptal edilene kadar oturum acik kalir.
  Stream<Result<T>> runContinuous<T>({
    required Future<Result<T>> Function(NfcTagHandle tag) onTag,
    Set<NfcPollingMode> polling = const {NfcPollingMode.iso14443},
  });

  /// Acik oturumu kapatir. Oturum yoksa bir sey yapmaz.
  Future<void> stopSession();
}
