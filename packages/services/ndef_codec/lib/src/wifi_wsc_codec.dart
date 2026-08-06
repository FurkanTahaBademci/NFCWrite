import 'dart:convert';
import 'dart:typed_data';

/// Wi-Fi kimlik dogrulama tipi (WSC `Authentication Type`, 0x1003).
///
/// Degerler Wi-Fi Simple Configuration Technical Specification v2.0.x
/// Tablo 32'den alinmistir.
enum WifiAuthType {
  /// Sifresiz ac1k ag.
  open(0x0001, 'Açık (şifresiz)'),

  /// Eski WPA-PSK. Yeni cihazlarda kullanilmaz, okuma icin destekli.
  wpaPersonal(0x0002, 'WPA-PSK'),

  /// WEP paylasilan anahtar. Guvensiz; yalnizca eski cihazlar icin.
  shared(0x0004, 'Paylaşılan anahtar (WEP)'),

  /// WPA2-PSK — bugun en yaygin ev agi tipi.
  wpa2Personal(0x0020, 'WPA2-PSK'),

  /// WPA/WPA2 karma mod. Uyumluluk gerektiginde en guvenli secim.
  wpaWpa2Personal(0x0022, 'WPA/WPA2-PSK (karma)');

  const WifiAuthType(this.value, this.label);

  /// WSC TLV'sine yazilan 2 byte'lik deger.
  final int value;

  /// Arayuzde gosterilen ad.
  final String label;

  /// Bu tip parola gerektirir mi?
  bool get requiresPassword => this != WifiAuthType.open;

  /// Ham degerden cozumler; taninmayan deger icin null.
  static WifiAuthType? fromValue(int value) {
    for (final type in WifiAuthType.values) {
      if (type.value == value) return type;
    }
    // Kurumsal (0x0008 / 0x0010) tipleri bilerek desteklenmiyor: NDEF
    // etiketine yazilabilir bir kimlik bilgisi iceremezler.
    return null;
  }
}

/// Wi-Fi sifreleme tipi (WSC `Encryption Type`, 0x100F).
enum WifiEncryptionType {
  none(0x0001, 'Yok'),
  wep(0x0002, 'WEP'),
  tkip(0x0004, 'TKIP'),
  aes(0x0008, 'AES (CCMP)'),
  tkipAes(0x000C, 'TKIP + AES');

  const WifiEncryptionType(this.value, this.label);

  final int value;
  final String label;

  static WifiEncryptionType? fromValue(int value) {
    for (final type in WifiEncryptionType.values) {
      if (type.value == value) return type;
    }
    return null;
  }

  /// [auth] icin makul varsayilan sifreleme.
  static WifiEncryptionType defaultFor(WifiAuthType auth) => switch (auth) {
    WifiAuthType.open => WifiEncryptionType.none,
    WifiAuthType.shared => WifiEncryptionType.wep,
    WifiAuthType.wpaPersonal => WifiEncryptionType.tkip,
    WifiAuthType.wpa2Personal => WifiEncryptionType.aes,
    WifiAuthType.wpaWpa2Personal => WifiEncryptionType.tkipAes,
  };
}

/// `application/vnd.wfa.wsc` yukunun kodlayici-cozucusu.
///
/// Yuk, 2 byte tip + 2 byte uzunluk (big-endian) + deger seklinde TLV
/// dizisidir. Tum alanlar `Credential` (0x100E) zarfinin icine yazilir;
/// Android ve iOS bu zarfi bekler.
///
/// Bkz. `.claude/docs/03-nfc-reference.md` §1.4
abstract final class WifiWscCodec {
  /// NDEF MIME tipi.
  static const String mimeType = 'application/vnd.wfa.wsc';

  // --- TLV tipleri ---
  static const int _tlvCredential = 0x100E;
  static const int _tlvNetworkIndex = 0x1026;
  static const int _tlvSsid = 0x1045;
  static const int _tlvAuthType = 0x1003;
  static const int _tlvEncryptionType = 0x100F;
  static const int _tlvNetworkKey = 0x1027;
  static const int _tlvMacAddress = 0x1020;

  /// SSID en fazla 32 byte olabilir (IEEE 802.11).
  static const int maxSsidBytes = 32;

  /// WPA-PSK parolasi 8-63 karakter ya da 64 haneli hex olabilir.
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 64;

