import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Bir NDEF kaydinin **cozumlenmis**, anlamli hali.
///
/// `sealed` — yeni bir tip eklendiginde onu ele almayan her `switch`
/// derleme hatasi verir. Yeni tip eklerken
/// `.claude/templates/new_record_type.md` sablonunu izle.
@immutable
sealed class NdefContent {
  const NdefContent();

  /// Listede gosterilecek kisa ozet.
  String get summary;
}

/// Duz metin kaydi (`T`).
final class TextContent extends NdefContent {
  const TextContent({
    required this.text,
    this.languageCode = 'tr',
    this.isUtf16 = false,
  });

  final String text;

  /// BCP-47 dil kodu (`tr`, `en`, `en-US`).
  final String languageCode;

  /// UTF-16 kodlama kullanilsin mi? Varsayilan UTF-8.
  final bool isUtf16;

  @override
  String get summary => text;

  @override
  bool operator ==(Object other) =>
      other is TextContent &&
      other.text == text &&
      other.languageCode == languageCode &&
      other.isUtf16 == isUtf16;

  @override
  int get hashCode => Object.hash(text, languageCode, isUtf16);

  @override
  String toString() => 'TextContent($languageCode: $text)';
}

/// URI kaydi (`U`) — web adresi, telefon, e-posta, konum vb.
final class UriContent extends NdefContent {
  const UriContent(this.uri);

  final String uri;

  /// URI'nin semasi (`https`, `tel`, `mailto`, `geo`...). Yoksa bos.
  String get scheme {
    final index = uri.indexOf(':');
    return index > 0 ? uri.substring(0, index) : '';
  }

  @override
  String get summary => uri;

  @override
  bool operator ==(Object other) => other is UriContent && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() => 'UriContent($uri)';
}

/// vCard kaydi (MIME `text/vcard`).
final class VCardContent extends NdefContent {
  VCardContent({
    required this.formattedName,
    this.familyName,
    this.givenName,
    this.organization,
    this.title,
    List<String> phones = const <String>[],
    List<String> emails = const <String>[],
    this.address,
    this.url,
    List<String> socialUrls = const <String>[],
    this.note,
  }) : phones = List.unmodifiable(phones),
       emails = List.unmodifiable(emails),
       socialUrls = List.unmodifiable(socialUrls);

  final String formattedName;
  final String? familyName;
  final String? givenName;
  final String? organization;
  final String? title;
  final List<String> phones;
  final List<String> emails;
  final String? address;
  final String? url;
  final List<String> socialUrls;
  final String? note;

  @override
  String get summary {
    final contact = phones.firstOrNull ?? emails.firstOrNull;
    return contact == null ? formattedName : '$formattedName · $contact';
  }

  @override
  bool operator ==(Object other) =>
      other is VCardContent &&
      other.formattedName == formattedName &&
      other.familyName == familyName &&
      other.givenName == givenName &&
      other.organization == organization &&
      other.title == title &&
      const ListEquality<String>().equals(other.phones, phones) &&
      const ListEquality<String>().equals(other.emails, emails) &&
      other.address == address &&
      other.url == url &&
      const ListEquality<String>().equals(other.socialUrls, socialUrls) &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
    formattedName,
    familyName,
    givenName,
    organization,
    title,
    const ListEquality<String>().hash(phones),
    const ListEquality<String>().hash(emails),
    address,
    url,
    const ListEquality<String>().hash(socialUrls),
    note,
  );

  @override
  String toString() => 'VCardContent($formattedName)';
}

/// MIME tipli veri kaydi (TNF 2).
final class MimeContent extends NdefContent {
  MimeContent({required this.mimeType, required Uint8List data})
    : data = Uint8List.fromList(data);

  final String mimeType;
  final Uint8List data;

  /// Icerik metin olarak yorumlanabiliyorsa metin, degilse null.
  String? get asText {
    if (!mimeType.startsWith('text/') &&
        !mimeType.contains('vcard') &&
        !mimeType.contains('calendar') &&
        !mimeType.contains('json')) {
      return null;
    }
    try {
      return String.fromCharCodes(data);
    } on Object {
      return null;
    }
  }

  @override
  String get summary => '$mimeType (${data.length} byte)';

  @override
  bool operator ==(Object other) =>
      other is MimeContent &&
      other.mimeType == mimeType &&
      const ListEquality<int>().equals(other.data, data);

  @override
  int get hashCode =>
      Object.hash(mimeType, const ListEquality<int>().hash(data));

  @override
  String toString() => 'MimeContent($mimeType, ${data.length} byte)';
}

/// Harici tip kaydi (TNF 4) — orn. Android Application Record.
final class ExternalContent extends NdefContent {
  ExternalContent({required this.domainType, required Uint8List data})
    : data = Uint8List.fromList(data);

  /// `android.com:pkg` gibi alan adi + tip.
  final String domainType;

  final Uint8List data;

  /// Bu bir Android Application Record mi?
  bool get isAndroidApplicationRecord => domainType == 'android.com:pkg';

  /// AAR ise paket adi, degilse null.
  String? get packageName =>
      isAndroidApplicationRecord ? String.fromCharCodes(data) : null;

  @override
  String get summary =>
      isAndroidApplicationRecord ? 'Uygulama: $packageName' : domainType;

  @override
  bool operator ==(Object other) =>
      other is ExternalContent &&
      other.domainType == domainType &&
      const ListEquality<int>().equals(other.data, data);

  @override
  int get hashCode =>
      Object.hash(domainType, const ListEquality<int>().hash(data));

  @override
  String toString() => 'ExternalContent($domainType)';
}

/// Bos kayit (TNF 0).
final class EmptyContent extends NdefContent {
  const EmptyContent();

  @override
  String get summary => 'Bos kayit';

  @override
  bool operator ==(Object other) => other is EmptyContent;

  @override
  int get hashCode => (EmptyContent).hashCode;

  @override
  String toString() => 'EmptyContent()';
}

/// Cozumlenemeyen kayit — ham haliyle gosterilir.
///
/// Bilinmeyen bir kayit tipiyle karsilasildiginda veri **kaybedilmez**;
/// kullanici hex olarak gorebilir ve kopyalayabilir.
final class RawContent extends NdefContent {
  RawContent({
    required this.typeNameFormatName,
    required this.typeAsString,
    required Uint8List payload,
  }) : payload = Uint8List.fromList(payload);

  final String typeNameFormatName;
  final String typeAsString;
  final Uint8List payload;

  @override
  String get summary =>
      '$typeNameFormatName${typeAsString.isEmpty ? '' : ' / $typeAsString'} '
      '(${payload.length} byte)';

  @override
  bool operator ==(Object other) =>
      other is RawContent &&
      other.typeNameFormatName == typeNameFormatName &&
      other.typeAsString == typeAsString &&
      const ListEquality<int>().equals(other.payload, payload);

  @override
  int get hashCode => Object.hash(
    typeNameFormatName,
    typeAsString,
    const ListEquality<int>().hash(payload),
  );

  @override
  String toString() => 'RawContent($summary)';
}
