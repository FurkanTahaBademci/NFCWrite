import 'package:meta/meta.dart';
import 'package:nfc_core/nfc_core.dart';

/// Bir NTAG/Ultralight yongasinin bellek yerlesimi.
///
/// Sayfa numaralari `.claude/docs/03-nfc-reference.md` §2.1 tablosundan
/// gelir. Yanlis sayfaya yazmak etiketi bozar; bu tablo tek dogruluk
/// kaynagidir.
@immutable
final class NtagLayout {
  const NtagLayout({
    required this.family,
    required this.displayName,
    required this.totalPages,
    required this.userPageStart,
    required this.userPageEnd,
    required this.capabilityContainer,
    this.configPage,
    this.dynamicLockPage,
    this.supportsPassword = false,
    this.supportsCounter = false,
    this.supportsSignature = false,
    this.supportsFastRead = false,
    this.supportsMirror = false,
  });

  final TagChipFamily family;
  final String displayName;
  final int totalPages;
  final int userPageStart;
  final int userPageEnd;

  /// Sayfa 3'e yazilacak Capability Container degeri.
  final List<int> capabilityContainer;

  /// CFG0 sayfasi. Desteklenmiyorsa null.
  ///
  /// CFG1 = [configPage] + 1, PWD = +2, PACK = +3.
  final int? configPage;

  /// Dinamik kilit byte'larinin bulundugu sayfa.
  final int? dynamicLockPage;

  final bool supportsPassword;
  final bool supportsCounter;
  final bool supportsSignature;
  final bool supportsFastRead;
  final bool supportsMirror;

  int? get configPage0 => configPage;
  int? get configPage1 => configPage == null ? null : configPage! + 1;
  int? get passwordPage => configPage == null ? null : configPage! + 2;
  int? get packPage => configPage == null ? null : configPage! + 3;

  /// Kullaniciya acik byte sayisi.
  int get userBytes => (userPageEnd - userPageStart + 1) * 4;

  /// Toplam byte sayisi.
  int get totalBytes => totalPages * 4;

  /// Verilen sayfa kullanici alaninda mi?
  bool isUserPage(int page) => page >= userPageStart && page <= userPageEnd;

  /// Bu yerlesimden bir [TagIdentity] uretir.
  TagIdentity toIdentity({
    required TagManufacturer manufacturer,
    List<int>? versionBytes,
  }) => TagIdentity(
    family: family,
    manufacturer: manufacturer,
    displayName: displayName,
    totalBytes: totalBytes,
    userBytes: userBytes,
    totalPages: totalPages,
    userPageStart: userPageStart,
    userPageEnd: userPageEnd,
    versionBytes: versionBytes,
    supportsPassword: supportsPassword,
    supportsCounter: supportsCounter,
    supportsSignature: supportsSignature,
    supportsFastRead: supportsFastRead,
    supportsMirror: supportsMirror,
  );
}

/// Bilinen yonga yerlesimleri.
abstract final class NtagLayouts {
  static const NtagLayout ntag213 = NtagLayout(
    family: TagChipFamily.ntag213,
    displayName: 'NTAG213',
    totalPages: 45,
    userPageStart: 0x04,
    userPageEnd: 0x27,
    capabilityContainer: [0xE1, 0x10, 0x12, 0x00],
    configPage: 0x29,
    dynamicLockPage: 0x28,
    supportsPassword: true,
    supportsCounter: true,
    supportsSignature: true,
    supportsFastRead: true,
    supportsMirror: true,
  );

  static const NtagLayout ntag215 = NtagLayout(
    family: TagChipFamily.ntag215,
    displayName: 'NTAG215',
    totalPages: 135,
    userPageStart: 0x04,
    userPageEnd: 0x81,
    capabilityContainer: [0xE1, 0x10, 0x3E, 0x00],
    configPage: 0x83,
    dynamicLockPage: 0x82,
    supportsPassword: true,
    supportsCounter: true,
    supportsSignature: true,
    supportsFastRead: true,
    supportsMirror: true,
  );

  static const NtagLayout ntag216 = NtagLayout(
    family: TagChipFamily.ntag216,
    displayName: 'NTAG216',
    totalPages: 231,
    userPageStart: 0x04,
    userPageEnd: 0xE1,
    capabilityContainer: [0xE1, 0x10, 0x6D, 0x00],
    configPage: 0xE3,
    dynamicLockPage: 0xE2,
    supportsPassword: true,
    supportsCounter: true,
    supportsSignature: true,
    supportsFastRead: true,
    supportsMirror: true,
  );

  static const NtagLayout ultralightEv1Mf0ul11 = NtagLayout(
    family: TagChipFamily.mifareUltralightEv1Mf0ul11,
    displayName: 'MIFARE Ultralight EV1 (48B)',
    totalPages: 20,
    userPageStart: 0x04,
    userPageEnd: 0x0F,
    capabilityContainer: [0xE1, 0x10, 0x06, 0x00],
    configPage: 0x10,
    dynamicLockPage: null,
    supportsPassword: true,
    supportsSignature: true,
    supportsFastRead: true,
  );

  static const NtagLayout ultralightEv1Mf0ul21 = NtagLayout(
    family: TagChipFamily.mifareUltralightEv1Mf0ul21,
    displayName: 'MIFARE Ultralight EV1 (128B)',
    totalPages: 41,
    userPageStart: 0x04,
    userPageEnd: 0x23,
    capabilityContainer: [0xE1, 0x10, 0x12, 0x00],
    configPage: 0x25,
    dynamicLockPage: 0x24,
    supportsPassword: true,
    supportsSignature: true,
    supportsFastRead: true,
  );

  /// `GET_VERSION` desteklemeyen klasik MIFARE Ultralight.
  static const NtagLayout ultralight = NtagLayout(
    family: TagChipFamily.mifareUltralight,
    displayName: 'MIFARE Ultralight',
    totalPages: 16,
    userPageStart: 0x04,
    userPageEnd: 0x0F,
    capabilityContainer: [0xE1, 0x10, 0x06, 0x00],
  );

  /// `GET_VERSION` cevabinin depolama byte'i (byte 6) ile arama.
  ///
  /// Bkz. `.claude/docs/03-nfc-reference.md` §2.7
  static NtagLayout? fromVersionBytes(List<int> version) {
    if (version.length < 8) return null;
    final productType = version[2];
    final storageSize = version[6];

    // 0x04 = NTAG ailesi
    if (productType == 0x04) {
      return switch (storageSize) {
        0x0F => ntag213,
        0x11 => ntag215,
        0x13 => ntag216,
        _ => null,
      };
    }

    // 0x03 = MIFARE Ultralight ailesi
    if (productType == 0x03) {
      return switch (storageSize) {
        0x0B => ultralightEv1Mf0ul11,
        0x0E => ultralightEv1Mf0ul21,
        _ => null,
      };
    }

    return null;
  }
}
