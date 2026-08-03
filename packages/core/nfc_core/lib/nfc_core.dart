/// NFC Toolkit cekirdek sozlesmeleri.
///
/// Bu paket saf Dart'tir — Flutter bagimliligi **yoktur**. Uygulamanin
/// tum katmanlari buradaki arayuslere ve varliklara gore konusur; somut
/// uygulamalar (`nfc_transport`, `tag_ops`, `storage`) yalnizca
/// composition root'ta baglanir.
///
/// Icerik:
///   * Sozlesmeler  — `src/contracts/`
///   * Varliklar    — `src/entities/`
///   * Sonuc/hata   — `src/result.dart`, `src/failures.dart`
///   * Guvenlik     — `src/safety.dart`
///
/// Bkz. `.claude/docs/01-architecture.md`
library;

export 'src/contracts/nfc_session_service.dart';
export 'src/contracts/repositories.dart';
export 'src/contracts/tag_operations.dart';
export 'src/entities/app_settings.dart';
export 'src/entities/ndef_entities.dart';
export 'src/entities/nfc_tag_info.dart';
export 'src/entities/ntag_config.dart';
export 'src/entities/storage_entities.dart';
export 'src/entities/tag_identity.dart';
export 'src/entities/tag_memory.dart';
export 'src/entities/tag_technology.dart';
export 'src/failures.dart';
export 'src/result.dart';
export 'src/safety.dart';
