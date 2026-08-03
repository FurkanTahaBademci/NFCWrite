/// Tek bir byte uzerinde bit islemleri.
///
/// NFC yapilandirma byte'lari yogun bit alani icerir; elle kaydirma yerine
/// bu yardimcilari kullan. Bkz. `.claude/docs/03-nfc-reference.md` §2.5
extension ByteBits on int {
  /// [position] numarali bit (0 = en dusuk anlamli) set mi?
  bool bit(int position) {
    _assertBitPosition(position);
    return (this >> position) & 0x01 == 0x01;
  }

  /// [position] numarali biti [value] yapar ve yeni byte'i dondurur.
  int withBit(int position, bool value) {
    _assertBitPosition(position);
    return value ? (this | (1 << position)) : (this & ~(1 << position));
  }

  /// [offset] konumundan baslayan [width] bitlik alani okur.
  ///
  /// ```dart
  /// // ACCESS byte'inda AUTHLIM bit 2-0'dadir:
  /// accessByte.bitField(offset: 0, width: 3)
  /// ```
  int bitField({required int offset, required int width}) {
    _assertBitPosition(offset);
    if (width < 1 || offset + width > 8) {
      throw RangeError.value(width, 'width', 'Alan byte sinirini asiyor');
    }
    return (this >> offset) & ((1 << width) - 1);
  }

  /// [offset] konumundan baslayan [width] bitlik alana [value] yazar.
  int withBitField({
    required int offset,
    required int width,
    required int value,
  }) {
    _assertBitPosition(offset);
    if (width < 1 || offset + width > 8) {
      throw RangeError.value(width, 'width', 'Alan byte sinirini asiyor');
    }
    final mask = ((1 << width) - 1) << offset;
    if (value < 0 || value > (1 << width) - 1) {
      throw RangeError.value(value, 'value', '$width bite sigmiyor');
    }
    return (this & ~mask) | ((value << offset) & mask);
  }

  /// Byte'i 8 haneli ikili metne cevirir: `10110010`.
  String toBinaryString() => toUnsigned(8).toRadixString(2).padLeft(8, '0');

  /// Byte'i iki haneli hex metne cevirir: `A2`.
  String toHexByte() =>
      toUnsigned(8).toRadixString(16).padLeft(2, '0').toUpperCase();

  static void _assertBitPosition(int position) {
    if (position < 0 || position > 7) {
      throw RangeError.value(
        position,
        'position',
        'Bit konumu 0-7 arasi olmali',
      );
    }
  }
}

/// Bir byte dizisi uzerinde bit islemleri.
extension ByteListBits on List<int> {
  /// Dizideki [byteIndex] numarali byte'in [bitPosition] bitini okur.
  bool bitAt(int byteIndex, int bitPosition) {
    if (byteIndex < 0 || byteIndex >= length) {
      throw RangeError.index(byteIndex, this, 'byteIndex');
    }
    return this[byteIndex].bit(bitPosition);
  }
}
