import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../contracts/nfc_session_service.dart';
import '../entities/ndef_entities.dart';
import '../entities/tag_technology.dart';
import '../failures.dart';
import '../result.dart';

/// Sahte bir ham komut cevabi.
@immutable
final class FakeTransceiveRule {
  const FakeTransceiveRule({
    required this.commandHex,
    this.response,
    this.failure,
  }) : assert(
         response != null || failure != null,
         'Kural ya cevap ya hata vermeli',
       );

  /// Beklenen komut, buyuk harf hex, ayracsiz (orn. `3A0004`).
  final String commandHex;

  /// Donecek cevap.
  final Uint8List? response;

  /// Cevap yerine donecek hata.
  final NfcFailure? failure;
}

/// Testlerde kullanilan, donanim gerektirmeyen [NfcTagHandle].
///
/// Komut/cevap kurallari verilerek betiklenir; gonderilen tum komutlar
/// [sentCommands] icinde kaydedilir. `tag_ops` testleri bu sinifla yazilir.
///
/// ```dart
/// final tag = FakeTagHandle(
///   uid: hexToBytes('04A1B2C3D4E5F6'),
///   rules: [
///     FakeTransceiveRule(commandHex: '60', response: hexToBytes('0004040201000F03')),
///   ],
/// );
/// ```
final class FakeTagHandle implements NfcTagHandle {
  FakeTagHandle({
    required Uint8List uid,
    this.technologies = const [
      TagTechnology.nfcA,
      TagTechnology.mifareUltralight,
      TagTechnology.ndef,
    ],
    List<FakeTransceiveRule> rules = const [],
    NdefMessageEntity? ndefMessage,
    this.ndefCapabilities = const NdefCapabilities(
      maxSize: 144,
      isWritable: true,
      canMakeReadOnly: true,
      typeName: 'org.nfcforum.ndef.type2',
    ),
    this.atqa,
    this.sak,
    this.dsfId,
    this.mifareClassicInfo,
    this.canFormatNdef = false,
    this.supportedChannels = const {
      TransceiveChannel.nfcA,
      TransceiveChannel.mifareUltralight,
    },
    Map<int, Uint8List>? pages,
    Set<Uint8List>? validSectorKeys,
  }) : uid = Uint8List.fromList(uid),
       _rules = List.of(rules),
       _pages = pages ?? <int, Uint8List>{},
       _validSectorKeys = validSectorKeys ?? <Uint8List>{} {
    _ndefMessage = ndefMessage;
  }

  @override
  final Uint8List uid;

  @override
  final List<TagTechnology> technologies;

  @override
  final Uint8List? atqa;

  @override
  final int? sak;

  @override
  final int? dsfId;

  @override
  final MifareClassicInfo? mifareClassicInfo;

  @override
  final NdefCapabilities? ndefCapabilities;

  @override
  final bool canFormatNdef;

  /// Hangi kanallarin desteklendigi.
  final Set<TransceiveChannel> supportedChannels;

  final List<FakeTransceiveRule> _rules;
  final Map<int, Uint8List> _pages;
  final Set<Uint8List> _validSectorKeys;

  NdefMessageEntity? _ndefMessage;
  bool _readOnly = false;

  /// Bu tutamaga gonderilen tum komutlar, sirasiyla.
  ///
  /// Testte `expect(tag.sentCommands, [...])` ile dogrulanir.
  final List<Uint8List> sentCommands = [];

  /// Yazilan tum sayfalar: `(sayfa, veri)` ciftleri, sirasiyla.
  final List<({int page, Uint8List data})> writtenPages = [];

  /// Etikete yazilan son NDEF mesaji.
  NdefMessageEntity? get lastWrittenNdef => _ndefMessage;

  /// Etiket salt-okunur yapildi mi?
  bool get wasMadeReadOnly => _readOnly;

  /// Yeni bir komut kurali ekler.
  void addRule(FakeTransceiveRule rule) => _rules.add(rule);

