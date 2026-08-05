import 'dart:typed_data';

import 'package:shared_utils/shared_utils.dart';

/// MIFARE Classic sektor/blok yerlesim yardimcilari.
///
/// Classic 1K/Mini'de her sektor 4 bloktur. Classic 4K'da ilk 32 sektor
/// 4'er blok, son 8 sektor 16'sar bloktur. Bkz.
/// `.claude/docs/03-nfc-reference.md` §3.
abstract final class MifareClassicLayout {
  /// 4K'nin genisletilmis (16 bloklu) sektorlerinin basladigi indeks.
  static const int _extendedSectorStart = 32;
  static const int _extendedFirstBlock = 128;

  static bool _isExtended(int sectorCount) => sectorCount > _extendedSectorStart;

  /// Verilen sektordeki blok sayisi.
  static int blocksInSector(int sectorIndex, {required int sectorCount}) {
    if (_isExtended(sectorCount) && sectorIndex >= _extendedSectorStart) {
      return 16;
    }
    return 4;
  }

  /// Sektorun ilk blok indeksi.
  static int firstBlockOfSector(int sectorIndex, {required int sectorCount}) {
    if (_isExtended(sectorCount) && sectorIndex >= _extendedSectorStart) {
      return _extendedFirstBlock + (sectorIndex - _extendedSectorStart) * 16;
    }
    return sectorIndex * 4;
  }

  /// Sektorun son blok indeksi (sektor fragmani / trailer).
  static int trailerBlockOfSector(int sectorIndex, {required int sectorCount}) =>
      firstBlockOfSector(sectorIndex, sectorCount: sectorCount) +
      blocksInSector(sectorIndex, sectorCount: sectorCount) -
      1;

  /// Verilen blogun ait oldugu sektor.
  static int sectorOfBlock(int blockIndex, {required int sectorCount}) {
    if (_isExtended(sectorCount) && blockIndex >= _extendedFirstBlock) {
      return _extendedSectorStart +
          (blockIndex - _extendedFirstBlock) ~/ 16;
    }
    return blockIndex ~/ 4;
  }

  /// Bu blok kendi sektorunun fragmani (trailer) mi?
  static bool isTrailerBlock(int blockIndex, {required int sectorCount}) =>
      blockIndex ==
      trailerBlockOfSector(
        sectorOfBlock(blockIndex, sectorCount: sectorCount),
        sectorCount: sectorCount,
      );

  // -------------------------------------------------------------------
  // Blok 0 / UID (manufacturer block)
  // -------------------------------------------------------------------
  //
  // Blok 0'in ilk 5 byte'i 4 byte'lik (tek boyut) UID'lerde
  // `UID0 UID1 UID2 UID3 BCC` seklindedir. BCC = UID byte'larinin XOR'u.
  // Yanlis BCC, karti bazi okuyuculara karsi olu hale getirir; bu yuzden
  // blok 0 yazmadan once **her zaman** dogrulanir.

  /// Blok 0'in BCC (Block Check Character) byte'ini hesaplar.
  ///
  /// 4 byte UID icin `UID0 ^ UID1 ^ UID2 ^ UID3`. [source] en az 4 byte
  /// olmali; fazlasi yok sayilir (yalnizca ilk 4 byte kullanilir).
  static int blockZeroBcc(List<int> source) {
    if (source.length < 4) {
      throw ArgumentError.value(source, 'source', 'En az 4 byte gerekli');
    }
    return (source[0] ^ source[1] ^ source[2] ^ source[3]) & 0xFF;
  }

  /// 16 byte'lik blok 0'in BCC byte'i (indeks 4) UID ile tutarli mi?
  ///
  /// Yalnizca 4 byte UID (tek boyut) kartlar icin anlamlidir. 7 byte UID'li
  /// kartlarda blok 0 duzeni farklidir ve bu kontrol uygulanmaz.
  static bool isBlockZeroBccValid(List<int> block) {
    if (block.length < 5) return false;
    return block[4] == blockZeroBcc(block);
  }

  /// Blok 0'in ilk 4 byte'indan BCC'yi yeniden hesaplayip 5. byte'a
  /// yerlestiren **yeni** bir kopya dondurur. Kaynak degistirilmez.
  static Uint8List withBlockZeroBcc(List<int> block) {
    final out = Uint8List.fromList(block);
    if (out.length >= 5) out[4] = blockZeroBcc(out);
    return out;
  }

  /// Yaygin varsayilan anahtar sozlugu (deneme sirasiyla).
  ///
  /// Bkz. `.claude/docs/03-nfc-reference.md` §3.
  static final List<Uint8List> defaultKeys = <Uint8List>[
    hexToBytes('FFFFFFFFFFFF'),
    hexToBytes('A0A1A2A3A4A5'),
    hexToBytes('D3F7D3F7D3F7'),
    hexToBytes('000000000000'),
    hexToBytes('B0B1B2B3B4B5'),
    hexToBytes('4D3A99C351DD'),
    hexToBytes('1A982C7E459A'),
    hexToBytes('AABBCCDDEEFF'),
    hexToBytes('714C5C886E97'),
    hexToBytes('587EE5F9350F'),
    hexToBytes('A0478CC39091'),
    hexToBytes('533CB6C723F6'),
    hexToBytes('8FD0A4F256E9'),
  ];
}
