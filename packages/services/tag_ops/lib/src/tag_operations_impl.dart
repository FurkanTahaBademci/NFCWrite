import 'dart:typed_data';

import 'package:nfc_core/nfc_core.dart';
import 'package:shared_utils/shared_utils.dart';

import 'config_parser.dart';
import 'ntag_commands.dart';
import 'ntag_layout.dart';

/// [TagOperations] arayuzunun uygulamasi.
///
/// Transport'u disaridan alir; NFC donanimi gerektirmeden
/// `FakeTagHandle` ile test edilebilir.
///
/// Sahibi: **T4** (bkz. `.claude/tracks/T4-tools.md`)
///
/// Su an okuma tarafi ve bazi yikici araclar uygulanmistir.
/// Kalan islemler `NotImplementedYet` doner ve ilgili gorev kodunu tasir.
final class TagOperationsImpl implements TagOperations {
  const TagOperationsImpl();

  static const AppLogger _log = AppLogger('tag_ops');

  /// GET_VERSION icin denenecek kanallar, sirasiyla.
  static const List<TransceiveChannel> _commandChannels = [
    TransceiveChannel.mifareUltralight,
    TransceiveChannel.nfcA,
  ];

  // =====================================================================
  // Okuma
  // =====================================================================

  @override
  Future<Result<TagIdentity>> identify(NfcTagHandle tag) async {
    final manufacturer = tag.uid.isEmpty
        ? TagManufacturer.unknown
        : TagManufacturer.fromUidByte(tag.uid.first);

    final versionResult = await _transceiveAnyChannel(
      tag,
      NtagCommands.getVersion(),
    );

    if (versionResult case Ok(:final value) when value.length >= 8) {
      final layout = NtagLayouts.fromVersionBytes(value);
      if (layout != null) {
        return Ok(
          layout.toIdentity(manufacturer: manufacturer, versionBytes: value),
        );
      }
      _log.debug('Tanimlanamayan GET_VERSION: ${bytesToHex(value)}');
    }

    // GET_VERSION yok ya da tanimlanamadi — ATQA/SAK ve teknoloji
    // listesinden tahmin et.
    return Ok(_identifyFromTechnologies(tag, manufacturer));
  }

  TagIdentity _identifyFromTechnologies(
    NfcTagHandle tag,
    TagManufacturer manufacturer,
  ) {
    final classic = tag.mifareClassicInfo;
    if (classic != null) {
      final family = switch (classic.sizeInBytes) {
        1024 => TagChipFamily.mifareClassic1k,
        4096 => TagChipFamily.mifareClassic4k,
        320 => TagChipFamily.mifareClassicMini,
        _ => TagChipFamily.mifareClassic1k,
      };
      return TagIdentity(
        family: family,
        manufacturer: manufacturer,
        displayName: switch (family) {
          TagChipFamily.mifareClassic4k => 'MIFARE Classic 4K',
          TagChipFamily.mifareClassicMini => 'MIFARE Classic Mini',
          _ => 'MIFARE Classic 1K',
        },
        totalBytes: classic.sizeInBytes,
        userBytes: classic.sizeInBytes,
        totalPages: classic.blockCount,
        pageSize: 16,
      );
    }

    if (tag.technologies.contains(TagTechnology.nfcV)) {
      return TagIdentity(
        family: TagChipFamily.icodeSlix,
        manufacturer: manufacturer,
        displayName: 'ISO 15693 etiketi',
      );
    }

    if (tag.technologies.contains(TagTechnology.mifareUltralight)) {
      return NtagLayouts.ultralight.toIdentity(manufacturer: manufacturer);
    }

    return TagIdentity(
      family: TagChipFamily.unknown,
      manufacturer: manufacturer,
    );
  }

