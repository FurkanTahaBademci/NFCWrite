import 'dart:typed_data';

const String _hexDigits = '0123456789ABCDEF';

/// Byte dizisini hex metne cevirir.
///
/// ```dart
/// bytesToHex([0x04, 0xA2])                  // '04A2'
/// bytesToHex([0x04, 0xA2], separator: ' ')  // '04 A2'
/// bytesToHex([0x04, 0xA2], lowerCase: true) // '04a2'
/// ```
String bytesToHex(
  List<int> bytes, {
  String separator = '',
  bool lowerCase = false,
}) {
  if (bytes.isEmpty) return '';
  final buffer = StringBuffer();
  for (var i = 0; i < bytes.length; i++) {
    if (i > 0 && separator.isNotEmpty) buffer.write(separator);
    final byte = bytes[i] & 0xFF;
    buffer
      ..write(_hexDigits[(byte >> 4) & 0x0F])
      ..write(_hexDigits[byte & 0x0F]);
  }
  final result = buffer.toString();
  return lowerCase ? result.toLowerCase() : result;
}

/// Hex metni byte dizisine cevirir.
///
/// Bosluk, `:`, `-` ve `0x` on eki yok sayilir. Tek sayida hex basamak
/// ya da gecersiz karakter varsa [FormatException] atar.
///
/// ```dart
/// hexToBytes('04 A2')     // [0x04, 0xA2]
/// hexToBytes('04:a2')     // [0x04, 0xA2]
/// hexToBytes('0x04A2')    // [0x04, 0xA2]
/// ```
Uint8List hexToBytes(String hex) {
  final cleaned = hex
      .replaceAll(RegExp('0[xX]'), '')
      .replaceAll(RegExp(r'[\s:_\-,]'), '');
  if (cleaned.isEmpty) return Uint8List(0);
  if (cleaned.length.isOdd) {
    throw FormatException('Hex metin cift sayida basamak icermeli', hex);
  }
  final result = Uint8List(cleaned.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    final high = _hexValue(cleaned.codeUnitAt(i * 2), hex);
    final low = _hexValue(cleaned.codeUnitAt(i * 2 + 1), hex);
    result[i] = (high << 4) | low;
  }
  return result;
}

/// Gecerli bir hex metin mi? [hexToBytes] atmadan calisir mi?
bool isValidHex(String hex) {
  try {
    hexToBytes(hex);
    return true;
  } on FormatException {
    return false;
  }
}

int _hexValue(int codeUnit, String source) {
  // '0'-'9'
  if (codeUnit >= 0x30 && codeUnit <= 0x39) return codeUnit - 0x30;
  // 'A'-'F'
  if (codeUnit >= 0x41 && codeUnit <= 0x46) return codeUnit - 0x41 + 10;
  // 'a'-'f'
  if (codeUnit >= 0x61 && codeUnit <= 0x66) return codeUnit - 0x61 + 10;
  throw FormatException(
    'Gecersiz hex karakteri: ${String.fromCharCode(codeUnit)}',
    source,
  );
}

/// Byte dizisini ASCII olarak yorumlar; yazdirilamayan byte'lari [placeholder]
/// ile degistirir. Hex dokumunun ASCII sutunu icin.
String bytesToAscii(List<int> bytes, {String placeholder = '.'}) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    final b = byte & 0xFF;
    buffer.write(b >= 0x20 && b <= 0x7E ? String.fromCharCode(b) : placeholder);
  }
  return buffer.toString();
}

/// Byte dizisini big-endian tam sayiya cevirir.
///
/// 8 byte'tan uzun diziler icin `int` tasabilir; cagiran taraf dikkat etmeli.
int bytesToIntBigEndian(List<int> bytes) {
  var value = 0;
  for (final byte in bytes) {
    value = (value << 8) | (byte & 0xFF);
  }
  return value;
}

/// Byte dizisini little-endian tam sayiya cevirir.
int bytesToIntLittleEndian(List<int> bytes) {
  var value = 0;
  for (var i = bytes.length - 1; i >= 0; i--) {
    value = (value << 8) | (bytes[i] & 0xFF);
  }
  return value;
}

/// Tam sayiyi [length] byte'lik big-endian diziye cevirir.
Uint8List intToBytesBigEndian(int value, int length) {
  final result = Uint8List(length);
  for (var i = length - 1; i >= 0; i--) {
    result[i] = (value >> ((length - 1 - i) * 8)) & 0xFF;
  }
  return result;
}

/// Tam sayiyi [length] byte'lik little-endian diziye cevirir.
Uint8List intToBytesLittleEndian(int value, int length) {
  final result = Uint8List(length);
  for (var i = 0; i < length; i++) {
    result[i] = (value >> (i * 8)) & 0xFF;
  }
  return result;
}

/// Iki byte dizisi esit mi?
bool bytesEqual(List<int> a, List<int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Birden fazla byte dizisini birlestirir.
Uint8List concatBytes(List<List<int>> parts) {
  final total = parts.fold<int>(0, (sum, part) => sum + part.length);
  final result = Uint8List(total);
  var offset = 0;
  for (final part in parts) {
    result.setRange(offset, offset + part.length, part);
    offset += part.length;
  }
  return result;
}

/// UID'yi okunabilir bicimde formatlar: `04:A2:FF:00`.
String formatUid(List<int> uid) => bytesToHex(uid, separator: ':');

/// UID'yi ters sirada hex olarak dondurur.
///
/// Bazi sistemler UID'yi ters sirada gosterir; kullanicinin karsilastirma
/// yapabilmesi icin her iki gosterim de sunulur.
String reverseUidHex(List<int> uid) =>
    bytesToHex(uid.reversed.toList(growable: false));

/// UID'yi ondalik (decimal) tam sayi metni olarak dondurur.
///
/// UID buyuk-endian yorumlanir (ilk byte en anlamli). 7-10 byte'lik UID'ler
/// `int`'e sigmayabilecegi icin [BigInt] kullanilir.
String formatUidDecimal(List<int> uid) {
  var value = BigInt.zero;
  for (final byte in uid) {
    value = (value << 8) | BigInt.from(byte & 0xFF);
  }
  return value.toString();
}
