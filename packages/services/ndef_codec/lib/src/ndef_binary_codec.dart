import 'dart:typed_data';

import 'package:nfc_core/nfc_core.dart';

/// NDEF kayit basligi bit maskeleri.
abstract final class NdefHeaderFlags {
  /// Message Begin.
  static const int mb = 0x80;

  /// Message End.
  static const int me = 0x40;

  /// Chunk Flag.
  static const int cf = 0x20;

  /// Short Record — yuk uzunlugu 1 byte.
  static const int sr = 0x10;

  /// ID Length alani var.
  static const int il = 0x08;

  /// TNF alani maskesi.
  static const int tnfMask = 0x07;
}

/// Type 2 Tag bellek TLV tipleri.
abstract final class TlvType {
  static const int nullTlv = 0x00;
  static const int lockControl = 0x01;
  static const int memoryControl = 0x02;
  static const int ndefMessage = 0x03;
  static const int proprietary = 0xFD;
  static const int terminator = 0xFE;
}

/// NDEF mesajlarinin ikili (binary) kodlayici-cozucusu.
///
/// Platform (Android) cogu zaman NDEF'i kendisi cozer; bu kodlayici
/// ham bellek dokumundan mesaj cikarmak, boyut hesaplamak ve
/// dogrulama yapmak icin gereklidir.
///
/// Bkz. `.claude/docs/03-nfc-reference.md` §1.1 ve §1.5
abstract final class NdefBinaryCodec {
  /// Bir NDEF mesajini byte dizisine cevirir.
  static Uint8List encodeMessage(NdefMessageEntity message) {
    if (message.records.isEmpty) {
      return encodeMessage(NdefMessageEntity.empty());
    }
    final builder = BytesBuilder(copy: false);
    for (var i = 0; i < message.records.length; i++) {
      builder.add(
        _encodeRecord(
          message.records[i],
          isFirst: i == 0,
          isLast: i == message.records.length - 1,
        ),
      );
    }
    return builder.toBytes();
  }

  static Uint8List _encodeRecord(
    NdefRecordEntity record, {
    required bool isFirst,
    required bool isLast,
  }) {
    final payload = record.payload;
    final type = record.type;
    final id = record.identifier;
    final shortRecord = payload.length < 256;

    var header = record.typeNameFormat.value & NdefHeaderFlags.tnfMask;
    if (isFirst) header |= NdefHeaderFlags.mb;
    if (isLast) header |= NdefHeaderFlags.me;
    if (shortRecord) header |= NdefHeaderFlags.sr;
    if (id.isNotEmpty) header |= NdefHeaderFlags.il;

    final builder = BytesBuilder(copy: false)
      ..addByte(header)
      ..addByte(type.length);

    if (shortRecord) {
      builder.addByte(payload.length);
    } else {
      builder.add(
        Uint8List(4)
          ..[0] = (payload.length >> 24) & 0xFF
          ..[1] = (payload.length >> 16) & 0xFF
          ..[2] = (payload.length >> 8) & 0xFF
          ..[3] = payload.length & 0xFF,
      );
    }

    if (id.isNotEmpty) builder.addByte(id.length);
    builder
      ..add(type)
      ..add(id)
      ..add(payload);

    return builder.toBytes();
  }