  /// Wi-Fi bilgilerini WSC yukune cevirir.
  ///
  /// [ssid] bos olamaz. [password] yalnizca [auth] parola gerektiriyorsa
  /// yazilir; acik aglarda bos anahtar TLV'si eklenir (bazi Android
  /// surumleri alanin tamamen eksik olmasini sevmiyor).
  static Uint8List encode({
    required String ssid,
    required String password,
    required WifiAuthType auth,
    WifiEncryptionType? encryption,
    bool hidden = false,
  }) {
    final ssidBytes = utf8.encode(ssid);
    if (ssidBytes.isEmpty) {
      throw ArgumentError.value(ssid, 'ssid', 'SSID bos olamaz');
    }
    if (ssidBytes.length > maxSsidBytes) {
      throw ArgumentError.value(
        ssid,
        'ssid',
        'SSID en fazla $maxSsidBytes byte olabilir',
      );
    }

    final keyBytes = auth.requiresPassword
        ? utf8.encode(password)
        : const <int>[];

    final credential = BytesBuilder()
      ..add(_tlv(_tlvNetworkIndex, const <int>[0x01]))
      ..add(_tlv(_tlvSsid, ssidBytes))
      ..add(_tlv(_tlvAuthType, _uint16(auth.value)))
      ..add(
        _tlv(
          _tlvEncryptionType,
          _uint16((encryption ?? WifiEncryptionType.defaultFor(auth)).value),
        ),
      )
      ..add(_tlv(_tlvNetworkKey, keyBytes))
      // MAC 00:00:00:00:00:00 = "herhangi bir erisim noktasi".
      ..add(_tlv(_tlvMacAddress, List<int>.filled(6, 0)));

    return Uint8List.fromList(
      _tlv(_tlvCredential, credential.takeBytes()),
    );
  }

  /// WSC yukunu cozumler. SSID bulunamazsa null doner.
  static WifiNetwork? decode(Uint8List payload) {
    String? ssid;
    String? password;
    int? authValue;
    int? encryptionValue;

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
          case _tlvCredential:
            scan(value);
          case _tlvSsid:
            ssid = _tryDecodeUtf8(value);
          case _tlvNetworkKey:
            password = _tryDecodeUtf8(value);
          case _tlvAuthType:
            if (value.length >= 2) authValue = (value[0] << 8) | value[1];
          case _tlvEncryptionType:
            if (value.length >= 2) {
              encryptionValue = (value[0] << 8) | value[1];
            }
        }

        offset = valueEnd;
      }
    }

    scan(payload);
    final resolvedSsid = ssid;
    if (resolvedSsid == null || resolvedSsid.isEmpty) return null;

    return WifiNetwork(
      ssid: resolvedSsid,
      password: password ?? '',
      auth: authValue == null
          ? WifiAuthType.wpa2Personal
          : (WifiAuthType.fromValue(authValue!) ?? WifiAuthType.wpa2Personal),
      encryption: encryptionValue == null
          ? null
          : WifiEncryptionType.fromValue(encryptionValue!),
    );
  }

  /// Parolanin [auth] icin gecerli olup olmadigini soyler.
  ///
  /// Gecerliyse null, degilse kullaniciya gosterilecek sebebi doner.
  static String? validatePassword(String password, WifiAuthType auth) {
    if (!auth.requiresPassword) return null;
    if (password.length < minPasswordLength) {
      return 'Parola en az $minPasswordLength karakter olmalı';
    }
    if (password.length > maxPasswordLength) {
      return 'Parola en fazla $maxPasswordLength karakter olabilir';
    }
    return null;
  }

  static List<int> _tlv(int type, List<int> value) => <int>[
    (type >> 8) & 0xFF,
    type & 0xFF,
    (value.length >> 8) & 0xFF,
    value.length & 0xFF,
    ...value,
  ];

  static List<int> _uint16(int value) => <int>[
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];

  static String? _tryDecodeUtf8(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return null;
    }
  }
}

/// Cozumlenmis bir Wi-Fi agi.
final class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.password,
    required this.auth,
    this.encryption,
  });

  final String ssid;
  final String password;
  final WifiAuthType auth;
  final WifiEncryptionType? encryption;

  @override
  bool operator ==(Object other) =>
      other is WifiNetwork &&
      other.ssid == ssid &&
      other.password == password &&
      other.auth == auth &&
      other.encryption == encryption;

  @override
  int get hashCode => Object.hash(ssid, password, auth, encryption);

  @override
  String toString() => 'WifiNetwork($ssid, ${auth.label})';
}
