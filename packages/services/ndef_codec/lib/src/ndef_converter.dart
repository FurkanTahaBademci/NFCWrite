import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_core/nfc_core.dart';

import 'ndef_content.dart';
import 'uri_prefixes.dart';

/// Iyi bilinen kayit tipleri (TNF 1).
abstract final class WellKnownType {
  static final Uint8List text = Uint8List.fromList('T'.codeUnits);
  static final Uint8List uri = Uint8List.fromList('U'.codeUnits);
  static final Uint8List smartPoster = Uint8List.fromList('Sp'.codeUnits);
}

/// Ham NDEF kaydi ile cozumlenmis [NdefContent] arasinda cevirmen.
///
/// **Yeni bir kayit tipi eklerken** hem [decode] hem [encode] tarafina
/// eklemeyi ve cift yonlu test yazmayi unutma.
/// Bkz. `.claude/templates/new_record_type.md`
abstract final class NdefConverter {
  /// Ham kaydi cozumler.
  ///
  /// Tanimadigi kayitlar icin [RawContent] doner — veri asla kaybolmaz.
  static NdefContent decode(NdefRecordEntity record) {
    switch (record.typeNameFormat) {
      case NdefTypeNameFormat.empty:
        return const EmptyContent();

      case NdefTypeNameFormat.wellKnown:
        final type = record.typeAsString;
        if (type == 'T') {
          final text = _decodeText(record.payload);
          if (text != null) return text;
        }
        if (type == 'U') {
          final uri = _decodeUri(record.payload);
          if (uri != null) return uri;
        }

      case NdefTypeNameFormat.media:
        return MimeContent(mimeType: record.typeAsString, data: record.payload);

      case NdefTypeNameFormat.absoluteUri:
        // TNF 3'te URI tip alanindadir, yukte degil.
        return UriContent(record.typeAsString);

      case NdefTypeNameFormat.externalType:
        return ExternalContent(
          domainType: record.typeAsString,
          data: record.payload,
        );

      case NdefTypeNameFormat.unknown:
      case NdefTypeNameFormat.unchanged:
      case NdefTypeNameFormat.reserved:
        break;
    }

    return RawContent(
      typeNameFormatName: record.typeNameFormat.name,
      typeAsString: record.typeAsString,
      payload: record.payload,
    );
  }

  /// Bir mesajin tum kayitlarini cozumler.
  static List<NdefContent> decodeAll(NdefMessageEntity message) =>
      message.records.map(decode).toList(growable: false);

  /// Cozumlenmis icerigi ham kayda cevirir.
  static NdefRecordEntity encode(NdefContent content) => switch (content) {
    EmptyContent() => NdefRecordEntity.empty(),
    TextContent() => _encodeText(content),
    UriContent() => _encodeUri(content),
    MimeContent() => NdefRecordEntity(
      typeNameFormat: NdefTypeNameFormat.media,
      type: Uint8List.fromList(utf8.encode(content.mimeType)),
      identifier: Uint8List(0),
      payload: content.data,
    ),
    ExternalContent() => NdefRecordEntity(
      typeNameFormat: NdefTypeNameFormat.externalType,
      type: Uint8List.fromList(utf8.encode(content.domainType)),
      identifier: Uint8List(0),
      payload: content.data,
    ),
    RawContent() => NdefRecordEntity(
      typeNameFormat: NdefTypeNameFormat.unknown,
      type: Uint8List(0),
      identifier: Uint8List(0),
      payload: content.payload,
    ),
  };

  /// Icerik listesinden mesaj olusturur.
  static NdefMessageEntity encodeAll(List<NdefContent> contents) =>
      contents.isEmpty
      ? NdefMessageEntity.empty()
      : NdefMessageEntity(contents.map(encode).toList());

  // -------------------------------------------------------------------
  // Metin (T)
  // -------------------------------------------------------------------