  /// Byte dizisinden NDEF mesaji cozer.
  ///
  /// Bicim bozuksa `MalformedData` doner.
  static Result<NdefMessageEntity> decodeMessage(Uint8List bytes) {
    final records = <NdefRecordEntity>[];
    var offset = 0;

    while (offset < bytes.length) {
      final result = _decodeRecord(bytes, offset);
      switch (result) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: (final record, final nextOffset, final isLast)):
          records.add(record);
          offset = nextOffset;
          if (isLast) {
            return Ok(NdefMessageEntity(records));
          }
      }
    }

    if (records.isEmpty) {
      return const Err(MalformedData('NDEF mesajinda hic kayit yok'));
    }
    // ME bayragi olmadan bitti — tolere ediyoruz ama kayitlari donduruyoruz.
    return Ok(NdefMessageEntity(records));
  }

  static Result<(NdefRecordEntity, int, bool)> _decodeRecord(
    Uint8List bytes,
    int start,
  ) {
    var offset = start;

    if (offset >= bytes.length) {
      return const Err(MalformedData('Kayit basligi eksik'));
    }
    final header = bytes[offset++];
    final tnf = NdefTypeNameFormat.fromValue(header & NdefHeaderFlags.tnfMask);
    final isLast = header & NdefHeaderFlags.me != 0;
    final shortRecord = header & NdefHeaderFlags.sr != 0;
    final hasId = header & NdefHeaderFlags.il != 0;

    if (offset >= bytes.length) {
      return const Err(MalformedData('Tip uzunlugu eksik'));
    }
    final typeLength = bytes[offset++];

    final int payloadLength;
    if (shortRecord) {
      if (offset >= bytes.length) {
        return const Err(MalformedData('Yuk uzunlugu eksik'));
      }
      payloadLength = bytes[offset++];
    } else {
      if (offset + 4 > bytes.length) {
        return const Err(MalformedData('Uzun kayit yuk uzunlugu eksik'));
      }
      payloadLength =
          (bytes[offset] << 24) |
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];
      offset += 4;
    }

    var idLength = 0;
    if (hasId) {
      if (offset >= bytes.length) {
        return const Err(MalformedData('Id uzunlugu eksik'));
      }
      idLength = bytes[offset++];
    }

    if (offset + typeLength + idLength + payloadLength > bytes.length) {
      return Err(
        MalformedData(
          'Kayit bildirdigi uzunlugu tasiyamiyor '
          '(tip: $typeLength, id: $idLength, yuk: $payloadLength)',
        ),
      );
    }

    final type = Uint8List.sublistView(bytes, offset, offset + typeLength);
    offset += typeLength;
    final id = Uint8List.sublistView(bytes, offset, offset + idLength);
    offset += idLength;
    final payload = Uint8List.sublistView(
      bytes,
      offset,
      offset + payloadLength,
    );
    offset += payloadLength;

    return Ok((
      NdefRecordEntity(
        typeNameFormat: tnf,
        type: type,
        identifier: id,
        payload: payload,
      ),
      offset,
      isLast,
    ));
  }

  /// Ham etiket belleginden NDEF mesajini cikarir.
  ///
  /// Bellegi TLV yapisi olarak tarar ve `0x03` (NDEF Message) TLV'sini bulur.
  /// [memory] kullanici alaninin basindan itibaren olmalidir
  /// (Type 2 etiketlerde sayfa 4).
  static Result<NdefMessageEntity?> extractFromMemory(Uint8List memory) {
    var offset = 0;

    while (offset < memory.length) {
      final tlvType = memory[offset++];

      switch (tlvType) {
        case TlvType.nullTlv:
          continue;
        case TlvType.terminator:
          return const Ok(null);
      }

      if (offset >= memory.length) {
        return const Err(MalformedData('TLV uzunluk alani eksik'));
      }

      int length = memory[offset++];
      if (length == 0xFF) {
        if (offset + 2 > memory.length) {
          return const Err(MalformedData('Uzun TLV uzunlugu eksik'));
        }
        length = (memory[offset] << 8) | memory[offset + 1];
        offset += 2;
      }

      if (offset + length > memory.length) {
        return Err(
          MalformedData('TLV degeri bellek disina tasiyor (uzunluk: $length)'),
        );
      }

      if (tlvType == TlvType.ndefMessage) {
        if (length == 0) return const Ok(null);
        return decodeMessage(
          Uint8List.sublistView(memory, offset, offset + length),
        ).map<NdefMessageEntity?>((message) => message);
      }

      offset += length;
    }

    return const Ok(null);
  }

  /// NDEF mesajini TLV zarfina sarar — etikete ham yazmak icin.
  ///
  /// Terminator TLV'si (`0xFE`) de eklenir.
  static Uint8List wrapInTlv(NdefMessageEntity message) {
    final payload = encodeMessage(message);
    final builder = BytesBuilder(copy: false)..addByte(TlvType.ndefMessage);

    if (payload.length < 0xFF) {
      builder.addByte(payload.length);
    } else {
      builder
        ..addByte(0xFF)
        ..addByte((payload.length >> 8) & 0xFF)
        ..addByte(payload.length & 0xFF);
    }

    builder
      ..add(payload)
      ..addByte(TlvType.terminator);

    return builder.toBytes();
  }
}
