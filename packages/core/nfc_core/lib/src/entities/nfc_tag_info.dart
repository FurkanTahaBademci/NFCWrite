import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'ndef_entities.dart';
import 'ntag_config.dart';
import 'tag_identity.dart';
import 'tag_memory.dart';
import 'tag_technology.dart';

/// Bir etiketten okunan her seyin bir araya getirilmis hali.
///
/// Alanlarin cogu istege baglidir: ne kadar derin okuma yapildigina gore
/// dolar. Hizli tarama yalnizca [uid], [technologies] ve [ndefMessage]
/// doldurur; derin analiz [memory], [config] ve [lockStatus] ekler.
@immutable
final class NfcTagInfo {
  NfcTagInfo({
    required Uint8List uid,
    required this.technologies,
    required this.identity,
    this.atqa,
    this.sak,
    this.ndefMessage,
    this.isNdefFormatted = false,
    this.isWritable = false,
    this.canMakeReadOnly = false,
    this.maxNdefSize,
    this.currentNdefSize,
    this.memory,
    this.config,
    this.lockStatus,
    this.counterValue,
    this.signature,
    DateTime? scannedAt,
  }) : uid = Uint8List.fromList(uid),
       scannedAt = scannedAt ?? DateTime.now();

  /// Etiketin benzersiz kimligi (4, 7 ya da 10 byte).
  final Uint8List uid;

  /// Etiketin destekledigi teknolojiler.
  final List<TagTechnology> technologies;

  /// Yonga kimligi ve yetenekleri.
  final TagIdentity identity;

  /// ISO 14443-3A cevap byte'lari (2 byte). Baska teknolojide null.
  final Uint8List? atqa;

  /// ISO 14443-3A SAK byte'i. Baska teknolojide null.
  final int? sak;

  /// Okunan NDEF mesaji. Etiket bicimlendirilmemisse ya da bossa null.
  final NdefMessageEntity? ndefMessage;

  /// Etiket NDEF olarak bicimlendirilmis mi?
  final bool isNdefFormatted;

  /// Etikete yazilabilir mi?
  final bool isWritable;

  /// Kalici salt-okunur yapilabilir mi?
  final bool canMakeReadOnly;

  /// NDEF icin kullanilabilir toplam alan (byte).
  final int? maxNdefSize;

  /// Su anki NDEF mesajinin kapladigi alan (byte).
  final int? currentNdefSize;

  /// Ham bellek dokumu. Derin okuma yapilmadiysa null.
  final TagMemory? memory;

  /// Cozumlenmis yapilandirma. NTAG/UL EV1 disinda null.
  final NtagConfig? config;

  /// Cozumlenmis kilit durumu.
  final LockStatus? lockStatus;

  /// NFC sayac degeri. Okunmadiysa ya da desteklenmiyorsa null.
  final int? counterValue;

  /// ECC orijinallik imzasi (32 byte). Okunmadiysa null.
  final Uint8List? signature;

  /// Okuma zamani.
  final DateTime scannedAt;

  /// UID'nin hex gosterimi, ayraci yok.
  String get uidHex =>
      uid.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();

  /// Etiket sifre korumali mi?
  bool get isPasswordProtected => config?.isPasswordProtected ?? false;

  /// NDEF icin kalan bos alan (byte). Bilinmiyorsa null.
  int? get freeNdefSize {
    final max = maxNdefSize;
    if (max == null) return null;
    return max - (currentNdefSize ?? 0);
  }

  NfcTagInfo copyWith({
    Uint8List? uid,
    List<TagTechnology>? technologies,
    TagIdentity? identity,
    Uint8List? atqa,
    int? sak,
    NdefMessageEntity? ndefMessage,
    bool? isNdefFormatted,
    bool? isWritable,
    bool? canMakeReadOnly,
    int? maxNdefSize,
    int? currentNdefSize,
    TagMemory? memory,
    NtagConfig? config,
    LockStatus? lockStatus,
    int? counterValue,
    Uint8List? signature,
    DateTime? scannedAt,
  }) => NfcTagInfo(
    uid: uid ?? this.uid,
    technologies: technologies ?? this.technologies,
    identity: identity ?? this.identity,
    atqa: atqa ?? this.atqa,
    sak: sak ?? this.sak,
    ndefMessage: ndefMessage ?? this.ndefMessage,
    isNdefFormatted: isNdefFormatted ?? this.isNdefFormatted,
    isWritable: isWritable ?? this.isWritable,
    canMakeReadOnly: canMakeReadOnly ?? this.canMakeReadOnly,
    maxNdefSize: maxNdefSize ?? this.maxNdefSize,
    currentNdefSize: currentNdefSize ?? this.currentNdefSize,
    memory: memory ?? this.memory,
    config: config ?? this.config,
    lockStatus: lockStatus ?? this.lockStatus,
    counterValue: counterValue ?? this.counterValue,
    signature: signature ?? this.signature,
    scannedAt: scannedAt ?? this.scannedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is NfcTagInfo &&
      const ListEquality<int>().equals(other.uid, uid) &&
      other.scannedAt == scannedAt &&
      other.ndefMessage == ndefMessage;

  @override
  int get hashCode =>
      Object.hash(const ListEquality<int>().hash(uid), scannedAt, ndefMessage);

  @override
  String toString() =>
      'NfcTagInfo($uidHex, ${identity.displayName ?? identity.family.name})';
}
