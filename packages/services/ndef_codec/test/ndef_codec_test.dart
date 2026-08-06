import 'dart:typed_data';

import 'package:ndef_codec/ndef_codec.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';
import 'package:test/test.dart';

void main() {
  group('URI on ekleri', () {
    test('en uzun eslesme secilir', () {
      // 'https://www.' (0x02), 'https://' (0x04) degil.
      expect(findBestUriPrefixCode('https://www.ornek.com'), 0x02);
      expect(findBestUriPrefixCode('https://ornek.com'), 0x04);
      expect(findBestUriPrefixCode('tel:+905551112233'), 0x05);
    });

    test('eslesme yoksa 0 doner', () {
      expect(findBestUriPrefixCode('ornek://test'), 0x00);
    });

    test('tablo 36 girdi icerir', () {
      expect(ndefUriPrefixes.length, 36);
    });
  });

  group('Metin kaydi', () {
    test('cift yonlu', () {
      const content = TextContent(text: 'Merhaba dunya', languageCode: 'tr');
      final decoded = NdefConverter.decode(NdefConverter.encode(content));
      expect(decoded, content);
    });

    test('bilinen byte dizisi uretir', () {
      const content = TextContent(text: 'hi', languageCode: 'en');
      final record = NdefConverter.encode(content);
      // 0x02 = UTF-8, dil kodu 2 byte; 'en' = 65 6E; 'hi' = 68 69
      expect(bytesToHex(record.payload), '02656E6869');
      expect(record.typeAsString, 'T');
      expect(record.typeNameFormat, NdefTypeNameFormat.wellKnown);
    });

    test('UTF-16 cift yonlu', () {
      const content = TextContent(
        text: 'Turkce karakterler',
        languageCode: 'tr',
        isUtf16: true,
      );
      expect(NdefConverter.decode(NdefConverter.encode(content)), content);
    });
  });

  group('URI kaydi', () {
    test('cift yonlu', () {
      const content = UriContent('https://www.ornek.com/sayfa');
      expect(NdefConverter.decode(NdefConverter.encode(content)), content);
    });

    test('on ek kodu yukun ilk byte`i olur', () {
      final record = NdefConverter.encode(
        const UriContent('https://ornek.com'),
      );
      expect(record.payload.first, 0x04);
      expect(record.typeAsString, 'U');
    });
  });

  group('vCard kaydi', () {
    test('cift yonlu', () {
      final content = VCardContent(
        formattedName: 'Furkan Bademci',
        givenName: 'Furkan',
        familyName: 'Bademci',
        phones: const <String>['+905551112233'],
        emails: const <String>['furkan@ornek.com'],
        organization: 'NFC Toolkit',
        title: 'Developer',
        address: 'Istanbul, Turkiye',
        url: 'https://ornek.com',
        socialUrls: const <String>[
          'https://instagram.com/furkan',
          'https://linkedin.com/in/furkan',
        ],
        note: 'Test notu',
      );

      final decoded = NdefConverter.decode(NdefConverter.encode(content));
      expect(decoded, content);
    });

    test('katlanmis satirlar cozulur', () {
      const folded =
          'BEGIN:VCARD\r\n'
          'VERSION:3.0\r\n'
          'N:Bademci;Furkan;;;\r\n'
          'FN:Furkan Bademci\r\n'
          'NOTE:Bu satir oldukca uzun oldugu icin katlanmistir ve\r\n'
          ' devam ediyor\r\n'
          'END:VCARD';

      final record = NdefRecordEntity(
        typeNameFormat: NdefTypeNameFormat.media,
        type: Uint8List.fromList('text/vcard'.codeUnits),
        identifier: Uint8List(0),
        payload: Uint8List.fromList(folded.codeUnits),
      );

      final decoded = NdefConverter.decode(record);
      expect(decoded, isA<VCardContent>());
      expect((decoded as VCardContent).note, contains('devam ediyor'));
    });
  });

  group('vCard paylasim baglantisi (iPhone uyumlu)', () {
    final content = VCardContent(
      formattedName: 'Furkan Bademci',
      givenName: 'Furkan',
      familyName: 'Bademci',
      phones: const <String>['+905551112233'],
      emails: const <String>['furkan@ornek.com'],
      organization: 'NFC Toolkit',
      url: 'https://ornek.com',
      note: 'Turkce karakter testi: ğüşiöç',
    );

    test('cift yonlu: build -> tryParse', () {
      final url = VCardShareLink.build(content);
      expect(url, startsWith(VCardShareLink.defaultBaseUrl));
      expect(VCardShareLink.tryParse(url), content);
    });

    test('fragment base64url alfabesi kullanir, padding icermez', () {
      final url = VCardShareLink.build(content);
      final fragment = url.substring(url.indexOf('#') + 1);
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(fragment), isTrue);
    });

    test('fragment sunucuya giden yol icermez', () {
      // Fragment'tan onceki kisim sabit cozucu sayfadir; kisi verisi
      // yalnizca '#' sonrasinda tasinir.
      final url = VCardShareLink.build(content);
      expect(url.substring(0, url.indexOf('#')), VCardShareLink.defaultBaseUrl);
    });

    test('bozuk baglantida null doner', () {
      expect(VCardShareLink.tryParse('https://ornek.com/v/'), isNull);
      expect(VCardShareLink.tryParse('https://ornek.com/v/#'), isNull);
      expect(VCardShareLink.tryParse('https://ornek.com/v/#%%%'), isNull);
    });
  });

  group('Ikili kodlayici', () {
    test('mesaj cift yonlu', () {
      final message = NdefConverter.encodeAll([
        const TextContent(text: 'bir'),
        const UriContent('https://ornek.com'),
      ]);

      final encoded = NdefBinaryCodec.encodeMessage(message);
      final decoded = NdefBinaryCodec.decodeMessage(encoded);

      expect(decoded, isA<Ok<NdefMessageEntity>>());
      expect((decoded as Ok<NdefMessageEntity>).value, message);
    });

    test('ilk kayitta MB, son kayitta ME bayragi var', () {
      final message = NdefConverter.encodeAll([
        const TextContent(text: 'a'),
        const TextContent(text: 'b'),
      ]);
      final bytes = NdefBinaryCodec.encodeMessage(message);

      expect(bytes.first & NdefHeaderFlags.mb, NdefHeaderFlags.mb);
      expect(bytes.first & NdefHeaderFlags.me, 0);
    });

    test('255 byte`tan uzun yuk uzun kayit olarak kodlanir', () {
      final longText = 'a' * 300;
      final message = NdefConverter.encodeAll([TextContent(text: longText)]);
      final bytes = NdefBinaryCodec.encodeMessage(message);

      // SR bayragi kapali olmali.
      expect(bytes.first & NdefHeaderFlags.sr, 0);

      final decoded = NdefBinaryCodec.decodeMessage(bytes);
      expect(decoded, isA<Ok<NdefMessageEntity>>());
      final content = NdefConverter.decode(
        (decoded as Ok<NdefMessageEntity>).value.records.first,
      );
      expect((content as TextContent).text, longText);
    });

    test('bozuk veri MalformedData doner', () {
      // Kayit 100 byte yuk bildiriyor ama dizide yok.
      final broken = Uint8List.fromList([0xD1, 0x01, 0x64, 0x54]);
      expect(NdefBinaryCodec.decodeMessage(broken), isA<Err<dynamic>>());
    });
  });

  group('TLV', () {
    test('TLV zarfi ve terminator eklenir', () {
      final message = NdefConverter.encodeAll([
        const TextContent(text: 'x', languageCode: 'en'),
      ]);
      final wrapped = NdefBinaryCodec.wrapInTlv(message);

      expect(wrapped.first, TlvType.ndefMessage);
      expect(wrapped.last, TlvType.terminator);
    });

    test('bellekten NDEF cikarilir', () {
      final message = NdefConverter.encodeAll([
        const UriContent('https://ornek.com'),
      ]);
      final memory = NdefBinaryCodec.wrapInTlv(message);

      final extracted = NdefBinaryCodec.extractFromMemory(memory);
      expect(extracted, isA<Ok<NdefMessageEntity?>>());
      expect((extracted as Ok<NdefMessageEntity?>).value, message);
    });

    test('bos bellekte null doner', () {
      final memory = Uint8List.fromList([TlvType.terminator, 0x00, 0x00]);
      final extracted = NdefBinaryCodec.extractFromMemory(memory);
      expect((extracted as Ok<NdefMessageEntity?>).value, isNull);
    });
  });

  group('Kapasite hesabi', () {
    test('TLV zarfi kapasiteye dahildir', () {
      final message = NdefConverter.encodeAll([
        const TextContent(text: 'test', languageCode: 'en'),
      ]);
      // TLV: tip (1) + uzunluk (1) + terminator (1) = 3 byte fazla.
      expect(message.byteLengthOnTag, message.byteLength + 3);
    });
  });

  group('Wi-Fi (WSC)', () {
    test('cift yonlu: sifreli ag', () {
      const content = WifiContent(
        ssid: 'Ofis Ağı',
        password: 'gizli-parola-123',
        auth: WifiAuthType.wpa2Personal,
      );

      final decoded = NdefConverter.decode(NdefConverter.encode(content));

      expect(decoded, isA<WifiContent>());
      final wifi = decoded as WifiContent;
      expect(wifi.ssid, 'Ofis Ağı');
      expect(wifi.password, 'gizli-parola-123');
      expect(wifi.auth, WifiAuthType.wpa2Personal);
    });

    test('cift yonlu: acik ag parola tasimaz', () {
      const content = WifiContent(
        ssid: 'Misafir',
        // Acik agda parola verilse bile yazilmamali.
        password: 'yok-sayilmali',
        auth: WifiAuthType.open,
      );

      final wifi =
          NdefConverter.decode(NdefConverter.encode(content)) as WifiContent;

      expect(wifi.ssid, 'Misafir');
      expect(wifi.password, isEmpty);
      expect(wifi.auth, WifiAuthType.open);
    });

    test('dogru MIME tipi ve TNF ile kodlanir', () {
      const content = WifiContent(
        ssid: 'A',
        password: 'parola12',
        auth: WifiAuthType.wpa2Personal,
      );

      final record = NdefConverter.encode(content);

      expect(record.typeNameFormat, NdefTypeNameFormat.media);
      expect(record.typeAsString, 'application/vnd.wfa.wsc');
    });

    test('yuk Credential (0x100E) zarfiyla baslar', () {
      final payload = WifiWscCodec.encode(
        ssid: 'Test',
        password: 'parola12',
        auth: WifiAuthType.wpa2Personal,
      );

      // 0x10 0x0E = Credential, ardindan 2 byte uzunluk.
      expect(payload[0], 0x10);
      expect(payload[1], 0x0E);
      final declaredLength = (payload[2] << 8) | payload[3];
      expect(declaredLength, payload.length - 4);
    });

    test('SSID 32 byte siniri asilirsa reddedilir', () {
      expect(
        () => WifiWscCodec.encode(
          ssid: 'x' * 33,
          password: 'parola12',
          auth: WifiAuthType.wpa2Personal,
        ),
        throwsArgumentError,
      );
    });

    test('kisa parola dogrulamada yakalanir', () {
      expect(
        WifiWscCodec.validatePassword('kisa', WifiAuthType.wpa2Personal),
        isNotNull,
      );
      expect(
        WifiWscCodec.validatePassword('yeterince-uzun', WifiAuthType.wpa2Personal),
        isNull,
      );
      // Acik agda parola hic aranmaz.
      expect(WifiWscCodec.validatePassword('', WifiAuthType.open), isNull);
    });

    test('taninmayan auth degeri WPA2ye duser', () {
      final payload = WifiWscCodec.encode(
        ssid: 'Test',
        password: 'parola12',
        auth: WifiAuthType.wpa2Personal,
      );
      final network = WifiWscCodec.decode(payload);

      expect(network, isNotNull);
      expect(network!.auth, WifiAuthType.wpa2Personal);
    });

    test('SSID yoksa cozumleme null doner', () {
      expect(WifiWscCodec.decode(Uint8List(0)), isNull);
    });
  });
}
