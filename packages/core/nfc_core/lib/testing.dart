/// Test sahteleri (fake).
///
/// **Yalnizca testlerde import edilir.** Uretim kodunda kullanma.
///
/// Bu sahteler `nfc_core` icinde durur ki her katman — feature paketleri
/// dahil — NFC donanimi olmadan test yazabilsin. `nfc_transport` paketine
/// bagimlilik gerektirmez, dolayisiyla mimari sinirlar korunur.
///
/// ```dart
/// import 'package:nfc_core/testing.dart';
///
/// final service = FakeNfcSessionService(tags: [FakeTagHandle(uid: uid)]);
/// ```
library;

export 'src/testing/fake_session_service.dart';
export 'src/testing/fake_tag_handle.dart';
