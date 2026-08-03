import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
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
        final mimeType = record.typeAsString;
        if (_isVCardMime(mimeType)) {
          final decoded = _decodeVCard(record.payload);
          if (decoded != null) return decoded;
        }
        return MimeContent(mimeType: mimeType, data: record.payload);

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
    VCardContent() => _encodeVCard(content),
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
  // vCard (MIME text/vcard)
  // -------------------------------------------------------------------

  static bool _isVCardMime(String mimeType) {
    final normalized = mimeType.trim().toLowerCase();
    return normalized == 'text/vcard' || normalized == 'text/x-vcard';
  }

  static VCardContent? _decodeVCard(Uint8List payload) {
    final raw = _decodeUtf8OrLatin1(payload);
    if (raw == null) return null;

    final unfolded = _unfoldVCardLines(raw);
    final lineMap = <String, List<String>>{};

    var hasBegin = false;
    var hasEnd = false;

    for (final line in unfolded) {
      if (line.isEmpty) continue;
      final upper = line.toUpperCase();
      if (upper == 'BEGIN:VCARD') {
        hasBegin = true;
        continue;
      }
      if (upper == 'END:VCARD') {
        hasEnd = true;
        continue;
      }

      final separator = line.indexOf(':');
      if (separator <= 0) continue;

      final left = line.substring(0, separator);
      final value = line.substring(separator + 1);
      final key = left.split(';').first.toUpperCase();
      lineMap.putIfAbsent(key, () => <String>[]).add(value);
    }

    if (!hasBegin || !hasEnd) return null;

    final formattedName = _firstValue(lineMap, 'FN');
    if (formattedName == null || formattedName.trim().isEmpty) return null;

    final nRaw = _firstValue(lineMap, 'N');
    final nParts = nRaw == null
        ? const <String>[]
        : nRaw.split(';').map(_unescapeVCard).toList(growable: false);

    return VCardContent(
      formattedName: _unescapeVCard(formattedName),
      familyName: _nullIfEmpty(nParts.elementAtOrNull(0)),
      givenName: _nullIfEmpty(nParts.elementAtOrNull(1)),
      organization: _nullIfEmpty(_mapFirst(lineMap, 'ORG')),
      title: _nullIfEmpty(_mapFirst(lineMap, 'TITLE')),
      phones: _mapMany(lineMap, 'TEL'),
      emails: _mapMany(lineMap, 'EMAIL'),
      address: _nullIfEmpty(_decodeAddress(_firstValue(lineMap, 'ADR'))),
      url: _nullIfEmpty(_mapFirst(lineMap, 'URL')),
      note: _nullIfEmpty(_mapFirst(lineMap, 'NOTE')),
    );
  }

  static NdefRecordEntity _encodeVCard(VCardContent content) {
    final lines = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
      'N:${_escapeVCard(content.familyName ?? '')};${_escapeVCard(content.givenName ?? '')};;;',
      'FN:${_escapeVCard(content.formattedName)}',
    ];

    if (_hasValue(content.organization)) {
      lines.add('ORG:${_escapeVCard(content.organization!)}');
    }
    if (_hasValue(content.title)) {
      lines.add('TITLE:${_escapeVCard(content.title!)}');
    }
    for (final phone in content.phones.where(_hasValue)) {
      lines.add('TEL;TYPE=CELL:${_escapeVCard(phone)}');
    }
    for (final email in content.emails.where(_hasValue)) {
      lines.add('EMAIL;TYPE=INTERNET:${_escapeVCard(email)}');
    }
    if (_hasValue(content.address)) {
      lines.add('ADR;TYPE=WORK:;;${_escapeVCard(content.address!)};;;;');
    }
    if (_hasValue(content.url)) {
      lines.add('URL:${_escapeVCard(content.url!)}');
    }
    if (_hasValue(content.note)) {
      lines.add('NOTE:${_escapeVCard(content.note!)}');
    }

    lines.add('END:VCARD');

    final vcard = lines
        .expand(_foldVCardLine)
        .join('\r\n');

    return NdefRecordEntity(
      typeNameFormat: NdefTypeNameFormat.media,
      type: Uint8List.fromList(ascii.encode('text/vcard')),
      identifier: Uint8List(0),
      payload: Uint8List.fromList(utf8.encode(vcard)),
    );
  }

  static String? _decodeUtf8OrLatin1(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      try {
        return latin1.decode(bytes);
      } on FormatException {
        return null;
      }
    }
  }

  static List<String> _unfoldVCardLines(String source) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawLines = normalized.split('\n');
    final result = <String>[];

    for (final line in rawLines) {
      if (line.startsWith(' ') || line.startsWith('\t')) {
        if (result.isNotEmpty) {
          result[result.length - 1] = '${result.last}${line.substring(1)}';
        }
      } else {
        result.add(line);
      }
    }

    return result;
  }

  static Iterable<String> _foldVCardLine(String line) sync* {
    final units = utf8.encode(line);
    if (units.length <= 75) {
      yield line;
      return;
    }

    var start = 0;
    while (start < line.length) {
      var end = start;
      var byteLen = 0;
      while (end < line.length) {
        final char = line.substring(end, end + 1);
        final charBytes = utf8.encode(char).length;
        if (byteLen + charBytes > 75) break;
        byteLen += charBytes;
        end += 1;
      }

      final chunk = line.substring(start, end);
      if (start == 0) {
        yield chunk;
      } else {
        yield ' $chunk';
      }
      start = end;
    }
  }

  static String _escapeVCard(String value) =>
      value
          .replaceAll('\\', r'\\')
          .replaceAll(';', r'\;')
          .replaceAll(',', r'\,')
          .replaceAll('\r\n', r'\n')
          .replaceAll('\n', r'\n')
          .replaceAll('\r', r'\n');

  static String _unescapeVCard(String value) {
    var result = value.replaceAllMapped(RegExp(r'\\[nN]'), (_) => '\n');
    result = result
        .replaceAll(r'\,', ',')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\\', r'\');
    return result;
  }

  static String? _firstValue(Map<String, List<String>> map, String key) {
    final values = map[key];
    if (values == null || values.isEmpty) return null;
    return values.first;
  }

  static String? _mapFirst(Map<String, List<String>> map, String key) {
    final value = _firstValue(map, key);
    return value == null ? null : _unescapeVCard(value);
  }

  static List<String> _mapMany(Map<String, List<String>> map, String key) {
    final values = map[key];
    if (values == null || values.isEmpty) return const <String>[];
    return values
        .map(_unescapeVCard)
        .map((value) => value.trim())
        .where(_hasValue)
        .toList(growable: false);
  }

  static String? _decodeAddress(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final parts = raw.split(';').map(_unescapeVCard).toList(growable: false);
    if (parts.length < 3) return _unescapeVCard(raw);

    final selected = <String>[];
    for (final index in <int>[2, 3, 4, 5, 6]) {
      if (index >= parts.length) break;
      final value = parts[index].trim();
      if (value.isNotEmpty) selected.add(value);
    }

    if (selected.isNotEmpty) return selected.join(', ');
    return _unescapeVCard(raw);
  }

  static String? _nullIfEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;

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
