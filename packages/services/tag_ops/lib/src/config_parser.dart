import 'dart:typed_data';

import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';

import 'ntag_layout.dart';

/// Yapilandirma ve kilit byte'larini cozumler / olusturur.
///
/// Bit anlamlari: `.claude/docs/03-nfc-reference.md` §2.3 ve §2.5
abstract final class ConfigParser {
  // --- CFG0 byte konumlari ---
  static const int _cfg0Mirror = 0;
  static const int _cfg0MirrorPage = 2;
  static const int _cfg0Auth0 = 3;

  // --- CFG1 byte konumlari ---
  static const int _cfg1Access = 0;

  /// CFG0 ve CFG1 sayfalarini [NtagConfig] nesnesine cevirir.
  static NtagConfig parseConfig({
    required Uint8List cfg0,
    required Uint8List cfg1,
  }) {
    if (cfg0.length < 4 || cfg1.length < 4) {
      throw ArgumentError('Yapilandirma sayfalari 4 byte olmali');
    }

    final mirror = cfg0[_cfg0Mirror];
    final access = cfg1[_cfg1Access];

    return NtagConfig(
      auth0: cfg0[_cfg0Auth0],
      protectionScope: access.bit(7)
          ? PasswordProtectionScope.readAndWrite
          : PasswordProtectionScope.writeOnly,
      configLocked: access.bit(6),
      authLimit: access.bitField(offset: 0, width: 3),
      counterEnabled: access.bit(4),
      counterPasswordProtected: access.bit(3),
      mirrorMode: MirrorMode.fromValue(mirror.bitField(offset: 6, width: 2)),
      mirrorPage: cfg0[_cfg0MirrorPage],
      mirrorByte: mirror.bitField(offset: 4, width: 2),
      strongModulation: mirror.bit(2),
    );
  }

  /// [NtagConfig] nesnesinden CFG0 sayfasini uretir.
  ///
  /// [previous] verilirse RFUI byte'lari korunur — bilinmeyen bitleri
  /// sifirlamak etiketi beklenmedik bicimde etkileyebilir.
  static Uint8List buildCfg0(NtagConfig config, {Uint8List? previous}) {
    final page = Uint8List(4);
    if (previous != null && previous.length >= 4) {
      page.setAll(0, previous);
    }

    var mirror = page[_cfg0Mirror];
    mirror = mirror
        .withBitField(offset: 6, width: 2, value: config.mirrorMode.value)
        .withBitField(offset: 4, width: 2, value: config.mirrorByte)
        .withBit(2, config.strongModulation);

    page[_cfg0Mirror] = mirror;
    page[_cfg0MirrorPage] = config.mirrorPage & 0xFF;
    page[_cfg0Auth0] = config.auth0 & 0xFF;
    return page;
  }

  /// [NtagConfig] nesnesinden CFG1 sayfasini uretir.
  static Uint8List buildCfg1(NtagConfig config, {Uint8List? previous}) {
    final page = Uint8List(4);
    if (previous != null && previous.length >= 4) {
      page.setAll(0, previous);
    }

    final access = page[_cfg1Access]
        .withBit(
          7,
          config.protectionScope == PasswordProtectionScope.readAndWrite,
        )
        .withBit(6, config.configLocked)
        .withBit(4, config.counterEnabled)
        .withBit(3, config.counterPasswordProtected)
        .withBitField(offset: 0, width: 3, value: config.authLimit);

    page[_cfg1Access] = access;
    return page;
  }

  /// Statik ve dinamik kilit byte'larini cozumler.
  ///
  /// [staticLock] sayfa 2'nin 2. ve 3. byte'lari (LOCK0, LOCK1).
  /// [dynamicLock] dinamik kilit sayfasi (varsa).
  /// [capabilityContainer] sayfa 3 — salt-okunur tespiti icin.
  static LockStatus parseLocks({
    required Uint8List staticLock,
    required NtagLayout layout,
    Uint8List? dynamicLock,
    Uint8List? capabilityContainer,
  }) {
    if (staticLock.length < 2) {
      throw ArgumentError('Statik kilit 2 byte olmali');
    }

    final locked = <int>{};
    final blockLocked = <int>{};

    final lock0 = staticLock[0];
    final lock1 = staticLock[1];

    // LOCK0 bit7..bit4 -> sayfa 7,6,5,4 ; bit3 -> sayfa 3 (CC)
    for (var bit = 4; bit <= 7; bit++) {
      if (lock0.bit(bit)) locked.add(bit);
    }
    final ccLocked = lock0.bit(3);
    if (ccLocked) locked.add(3);

    // LOCK0 bit2..bit0 -> blok kilitleri
    if (lock0.bit(0)) blockLocked.add(3);
    if (lock0.bit(1)) blockLocked.addAll([for (var p = 4; p <= 9; p++) p]);
    if (lock0.bit(2)) blockLocked.addAll([for (var p = 10; p <= 15; p++) p]);

    // LOCK1 bit7..bit0 -> sayfa 15..8
    for (var bit = 0; bit <= 7; bit++) {
      if (lock1.bit(bit)) locked.add(8 + bit);
    }

    // Dinamik kilitler: her bit bir sayfa blogunu kilitler. Blok boyutu
    // yongaya gore degisir (NTAG213'te 4 sayfa, 215/216'da 16 sayfa).
    //
    // UYARI: 215/216 eslemesi datasheet ile dogrulanmali.
    // Bkz. .claude/state/progress.md -> "Dogrulanacak teknik noktalar"
    if (dynamicLock != null && dynamicLock.isNotEmpty) {
      final pagesPerBit = switch (layout.family) {
        TagChipFamily.ntag213 => 4,
        TagChipFamily.ntag215 || TagChipFamily.ntag216 => 16,
        _ => 4,
      };
      const dynamicLockFirstPage = 16;
      // Son byte BD (block-locking) byte'idir, sayfa kilidi tasimaz.
      final usableBytes = dynamicLock.length >= 3 ? 2 : dynamicLock.length;

      for (var byteIndex = 0; byteIndex < usableBytes; byteIndex++) {
        for (var bit = 0; bit < 8; bit++) {
          if (!dynamicLock[byteIndex].bit(bit)) continue;
          final blockIndex = byteIndex * 8 + bit;
          final firstPage = dynamicLockFirstPage + blockIndex * pagesPerBit;
          for (var offset = 0; offset < pagesPerBit; offset++) {
            final page = firstPage + offset;
            if (page > layout.userPageEnd) break;
            locked.add(page);
          }
        }
      }
    }

    // CC erisim byte'inin alt nibble'i 0x0F ise etiket salt-okunurdur.
    var permanentlyReadOnly = false;
    if (capabilityContainer != null && capabilityContainer.length >= 4) {
      permanentlyReadOnly = (capabilityContainer[3] & 0x0F) == 0x0F;
    }

    return LockStatus(
      lockedPages: locked,
      blockLockedPages: blockLocked,
      capabilityContainerLocked: ccLocked,
      permanentlyReadOnly: permanentlyReadOnly,
    );
  }
}