  @override
  Future<Result<NfcTagInfo>> inspect(
    NfcTagHandle tag, {
    bool deep = false,
  }) async {
    final identityResult = await identify(tag);
    if (identityResult case Err(:final failure)) return Err(failure);
    final identity = (identityResult as Ok<TagIdentity>).value;

    final ndefResult = await tag.readNdef();
    // NDEF okunamamasi olumcul degil — etiket bicimlendirilmemis olabilir.
    final ndefMessage = ndefResult.valueOrNull;
    final capabilities = tag.ndefCapabilities;

    TagMemory? memory;
    NtagConfig? config;
    LockStatus? lockStatus;
    int? counter;
    Uint8List? signature;

    if (deep) {
      memory = (await readMemory(tag)).valueOrNull;
      config = (await readConfig(tag)).valueOrNull;
      lockStatus = (await readLockStatus(tag)).valueOrNull;
      if (identity.supportsCounter) {
        counter = (await readCounter(tag)).valueOrNull;
      }
      if (identity.supportsSignature) {
        signature = (await readSignature(tag)).valueOrNull;
      }
    }

    return Ok(
      NfcTagInfo(
        uid: tag.uid,
        technologies: tag.technologies,
        identity: identity,
        atqa: tag.atqa,
        sak: tag.sak,
        ndefMessage: ndefMessage,
        isNdefFormatted: tag.hasNdef,
        isWritable: capabilities?.isWritable ?? false,
        canMakeReadOnly: capabilities?.canMakeReadOnly ?? false,
        maxNdefSize: capabilities?.maxSize,
        currentNdefSize: ndefMessage?.byteLength,
        memory: memory,
        config: config,
        lockStatus: lockStatus,
        counterValue: counter,
        signature: signature,
      ),
    );
  }

  @override
  Future<Result<TagMemory>> readMemory(
    NfcTagHandle tag, {
    Uint8List? password,
  }) async {
    if (password != null) {
      final auth = await authenticate(tag, password);
      if (auth case Err(:final failure)) return Err(failure);
    }

    final identityResult = await identify(tag);
    if (identityResult case Err(:final failure)) return Err(failure);
    final identity = (identityResult as Ok<TagIdentity>).value;

    final totalPages = identity.totalPages;
    if (totalPages == null || totalPages <= 0) {
      return const Err(
        TagNotSupported(detail: 'Bu etiketin bellek yerlesimi bilinmiyor'),
      );
    }

    if (identity.isMifareClassic) {
      return const Err(NotImplementedYet('T4.33'));
    }

    final channel = _pickCommandChannel(tag);
    if (channel == null) {
      return const Err(
        TagNotSupported(detail: 'Ham komut kanali bu etikette yok'),
      );
    }

    final buffer = Uint8List(totalPages * 4);
    final unreadable = <int>{};

    if (identity.supportsFastRead) {
      final maxLengthResult = await tag.maxTransceiveLength(channel);
      // Cevap boyutu sinira sigmali; ayrica bir miktar pay birakiyoruz.
      final maxResponse = (maxLengthResult.valueOrNull ?? 64) - 4;
      final pagesPerChunk = (maxResponse ~/ 4).clamp(1, 60);

      var page = 0;
      while (page < totalPages) {
        final end = (page + pagesPerChunk - 1).clamp(0, totalPages - 1);
        final result = await tag.transceive(
          NtagCommands.fastRead(page, end),
          channel: channel,
        );
        switch (result) {
          case Ok(:final value):
            final length = (end - page + 1) * 4;
            buffer.setRange(
              page * 4,
              page * 4 + (value.length < length ? value.length : length),
              value,
            );
          case Err(failure: TagLost()):
            return const Err(TagLost());
          case Err():
            // Bu aralik korumali ya da okunamiyor — isaretle, devam et.
            for (var p = page; p <= end; p++) {
              unreadable.add(p);
            }
        }
        page = end + 1;
      }
    } else {
      // FAST_READ yok: 4'er sayfa oku.
      for (var page = 0; page < totalPages; page += 4) {
        final result = await tag.readUltralightPages(page);
        switch (result) {
          case Ok(:final value):
            final remaining = (totalPages - page) * 4;
            final length = value.length < remaining ? value.length : remaining;
            buffer.setRange(page * 4, page * 4 + length, value);
          case Err(failure: TagLost()):
            return const Err(TagLost());
          case Err():
            for (var p = page; p < page + 4 && p < totalPages; p++) {
              unreadable.add(p);
            }
        }
      }
    }

    return Ok(TagMemory(bytes: buffer, unreadablePages: unreadable));
  }

