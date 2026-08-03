/// NDEF kodlayici-cozucu.
///
/// Saf Dart — NFC donanimi gerektirmez, tamamen birim testi yazilabilir.
/// Uygulamadaki tum NDEF dogruluk kaynagi burasidir; baska bir yerde
/// elle NDEF ayristirma yazma.
///
/// Sahibi: **T3** (bkz. `.claude/tracks/T3-write.md`)
library;

export 'src/ndef_binary_codec.dart';
export 'src/ndef_content.dart';
export 'src/ndef_converter.dart';
export 'src/uri_prefixes.dart';
