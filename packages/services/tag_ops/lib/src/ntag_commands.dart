import 'dart:typed_data';

/// NTAG21x / MIFARE Ultralight komut kodlari.
///
/// Bkz. `.claude/docs/03-nfc-reference.md` §2.6
abstract final class NtagCommand {
  static const int getVersion = 0x60;
  static const int read = 0x30;
  static const int fastRead = 0x3A;
  static const int write = 0xA2;
  static const int compatibilityWrite = 0xA0;
  static const int pwdAuth = 0x1B;
  static const int readCounter = 0x39;
  static const int readSignature = 0x3C;
  static const int halt = 0x50;
}

/// NTAG komut baytlarini olusturur.
///
/// Elle `Uint8List.fromList([0x3A, start, end])` yazma — buradaki
/// olusturuculari kullan ki komutlar tek yerde dogrulanabilsin.
abstract final class NtagCommands {
  /// `GET_VERSION` — 8 byte yonga bilgisi doner.
  static Uint8List getVersion() => Uint8List.fromList([NtagCommand.getVersion]);

  /// `READ` — [page] sayfasindan itibaren 16 byte (4 sayfa) doner.
  ///
  /// Etiket sonunda okuma basa doner (roll-over); okunan verinin hangi
  /// sayfaya ait oldugunu cagiran hesaplamali.
  static Uint8List read(int page) {
    _requireByte(page, 'page');
    return Uint8List.fromList([NtagCommand.read, page]);
  }

  /// `FAST_READ` — [start] ile [end] arasi (dahil) tum sayfalari doner.
  ///
  /// Cevap boyutu `(end - start + 1) * 4` byte'tir ve kanalin
  /// `maxTransceiveLength` degerini asamaz.
  static Uint8List fastRead(int start, int end) {
    _requireByte(start, 'start');
    _requireByte(end, 'end');
    if (end < start) {
      throw ArgumentError('end ($end) start ($start) degerinden kucuk olamaz');
    }
    return Uint8List.fromList([NtagCommand.fastRead, start, end]);
  }

  /// `WRITE` — tek sayfaya 4 byte yazar.
  static Uint8List write(int page, Uint8List data) {
    _requireByte(page, 'page');
    if (data.length != 4) {
      throw ArgumentError.value(data, 'data', 'Sayfa verisi tam 4 byte olmali');
    }
    return Uint8List.fromList([NtagCommand.write, page, ...data]);
  }

  /// `PWD_AUTH` — 4 byte sifre gonderir, 2 byte PACK doner.
  static Uint8List passwordAuth(Uint8List password) {
    if (password.length != 4) {
      throw ArgumentError.value(password, 'password', 'Sifre 4 byte olmali');
    }
    return Uint8List.fromList([NtagCommand.pwdAuth, ...password]);
  }

  /// `READ_CNT` — 3 byte NFC sayac degeri doner.
  static Uint8List readCounter() =>
      Uint8List.fromList([NtagCommand.readCounter, 0x02]);

  /// `READ_SIG` — 32 byte ECC orijinallik imzasi doner.
  static Uint8List readSignature() =>
      Uint8List.fromList([NtagCommand.readSignature, 0x00]);

  /// `HALT` — etiketi uyutur.
  static Uint8List halt() => Uint8List.fromList([NtagCommand.halt, 0x00]);

  static void _requireByte(int value, String name) {
    if (value < 0 || value > 0xFF) {
      throw RangeError.value(value, name, '0-255 arasi olmali');
    }
  }
}

/// ISO 15693 komut kodlari.
///
/// Bkz. `.claude/docs/03-nfc-reference.md` §4
abstract final class Iso15693Command {
  static const int readSingleBlock = 0x20;
  static const int writeSingleBlock = 0x21;
  static const int lockBlock = 0x22;
  static const int readMultipleBlocks = 0x23;
  static const int writeMultipleBlocks = 0x24;
  static const int select = 0x25;
  static const int resetToReady = 0x26;
  static const int writeAfi = 0x27;
  static const int lockAfi = 0x28;
  static const int writeDsfid = 0x29;
  static const int lockDsfid = 0x2A;
  static const int getSystemInformation = 0x2B;
  static const int getMultipleBlockSecurityStatus = 0x2C;

  /// Yuksek veri hizi bayragi — adressiz komutlar icin tipik deger.
  static const int flagHighDataRate = 0x02;

  /// Adresli komut bayragi — UID belirtilir.
  static const int flagAddressed = 0x20;
}

/// ISO 15693 komut baytlarini olusturur.
abstract final class Iso15693Commands {
  /// Tek blok okur.
  ///
  /// [uid] verilirse adresli komut olusturulur (UID ters sirada gonderilir).
  static Uint8List readSingleBlock(int blockNumber, {Uint8List? uid}) =>
      _build(Iso15693Command.readSingleBlock, uid, [blockNumber & 0xFF]);

  /// Tek bloga yazar.
  static Uint8List writeSingleBlock(
    int blockNumber,
    Uint8List data, {
    Uint8List? uid,
  }) => _build(Iso15693Command.writeSingleBlock, uid, [
    blockNumber & 0xFF,
    ...data,
  ]);

  /// Sistem bilgisi ister.
  static Uint8List getSystemInformation({Uint8List? uid}) =>
      _build(Iso15693Command.getSystemInformation, uid, const []);

  static Uint8List _build(int command, Uint8List? uid, List<int> params) {
    final flags =
        Iso15693Command.flagHighDataRate |
        (uid != null ? Iso15693Command.flagAddressed : 0);
    return Uint8List.fromList([
      flags,
      command,
      // ISO 15693'te UID en dusuk anlamli byte once gonderilir.
      if (uid != null) ...uid.reversed,
      ...params,
    ]);
  }
}
