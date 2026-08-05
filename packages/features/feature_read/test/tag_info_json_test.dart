import 'dart:convert';
import 'dart:typed_data';

import 'package:feature_read/src/domain/tag_info_json.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_core/nfc_core.dart';

void main() {
  group('tagInfoToJson', () {
    test('temel alanlari ve NDEF kayitlarini icerir', () {
      final info = NfcTagInfo(
        uid: Uint8List.fromList([0x04, 0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0x80]),
        technologies: const [TagTechnology.nfcA, TagTechnology.mifareUltralight],
        identity: const TagIdentity(
          family: TagChipFamily.ntag213,
          manufacturer: TagManufacturer.nxp,
          displayName: 'NTAG213',
          totalBytes: 180,
          userBytes: 144,
        ),
        isNdefFormatted: true,
        isWritable: true,
        maxNdefSize: 144,
        currentNdefSize: 10,
        ndefMessage: NdefMessageEntity([
          NdefRecordEntity(
            typeNameFormat: NdefTypeNameFormat.wellKnown,
            type: Uint8List.fromList('U'.codeUnits),
            identifier: Uint8List(0),
            payload: Uint8List.fromList([
              0x04,
              ...'example.com'.codeUnits,
            ]),
          ),
        ]),
      );

      final json = tagInfoToJson(info);

      expect(json['uidHex'], '04A1B2C3D4E580');
      expect((json['identity'] as Map)['family'], 'ntag213');
      expect((json['identity'] as Map)['displayName'], 'NTAG213');
      expect(json['isNdefFormatted'], isTrue);

      final records = json['ndefRecords'] as List;
      expect(records, hasLength(1));
      expect((records.first as Map)['type'], 'U');
      expect((records.first as Map)['summary'], 'https://example.com');
    });

    test('JSON gecerli ve okunabilir metne cevrilir', () {
      final info = NfcTagInfo(
        uid: Uint8List.fromList([0x04, 0x01]),
        technologies: const [TagTechnology.nfcA],
        identity: const TagIdentity.unknown(),
      );

      final text = tagInfoToJsonString(info);
      final decoded = jsonDecode(text) as Map<String, Object?>;

      expect(decoded['uidHex'], '0401');
      expect(decoded['ndefRecords'], isNull);
    });
  });
}
