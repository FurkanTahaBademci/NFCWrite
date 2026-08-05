import 'dart:typed_data';

import 'package:nfc_core/nfc_core.dart';
import 'package:nfc_core/testing.dart';
import 'package:shared_utils/shared_utils.dart';
import 'package:tag_ops/src/ecc/ecdsa.dart';
import 'package:tag_ops/src/ecc/secp128r1.dart';
import 'package:tag_ops/src/iso15693_system_info.dart';
import 'package:tag_ops/src/mifare_classic_layout.dart';
import 'package:tag_ops/tag_ops.dart';
import 'package:test/test.dart';

/// NTAG213'un gercek `GET_VERSION` cevabi.
final _ntag213Version = hexToBytes('0004040201000F03');

/// NTAG215'in gercek `GET_VERSION` cevabi.
final _ntag215Version = hexToBytes('000404020100 1103'.replaceAll(' ', ''));

FakeTagHandle _ntagTag(String versionHex) => FakeTagHandle(
  uid: hexToBytes('04A1B2C3D4E580'),
  rules: [
    FakeTransceiveRule(commandHex: '60', response: hexToBytes(versionHex)),
  ],
);

FakeTagHandle _ntag213WithPages({
  Map<int, Uint8List> pages = const {},
  NdefMessageEntity? ndefMessage,
}) => FakeTagHandle(
  uid: hexToBytes('04A1B2C3D4E580'),
  rules: [
    FakeTransceiveRule(
      commandHex: '60',
      response: hexToBytes('0004040201000F03'),
    ),
  ],
  ndefMessage: ndefMessage,
  pages: {
    0x29: hexToBytes('000000FF'),
    0x2A: hexToBytes('00000000'),
    0x2B: hexToBytes('00000000'),
    0x2C: hexToBytes('00000000'),
    ...pages,
  },
);

