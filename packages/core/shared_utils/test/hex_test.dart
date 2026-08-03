import 'package:shared_utils/shared_utils.dart';
import 'package:test/test.dart';

void main() {
  group('bytesToHex', () {
    test('ayracsiz buyuk harf uretir', () {
      expect(bytesToHex([0x04, 0xa2, 0x00, 0xff]), '04A200FF');
    });

    test('ayrac ekler', () {
      expect(bytesToHex([0x04, 0xa2], separator: ':'), '04:A2');
    });

    test('bos dizi bos metin verir', () {
      expect(bytesToHex(const []), '');
    });
  });

  group('hexToBytes', () {
    test('duz hex cozer', () {
      expect(hexToBytes('04A2FF'), [0x04, 0xa2, 0xff]);
    });

    test('bosluk, iki nokta ve tire yok sayilir', () {
      expect(hexToBytes('04 a2:ff-00'), [0x04, 0xa2, 0xff, 0x00]);
    });

    test('0x on eki yok sayilir', () {
      expect(hexToBytes('0x04A2'), [0x04, 0xa2]);
    });

    test('tek sayida basamak hata verir', () {
      expect(() => hexToBytes('04A'), throwsFormatException);
    });

    test('gecersiz karakter hata verir', () {
      expect(() => hexToBytes('04ZZ'), throwsFormatException);
    });
  });

  test('hex donusumu cift yonlu', () {
    final bytes = List<int>.generate(256, (i) => i);
    expect(hexToBytes(bytesToHex(bytes)), bytes);
  });

  group('tam sayi donusumleri', () {
    test('big-endian', () {
      expect(bytesToIntBigEndian([0x01, 0x02]), 0x0102);
      expect(intToBytesBigEndian(0x0102, 2), [0x01, 0x02]);
    });

    test('little-endian', () {
      expect(bytesToIntLittleEndian([0x01, 0x02]), 0x0201);
      expect(intToBytesLittleEndian(0x0201, 2), [0x01, 0x02]);
    });
  });

  group('bit alanlari', () {
    test('bit okuma', () {
      expect(0x80.bit(7), isTrue);
      expect(0x80.bit(0), isFalse);
    });

    test('bit yazma', () {
      expect(0x00.withBit(3, true), 0x08);
      expect(0xFF.withBit(3, false), 0xF7);
    });

    test('alan okuma — ACCESS byte AUTHLIM (bit 2-0)', () {
      // 0b1000_0101 -> PROT=1, AUTHLIM=5
      const access = 0x85;
      expect(access.bit(7), isTrue);
      expect(access.bitField(offset: 0, width: 3), 5);
    });

    test('alan yazma', () {
      expect(0x00.withBitField(offset: 6, width: 2, value: 3), 0xC0);
    });

    test('alan tasmasi hata verir', () {
      expect(
        () => 0x00.withBitField(offset: 0, width: 2, value: 4),
        throwsRangeError,
      );
    });
  });

  test('UID bicimlendirme', () {
    expect(formatUid([0x04, 0xa1, 0xb2]), '04:A1:B2');
    expect(reverseUidHex([0x04, 0xa1, 0xb2]), 'B2A104');
  });
}
