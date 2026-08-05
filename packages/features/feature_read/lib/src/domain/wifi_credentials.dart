import 'dart:convert';
import 'dart:typed_data';

/// WSC (Wi-Fi Simple Config) yukunden cozumlenmis Wi-Fi bilgileri.
///
/// Bkz. `.claude/docs/03-nfc-reference.md` §1.4. Bu bir NDEF kod cozucusu
/// degil — yalnizca A10 "Wi-Fi bilgilerini goster" eylemi icin
/// `MimeContent` yukunu okunabilir hale getirir.
final class WifiCredentials {
  const WifiCredentials({
    this.ssid,
    this.password,
    this.authType,
    this.encryptionType,
  });

  final String? ssid;
  final String? password;
  final int? authType;
  final int? encryptionType;

  /// Insan-okunur guvenlik etiketi.
  String get securityLabel => switch (authType) {
    0x0001 => 'Açık',
    0x0002 || 0x0020 => 'WPA/WPA2-PSK',
    0x0004 => 'Paylaşılan anahtar',
    0x0008 || 0x0010 => 'WPA-Enterprise',
    _ => 'Bilinmiyor',
  };

  /// `application/vnd.wfa.wsc` yukunu cozumler.
  ///
  /// TLV: 2 byte tip + 2 byte uzunluk (big-endian) + deger. `0x100E`
  /// (Credential) diger alanlari saran bir zarftir; icine de bakilir.
  static WifiCredentials? tryParse(Uint8List data) {
    String? ssid;
    String? password;
    int? authType;
    int? encryptionType;

    void scan(Uint8List bytes) {
      var offset = 0;
      while (offset + 4 <= bytes.length) {
        final type = (bytes[offset] << 8) | bytes[offset + 1];
        final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
        final valueStart = offset + 4;
        final valueEnd = valueStart + length;
        if (valueEnd > bytes.length) break;
        final value = Uint8List.sublistView(bytes, valueStart, valueEnd);

        switch (type) {
          case 0x100E:
            scan(value);
          case 0x1045:
            ssid = _decodeText(value);
          case 0x1027:
            password = _decodeText(value);
          case 0x1003:
            if (value.length >= 2) authType = (value[0] << 8) | value[1];
          case 0x100F:
            if (value.length >= 2) {
              encryptionType = (value[0] << 8) | value[1];
            }
        }

        offset = valueEnd;
      }
    }

    scan(data);
    if (ssid == null) return null;

    return WifiCredentials(
      ssid: ssid,
      password: password,
      authType: authType,
      encryptionType: encryptionType,
    );
  }

  static String? _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return null;
    }
  }
}
