import 'dart:typed_data';

import 'package:nfc_core/nfc_core.dart';
import 'package:nfc_manager/nfc_manager.dart' as platform;
import 'package:nfc_manager/nfc_manager_android.dart' as android;

import 'error_mapper.dart';
import 'ndef_mapper.dart';

/// MIFARE Classic icin `getMaxTransceiveLength` platform tarafinda
/// acilmadigindan kullanilan tutucu deger.
///
/// Android'in gercek siniri genelde 253 byte'tir; daha kucuk bir deger
/// secmek yalnizca gereksiz parcalamaya yol acar, veri kaybettirmez.
const int _mifareClassicAssumedMaxTransceive = 253;

/// [NfcTagHandle] arayuzunun Android uygulamasi.
///
/// `nfc_manager` tiplerini sarmalar. Bu sinifin disina platform tipi
/// **sizmaz** — tum donusler `nfc_core` tipleridir.
final class AndroidTagHandle implements NfcTagHandle {
  AndroidTagHandle(this._tag);

  final platform.NfcTag _tag;

  late final android.NfcTagAndroid? _base = android.NfcTagAndroid.from(_tag);
  late final android.NdefAndroid? _ndef = android.NdefAndroid.from(_tag);
  late final android.NdefFormatableAndroid? _formatable =
      android.NdefFormatableAndroid.from(_tag);
  late final android.NfcAAndroid? _nfcA = android.NfcAAndroid.from(_tag);
  late final android.NfcVAndroid? _nfcV = android.NfcVAndroid.from(_tag);
  late final android.IsoDepAndroid? _isoDep = android.IsoDepAndroid.from(_tag);
  late final android.MifareUltralightAndroid? _ultralight =
      android.MifareUltralightAndroid.from(_tag);
  late final android.MifareClassicAndroid? _classic =
      android.MifareClassicAndroid.from(_tag);

  // ---------------------------------------------------------------------
  // Kimlik
  // ---------------------------------------------------------------------

  @override
  Uint8List get uid => _base?.id ?? Uint8List(0);

  @override
  List<TagTechnology> get technologies {
    final names = _base?.techList ?? const <String>[];
    return names
        .map(TagTechnology.fromAndroidName)
        .whereType<TagTechnology>()
        .toList(growable: false);
  }

  @override
  Uint8List? get atqa => _nfcA?.atqa;

  @override
  int? get sak => _nfcA?.sak;

  @override
  int? get dsfId => _nfcV?.dsfId;

  @override
  MifareClassicInfo? get mifareClassicInfo {
    final classic = _classic;
    if (classic == null) return null;
    return MifareClassicInfo(
      sectorCount: classic.sectorCount,
      blockCount: classic.blockCount,
      sizeInBytes: classic.size,
    );
  }

  // ---------------------------------------------------------------------
  // NDEF
  // ---------------------------------------------------------------------

  @override
  bool get hasNdef => _ndef != null;

  @override
  bool get canFormatNdef => _formatable != null;

  @override
  NdefCapabilities? get ndefCapabilities {
    final ndef = _ndef;
    if (ndef == null) return null;
    return NdefCapabilities(
      maxSize: ndef.maxSize,
      isWritable: ndef.isWritable,
      canMakeReadOnly: ndef.canMakeReadOnly,
      typeName: ndef.type,
    );
  }

  @override
  NdefMessageEntity? get cachedNdefMessage {
    final cached = _ndef?.cachedNdefMessage;
    return cached == null ? null : NdefMapper.toCoreMessage(cached);
  }

  @override
  Future<Result<NdefMessageEntity?>> readNdef() async {
    final ndef = _ndef;
    if (ndef == null) {
      return const Err(TagNotSupported(detail: 'Etiket NDEF destegi sunmuyor'));
    }
    try {
      final message = await ndef.getNdefMessage();
      return Ok(message == null ? null : NdefMapper.toCoreMessage(message));
    } on Object catch (e, s) {
      return Err(ErrorMapper.map(e, s));
    }
  }