  /// Kaydedilen komut/sayfa gecmisini temizler.
  void reset() {
    sentCommands.clear();
    writtenPages.clear();
  }

  @override
  bool get hasNdef => ndefCapabilities != null;

  @override
  NdefMessageEntity? get cachedNdefMessage => _ndefMessage;

  @override
  Future<Result<NdefMessageEntity?>> readNdef() async => Ok(_ndefMessage);

  @override
  Future<Result<void>> writeNdef(NdefMessageEntity message) async {
    if (_readOnly) return const Err(TagReadOnly());
    final capabilities = ndefCapabilities;
    if (capabilities == null) {
      return const Err(TagNotSupported(detail: 'NDEF yok'));
    }
    if (message.byteLength > capabilities.maxSize) {
      return Err(
        InsufficientSpace(
          needed: message.byteLength,
          available: capabilities.maxSize,
        ),
      );
    }
    _ndefMessage = message;
    return okVoid;
  }

  @override
  Future<Result<void>> makeNdefReadOnly() async {
    _readOnly = true;
    return okVoid;
  }

  @override
  Future<Result<void>> formatNdef(
    NdefMessageEntity firstMessage, {
    bool readOnly = false,
  }) async {
    _ndefMessage = firstMessage;
    if (readOnly) _readOnly = true;
    return okVoid;
  }

  @override
  bool supportsChannel(TransceiveChannel channel) =>
      supportedChannels.contains(channel);

  @override
  Future<Result<Uint8List>> transceive(
    Uint8List command, {
    required TransceiveChannel channel,
  }) async {
    sentCommands.add(Uint8List.fromList(command));
    if (!supportsChannel(channel)) {
      return Err(TagNotSupported(detail: '${channel.name} kanali yok'));
    }
    final key = _toHex(command);
    for (final rule in _rules) {
      if (rule.commandHex.toUpperCase() == key) {
        final failure = rule.failure;
        if (failure != null) return Err(failure);
        return Ok(rule.response!);
      }
    }
    return Err(
      TransportError('FakeTagHandle: $key komutu icin kural tanimlanmamis'),
    );
  }

  @override
  Future<Result<int>> maxTransceiveLength(TransceiveChannel channel) async =>
      const Ok(253);

  @override
  Future<Result<void>> setTimeout(
    TransceiveChannel channel,
    int milliseconds,
  ) async => okVoid;

  @override
  Future<Result<Uint8List>> readUltralightPages(int pageOffset) async {
    final buffer = Uint8List(16);
    for (var i = 0; i < 4; i++) {
      final page = _pages[pageOffset + i];
      if (page != null) buffer.setRange(i * 4, i * 4 + 4, page);
    }
    return Ok(buffer);
  }

  @override
  Future<Result<void>> writeUltralightPage(
    int pageOffset,
    Uint8List data,
  ) async {
    if (data.length != 4) {
      return const Err(InvalidArgument('Sayfa verisi 4 byte olmali'));
    }
    if (_readOnly) return const Err(TagReadOnly());
    _pages[pageOffset] = Uint8List.fromList(data);
    writtenPages.add((page: pageOffset, data: Uint8List.fromList(data)));
    return okVoid;
  }

  @override
  Future<Result<bool>> authenticateSector({
    required int sectorIndex,
    required Uint8List key,
    required MifareKeyType keyType,
  }) async {
    for (final valid in _validSectorKeys) {
      if (_toHex(valid) == _toHex(key)) return const Ok(true);
    }
    return const Ok(false);
  }

  @override
  Future<Result<Uint8List>> readClassicBlock(int blockIndex) async =>
      Ok(_pages[blockIndex] ?? Uint8List(16));

  @override
  Future<Result<void>> writeClassicBlock(int blockIndex, Uint8List data) async {
    if (data.length != 16) {
      return const Err(InvalidArgument('Blok verisi 16 byte olmali'));
    }
    _pages[blockIndex] = Uint8List.fromList(data);
    return okVoid;
  }

  static String _toHex(List<int> bytes) => bytes
      .map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();
}
