import 'dart:convert';

import 'package:ndef_codec/ndef_codec.dart';
import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';

/// Okuma sonucunu (A18) disa aktarilabilir JSON'a cevirir.
///
/// `nfc_core` kod uretimi kullanmadigi icin bu donusum elle yazilir
/// (bkz. `.claude/docs/adr/ADR-0003-no-codegen.md`).
Map<String, Object?> tagInfoToJson(NfcTagInfo info) => {
  'uidHex': info.uidHex,
  'uidReversedHex': reverseUidHex(info.uid),
  'uidDecimal': formatUidDecimal(info.uid),
  'scannedAt': info.scannedAt.toIso8601String(),
  'identity': {
    'family': info.identity.family.name,
    'displayName': info.identity.displayName,
    'manufacturer': info.identity.manufacturer.displayName,
    'totalBytes': info.identity.totalBytes,
    'userBytes': info.identity.userBytes,
  },
  'atqaHex': info.atqa == null ? null : bytesToHex(info.atqa!),
  'sak': info.sak,
  'technologies': info.technologies.map((tech) => tech.name).toList(),
  'isNdefFormatted': info.isNdefFormatted,
  'isWritable': info.isWritable,
  'isPasswordProtected': info.isPasswordProtected,
  'maxNdefSize': info.maxNdefSize,
  'currentNdefSize': info.currentNdefSize,
  'counterValue': info.counterValue,
  'ndefRecords': info.ndefMessage?.records
      .map(
        (record) => <String, Object?>{
          'tnf': record.typeNameFormat.name,
          'type': record.typeAsString,
          'payloadHex': bytesToHex(record.payload),
          'summary': NdefConverter.decode(record).summary,
        },
      )
      .toList(),
};

/// [tagInfoToJson] cikitisini bicimlendirilmis metne cevirir.
String tagInfoToJsonString(NfcTagInfo info) =>
    const JsonEncoder.withIndent('  ').convert(tagInfoToJson(info));