  @override
  Future<Result<void>> writeNdef(NdefMessageEntity message) async {
    final ndef = _ndef;
    if (ndef == null) {
      return const Err(TagNotSupported(detail: 'Etiket NDEF destegi sunmuyor'));
    }
    if (!ndef.isWritable) return const Err(TagReadOnly());

    // Kapasite kontrolunu platforma birakmiyoruz: platform hatasi
    // "too large" gibi belirsiz bir metin dondururken biz kesin sayilari
    // verebiliyoruz.
    final needed = message.byteLength;
    if (needed > ndef.maxSize) {
      return Err(InsufficientSpace(needed: needed, available: ndef.maxSize));
    }

    try {
      await ndef.writeNdefMessage(NdefMapper.toPlatformMessage(message));
      return okVoid;
    } on Object catch (e, s) {
      return Err(ErrorMapper.map(e, s));
    }
  }

  @override
  Future<Result<void>> makeNdefReadOnly() async {
    final ndef = _ndef;
    if (ndef == null) {
      return const Err(TagNotSupported(detail: 'Etiket NDEF destegi sunmuyor'));
    }
    if (!ndef.canMakeReadOnly) {
      return const Err(
        TagNotSupported(detail: 'Bu etiket salt-okunur yapilamiyor'),
      );
    }
    try {
      await ndef.makeReadOnly();
      return okVoid;
    } on Object catch (e, s) {
      return Err(ErrorMapper.map(e, s));
    }
  }

  @override
  Future<Result<void>> formatNdef(
    NdefMessageEntity firstMessage, {
    bool readOnly = false,
  }) async {
    final formatable = _formatable;
    if (formatable == null) {
      return const Err(
        TagNotSupported(detail: 'Etiket NDEF olarak bicimlendirilemiyor'),
      );
    }
    try {
      final message = NdefMapper.toPlatformMessage(firstMessage);
      if (readOnly) {
        await formatable.formatReadOnly(message);
      } else {
        await formatable.format(message);
      }
      return okVoid;
    } on Object catch (e, s) {
      return Err(ErrorMapper.map(e, s));
    }
  }

  // ---------------------------------------------------------------------
  // Ham komut
  // ---------------------------------------------------------------------

  @override
  bool supportsChannel(TransceiveChannel channel) => switch (channel) {
    TransceiveChannel.nfcA => _nfcA != null,
    TransceiveChannel.nfcV => _nfcV != null,
    TransceiveChannel.mifareUltralight => _ultralight != null,
    TransceiveChannel.mifareClassic => _classic != null,
    TransceiveChannel.isoDep => _isoDep != null,
  };

  @override
  Future<Result<Uint8List>> transceive(
    Uint8List command, {
    required TransceiveChannel channel,
  }) async {
    if (!supportsChannel(channel)) {
      return Err(
        TagNotSupported(detail: '${channel.name} kanali bu etikette yok'),
      );
    }
    try {
      final response = await switch (channel) {
        TransceiveChannel.nfcA => _nfcA!.transceive(command),
        TransceiveChannel.nfcV => _nfcV!.transceive(command),
        TransceiveChannel.mifareUltralight => _ultralight!.transceive(command),
        TransceiveChannel.mifareClassic => _classic!.transceive(command),
        TransceiveChannel.isoDep => _isoDep!.transceive(command),
      };
      return Ok(response);
    } on Object catch (e, s) {
      return Err(ErrorMapper.map(e, s));
    }
  }

  @override
  Future<Result<int>> maxTransceiveLength(TransceiveChannel channel) async {
    if (!supportsChannel(channel)) {
      return Err(
        TagNotSupported(detail: '${channel.name} kanali bu etikette yok'),
      );
    }
    try {
      final length = await switch (channel) {
        TransceiveChannel.nfcA => _nfcA!.getMaxTransceiveLength(),
        TransceiveChannel.nfcV => _nfcV!.getMaxTransceiveLength(),
        TransceiveChannel.mifareUltralight =>
          _ultralight!.getMaxTransceiveLength(),
        TransceiveChannel.isoDep => _isoDep!.getMaxTransceiveLength(),
        // Platform bu bilgiyi MIFARE Classic icin acmiyor.
        TransceiveChannel.mifareClassic => Future<int>.value(
          _mifareClassicAssumedMaxTransceive,
        ),
      };
      return Ok(length);
    } on Object catch (e, s) {
      return Err(ErrorMapper.map(e, s));
    }
  }

