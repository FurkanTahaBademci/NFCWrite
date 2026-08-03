import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// UID/sayac yansitma (mirror) kipi — CFG0 MIRROR alani bit 7-6.
enum MirrorMode {
  /// Yansitma kapali.
  none(0x00),

  /// UID ASCII olarak yansitilir.
  uid(0x01),

  /// NFC sayaci yansitilir.
  counter(0x02),

  /// UID + sayac birlikte yansitilir.
  uidAndCounter(0x03);

  const MirrorMode(this.value);

  final int value;

  static MirrorMode fromValue(int value) => switch (value & 0x03) {
    0x01 => MirrorMode.uid,
    0x02 => MirrorMode.counter,
    0x03 => MirrorMode.uidAndCounter,
    _ => MirrorMode.none,
  };
}

/// Sifre korumasinin kapsami — CFG1 ACCESS biti 7 (PROT).
enum PasswordProtectionScope {
  /// Yalnizca yazma korumali; okuma serbest.
  writeOnly,

  /// Okuma ve yazma korumali.
  readAndWrite,
}

/// NTAG21x / Ultralight EV1 yapilandirma sayfalarinin cozumlenmis hali.
///
/// Bit anlamlari icin `.claude/docs/03-nfc-reference.md` §2.5
@immutable
final class NtagConfig {
  const NtagConfig({
    required this.auth0,
    required this.protectionScope,
    required this.configLocked,
    required this.authLimit,
    required this.counterEnabled,
    required this.counterPasswordProtected,
    required this.mirrorMode,
    required this.mirrorPage,
    required this.mirrorByte,
    required this.strongModulation,
  });

  /// Koruma kapali varsayilan yapilandirma.
  const NtagConfig.unprotected()
    : auth0 = 0xFF,
      protectionScope = PasswordProtectionScope.writeOnly,
      configLocked = false,
      authLimit = 0,
      counterEnabled = false,
      counterPasswordProtected = false,
      mirrorMode = MirrorMode.none,
      mirrorPage = 0,
      mirrorByte = 0,
      strongModulation = false;

  /// Sifre korumasinin BASLADIGI sayfa. `0xFF` = koruma kapali.
  final int auth0;

  /// Korumanin kapsami (PROT biti).
  final PasswordProtectionScope protectionScope;

  /// CFGLCK — yapilandirma kalici olarak dondurulmus mu?
  ///
  /// `true` ise bu etiketin yapilandirmasi **bir daha asla** degistirilemez.
  final bool configLocked;

  /// AUTHLIM — yanlis sifre deneme limiti. 0 = sinirsiz.
  ///
  /// 0'dan buyukse ve limit asilirsa etiket kalici olarak erisilemez olur.
  final int authLimit;

  /// NFC sayaci etkin mi?
  final bool counterEnabled;

  /// Sayac okumak icin sifre gerekiyor mu?
  final bool counterPasswordProtected;

  final MirrorMode mirrorMode;

  /// Yansitmanin yazilacagi sayfa. 0 = kapali.
  final int mirrorPage;

  /// Yansitmanin sayfa icindeki baslangic byte'i (0-3).
  final int mirrorByte;

  /// Guclu modulasyon etkin mi (STRG_MOD_EN)?
  final bool strongModulation;

  /// Sifre korumasi etkin mi?
  bool get isPasswordProtected => auth0 != 0xFF;

  /// Okuma da korunuyor mu?
  bool get isReadProtected =>
      isPasswordProtected &&
      protectionScope == PasswordProtectionScope.readAndWrite;

  NtagConfig copyWith({
    int? auth0,
    PasswordProtectionScope? protectionScope,
    bool? configLocked,
    int? authLimit,
    bool? counterEnabled,
    bool? counterPasswordProtected,
    MirrorMode? mirrorMode,
    int? mirrorPage,
    int? mirrorByte,
    bool? strongModulation,
  }) => NtagConfig(
    auth0: auth0 ?? this.auth0,
    protectionScope: protectionScope ?? this.protectionScope,
    configLocked: configLocked ?? this.configLocked,
    authLimit: authLimit ?? this.authLimit,
    counterEnabled: counterEnabled ?? this.counterEnabled,
    counterPasswordProtected:
        counterPasswordProtected ?? this.counterPasswordProtected,
    mirrorMode: mirrorMode ?? this.mirrorMode,
    mirrorPage: mirrorPage ?? this.mirrorPage,
    mirrorByte: mirrorByte ?? this.mirrorByte,
    strongModulation: strongModulation ?? this.strongModulation,
  );

  @override
  bool operator ==(Object other) =>
      other is NtagConfig &&
      other.auth0 == auth0 &&
      other.protectionScope == protectionScope &&
      other.configLocked == configLocked &&
      other.authLimit == authLimit &&
      other.counterEnabled == counterEnabled &&
      other.counterPasswordProtected == counterPasswordProtected &&
      other.mirrorMode == mirrorMode &&
      other.mirrorPage == mirrorPage &&
      other.mirrorByte == mirrorByte &&
      other.strongModulation == strongModulation;

  @override
  int get hashCode => Object.hash(
    auth0,
    protectionScope,
    configLocked,
    authLimit,
    counterEnabled,
    counterPasswordProtected,
    mirrorMode,
    mirrorPage,
    mirrorByte,
    strongModulation,
  );

  @override
  String toString() =>
      'NtagConfig(auth0: 0x${auth0.toRadixString(16)}, '
      'scope: ${protectionScope.name}, cfgLck: $configLocked, '
      'authLim: $authLimit)';
}

/// Etiketin kilit durumu — statik ve dinamik kilit byte'larindan cozulur.
@immutable
final class LockStatus {
  const LockStatus({
    required this.lockedPages,
    required this.blockLockedPages,
    required this.capabilityContainerLocked,
    required this.permanentlyReadOnly,
  });

  /// Hicbir sey kilitli degil.
  const LockStatus.unlocked()
    : lockedPages = const <int>{},
      blockLockedPages = const <int>{},
      capabilityContainerLocked = false,
      permanentlyReadOnly = false;

  /// Yazmaya kapali sayfalar.
  final Set<int> lockedPages;

  /// Kilit bitleri de dondurulmus sayfalar (block-lock).
  ///
  /// Bu sayfalarin kilit durumu **bir daha degistirilemez**.
  final Set<int> blockLockedPages;

  /// Capability Container (sayfa 3) kilitli mi?
  final bool capabilityContainerLocked;

  /// Etiketin tamami kalici olarak salt-okunur mu?
  final bool permanentlyReadOnly;

  bool isPageLocked(int page) => lockedPages.contains(page);

  @override
  bool operator ==(Object other) =>
      other is LockStatus &&
      const SetEquality<int>().equals(other.lockedPages, lockedPages) &&
      const SetEquality<int>().equals(
        other.blockLockedPages,
        blockLockedPages,
      ) &&
      other.capabilityContainerLocked == capabilityContainerLocked &&
      other.permanentlyReadOnly == permanentlyReadOnly;

  @override
  int get hashCode => Object.hash(
    const SetEquality<int>().hash(lockedPages),
    const SetEquality<int>().hash(blockLockedPages),
    capabilityContainerLocked,
    permanentlyReadOnly,
  );

  @override
  String toString() =>
      'LockStatus(${lockedPages.length} kilitli sayfa, '
      'salt-okunur: $permanentlyReadOnly)';
}