  static TextContent? _decodeText(Uint8List payload) {
    if (payload.isEmpty) return null;
    final status = payload[0];
    final isUtf16 = status & 0x80 != 0;
    final languageLength = status & 0x3F;
    if (1 + languageLength > payload.length) return null;

    final language = String.fromCharCodes(
      payload.sublist(1, 1 + languageLength),
    );
    final textBytes = payload.sublist(1 + languageLength);

    final String text;
    if (isUtf16) {
      text = _decodeUtf16(textBytes);
    } else {
      try {
        text = utf8.decode(textBytes);
      } on FormatException {
        return null;
      }
    }

    return TextContent(text: text, languageCode: language, isUtf16: isUtf16);
  }

  static NdefRecordEntity _encodeText(TextContent content) {
    final languageBytes = ascii.encode(content.languageCode);
    if (languageBytes.length > 0x3F) {
      throw ArgumentError.value(
        content.languageCode,
        'languageCode',
        'Dil kodu en fazla 63 byte olabilir',
      );
    }
    final textBytes = content.isUtf16
        ? _encodeUtf16(content.text)
        : utf8.encode(content.text);

    final payload = Uint8List(1 + languageBytes.length + textBytes.length);
    payload[0] =
        (content.isUtf16 ? 0x80 : 0x00) | (languageBytes.length & 0x3F);
    payload.setRange(1, 1 + languageBytes.length, languageBytes);
    payload.setRange(1 + languageBytes.length, payload.length, textBytes);

    return NdefRecordEntity(
      typeNameFormat: NdefTypeNameFormat.wellKnown,
      type: WellKnownType.text,
      identifier: Uint8List(0),
      payload: payload,
    );
  }

  // -------------------------------------------------------------------
  // URI (U)
  // -------------------------------------------------------------------

  static UriContent? _decodeUri(Uint8List payload) {
    if (payload.isEmpty) return null;
    final prefix = uriPrefixForCode(payload[0]);
    try {
      return UriContent(prefix + utf8.decode(payload.sublist(1)));
    } on FormatException {
      return null;
    }
  }

  static NdefRecordEntity _encodeUri(UriContent content) {
    final prefixCode = findBestUriPrefixCode(content.uri);
    final remainder = content.uri.substring(ndefUriPrefixes[prefixCode].length);
    final remainderBytes = utf8.encode(remainder);

    final payload = Uint8List(1 + remainderBytes.length)
      ..[0] = prefixCode
      ..setRange(1, 1 + remainderBytes.length, remainderBytes);

    return NdefRecordEntity(
      typeNameFormat: NdefTypeNameFormat.wellKnown,
      type: WellKnownType.uri,
      identifier: Uint8List(0),
      payload: payload,
    );
  }

  // -------------------------------------------------------------------
  // UTF-16 yardimcilari
  //
  // dart:convert UTF-16 sunmuyor. NDEF metin kayitlarinda UTF-16 nadirdir
  // ama spesifikasyonda vardir; big-endian varsayilir, BOM varsa dikkate
  // alinir.
  // -------------------------------------------------------------------

  static String _decodeUtf16(Uint8List bytes) {
    if (bytes.length < 2) return '';
    var offset = 0;
    var bigEndian = true;

    // Byte Order Mark
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      bigEndian = false;
      offset = 2;
    } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      offset = 2;
    }

    final units = <int>[];
    for (var i = offset; i + 1 < bytes.length; i += 2) {
      units.add(
        bigEndian
            ? (bytes[i] << 8) | bytes[i + 1]
            : (bytes[i + 1] << 8) | bytes[i],
      );
    }
    return String.fromCharCodes(units);
  }

  static Uint8List _encodeUtf16(String text) {
    final units = text.codeUnits;
    final bytes = Uint8List(units.length * 2);
    for (var i = 0; i < units.length; i++) {
      bytes[i * 2] = (units[i] >> 8) & 0xFF;
      bytes[i * 2 + 1] = units[i] & 0xFF;
    }
    return bytes;
  }
}