  @override
  Future<Result<void>> setTimeout(
    TransceiveChannel channel,
    int milliseconds,
  ) async {
    try {
      switch (channel) {
        case TransceiveChannel.nfcA:
          await _nfcA?.setTimeout(milliseconds);
        case TransceiveChannel.mifareUltralight:
          await _ultralight?.setTimeout(milliseconds);
        case TransceiveChannel.isoDep:
          await _isoDep?.setTimeout(milliseconds);
        case TransceiveChannel.nfcV:
        case TransceiveChannel.mifareClassic:
          // Platform bu kanallarda zaman asimi ayarini acmiyor; sessizce
          // yok sayiyoruz — varsayilan degerler bu komutlar icin yeterli.
          break;
      }
      return okVoid;
    } on Object catch (e, s) {
      return Err(ErrorMapper.map(e, s));
    }
  }

  // ---------------------------------------------------------------------
  // MIFARE Ultralight
  // ---------------------------------------------------------------------

  @override
  Future<Result<Uint8List>> readUltralightPages(int pageOffset) async {
    final ultralight = _ultralight;
    if (ultralight == null) {
      return const Err(TagNotSupported(detail: 'MIFARE Ultralight degil'));
    }
    if (pageOffset < 0) {
      return const Err(InvalidArgument('Sayfa numarasi negatif olamaz'));
    }
    try {
      return Ok(await ultralight.readPages(pageOffset: pageOffset));
    } on Object catch (e, s) {
      return Err(ErrorMapper.map(e, s));
    }
  }

  @override
  Future<Result<void>> writeUltralightPage(
    int pageOffset,
    Uint8List data,
  ) async {
    final ultralight = _ultralight;
    if (ultralight == null) {
      return const Err(TagNotSupported(detail: 'MIFARE Ultralight degil'));
    }
    if (data.length != 4) {
      return const Err(InvalidArgument('Sayfa verisi tam 4 byte olmali'));
    }
    if (pageOffset < 0) {
      return const Err(InvalidArgument('Sayfa numarasi negatif olamaz'));
    }
    try {
      await ultralight.writePage(pageOffset: pageOffset, data: data);
      return okVoid;
    } on Object catch (e, s) {
      return Err(ErrorMapper.map(e, s));
    }
  }

  // ---------------------------------------------------------------------
  // MIFARE Classic
  // ---------------------------------------------------------------------

  @override
  Future<Result<bool>> authenticateSector({
    required int sectorIndex,
    required Uint8List key,
    required MifareKeyType keyType,
  }) async {
    final classic = _classic;
    if (classic == null) {
      return const Err(TagNotSupported(detail: 'MIFARE Classic degil'));
    }
    if (key.length != 6) {
      return const Err(InvalidArgument('Anahtar 6 byte olmali'));
    }
    if (sectorIndex < 0 || sectorIndex >= classic.sectorCount) {
      return Err(
        InvalidArgument(
          'Sektor $sectorIndex yok (0-${classic.sectorCount - 1})',
        ),
      );
    }
    try {
      final ok = switch (keyType) {
        MifareKeyType.keyA => await classic.authenticateSectorWithKeyA(
          sectorIndex: sectorIndex,
          key: key,
        ),
        MifareKeyType.keyB => await classic.authenticateSectorWithKeyB(
          sectorIndex: sectorIndex,
          key: key,
        ),
      };
      return Ok(ok);
    } on Object catch (e, s) {
      return Err(ErrorMapper.map(e, s));
    }
  }

  @override
  Future<Result<Uint8List>> readClassicBlock(int blockIndex) async {
    final classic = _classic;
    if (classic == null) {
      return const Err(TagNotSupported(detail: 'MIFARE Classic degil'));
    }
    if (blockIndex < 0 || blockIndex >= classic.blockCount) {
      return Err(
        InvalidArgument('Blok $blockIndex yok (0-${classic.blockCount - 1})'),
      );
    }
    try {
      return Ok(await classic.readBlock(blockIndex: blockIndex));
    } on Object catch (e, s) {
      return Err(ErrorMapper.map(e, s));
    }
  }

  @override
  Future<Result<void>> writeClassicBlock(int blockIndex, Uint8List data) async {
    final classic = _classic;
    if (classic == null) {
      return const Err(TagNotSupported(detail: 'MIFARE Classic degil'));
    }
    if (data.length != 16) {
      return const Err(InvalidArgument('Blok verisi tam 16 byte olmali'));
    }
    if (blockIndex < 0 || blockIndex >= classic.blockCount) {
      return Err(
        InvalidArgument('Blok $blockIndex yok (0-${classic.blockCount - 1})'),
      );
    }
    try {
      await classic.writeBlock(blockIndex: blockIndex, data: data);
      return okVoid;
    } on Object catch (e, s) {
      return Err(ErrorMapper.map(e, s));
    }
  }
}
