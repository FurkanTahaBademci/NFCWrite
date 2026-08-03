import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// NDEF kayit basligindaki TNF (Type Name Format) alani.
///
/// Bkz. `.claude/docs/03-nfc-reference.md` §1.1
enum NdefTypeNameFormat {
  /// Bos kayit.
  empty(0x00),

  /// NFC Forum iyi bilinen tip: `T`, `U`, `Sp`.
  wellKnown(0x01),

  /// RFC 2046 MIME tipi.
  media(0x02),

  /// RFC 3986 mutlak URI.
  absoluteUri(0x03),

  /// NFC Forum harici tip (orn. `android.com:pkg`).
  ///
  /// `external` Dart'ta ayrilmis bir kelime oldugu icin `externalType` adi
  /// kullanildi.
  externalType(0x04),

  /// Tip bilinmiyor.
  unknown(0x05),

  /// Onceki kaydin devami (chunk).
  unchanged(0x06),

  /// Ayrilmis, kullanilmaz.
  reserved(0x07);

  const NdefTypeNameFormat(this.value);

  /// 3 bitlik ham deger.
  final int value;

  /// Ham degerden cozer. Gecersizse [NdefTypeNameFormat.unknown].
  static NdefTypeNameFormat fromValue(int value) {
    for (final tnf in NdefTypeNameFormat.values) {
      if (tnf.value == value) return tnf;
    }
    return NdefTypeNameFormat.unknown;
  }
}

/// Tek bir NDEF kaydi — ham hali.
///
/// Bu tip **cozumlenmemis** veriyi tasir. Anlamli hale getirmek
/// `ndef_codec` paketinin isidir.
@immutable
final class NdefRecordEntity {
  NdefRecordEntity({
    required this.typeNameFormat,
    required Uint8List type,
    required Uint8List identifier,
    required Uint8List payload,
  }) : // Savunmaci kopya: disaridan gelen tampon sonradan degistirilirse
       // kayit bozulmasin.
       type = Uint8List.fromList(type),
       identifier = Uint8List.fromList(identifier),
       payload = Uint8List.fromList(payload);

  /// Bos kayit (TNF 0).
  factory NdefRecordEntity.empty() => NdefRecordEntity(
    typeNameFormat: NdefTypeNameFormat.empty,
    type: Uint8List(0),
    identifier: Uint8List(0),
    payload: Uint8List(0),
  );

  final NdefTypeNameFormat typeNameFormat;

  /// Tip alani. `wellKnown` icin `T`, `U` gibi; `media` icin MIME tipi.
  final Uint8List type;

  /// Istege bagli kayit kimligi.
  final Uint8List identifier;

  /// Yuk (payload).
  final Uint8List payload;

  /// Tip alaninin ASCII karsiligi (`T`, `U`, `text/vcard`...).
  String get typeAsString => String.fromCharCodes(type);

  /// Bu kaydin etiket uzerinde kaplayacagi byte sayisi.
  ///
  /// Baslik (1) + tip uzunlugu (1) + yuk uzunlugu (1 ya da 4) +
  /// [id uzunlugu (1)] + tip + id + yuk.
  int get byteLength {
    final shortRecord = payload.length < 256;
    var length = 1 + 1 + (shortRecord ? 1 : 4);
    if (identifier.isNotEmpty) length += 1;
    return length + type.length + identifier.length + payload.length;
  }

  @override
  bool operator ==(Object other) =>
      other is NdefRecordEntity &&
      other.typeNameFormat == typeNameFormat &&
      const ListEquality<int>().equals(other.type, type) &&
      const ListEquality<int>().equals(other.identifier, identifier) &&
      const ListEquality<int>().equals(other.payload, payload);

  @override
  int get hashCode => Object.hash(
    typeNameFormat,
    const ListEquality<int>().hash(type),
    const ListEquality<int>().hash(identifier),
    const ListEquality<int>().hash(payload),
  );

  @override
  String toString() =>
      'NdefRecordEntity(${typeNameFormat.name}, type: $typeAsString, '
      'payload: ${payload.length} byte)';
}

/// Bir ya da daha fazla kayittan olusan NDEF mesaji.
@immutable
final class NdefMessageEntity {
  const NdefMessageEntity(this.records);

  /// Bos mesaj — etiketi temizlemek icin kullanilir.
  ///
  /// Tek bir bos kayit (TNF 0) icerir; tamamen bos bir mesaj gecerli degildir.
  factory NdefMessageEntity.empty() =>
      NdefMessageEntity([NdefRecordEntity.empty()]);

  final List<NdefRecordEntity> records;

  bool get isEmpty =>
      records.isEmpty ||
      (records.length == 1 &&
          records.first.typeNameFormat == NdefTypeNameFormat.empty);

  /// Mesajin toplam byte boyutu (TLV zarfi haric).
  int get byteLength =>
      records.fold(0, (sum, record) => sum + record.byteLength);

  /// Type 2 etiket uzerinde kaplayacagi toplam byte — TLV basligi
  /// ve terminator dahil.
  ///
  /// Kapasite kontrolu **bu degerle** yapilmalidir; [byteLength] ile degil.
  int get byteLengthOnTag {
    final payloadLength = byteLength;
    // NDEF TLV: tip (1) + uzunluk (1 ya da 3) + deger + terminator (1)
    final lengthFieldSize = payloadLength < 0xFF ? 1 : 3;
    return 1 + lengthFieldSize + payloadLength + 1;
  }

  @override
  bool operator ==(Object other) =>
      other is NdefMessageEntity &&
      const ListEquality<NdefRecordEntity>().equals(other.records, records);

  @override
  int get hashCode => const ListEquality<NdefRecordEntity>().hash(records);

  @override
  String toString() => 'NdefMessageEntity(${records.length} kayit)';
}