  @override
  Future<Result<NtagConfig>> readConfig(NfcTagHandle tag) async {
    final layoutResult = await _resolveLayout(tag);
    if (layoutResult case Err(:final failure)) return Err(failure);
    final layout = (layoutResult as Ok<NtagLayout>).value;

    final configPage = layout.configPage;
    if (configPage == null) {
      return const Err(
        TagNotSupported(detail: 'Bu yongada yapilandirma sayfasi yok'),
      );
    }

    final channel = _pickCommandChannel(tag);
    if (channel == null) {
      return const Err(TagNotSupported(detail: 'Ham komut kanali yok'));
    }

    // Tek READ 4 sayfa dondurur: CFG0, CFG1, PWD, PACK.
    final result = await tag.transceive(
      NtagCommands.read(configPage),
      channel: channel,
    );

    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(:final value) when value.length < 8 => const Err(
        MalformedData('Yapilandirma sayfalari eksik dondu'),
      ),
      Ok(:final value) => Ok(
        ConfigParser.parseConfig(
          cfg0: Uint8List.sublistView(value, 0, 4),
          cfg1: Uint8List.sublistView(value, 4, 8),
        ),
      ),
    };
  }

  @override
  Future<Result<LockStatus>> readLockStatus(NfcTagHandle tag) async {
    final layoutResult = await _resolveLayout(tag);
    if (layoutResult case Err(:final failure)) return Err(failure);
    final layout = (layoutResult as Ok<NtagLayout>).value;

    final channel = _pickCommandChannel(tag);
    if (channel == null) {
      return const Err(TagNotSupported(detail: 'Ham komut kanali yok'));
    }

    // Sayfa 0'dan itibaren 4 sayfa: UID, UID, (BCC1/INT/LOCK0/LOCK1), CC.
    final headerResult = await tag.transceive(
      NtagCommands.read(0),
      channel: channel,
    );
    if (headerResult case Err(:final failure)) return Err(failure);
    final header = (headerResult as Ok<Uint8List>).value;
    if (header.length < 16) {
      return const Err(MalformedData('Basliktaki sayfalar eksik dondu'));
    }

    Uint8List? dynamicLock;
    final dynamicLockPage = layout.dynamicLockPage;
    if (dynamicLockPage != null) {
      final result = await tag.transceive(
        NtagCommands.read(dynamicLockPage),
        channel: channel,
      );
      if (result case Ok(:final value) when value.length >= 4) {
        dynamicLock = Uint8List.sublistView(value, 0, 4);
      }
    }

    return Ok(
      ConfigParser.parseLocks(
        staticLock: Uint8List.sublistView(header, 10, 12),
        layout: layout,
        dynamicLock: dynamicLock,
        capabilityContainer: Uint8List.sublistView(header, 12, 16),
      ),
    );
  }

  @override
  Future<Result<int>> readCounter(NfcTagHandle tag) async {
    final channel = _pickCommandChannel(tag);
    if (channel == null) {
      return const Err(TagNotSupported(detail: 'Ham komut kanali yok'));
    }
    final result = await tag.transceive(
      NtagCommands.readCounter(),
      channel: channel,
    );
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(:final value) when value.length < 3 => const Err(
        MalformedData('Sayac cevabi 3 byte olmali'),
      ),
      // Sayac little-endian 3 byte'tir.
      Ok(:final value) => Ok(bytesToIntLittleEndian(value.sublist(0, 3))),
    };
  }

  @override
  Future<Result<Uint8List>> readSignature(NfcTagHandle tag) async {
    final channel = _pickCommandChannel(tag);
    if (channel == null) {
      return const Err(TagNotSupported(detail: 'Ham komut kanali yok'));
    }
    final result = await tag.transceive(
      NtagCommands.readSignature(),
      channel: channel,
    );
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(:final value) when value.length < 32 => const Err(
        MalformedData('Imza 32 byte olmali'),
      ),
      Ok(:final value) => Ok(Uint8List.sublistView(value, 0, 32)),
    };
  }

  @override
  Future<Result<bool>> verifySignature(NfcTagHandle tag) async =>
      // ECC secp128r1 dogrulamasi + NXP acik anahtar tablosu gerekiyor.
      const Err(NotImplementedYet('T4.12'));

  @override
  Future<Result<Uint8List>> authenticate(
    NfcTagHandle tag,
    Uint8List password,
  ) async {
    if (password.length != 4) {
      return const Err(InvalidArgument('Sifre 4 byte olmali'));
    }
    final channel = _pickCommandChannel(tag);
    if (channel == null) {
      return const Err(TagNotSupported(detail: 'Ham komut kanali yok'));
    }

    final result = await tag.transceive(
      NtagCommands.passwordAuth(password),
      channel: channel,
    );

    return switch (result) {
      Ok(:final value) when value.length >= 2 => Ok(
        Uint8List.sublistView(value, 0, 2),
      ),
      Ok() => const Err(MalformedData('PACK cevabi eksik')),
      // Etiket yanlis sifreye NAK ile cevap verir; bu transport
      // katmaninda genel bir hata olarak gorunur.
      Err(failure: TagLost()) => const Err(TagLost()),
      Err() => const Err(AuthenticationFailed()),
    };
  }

  // =====================================================================
  // Yazma — NDEF
  // =====================================================================

  @override
  Future<Result<void>> writeNdef(
    NfcTagHandle tag,
    NdefMessageEntity message, {
    bool verify = true,
  }) async {
    final writeResult = await tag.writeNdef(message);
    if (writeResult case Err(:final failure)) return Err(failure);
    if (!verify) return okVoid;

    final readBack = await tag.readNdef();
    return switch (readBack) {
      Err(:final failure) => Err(failure),
      Ok(:final value) when value == message => okVoid,
      Ok() => const Err(VerificationFailed()),
    };
  }

  @override
  Future<Result<void>> eraseNdef(
    NfcTagHandle tag, {
    required DangerAck ack,
  }) async {
    final guard = _guard(tag, ack);
    if (guard != null) return Err(guard);
    return writeNdef(tag, NdefMessageEntity.empty(), verify: false);
  }

  // =====================================================================
  // Henuz uygulanmadi — T4 gorev listesine bakin
  // =====================================================================

  @override
  Future<Result<void>> factoryReset(
    NfcTagHandle tag, {
    required DangerAck ack,
  }) async {
    final guard = _guard(tag, ack);
    if (guard != null) return Err(guard);

    final layoutResult = await _resolveLayout(tag);
    if (layoutResult case Err(:final failure)) return Err(failure);
    final layout = (layoutResult as Ok<NtagLayout>).value;

    if (layout.family == TagChipFamily.unknown || layout.totalPages <= 0) {
      return const Err(
        TagNotSupported(detail: 'Bu etiketin fabrika sıfırlaması desteklenmiyor'),
      );
    }

    for (var page = layout.userPageStart; page <= layout.userPageEnd; page++) {
      final failure = await _writePage(tag, page, Uint8List(4));
      if (failure != null) return Err(failure);
    }

    if (tag.hasNdef) {
      final emptyResult = await tag.writeNdef(NdefMessageEntity.empty());
      if (emptyResult case Err(:final failure)) return Err(failure);
    }

    return okVoid;
  }

  @override
  Future<Result<CopyReport>> copyNdefTo(
    NfcTagHandle target, {
    required NdefMessageEntity message,
    required String sourceUidHex,
    required DangerAck ack,
  }) async {
    final guard = _guard(target, ack);
    if (guard != null) return Err(guard);

    if (!target.hasNdef) {
      return const Err(TagNotSupported(detail: 'Hedef etiket NDEF degil'));
    }

    final capabilities = target.ndefCapabilities;
    if (capabilities == null) {
      return const Err(TagNotSupported(detail: 'Hedef etiket NDEF degil'));
    }

    if (message.byteLengthOnTag > capabilities.maxSize) {
      return Err(
        InsufficientSpace(
          needed: message.byteLengthOnTag,
          available: capabilities.maxSize,
        ),
      );
    }

    final writeResult = await target.writeNdef(message);
    if (writeResult case Err(:final failure)) return Err(failure);

    final verifyResult = await target.readNdef();
    if (verifyResult case Err(:final failure)) return Err(failure);
    final readBack = (verifyResult as Ok<NdefMessageEntity?>).value;
    if (readBack != message) {
      return const Err(VerificationFailed());
    }

    return Ok(
      CopyReport(
        sourceUidHex: sourceUidHex,
        targetUidHex: bytesToHex(target.uid),
        bytesWritten: message.byteLengthOnTag,
        recordCount: message.records.length,
        truncated: false,
      ),
    );
  }

  @override
  Future<Result<void>> restoreDump(
    NfcTagHandle tag,
    TagDump dump, {
    required DangerAck ack,
  }) async {
    final guard = _guard(tag, ack);
    if (guard != null) return Err(guard);

    if (dump.pageSize != 4) {
      return const Err(
        TagNotSupported(detail: 'Bu döküm sayfa boyutu ile geri yüklenemiyor'),
      );
    }

    final identityResult = await identify(tag);
    if (identityResult case Err(:final failure)) return Err(failure);
    final identity = (identityResult as Ok<TagIdentity>).value;
    if (identity.userPageStart == null || identity.userPageEnd == null) {
      return const Err(
        TagNotSupported(detail: 'Bu etiketin kullanıcı alanı bilinmiyor'),
      );
    }

    if (identity.isMifareClassic) {
      return const Err(NotImplementedYet('T4.17'));
    }

    final firstPage = dump.startPage;
    final lastPage = dump.startPage + dump.pageCount - 1;
    if (firstPage < identity.userPageStart! || lastPage > identity.userPageEnd!) {
      return const Err(TagNotSupported(detail: 'Döküm bu etiketin kullanıcı alanına sığmıyor'));
    }

    for (var index = 0; index < dump.pageCount; index++) {
      final page = dump.startPage + index;
      final start = index * dump.pageSize;
      final end = start + dump.pageSize > dump.bytes.length ? dump.bytes.length : start + dump.pageSize;
      final data = Uint8List(4);
      if (start < dump.bytes.length) {
        data.setRange(0, end - start, dump.bytes.sublist(start, end));
      }
      final failure = await _writePage(tag, page, data);
      if (failure != null) return Err(failure);
    }

    return okVoid;
  }

  @override
  Future<Result<void>> formatNdef(
    NfcTagHandle tag, {
    required DangerAck ack,
  }) async {
    final guard = _guard(tag, ack);
    if (guard != null) return Err(guard);

    if (tag.hasNdef) {
      return writeNdef(tag, NdefMessageEntity.empty(), verify: false);
    }

    return tag.formatNdef(NdefMessageEntity.empty());
  }

  @override
  Future<Result<void>> setPassword(
    NfcTagHandle tag, {
    required PasswordSetup setup,
    required DangerAck ack,
  }) async {
    final guard = _guard(tag, ack);
    if (guard != null) return Err(guard);

    final layoutResult = await _resolveLayout(tag);
    if (layoutResult case Err(:final failure)) return Err(failure);
    final layout = (layoutResult as Ok<NtagLayout>).value;

    final configPage = layout.configPage;
    final passwordPage = layout.passwordPage;
    final packPage = layout.packPage;
    if (!layout.supportsPassword ||
        configPage == null ||
        passwordPage == null ||
        packPage == null) {
      return const Err(
        TagNotSupported(detail: 'Bu yongada sifre korumasi desteklenmiyor'),
      );
    }

    if (setup.protectFromPage < 0 || setup.protectFromPage > 0xFF) {
      return const Err(InvalidArgument('AUTH0 (protectFromPage) 0-255 olmali'));
    }

    final configPagesResult = await tag.readUltralightPages(configPage);
    if (configPagesResult case Err(:final failure)) return Err(failure);
    final configPages = (configPagesResult as Ok<Uint8List>).value;
    if (configPages.length < 16) {
      return const Err(MalformedData('Yapilandirma sayfalari eksik dondu'));
    }

    final cfg0 = Uint8List.fromList(configPages.sublist(0, 4));
    final cfg1 = Uint8List.fromList(configPages.sublist(4, 8));
    final oldPackPage = Uint8List.fromList(configPages.sublist(12, 16));

    var access = cfg1[0] & 0x70;
    access |= setup.authLimit & 0x07;
    if (setup.protectCounter) access |= 0x08;
    if (setup.scope == PasswordProtectionScope.readAndWrite) {
      access |= 0x80;
    }
    cfg1[0] = access;

    cfg0[3] = setup.protectFromPage & 0xFF;

    final newPackPage = Uint8List.fromList([
      setup.pack[0],
      setup.pack[1],
      oldPackPage[2],
      oldPackPage[3],
    ]);

    // Kritik sira: PWD -> PACK -> CFG1(ACCESS) -> CFG0(AUTH0)
    final writePwdFailure = await _writePage(tag, passwordPage, setup.password);
    if (writePwdFailure != null) return Err(writePwdFailure);

    final writePackFailure = await _writePage(tag, packPage, newPackPage);
    if (writePackFailure != null) return Err(writePackFailure);

    final writeCfg1Failure = await _writePage(tag, configPage + 1, cfg1);
    if (writeCfg1Failure != null) return Err(writeCfg1Failure);

    final writeCfg0Failure = await _writePage(tag, configPage, cfg0);
    if (writeCfg0Failure != null) return Err(writeCfg0Failure);

    return okVoid;
  }

  @override
  Future<Result<void>> removePassword(
    NfcTagHandle tag, {
    required Uint8List currentPassword,
    required DangerAck ack,
  }) async {
    final guard = _guard(tag, ack);
    if (guard != null) return Err(guard);

    final authResult = await authenticate(tag, currentPassword);
    if (authResult case Err(:final failure)) return Err(failure);

    final layoutResult = await _resolveLayout(tag);
    if (layoutResult case Err(:final failure)) return Err(failure);
    final layout = (layoutResult as Ok<NtagLayout>).value;

    final configPage = layout.configPage;
    final passwordPage = layout.passwordPage;
    final packPage = layout.packPage;
    if (!layout.supportsPassword ||
        configPage == null ||
        passwordPage == null ||
        packPage == null) {
      return const Err(
        TagNotSupported(detail: 'Bu yongada sifre korumasi desteklenmiyor'),
      );
    }

    final configPagesResult = await tag.readUltralightPages(configPage);
    if (configPagesResult case Err(:final failure)) return Err(failure);
    final configPages = (configPagesResult as Ok<Uint8List>).value;
    if (configPages.length < 16) {
      return const Err(MalformedData('Yapilandirma sayfalari eksik dondu'));
    }

    final cfg0 = Uint8List.fromList(configPages.sublist(0, 4));
    final cfg1 = Uint8List.fromList(configPages.sublist(4, 8));
    final oldPackPage = Uint8List.fromList(configPages.sublist(12, 16));

    // Korumayi kaldir: AUTH0=0xFF ve ACCESS koruma bitlerini temizle.
    cfg0[3] = 0xFF;
    cfg1[0] = cfg1[0] & 0x70;

    final zeroPwdPage = Uint8List(4);
    final zeroPackPage = Uint8List.fromList([
      0x00,
      0x00,
      oldPackPage[2],
      oldPackPage[3],
    ]);

    // Kaldirma sirasi: AUTH0 kapat -> PWD/PACK temizle -> ACCESS temizle
    final writeCfg0Failure = await _writePage(tag, configPage, cfg0);
    if (writeCfg0Failure != null) return Err(writeCfg0Failure);

    final writePwdFailure = await _writePage(tag, passwordPage, zeroPwdPage);
    if (writePwdFailure != null) return Err(writePwdFailure);

    final writePackFailure = await _writePage(tag, packPage, zeroPackPage);
    if (writePackFailure != null) return Err(writePackFailure);

    final writeCfg1Failure = await _writePage(tag, configPage + 1, cfg1);
    if (writeCfg1Failure != null) return Err(writeCfg1Failure);

    return okVoid;
  }

  @override
  Future<Result<void>> changePassword(
    NfcTagHandle tag, {
    required Uint8List currentPassword,
    required PasswordSetup newSetup,
    required DangerAck ack,
  }) async => const Err(NotImplementedYet('T4.23'));

  @override
  Future<Result<void>> configureMirror(
    NfcTagHandle tag, {
    required MirrorSetup setup,
    required DangerAck ack,
  }) async {
    final guard = _guard(tag, ack);
    if (guard != null) return Err(guard);

    final configResult = await _readConfigState(tag);
    if (configResult case Err(:final failure)) return Err(failure);
    final state = (configResult as Ok<({NtagLayout layout, NtagConfig config, Uint8List cfg0, Uint8List cfg1})>).value;

    if (!state.layout.supportsMirror) {
      return const Err(
        TagNotSupported(detail: 'Bu etiket yansitma desteği sunmuyor'),
      );
    }

    final mirrorPage = setup.mode == MirrorMode.none ? 0 : setup.page;
    final mirrorByte = setup.mode == MirrorMode.none ? 0 : setup.byteOffset;
    if (setup.mode != MirrorMode.none) {
      if (mirrorPage < state.layout.userPageStart ||
          mirrorPage > state.layout.userPageEnd) {
        return const Err(
          InvalidArgument('Mirror sayfasi kullanici alaninda olmali'),
        );
      }
      if (mirrorByte < 0 || mirrorByte > 3) {
        return const Err(InvalidArgument('Mirror byte 0-3 olmali'));
      }
    }

    final updated = state.config.copyWith(
      mirrorMode: setup.mode,
      mirrorPage: mirrorPage,
      mirrorByte: mirrorByte,
      strongModulation: state.config.strongModulation,
    );
    return _writeConfigState(tag, state.layout, state.cfg0, state.cfg1, updated);
  }

  @override
  Future<Result<void>> configureCounter(
    NfcTagHandle tag, {
    required bool enabled,
    required bool passwordProtected,
    required DangerAck ack,
  }) async {
    final guard = _guard(tag, ack);
    if (guard != null) return Err(guard);

    final configResult = await _readConfigState(tag);
    if (configResult case Err(:final failure)) return Err(failure);
    final state = (configResult as Ok<({NtagLayout layout, NtagConfig config, Uint8List cfg0, Uint8List cfg1})>).value;

    if (!state.layout.supportsCounter) {
      return const Err(
        TagNotSupported(detail: 'Bu etiket sayaç desteği sunmuyor'),
      );
    }

    final updated = state.config.copyWith(
      counterEnabled: enabled,
      counterPasswordProtected: passwordProtected,
    );
    return _writeConfigState(tag, state.layout, state.cfg0, state.cfg1, updated);
  }

  @override
  Future<Result<void>> makeReadOnly(
    NfcTagHandle tag, {
    required DangerAck ack,
  }) async {
    final guard = _guard(tag, ack);
    if (guard != null) return Err(guard);
    return tag.makeNdefReadOnly();
  }

  @override
  Future<Result<void>> lockPages(
    NfcTagHandle tag, {
    required Set<int> pages,
    required DangerAck ack,
  }) async => const Err(NotImplementedYet('T4.28'));

  @override
  Future<Result<void>> lockConfiguration(
    NfcTagHandle tag, {
    required DangerAck ack,
  }) async => const Err(NotImplementedYet('T4.30'));

  @override
  Future<Result<Uint8List>> sendRawCommand(
    NfcTagHandle tag, {
    required Uint8List command,
    required TransceiveChannel channel,
  }) => tag.transceive(command, channel: channel);

  @override
  Future<Result<MifareKeyScanReport>> scanMifareClassicKeys(
    NfcTagHandle tag, {
    List<Uint8List>? keyDictionary,
  }) async => const Err(NotImplementedYet('T4.32'));

  @override
  Future<Result<Uint8List>> readIso15693Block(
    NfcTagHandle tag, {
    required int blockNumber,
  }) async {
    if (!tag.supportsChannel(TransceiveChannel.nfcV)) {
      return const Err(TagNotSupported(detail: 'ISO 15693 etiketi degil'));
    }
    final result = await tag.transceive(
      Iso15693Commands.readSingleBlock(blockNumber, uid: tag.uid),
      channel: TransceiveChannel.nfcV,
    );
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(:final value) when value.isEmpty => const Err(
        MalformedData('Bos cevap'),
      ),
      // Ilk byte yanit bayragidir; bit0 set ise hata.
      Ok(:final value) when value[0].bit(0) => Err(
        MalformedData(
          'ISO 15693 hata kodu: '
          '0x${value.length > 1 ? value[1].toHexByte() : '??'}',
        ),
      ),
      Ok(:final value) => Ok(Uint8List.sublistView(value, 1)),
    };
  }

  @override
  Future<Result<void>> writeIso15693Block(
    NfcTagHandle tag, {
    required int blockNumber,
    required Uint8List data,
    required DangerAck ack,
  }) async => const Err(NotImplementedYet('T4.34'));

  Future<Result<({NtagLayout layout, NtagConfig config, Uint8List cfg0, Uint8List cfg1})>>
  _readConfigState(NfcTagHandle tag) async {
    final layoutResult = await _resolveLayout(tag);
    if (layoutResult case Err(:final failure)) {
      return Err(failure);
    }
    final layout = (layoutResult as Ok<NtagLayout>).value;

    final configPage = layout.configPage;
    if (configPage == null) {
      return const Err(TagNotSupported(detail: 'Bu yongada yapilandirma sayfasi yok'));
    }

    final raw = await tag.readUltralightPages(configPage);
    if (raw case Err(:final failure)) return Err(failure);
    final bytes = (raw as Ok<Uint8List>).value;
    if (bytes.length < 16) {
      return const Err(MalformedData('Yapilandirma sayfalari eksik dondu'));
    }

    final cfg0 = Uint8List.sublistView(bytes, 0, 4);
    final cfg1 = Uint8List.sublistView(bytes, 4, 8);
    return Ok((
      layout: layout,
      config: ConfigParser.parseConfig(cfg0: cfg0, cfg1: cfg1),
      cfg0: Uint8List.fromList(cfg0),
      cfg1: Uint8List.fromList(cfg1),
    ));
  }

  Future<Result<void>> _writeConfigState(
    NfcTagHandle tag,
    NtagLayout layout,
    Uint8List previousCfg0,
    Uint8List previousCfg1,
    NtagConfig config,
  ) async {
    final configPage = layout.configPage;
    if (configPage == null) {
      return const Err(
        TagNotSupported(detail: 'Bu yongada yapilandirma sayfasi yok'));
    }

    final cfg0 = ConfigParser.buildCfg0(config, previous: previousCfg0);
    final cfg1 = ConfigParser.buildCfg1(config, previous: previousCfg1);

    final cfg1Failure = await _writePage(tag, configPage + 1, cfg1);
    if (cfg1Failure != null) return Err(cfg1Failure);

    final cfg0Failure = await _writePage(tag, configPage, cfg0);
    if (cfg0Failure != null) return Err(cfg0Failure);

    return okVoid;
  }

  Future<NfcFailure?> _writePage(
    NfcTagHandle tag,
    int page,
    Uint8List data,
  ) async {
    final result = await tag.writeUltralightPage(page, data);
    return switch (result) {
      Ok() => null,
      Err(:final failure) => failure,
    };
  }

  // =====================================================================
  // Yardimcilar
  // =====================================================================

  /// Onayin bu etiket icin ve hala taze oldugunu dogrular.
  ///
  /// Kullanici bir etiket icin onay verip baska bir etiketi yaklastirmis
  /// olabilir — bu kontrol o durumu yakalar.
  NfcFailure? _guard(NfcTagHandle tag, DangerAck ack) {
    final uidHex = bytesToHex(tag.uid);
    if (!ack.isFor(uidHex)) {
      return const InvalidArgument('Onay baska bir etiket icin verilmis');
    }
    if (!ack.isFresh()) {
      return const OperationCancelled();
    }
    return null;
  }

  /// Ham komut icin uygun kanali secer.
  TransceiveChannel? _pickCommandChannel(NfcTagHandle tag) {
    for (final channel in _commandChannels) {
      if (tag.supportsChannel(channel)) return channel;
    }
    return null;
  }

  /// Komutu desteklenen ilk kanaldan gonderir.
  Future<Result<Uint8List>> _transceiveAnyChannel(
    NfcTagHandle tag,
    Uint8List command,
  ) async {
    for (final channel in _commandChannels) {
      if (!tag.supportsChannel(channel)) continue;
      final result = await tag.transceive(command, channel: channel);
      if (result.isOk) return result;
    }
    return const Err(TagNotSupported(detail: 'Komut kanali bulunamadi'));
  }

  /// Etiketin bellek yerlesimini cozer.
  Future<Result<NtagLayout>> _resolveLayout(NfcTagHandle tag) async {
    final versionResult = await _transceiveAnyChannel(
      tag,
      NtagCommands.getVersion(),
    );
    if (versionResult case Ok(:final value) when value.length >= 8) {
      final layout = NtagLayouts.fromVersionBytes(value);
      if (layout != null) return Ok(layout);
    }
    if (tag.technologies.contains(TagTechnology.mifareUltralight)) {
      return const Ok(NtagLayouts.ultralight);
    }
    return const Err(
      TagNotSupported(detail: 'Etiketin bellek yerlesimi tanimlanamadi'),
    );
  }
}
