/// NFC platform adaptoru.
///
/// `nfc_manager` paketini sarmalar ve `nfc_core` sozlesmelerini uygular.
///
/// **Bu paketi yalnizca composition root (`apps/nfc_toolkit`) import eder.**
/// Feature paketleri `nfc_core` arayuzlerini kullanir; bu paketin varligindan
/// haberdar degildir. Bkz. `.claude/docs/01-architecture.md`
library;

export 'src/android_session_service.dart' show AndroidNfcSessionService;
export 'src/android_tag_handle.dart' show AndroidTagHandle;
export 'src/error_mapper.dart' show ErrorMapper;
export 'src/ndef_mapper.dart' show NdefMapper;
