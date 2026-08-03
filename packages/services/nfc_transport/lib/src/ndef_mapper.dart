import 'dart:typed_data';

import 'package:nfc_core/nfc_core.dart';
// nfc_manager, ndef_record tiplerini bu yoldan yeniden ihrac eder.
// Dogrudan `package:ndef_record/...` import etmiyoruz ki ek bir bagimlilik
// beyan etmek zorunda kalmayalim.
import 'package:nfc_manager/ndef_record.dart' as platform;

/// `nfc_core` ile `ndef_record` paketinin tipleri arasinda cevirmen.
///
/// Bu dosya, platform tiplerinin uygulamanin geri kalanina sizmasini
/// engelleyen sinirdir. `ndef_record` tipleri **yalnizca** burada gorunur.
abstract final class NdefMapper {
  /// Platform TNF -> cekirdek TNF.
  static NdefTypeNameFormat toCoreTnf(platform.TypeNameFormat tnf) =>
      switch (tnf) {
        platform.TypeNameFormat.empty => NdefTypeNameFormat.empty,
        platform.TypeNameFormat.wellKnown => NdefTypeNameFormat.wellKnown,
        platform.TypeNameFormat.media => NdefTypeNameFormat.media,
        platform.TypeNameFormat.absoluteUri => NdefTypeNameFormat.absoluteUri,
        platform.TypeNameFormat.external => NdefTypeNameFormat.externalType,
        platform.TypeNameFormat.unknown => NdefTypeNameFormat.unknown,
        platform.TypeNameFormat.unchanged => NdefTypeNameFormat.unchanged,
      };

  /// Cekirdek TNF -> platform TNF.
  ///
  /// [NdefTypeNameFormat.reserved] platformda karsiligi olmadigi icin
  /// `unknown` olarak gonderilir; NDEF spesifikasyonu zaten bu degerin
  /// kullanilmamasini soyler.
  static platform.TypeNameFormat toPlatformTnf(NdefTypeNameFormat tnf) =>
      switch (tnf) {
        NdefTypeNameFormat.empty => platform.TypeNameFormat.empty,
        NdefTypeNameFormat.wellKnown => platform.TypeNameFormat.wellKnown,
        NdefTypeNameFormat.media => platform.TypeNameFormat.media,
        NdefTypeNameFormat.absoluteUri => platform.TypeNameFormat.absoluteUri,
        NdefTypeNameFormat.externalType => platform.TypeNameFormat.external,
        NdefTypeNameFormat.unknown => platform.TypeNameFormat.unknown,
        NdefTypeNameFormat.unchanged => platform.TypeNameFormat.unchanged,
        NdefTypeNameFormat.reserved => platform.TypeNameFormat.unknown,
      };

  /// Platform kaydi -> cekirdek kaydi.
  static NdefRecordEntity toCoreRecord(platform.NdefRecord record) =>
      NdefRecordEntity(
        typeNameFormat: toCoreTnf(record.typeNameFormat),
        type: record.type,
        identifier: record.identifier,
        payload: record.payload,
      );

  /// Cekirdek kaydi -> platform kaydi.
  ///
  /// Platform tarafi bazi TNF/alan birlesimlerini reddeder ve
  /// [FormatException] atar; cagiran taraf yakalamali.
  static platform.NdefRecord toPlatformRecord(NdefRecordEntity record) {
    final tnf = toPlatformTnf(record.typeNameFormat);
    // Platform, EMPTY kayitta hicbir alanin dolu olmasina izin vermez;
    // UNKNOWN kayitta da tip alani bos olmalidir.
    final type = switch (tnf) {
      platform.TypeNameFormat.empty ||
      platform.TypeNameFormat.unknown => Uint8List(0),
      _ => Uint8List.fromList(record.type),
    };
    final identifier = tnf == platform.TypeNameFormat.empty
        ? Uint8List(0)
        : Uint8List.fromList(record.identifier);
    final payload = tnf == platform.TypeNameFormat.empty
        ? Uint8List(0)
        : Uint8List.fromList(record.payload);

    return platform.NdefRecord(
      typeNameFormat: tnf,
      type: type,
      identifier: identifier,
      payload: payload,
    );
  }

  /// Platform mesaji -> cekirdek mesaji.
  static NdefMessageEntity toCoreMessage(platform.NdefMessage message) =>
      NdefMessageEntity(message.records.map(toCoreRecord).toList());

  /// Cekirdek mesaji -> platform mesaji.
  static platform.NdefMessage toPlatformMessage(NdefMessageEntity message) =>
      platform.NdefMessage(
        records: message.records.map(toPlatformRecord).toList(),
      );
}