void main() {
  const operations = TagOperationsImpl();

  group('Komut olusturucular', () {
    test('GET_VERSION', () {
      expect(bytesToHex(NtagCommands.getVersion()), '60');
    });

    test('READ', () {
      expect(bytesToHex(NtagCommands.read(0x04)), '3004');
    });

    test('FAST_READ', () {
      expect(bytesToHex(NtagCommands.fastRead(0x04, 0x27)), '3A0427');
    });

    test('FAST_READ ters aralik reddedilir', () {
      expect(() => NtagCommands.fastRead(0x10, 0x04), throwsArgumentError);
    });

    test('WRITE', () {
      expect(
        bytesToHex(NtagCommands.write(0x29, hexToBytes('000000FF'))),
        'A229000000FF',
      );
    });

    test('WRITE yanlis uzunlukta veriyi reddeder', () {
      expect(
        () => NtagCommands.write(0x04, hexToBytes('0102')),
        throwsArgumentError,
      );
    });

    test('PWD_AUTH', () {
      expect(
        bytesToHex(NtagCommands.passwordAuth(hexToBytes('FFFFFFFF'))),
        '1BFFFFFFFF',
      );
    });

    test('READ_CNT ve READ_SIG', () {
      expect(bytesToHex(NtagCommands.readCounter()), '3902');
      expect(bytesToHex(NtagCommands.readSignature()), '3C00');
    });
  });

  group('Yonga tanimlama', () {
    test('NTAG213 tanimlanir', () async {
      final result = await operations.identify(_ntagTag('0004040201000F03'));

      expect(result, isA<Ok<TagIdentity>>());
      final identity = (result as Ok<TagIdentity>).value;
      expect(identity.family, TagChipFamily.ntag213);
      expect(identity.displayName, 'NTAG213');
      expect(identity.userBytes, 144);
      expect(identity.supportsPassword, isTrue);
    });

    test('NTAG215 tanimlanir', () async {
      final result = await operations.identify(_ntagTag('0004040201001103'));
      final identity = (result as Ok<TagIdentity>).value;

      expect(identity.family, TagChipFamily.ntag215);
      expect(identity.userBytes, 504);
    });

    test('NTAG216 tanimlanir', () async {
      final result = await operations.identify(_ntagTag('0004040201001303'));
      final identity = (result as Ok<TagIdentity>).value;

      expect(identity.family, TagChipFamily.ntag216);
      expect(identity.userBytes, 888);
    });

    test('uretici UID`nin ilk byte`indan cozulur', () async {
      final result = await operations.identify(_ntagTag('0004040201000F03'));
      final identity = (result as Ok<TagIdentity>).value;

      expect(identity.manufacturer, TagManufacturer.nxp);
    });

    test('GET_VERSION desteklenmezse teknolojiden tahmin edilir', () async {
      // Kural tanimlanmadi -> transceive hata dondurur.
      final tag = FakeTagHandle(uid: hexToBytes('04A1B2C3'));
      final result = await operations.identify(tag);

      expect(result, isA<Ok<TagIdentity>>());
      expect(
        (result as Ok<TagIdentity>).value.family,
        TagChipFamily.mifareUltralight,
      );
    });

    test('GET_VERSION komutu gercekten gonderilir', () async {
      final tag = _ntagTag('0004040201000F03');
      await operations.identify(tag);

      expect(tag.sentCommands.map(bytesToHex), contains('60'));
    });
  });

  group('Yerlesim tablosu', () {
    test('NTAG213 yapilandirma sayfalari', () {
      const layout = NtagLayouts.ntag213;
      expect(layout.configPage0, 0x29);
      expect(layout.configPage1, 0x2A);
      expect(layout.passwordPage, 0x2B);
      expect(layout.packPage, 0x2C);
      expect(layout.dynamicLockPage, 0x28);
    });

    test('NTAG216 yapilandirma sayfalari', () {
      const layout = NtagLayouts.ntag216;
      expect(layout.configPage0, 0xE3);
      expect(layout.packPage, 0xE6);
    });

    test('kullanici alani sinirlari', () {
      expect(NtagLayouts.ntag213.isUserPage(0x04), isTrue);
      expect(NtagLayouts.ntag213.isUserPage(0x27), isTrue);
      expect(NtagLayouts.ntag213.isUserPage(0x28), isFalse);
      expect(NtagLayouts.ntag213.isUserPage(0x03), isFalse);
    });
  });

  group('Yapilandirma cozumlemesi', () {
    test('korumasiz varsayilan', () {
      final config = ConfigParser.parseConfig(
        cfg0: hexToBytes('000000FF'),
        cfg1: hexToBytes('00000000'),
      );

      expect(config.auth0, 0xFF);
      expect(config.isPasswordProtected, isFalse);
      expect(config.configLocked, isFalse);
      expect(config.authLimit, 0);
    });

    test('sifre korumali, okuma+yazma, AUTHLIM 5', () {
      final config = ConfigParser.parseConfig(
        // AUTH0 = 0x04
        cfg0: hexToBytes('00000004'),
        // ACCESS = 0b1000_0101 -> PROT=1, AUTHLIM=5
        cfg1: hexToBytes('85000000'),
      );

      expect(config.isPasswordProtected, isTrue);
      expect(config.protectionScope, PasswordProtectionScope.readAndWrite);
      expect(config.authLimit, 5);
      expect(config.isReadProtected, isTrue);
    });

    test('CFGLCK okunur', () {
      final config = ConfigParser.parseConfig(
        cfg0: hexToBytes('000000FF'),
        cfg1: hexToBytes('40000000'),
      );
      expect(config.configLocked, isTrue);
    });

    test('cozumleme ve olusturma cift yonlu', () {
      const original = NtagConfig(
        auth0: 0x10,
        protectionScope: PasswordProtectionScope.readAndWrite,
        configLocked: false,
        authLimit: 3,
        counterEnabled: true,
        counterPasswordProtected: false,
        mirrorMode: MirrorMode.uid,
        mirrorPage: 0x06,
        mirrorByte: 2,
        strongModulation: false,
      );

      final roundTrip = ConfigParser.parseConfig(
        cfg0: ConfigParser.buildCfg0(original),
        cfg1: ConfigParser.buildCfg1(original),
      );

      expect(roundTrip, original);
    });
  });

  group('Kilit cozumlemesi', () {
    test('kilitsiz etiket', () {
      final status = ConfigParser.parseLocks(
        staticLock: hexToBytes('0000'),
        layout: NtagLayouts.ntag213,
        capabilityContainer: hexToBytes('E1101200'),
      );

      expect(status.lockedPages, isEmpty);
      expect(status.permanentlyReadOnly, isFalse);
    });

    test('CC kilidi ve sayfa kilitleri okunur', () {
      // LOCK0 = 0b0001_1000 -> bit4 (sayfa 4) + bit3 (CC/sayfa 3)
      final status = ConfigParser.parseLocks(
        staticLock: hexToBytes('1800'),
        layout: NtagLayouts.ntag213,
        capabilityContainer: hexToBytes('E1101200'),
      );

      expect(status.capabilityContainerLocked, isTrue);
      expect(status.lockedPages, containsAll([3, 4]));
    });

    test('CC erisim byte`i 0x0F ise salt-okunur', () {
      final status = ConfigParser.parseLocks(
        staticLock: hexToBytes('0000'),
        layout: NtagLayouts.ntag213,
        capabilityContainer: hexToBytes('E110120F'),
      );

      expect(status.permanentlyReadOnly, isTrue);
    });
  });

  group('Guvenlik kapisi', () {
    test('baska etiket icin verilen onay reddedilir', () async {
      final tag = _ntagTag('0004040201000F03');
      final wrongAck = DangerAck.forTest(targetUidHex: 'DEADBEEF');

      final result = await operations.eraseNdef(tag, ack: wrongAck);

      expect(result, isA<Err<void>>());
      expect((result as Err<void>).failure, isA<InvalidArgument>());
    });

    test('dogru etiket icin onay kabul edilir', () async {
      final tag = _ntagTag('0004040201000F03');
      final ack = DangerAck.forTest(targetUidHex: bytesToHex(tag.uid));

      final result = await operations.eraseNdef(tag, ack: ack);

      expect(result, isA<Ok<void>>());
      expect(tag.lastWrittenNdef?.isEmpty, isTrue);
    });

    test('guvenli islem icin DangerAck uretilemez', () {
      expect(
        () => DangerAck.userConfirmed(
          risk: OperationRisk.safe,
          operationId: 'x',
          targetUidHex: '04',
          backupTaken: false,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Sayac okuma', () {
    test('3 byte little-endian cozulur', () async {
      final tag = FakeTagHandle(
        uid: hexToBytes('04A1B2C3D4E580'),
        rules: [
          FakeTransceiveRule(
            commandHex: '3902',
            // 0x000201 little-endian -> 0x010200 = 66048
            response: hexToBytes('000201'),
          ),
        ],
      );

      final result = await operations.readCounter(tag);
      expect(result, isA<Ok<int>>());
      expect((result as Ok<int>).value, 0x010200);
    });
  });

  group('Sifre ve bicimlendirme', () {
    test('copyNdefTo hedefe NDEF yazar ve raporlar', () async {
      final target = FakeTagHandle(uid: hexToBytes('04B1B2C3D4E581'));
      final ack = DangerAck.forTest(targetUidHex: bytesToHex(target.uid));
      final message = NdefMessageEntity([
        NdefRecordEntity(
          typeNameFormat: NdefTypeNameFormat.wellKnown,
          type: Uint8List.fromList('T'.codeUnits),
          identifier: Uint8List(0),
          payload: Uint8List.fromList([0x02, ...'enhello'.codeUnits]),
        ),
      ]);

      final result = await operations.copyNdefTo(
        target,
        message: message,
        sourceUidHex: '04A1B2C3D4E580',
        ack: ack,
      );

      expect(result, isA<Ok<CopyReport>>());
      final report = (result as Ok<CopyReport>).value;
      expect(report.sourceUidHex, '04A1B2C3D4E580');
      expect(report.targetUidHex, bytesToHex(target.uid));
      expect(report.recordCount, 1);
      expect(target.lastWrittenNdef, message);
    });

    test('factoryReset kullanıcı sayfalarını sıfırlar', () async {
      final tag = _ntag213WithPages(
        ndefMessage: NdefMessageEntity([
          NdefRecordEntity(
            typeNameFormat: NdefTypeNameFormat.wellKnown,
            type: Uint8List.fromList('T'.codeUnits),
            identifier: Uint8List(0),
            payload: Uint8List.fromList([0x02, 0x65, 0x6E, 0x68, 0x69]),
          ),
        ]),
      );

      final ack = DangerAck.forTest(targetUidHex: bytesToHex(tag.uid));
      final result = await operations.factoryReset(tag, ack: ack);

      expect(result, isA<Ok<void>>());
      expect(tag.writtenPages.length, 36);
      expect(tag.writtenPages.first.page, 0x04);
      expect(tag.writtenPages.last.page, 0x27);
      expect(
        tag.writtenPages.every((entry) => entry.data.every((b) => b == 0)),
        isTrue,
      );
      expect(tag.lastWrittenNdef?.isEmpty, isTrue);
    });

    test('restoreDump sayfaları dump ile geri yazar', () async {
      final tag = _ntag213WithPages();
      final dump = TagDump(
        id: null,
        uidHex: '04A1B2C3D4E580',
        createdAt: DateTime(2026, 8, 3),
        bytes: hexToBytes('0102030405060708'),
        pageSize: 4,
        startPage: 0x04,
        reason: DumpReason.imported,
      );

      final ack = DangerAck.forTest(targetUidHex: bytesToHex(tag.uid));
      final result = await operations.restoreDump(tag, dump, ack: ack);

      expect(result, isA<Ok<void>>());
      expect(tag.writtenPages.map((entry) => entry.page), [0x04, 0x05]);
      expect(bytesToHex(tag.writtenPages[0].data), '01020304');
      expect(bytesToHex(tag.writtenPages[1].data), '05060708');
    });

    test('configureMirror CFG0 ve CFG1 yazilir', () async {
      final tag = _ntag213WithPages();
      final ack = DangerAck.forTest(targetUidHex: bytesToHex(tag.uid));

      final result = await operations.configureMirror(
        tag,
        setup: const MirrorSetup(
          mode: MirrorMode.uidAndCounter,
          page: 0x06,
          byteOffset: 1,
        ),
        ack: ack,
      );

      expect(result, isA<Ok<void>>());
      expect(tag.writtenPages.map((entry) => entry.page), [0x2A, 0x29]);
      expect(bytesToHex(tag.writtenPages[1].data), 'D00006FF');
    });

    test('configureCounter CFG0 ve CFG1 yazilir', () async {
      final tag = _ntag213WithPages();
      final ack = DangerAck.forTest(targetUidHex: bytesToHex(tag.uid));

      final result = await operations.configureCounter(
        tag,
        enabled: true,
        passwordProtected: true,
        ack: ack,
      );

      expect(result, isA<Ok<void>>());
      expect(tag.writtenPages.map((entry) => entry.page), [0x2A, 0x29]);
      expect(bytesToHex(tag.writtenPages[0].data), '18000000');
      expect(bytesToHex(tag.writtenPages[1].data), '000000FF');
    });

    test('setPassword sirasiyla PWD, PACK, CFG1, CFG0 yazar', () async {
      final tag = FakeTagHandle(
        uid: hexToBytes('04A1B2C3D4E580'),
        rules: [
          FakeTransceiveRule(
            commandHex: '60',
            response: hexToBytes('0004040201000F03'),
          ),
        ],
      );

      final ack = DangerAck.forTest(targetUidHex: bytesToHex(tag.uid));
      final result = await operations.setPassword(
        tag,
        setup: PasswordSetup(
          password: hexToBytes('01020304'),
          pack: hexToBytes('A1B2'),
          protectFromPage: 0x04,
          scope: PasswordProtectionScope.readAndWrite,
          authLimit: 5,
          protectCounter: true,
        ),
        ack: ack,
      );

      expect(result, isA<Ok<void>>());
      expect(
        tag.writtenPages.map((entry) => entry.page).toList(growable: false),
        [0x2B, 0x2C, 0x2A, 0x29],
      );

      final cfg1Write = tag.writtenPages[2].data;
      final cfg0Write = tag.writtenPages[3].data;
      expect(cfg1Write[0], 0x8D); // PROT=1, NFC_CNT_PWD_PROT=1, AUTHLIM=5
      expect(cfg0Write[3], 0x04); // AUTH0
    });

    test('removePassword once dogrular sonra korumayi kapatir', () async {
      final tag = FakeTagHandle(
        uid: hexToBytes('04A1B2C3D4E580'),
        rules: [
          FakeTransceiveRule(
            commandHex: '1B01020304',
            response: hexToBytes('A1B2'),
          ),
          FakeTransceiveRule(
            commandHex: '60',
            response: hexToBytes('0004040201000F03'),
          ),
        ],
      );

      final ack = DangerAck.forTest(targetUidHex: bytesToHex(tag.uid));
      final result = await operations.removePassword(
        tag,
        currentPassword: hexToBytes('01020304'),
        ack: ack,
      );

      expect(result, isA<Ok<void>>());
      expect(tag.sentCommands.map(bytesToHex), contains('1B01020304'));
      expect(
        tag.writtenPages.map((entry) => entry.page).toList(growable: false),
        [0x29, 0x2B, 0x2C, 0x2A],
      );

      final cfg0Write = tag.writtenPages[0].data;
      final pwdWrite = tag.writtenPages[1].data;
      final packWrite = tag.writtenPages[2].data;
      final cfg1Write = tag.writtenPages[3].data;
      expect(cfg0Write[3], 0xFF);
      expect(bytesToHex(pwdWrite), '00000000');
      expect(packWrite[0], 0x00);
      expect(packWrite[1], 0x00);
      expect(cfg1Write[0], 0x00);
    });

    test('formatNdef NDEF olmayan etikette bicimlendirme cagirir', () async {
      final tag = FakeTagHandle(
        uid: hexToBytes('04A1B2C3D4E580'),
        technologies: const [
          TagTechnology.nfcA,
          TagTechnology.mifareUltralight,
        ],
        ndefCapabilities: null,
      );

      final ack = DangerAck.forTest(targetUidHex: bytesToHex(tag.uid));
      final result = await operations.formatNdef(tag, ack: ack);

      expect(result, isA<Ok<void>>());
      expect(tag.lastWrittenNdef?.isEmpty, isTrue);
    });
  });

  // Kullanilmayan sabitleri analiz uyarisi vermesin diye referansla.
  test('ornek surum dizileri gecerli', () {
    expect(_ntag213Version.length, 8);
    expect(_ntag215Version.length, 8);
  });

  group('ISO 15693 tanimlama (ICODE SLIX/SLIX2)', () {
    FakeTagHandle isoTag({int? icReference}) {
      final uid = hexToBytes('E004010203040506');
      final command = Iso15693Commands.getSystemInformation(uid: uid);
      final rules = <FakeTransceiveRule>[];
      if (icReference != null) {
        final response = Uint8List.fromList([
          0x00, 0x0F, // yanit bayragi, bilgi bayraklari (hepsi mevcut)
          ...uid,
          0x00, 0x00, // DSFID, AFI
          0x1A, 0x03, // bellek boyutu: 27 blok, blok basina 4 byte
          icReference,
        ]);
        rules.add(
          FakeTransceiveRule(commandHex: bytesToHex(command), response: response),
        );
      }
      return FakeTagHandle(
        uid: uid,
        technologies: const [TagTechnology.nfcV],
        supportedChannels: const {TransceiveChannel.nfcV},
        ndefCapabilities: null,
        rules: rules,
      );
    }

    test('ICODE SLIX IC referansindan tanimlanir', () async {
      final result = await operations.identify(
        isoTag(icReference: IcodeIcReference.slix),
      );
      final identity = (result as Ok<TagIdentity>).value;

      expect(identity.family, TagChipFamily.icodeSlix);
      expect(identity.displayName, 'ICODE SLIX');
      expect(identity.totalBytes, 108);
      expect(identity.totalPages, 27);
      expect(identity.pageSize, 4);
    });

    test('ICODE SLIX2 IC referansindan tanimlanir', () async {
      final result = await operations.identify(
        isoTag(icReference: IcodeIcReference.slix2),
      );
      final identity = (result as Ok<TagIdentity>).value;

      expect(identity.family, TagChipFamily.icodeSlix2);
      expect(identity.displayName, 'ICODE SLIX2');
    });

    test('sistem bilgisi okunamazsa jenerik kimlik doner', () async {
      final result = await operations.identify(isoTag());
      final identity = (result as Ok<TagIdentity>).value;

      expect(identity.family, TagChipFamily.icodeSlix);
      expect(identity.displayName, 'ISO 15693 etiketi');
      expect(identity.totalBytes, isNull);
    });
  });

  group('MIFARE Classic bellek dokumu', () {
    FakeTagHandle classicTag({
      Set<Uint8List>? validSectorKeys,
      Map<int, Uint8List> pages = const {},
    }) => FakeTagHandle(
      uid: hexToBytes('04A1B2C3D4E580'),
      technologies: const [TagTechnology.nfcA, TagTechnology.mifareClassic],
      ndefCapabilities: null,
      mifareClassicInfo: const MifareClassicInfo(
        sectorCount: 16,
        blockCount: 64,
        sizeInBytes: 1024,
      ),
      validSectorKeys: validSectorKeys,
      pages: pages,
    );

    test('varsayilan anahtarla tum bloklar okunur', () async {
      final tag = classicTag(
        validSectorKeys: {hexToBytes('FFFFFFFFFFFF')},
        pages: {0: hexToBytes('00112233445566778899AABBCCDDEEFF')},
      );

      final result = await operations.readMemory(tag);

      expect(result, isA<Ok<TagMemory>>());
      final memory = (result as Ok<TagMemory>).value;
      expect(memory.pageSize, 16);
      expect(memory.pageCount, 64);
      expect(memory.unreadablePages, isEmpty);
      expect(bytesToHex(memory.page(0)!), '00112233445566778899AABBCCDDEEFF');
    });

    test('anahtar bulunamayan sektorun bloklari okunamaz isaretlenir', () async {
      final tag = classicTag();

      final result = await operations.readMemory(tag);

      final memory = (result as Ok<TagMemory>).value;
      expect(memory.unreadablePages.length, 64);
    });
  });

  group('MIFARE Classic anahtar taramasi', () {
    test('sozlukteki anahtar tum sektorlerde bulunur', () async {
      final tag = FakeTagHandle(
        uid: hexToBytes('04A1B2C3D4E580'),
        ndefCapabilities: null,
        mifareClassicInfo: const MifareClassicInfo(
          sectorCount: 16,
          blockCount: 64,
          sizeInBytes: 1024,
        ),
        validSectorKeys: {hexToBytes('D3F7D3F7D3F7')},
      );

      final result = await operations.scanMifareClassicKeys(tag);

      expect(result, isA<Ok<MifareKeyScanReport>>());
      final report = (result as Ok<MifareKeyScanReport>).value;
      expect(report.allUnlocked, isTrue);
      expect(report.sectorKeys[0]!.type, MifareKeyType.keyA);
      expect(bytesToHex(report.sectorKeys[0]!.key), 'D3F7D3F7D3F7');
    });

    test('sozluk disi anahtarli sektor kilitli kalir', () async {
      final tag = FakeTagHandle(
        uid: hexToBytes('04A1B2C3D4E580'),
        ndefCapabilities: null,
        mifareClassicInfo: const MifareClassicInfo(
          sectorCount: 16,
          blockCount: 64,
          sizeInBytes: 1024,
        ),
      );

      final result = await operations.scanMifareClassicKeys(tag);

      final report = (result as Ok<MifareKeyScanReport>).value;
      expect(report.unlockedCount, 0);
      expect(report.totalSectors, 16);
    });
  });

  group('MifareClassicLayout', () {
    test('1K: her sektor 4 blok', () {
      expect(
        MifareClassicLayout.blocksInSector(0, sectorCount: 16),
        4,
      );
      expect(
        MifareClassicLayout.trailerBlockOfSector(15, sectorCount: 16),
        63,
      );
      expect(MifareClassicLayout.sectorOfBlock(7, sectorCount: 16), 1);
    });

    test('4K: son sektorler 16 blok', () {
      expect(
        MifareClassicLayout.firstBlockOfSector(32, sectorCount: 40),
        128,
      );
      expect(
        MifareClassicLayout.blocksInSector(32, sectorCount: 40),
        16,
      );
      expect(
        MifareClassicLayout.trailerBlockOfSector(39, sectorCount: 40),
        255,
      );
      expect(MifareClassicLayout.sectorOfBlock(200, sectorCount: 40), 36);
    });

    test('blok 0 BCC = UID byte XOR', () {
      // 04 ^ A1 ^ B2 ^ C3 = D4
      expect(
        MifareClassicLayout.blockZeroBcc(hexToBytes('04A1B2C3')),
        0xD4,
      );
    });

    test('dogru BCC gecerli, yanlis BCC gecersiz', () {
      expect(
        MifareClassicLayout.isBlockZeroBccValid(
          hexToBytes('04A1B2C3D40804000011223344556677'),
        ),
        isTrue,
      );
      expect(
        MifareClassicLayout.isBlockZeroBccValid(
          hexToBytes('04A1B2C3000804000011223344556677'),
        ),
        isFalse,
      );
    });

    test('withBlockZeroBcc 5. byte i duzeltir, kaynagi bozmaz', () {
      final source = hexToBytes('04A1B2C3000804000011223344556677');
      final fixed = MifareClassicLayout.withBlockZeroBcc(source);
      expect(fixed[4], 0xD4);
      expect(MifareClassicLayout.isBlockZeroBccValid(fixed), isTrue);
      // Kaynak degismedi.
      expect(source[4], 0x00);
    });
  });

  group('MIFARE Classic magic / blok 0', () {
    const validBlock0 = '04A1B2C3D40804000011223344556677';

    FakeTagHandle classicTag({
      Set<Uint8List>? validSectorKeys = const {},
      Map<int, Uint8List>? pages,
      Set<int>? readOnlyClassicBlocks,
    }) => FakeTagHandle(
      uid: hexToBytes('04A1B2C3D4E580'),
      technologies: const [TagTechnology.nfcA, TagTechnology.mifareClassic],
      ndefCapabilities: null,
      supportedChannels: const {TransceiveChannel.mifareClassic},
      mifareClassicInfo: const MifareClassicInfo(
        sectorCount: 16,
        blockCount: 64,
        sizeInBytes: 1024,
      ),
      validSectorKeys: validSectorKeys?.isEmpty ?? true
          ? {hexToBytes('FFFFFFFFFFFF')}
          : validSectorKeys,
      pages: pages ?? {0: hexToBytes(validBlock0)},
      readOnlyClassicBlocks: readOnlyClassicBlocks,
    );

    DangerAck ackFor(FakeTagHandle tag) =>
        DangerAck.forTest(targetUidHex: bytesToHex(tag.uid));

    test('probe: yazilabilir blok 0 -> Gen2', () async {
      final tag = classicTag();
      final result = await operations.probeMifareMagic(tag);
      final probe = (result as Ok<MifareMagicProbe>).value;
      expect(probe.isBlockZeroWritable, isTrue);
      expect(probe.kind, MifareMagicKind.gen2);
    });

    test('probe: blok 0 salt-okunur -> standart kart', () async {
      final tag = classicTag(readOnlyClassicBlocks: {0});
      final result = await operations.probeMifareMagic(tag);
      final probe = (result as Ok<MifareMagicProbe>).value;
      expect(probe.isBlockZeroWritable, isFalse);
      expect(probe.kind, MifareMagicKind.none);
    });

    test('probe: sektor 0 anahtari yoksa -> unknown', () async {
      final tag = classicTag(validSectorKeys: {hexToBytes('A0A1A2A3A4A6')});
      final result = await operations.probeMifareMagic(tag);
      final probe = (result as Ok<MifareMagicProbe>).value;
      expect(probe.isBlockZeroWritable, isFalse);
      expect(probe.kind, MifareMagicKind.unknown);
    });

    test('probe: Classic olmayan etiket -> TagNotSupported', () async {
      final tag = FakeTagHandle(uid: hexToBytes('04A1B2C3D4E580'));
      final result = await operations.probeMifareMagic(tag);
      expect(result, isA<Err<MifareMagicProbe>>());
      expect((result as Err).failure, isA<TagNotSupported>());
    });

    test('blok 0 yazma: gecerli BCC yazilir ve dogrulanir', () async {
      final tag = classicTag();
      final result = await operations.writeMifareClassicBlock(
        tag,
        blockIndex: 0,
        data: hexToBytes(validBlock0),
        key: hexToBytes('FFFFFFFFFFFF'),
        keyType: MifareKeyType.keyA,
        ack: ackFor(tag),
      );
      expect(result, isA<Ok<void>>());
      expect(
        bytesToHex(tag.writtenClassicBlocks.last.data),
        validBlock0,
      );
    });

    test('blok 0 yazma: hatali BCC reddedilir', () async {
      final tag = classicTag();
      final result = await operations.writeMifareClassicBlock(
        tag,
        blockIndex: 0,
        data: hexToBytes('04A1B2C3000804000011223344556677'),
        key: hexToBytes('FFFFFFFFFFFF'),
        keyType: MifareKeyType.keyA,
        ack: ackFor(tag),
      );
      expect(result, isA<Err<void>>());
      expect((result as Err).failure, isA<InvalidArgument>());
      expect(tag.writtenClassicBlocks, isEmpty);
    });

    test('blok yazma: yanlis anahtar -> AuthenticationFailed', () async {
      final tag = classicTag();
      final result = await operations.writeMifareClassicBlock(
        tag,
        blockIndex: 1,
        data: Uint8List(16),
        key: hexToBytes('A0A1A2A3A4A6'),
        ack: ackFor(tag),
      );
      expect((result as Err).failure, isA<AuthenticationFailed>());
    });

    test('blok yazma: onay baska etiket icinse reddedilir', () async {
      final tag = classicTag();
      final result = await operations.writeMifareClassicBlock(
        tag,
        blockIndex: 1,
        data: Uint8List(16),
        key: hexToBytes('FFFFFFFFFFFF'),
        ack: DangerAck.forTest(targetUidHex: 'DEADBEEF'),
      );
      expect((result as Err).failure, isA<InvalidArgument>());
    });

    test('klon: veri bloklari + blok 0 yazilir, fragmanlar atlanir', () async {
      final target = classicTag(pages: {});
      final bytes = Uint8List(1024);
      bytes.setRange(0, 16, hexToBytes(validBlock0));
      final source = TagMemory(bytes: bytes, pageSize: 16);

      final result = await operations.cloneMifareClassicTo(
        target,
        source: source,
        sourceUidHex: 'AABBCCDD',
        ack: ackFor(target),
      );

      final report = (result as Ok<MifareCloneReport>).value;
      // 16 sektor x 3 veri blogu = 48 yazildi, 16 fragman atlandi.
      expect(report.blocksWritten, 48);
      expect(report.blocksSkipped, 16);
      expect(report.blocksFailed, 0);
      expect(report.blockZeroWritten, isTrue);
      expect(report.trailersWritten, isFalse);
      // Blok 0'a en son yazilan veri kaynak blok 0'dir.
      final blockZeroWrites =
          target.writtenClassicBlocks.where((w) => w.block == 0).toList();
      expect(bytesToHex(blockZeroWrites.last.data), validBlock0);
    });

    test('klon: hedef blok 0 yazamiyorsa TagNotSupported', () async {
      final target = classicTag(pages: {}, readOnlyClassicBlocks: {0});
      final source = TagMemory(bytes: Uint8List(1024), pageSize: 16);
      final result = await operations.cloneMifareClassicTo(
        target,
        source: source,
        sourceUidHex: 'AABBCCDD',
        ack: ackFor(target),
      );
      expect((result as Err).failure, isA<TagNotSupported>());
    });
  });

  group('ECC secp128r1 / ECDSA', () {
    test('uretici nokta mertebesi dogru: n * G = sonsuzluk', () {
      final result = Secp128r1.multiply(Secp128r1.n, Secp128r1.g);
      expect(result.isInfinity, isTrue);
    });

    test('imzalama/dogrulama round-trip gecerli imzayi kabul eder', () {
      final d =
          BigInt.parse('123456789ABCDEF0123456789ABCDEF0', radix: 16) %
              (Secp128r1.n - BigInt.one) +
          BigInt.one;
      final publicKey = Secp128r1.multiply(d, Secp128r1.g);

      final k =
          BigInt.parse('FEDCBA9876543210FEDCBA9876543210', radix: 16) %
              (Secp128r1.n - BigInt.one) +
          BigInt.one;
      final message = BigInt.parse('04A1B2C3D4E580', radix: 16);

      final r = Secp128r1.multiply(k, Secp128r1.g).x! % Secp128r1.n;
      final s =
          (k.modInverse(Secp128r1.n) * (message + r * d)) % Secp128r1.n;

      expect(
        Ecdsa.verify(message: message, r: r, s: s, publicKey: publicKey),
        isTrue,
      );
      expect(
        Ecdsa.verify(
          message: message + BigInt.one,
          r: r,
          s: s,
          publicKey: publicKey,
        ),
        isFalse,
      );
    });

    test('verifySignature icin NXP anahtari henuz ayarlanmadi', () async {
      final tag = FakeTagHandle(
        uid: hexToBytes('04A1B2C3D4E580'),
        rules: [
          FakeTransceiveRule(
            commandHex: '3C00',
            response: Uint8List(32),
          ),
        ],
      );

      final result = await operations.verifySignature(tag);

      expect(result, isA<Err<bool>>());
      expect((result as Err<bool>).failure, isA<TagNotSupported>());
    });
  });
}
