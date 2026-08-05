import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';

/// `GET_SYSTEM_INFO` (0x2B) cevabinin cozumlenmis hali.
///
/// Bkz. `.claude/docs/03-nfc-reference.md` §4. Bellek boyutu ve DSFID/AFI
/// alanlari ISO/IEC 15693-3 standardinin genel alanlaridir; [icReference]
/// ise uretici-ozel bir byte'tir ve ICODE SLIX/SLIX2 ayrimi icin kullanilir.
@immutable
final class Iso15693SystemInfo {
  const Iso15693SystemInfo({
    this.dsfid,
    this.afi,
    this.blockCount,
    this.blockSize,
    this.icReference,
  });

  final int? dsfid;
  final int? afi;

  /// Toplam blok sayisi.
  final int? blockCount;

  /// Blok basina byte sayisi.
  final int? blockSize;

  /// Uretici-ozel IC referans byte'i.
  ///
  /// ⚠️ NXP ICODE SLIX/SLIX2 ayrimi bu byte'a dayanir ama tam eslesme
  /// tablosu (`IcodeIcReference`) datasheet ile dogrulanmalidir.
  final int? icReference;

  int? get totalBytes =>
      (blockCount == null || blockSize == null) ? null : blockCount! * blockSize!;

  /// Ham `GET_SYSTEM_INFO` cevabini cozumler.
  ///
  /// [raw] transport katmanindan gelen ham cevaptir; ilk byte yanit
  /// bayragidir (bkz. diger ISO 15693 komutlarindaki kural).
  static Result<Iso15693SystemInfo> parse(Uint8List raw) {
    // Bayrak(1) + bilgi bayraklari(1) + UID(8) = en az 10 byte.
    if (raw.length < 10) {
      return const Err(MalformedData('GET_SYSTEM_INFO cevabi eksik'));
    }

    final infoFlags = raw[1];
    var offset = 10;
    int? dsfid;
    int? afi;
    int? blockCount;
    int? blockSize;
    int? icReference;

    if (infoFlags.bit(0)) {
      if (offset >= raw.length) {
        return const Err(MalformedData('DSFID alani eksik'));
      }
      dsfid = raw[offset++];
    }
    if (infoFlags.bit(1)) {
      if (offset >= raw.length) {
        return const Err(MalformedData('AFI alani eksik'));
      }
      afi = raw[offset++];
    }
    if (infoFlags.bit(2)) {
      if (offset + 1 >= raw.length) {
        return const Err(MalformedData('Bellek boyutu alani eksik'));
      }
      // Byte 0: blok sayisi - 1. Byte 1 bit 0-4: blok basina byte - 1.
      blockCount = raw[offset] + 1;
      blockSize = (raw[offset + 1] & 0x1F) + 1;
      offset += 2;
    }
    if (infoFlags.bit(3)) {
      if (offset >= raw.length) {
        return const Err(MalformedData('IC referansi alani eksik'));
      }
      icReference = raw[offset++];
    }

    return Ok(
      Iso15693SystemInfo(
        dsfid: dsfid,
        afi: afi,
        blockCount: blockCount,
        blockSize: blockSize,
        icReference: icReference,
      ),
    );
  }
}

/// NXP ICODE ailesi IC referans byte'lari (`GET_SYSTEM_INFO` son alani).
///
/// ⚠️ **DOGRULANMADI.** Bu degerler ICODE SLIX/SLIX2 datasheet'i ile
/// karsilastirilmadan kesin kabul edilmemelidir — yalniz bunlara dayanarak
/// "SLIX2" gibi kesin bir model adi gostermek yaniltici olabilir.
/// Bkz. `.claude/state/progress.md` -> "Dogrulanacak teknik noktalar".
abstract final class IcodeIcReference {
  static const int slix = 0x02;
  static const int slix2 = 0x01;
}
