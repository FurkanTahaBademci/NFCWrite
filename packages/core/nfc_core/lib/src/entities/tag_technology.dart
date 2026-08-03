/// Etiketin destekledigi radyo/protokol teknolojisi.
///
/// Android `techList` degerlerinin platformdan bagimsiz karsiligi.
enum TagTechnology {
  /// ISO/IEC 14443-3A — NTAG, MIFARE Ultralight/Classic tabani.
  nfcA('android.nfc.tech.NfcA'),

  /// ISO/IEC 14443-3B.
  nfcB('android.nfc.tech.NfcB'),

  /// JIS 6319-4 (FeliCa).
  nfcF('android.nfc.tech.NfcF'),

  /// ISO/IEC 15693 — ICODE, vicinity kartlar.
  nfcV('android.nfc.tech.NfcV'),

  /// ISO/IEC 14443-4 — APDU tabanli kartlar.
  isoDep('android.nfc.tech.IsoDep'),

  /// Etiket NDEF olarak okunabilir.
  ndef('android.nfc.tech.Ndef'),

  /// Etiket NDEF'e bicimlendirilebilir.
  ndefFormatable('android.nfc.tech.NdefFormatable'),

  /// MIFARE Classic 1K/4K.
  mifareClassic('android.nfc.tech.MifareClassic'),

  /// MIFARE Ultralight / Ultralight C / NTAG.
  mifareUltralight('android.nfc.tech.MifareUltralight'),

  /// Kovio barkod etiketleri.
  nfcBarcode('android.nfc.tech.NfcBarcode');

  const TagTechnology(this.androidName);

  /// Android tarafindaki tam sinif adi.
  final String androidName;

  /// Android teknoloji adindan cozer. Bilinmiyorsa null.
  static TagTechnology? fromAndroidName(String name) {
    for (final tech in TagTechnology.values) {
      if (tech.androidName == name) return tech;
    }
    return null;
  }
}
