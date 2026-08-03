import 'package:meta/meta.dart';

/// Tanimlanmis yonga ailesi.
enum TagChipFamily {
  ntag213,
  ntag215,
  ntag216,
  ntag210,
  ntag212,
  mifareUltralight,
  mifareUltralightC,

  /// MIFARE Ultralight EV1, 48 byte kullanici alani (MF0UL11).
  mifareUltralightEv1Mf0ul11,

  /// MIFARE Ultralight EV1, 128 byte kullanici alani (MF0UL21).
  mifareUltralightEv1Mf0ul21,
  mifareClassic1k,
  mifareClassic4k,
  mifareClassicMini,
  mifareDesfire,
  icodeSlix,
  icodeSlix2,
  topaz,
  felica,
  unknown,
}

/// Yonga ureticisi (UID byte 0'dan cozulur).
enum TagManufacturer {
  nxp(0x04, 'NXP Semiconductors'),
  stMicroelectronics(0x02, 'STMicroelectronics'),
  infineon(0x05, 'Infineon Technologies'),
  texasInstruments(0x07, 'Texas Instruments'),
  emMicroelectronic(0x16, 'EM Microelectronic'),
  ibm(0x28, 'IBM'),
  fudan(0x2B, 'Shanghai Fudan Microelectronics'),
  unknown(-1, 'Bilinmiyor');

  const TagManufacturer(this.code, this.displayName);

  /// UID'nin ilk byte'i.
  final int code;

  /// Insan okunur ad. Bu ad ceviriye tabi degildir (marka adi).
  final String displayName;

  /// UID'nin ilk byte'indan uretici cozer.
  static TagManufacturer fromUidByte(int byte) {
    for (final m in TagManufacturer.values) {
      if (m.code == byte) return m;
    }
    return TagManufacturer.unknown;
  }
}

/// Etiket yongasinin kimligi ve yetenekleri.
///
/// `GET_VERSION` cevabi, ATQA/SAK ve UID'den turetilir.
@immutable
final class TagIdentity {
  const TagIdentity({
    required this.family,
    required this.manufacturer,
    this.displayName,
    this.totalBytes,
    this.userBytes,
    this.totalPages,
    this.userPageStart,
    this.userPageEnd,
    this.pageSize = 4,
    this.versionBytes,
    this.supportsPassword = false,
    this.supportsCounter = false,
    this.supportsSignature = false,
    this.supportsFastRead = false,
    this.supportsMirror = false,
  });

  /// Bilinmeyen etiket icin yer tutucu.
  const TagIdentity.unknown()
    : family = TagChipFamily.unknown,
      manufacturer = TagManufacturer.unknown,
      displayName = null,
      totalBytes = null,
      userBytes = null,
      totalPages = null,
      userPageStart = null,
      userPageEnd = null,
      pageSize = 4,
      versionBytes = null,
      supportsPassword = false,
      supportsCounter = false,
      supportsSignature = false,
      supportsFastRead = false,
      supportsMirror = false;

  final TagChipFamily family;
  final TagManufacturer manufacturer;

  /// Model adi, orn. "NTAG215". Bilinmiyorsa null.
  final String? displayName;

  /// Toplam bellek (byte), yapilandirma sayfalari dahil.
  final int? totalBytes;

  /// Kullaniciya acik bellek (byte).
  final int? userBytes;

  /// Toplam sayfa sayisi.
  final int? totalPages;

  /// Kullanici alaninin ilk sayfasi (dahil).
  final int? userPageStart;

  /// Kullanici alaninin son sayfasi (dahil).
  final int? userPageEnd;

  /// Sayfa boyutu (byte). Type 2 etiketlerde 4, MIFARE Classic'te 16.
  final int pageSize;

  /// Ham `GET_VERSION` cevabi (8 byte). Desteklenmiyorsa null.
  final List<int>? versionBytes;

  final bool supportsPassword;
  final bool supportsCounter;
  final bool supportsSignature;
  final bool supportsFastRead;
  final bool supportsMirror;

  /// NTAG ailesinden mi?
  bool get isNtag => switch (family) {
    TagChipFamily.ntag210 ||
    TagChipFamily.ntag212 ||
    TagChipFamily.ntag213 ||
    TagChipFamily.ntag215 ||
    TagChipFamily.ntag216 => true,
    _ => false,
  };

  /// MIFARE Classic ailesinden mi?
  bool get isMifareClassic => switch (family) {
    TagChipFamily.mifareClassic1k ||
    TagChipFamily.mifareClassic4k ||
    TagChipFamily.mifareClassicMini => true,
    _ => false,
  };

  TagIdentity copyWith({
    TagChipFamily? family,
    TagManufacturer? manufacturer,
    String? displayName,
    int? totalBytes,
    int? userBytes,
    int? totalPages,
    int? userPageStart,
    int? userPageEnd,
    int? pageSize,
    List<int>? versionBytes,
    bool? supportsPassword,
    bool? supportsCounter,
    bool? supportsSignature,
    bool? supportsFastRead,
    bool? supportsMirror,
  }) => TagIdentity(
    family: family ?? this.family,
    manufacturer: manufacturer ?? this.manufacturer,
    displayName: displayName ?? this.displayName,
    totalBytes: totalBytes ?? this.totalBytes,
    userBytes: userBytes ?? this.userBytes,
    totalPages: totalPages ?? this.totalPages,
    userPageStart: userPageStart ?? this.userPageStart,
    userPageEnd: userPageEnd ?? this.userPageEnd,
    pageSize: pageSize ?? this.pageSize,
    versionBytes: versionBytes ?? this.versionBytes,
    supportsPassword: supportsPassword ?? this.supportsPassword,
    supportsCounter: supportsCounter ?? this.supportsCounter,
    supportsSignature: supportsSignature ?? this.supportsSignature,
    supportsFastRead: supportsFastRead ?? this.supportsFastRead,
    supportsMirror: supportsMirror ?? this.supportsMirror,
  );

  @override
  bool operator ==(Object other) =>
      other is TagIdentity &&
      other.family == family &&
      other.manufacturer == manufacturer &&
      other.displayName == displayName &&
      other.totalBytes == totalBytes &&
      other.userBytes == userBytes;

  @override
  int get hashCode =>
      Object.hash(family, manufacturer, displayName, totalBytes, userBytes);

  @override
  String toString() => 'TagIdentity(${displayName ?? family.name})';
}
