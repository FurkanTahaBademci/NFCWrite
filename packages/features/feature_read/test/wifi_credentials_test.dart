import 'dart:typed_data';

import 'package:feature_read/src/domain/wifi_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

/// WSC TLV yardimcisi — buyuk-endian 2 byte tip + 2 byte uzunluk + deger.
Uint8List _tlv(int type, List<int> value) => Uint8List.fromList([
  (type >> 8) & 0xFF,
  type & 0xFF,
  (value.length >> 8) & 0xFF,
  value.length & 0xFF,
  ...value,
]);

void main() {
  group('WifiCredentials.tryParse', () {
    test('Credential zarfi icindeki SSID/parola/guvenlik cozulur', () {
      final ssidBytes = 'EvAgi'.codeUnits;
      final passwordBytes = 'gizliSifre'.codeUnits;
      final credential = <int>[
        ..._tlv(0x1045, ssidBytes),
        ..._tlv(0x1003, [0x00, 0x20]), // WPA2-PSK
        ..._tlv(0x100F, [0x00, 0x08]), // AES
        ..._tlv(0x1027, passwordBytes),
      ];
      final payload = _tlv(0x100E, credential);

      final result = WifiCredentials.tryParse(payload);

      expect(result, isNotNull);
      expect(result!.ssid, 'EvAgi');
      expect(result.password, 'gizliSifre');
      expect(result.authType, 0x0020);
      expect(result.securityLabel, 'WPA/WPA2-PSK');
    });

    test('zarf olmadan duz alanlar da cozulur', () {
      final payload = Uint8List.fromList([
        ..._tlv(0x1045, 'Ofis'.codeUnits),
        ..._tlv(0x1003, [0x00, 0x01]), // Acik
      ]);

      final result = WifiCredentials.tryParse(payload);

      expect(result!.ssid, 'Ofis');
      expect(result.password, isNull);
      expect(result.securityLabel, 'Açık');
    });

    test('SSID yoksa null doner', () {
      final payload = _tlv(0x1027, 'sadece-sifre'.codeUnits);

      expect(WifiCredentials.tryParse(payload), isNull);
    });

    test('bozuk/eksik TLV hata atmadan durur', () {
      final payload = Uint8List.fromList([0x10, 0x45, 0xFF, 0xFF, 0x01]);

      expect(WifiCredentials.tryParse(payload), isNull);
    });
  });
}
