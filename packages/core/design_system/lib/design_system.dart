/// Tasarim sistemi — tokenlar, temalar ve yeniden kullanilabilir widget'lar.
///
/// Bu paket `nfc_core`'a bagimli **degildir**. Widget'lar ham tipler alir
/// (`Uint8List`, `String`, `enum`); alan modeli almaz. Boylece tasarim
/// katmani bagimsiz test edilir ve alan modeli degisince kirilmaz.
///
/// Sahibi: **T5** (bkz. `.claude/tracks/T5-design.md`)
library;

export 'src/app_theme.dart';
export 'src/tokens.dart';
export 'src/widgets/common_widgets.dart';
export 'src/widgets/danger_dialog.dart';
export 'src/widgets/hex_dump_view.dart';
export 'src/widgets/nfc_scan_sheet.dart';
