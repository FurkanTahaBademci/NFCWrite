import 'dart:convert';

import 'ndef_content.dart';
import 'ndef_converter.dart';

/// vCard'i URL fragment'ina gomen "iPhone uyumlu" baglanti ureticisi.
///
/// **Neden var:** iOS arka plan NFC okumasi yalnizca URI kayitlarini
/// isler; MIME `text/vcard` kayitlarini sessizce yok sayar (bildirim
/// bile cikmaz). Android ise vCard'i dogrudan Kisiler'e acar. Iki
/// platformu ayni kartta memnun etmek icin "record stacking" kullanilir:
///
/// 1. kayit → `text/vcard` (Android ilk kaydi isler, cevrimdisi calisir)
/// 2. kayit → bu siniftan uretilen URL (iOS destekledigi ilk kayda atlar)
///
/// vCard'in tamami `#` sonrasindaki fragment'ta base64url tasinir.
/// Fragment tarayici tarafindan sunucuya **gonderilmez** — kisi verisi
/// kartin uzerinde yasar; sayfa yalnizca istemci tarafinda cozer ve
/// "Kisilere Ekle" (.vcf) dosyasi sunar.
abstract final class VCardShareLink {
  /// GitHub Pages uzerindeki cozucu sayfa (`docs/v/index.html`).
  ///
  /// Fiziksel kartlara kalici yazildigi icin bu adres degistirilirse
  /// sahadaki eski kartlar kirilir — degistirme.
  static const String defaultBaseUrl =
      'https://furkantahabademci.github.io/NFCWrite/v/';

  /// [content] icin cozucu sayfa baglantisi uretir.
  static String build(
    VCardContent content, {
    String baseUrl = defaultBaseUrl,
  }) {
    final text = NdefConverter.encodeVCardText(content);
    final data = base64UrlEncode(utf8.encode(text)).replaceAll('=', '');
    return '$baseUrl#$data';
  }

  /// [build] ile uretilmis bir baglantidan vCard icerigini geri cozer.
  ///
  /// Fragment tasimayan veya cozulemeyen baglantilar icin null doner.
  static VCardContent? tryParse(String url) {
    final hashIndex = url.indexOf('#');
    if (hashIndex < 0 || hashIndex == url.length - 1) return null;

    var data = url.substring(hashIndex + 1);
    final padding = data.length % 4;
    if (padding == 1) return null;
    if (padding > 0) data = data.padRight(data.length + (4 - padding), '=');

    try {
      final text = utf8.decode(base64Url.decode(data));
      return NdefConverter.decodeVCardText(text);
    } on FormatException {
      return null;
    }
  }
}
