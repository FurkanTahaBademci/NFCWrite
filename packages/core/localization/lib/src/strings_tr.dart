import 'app_strings.dart';

/// Turkce metinler.
final class AppStringsTr extends AppStrings {
  const AppStringsTr();

  @override
  String get languageCode => 'tr';

  @override
  String get appName => 'NFC Toolkit';

  @override
  String get tabRead => 'Oku';
  @override
  String get tabWrite => 'Yaz';
  @override
  String get tabTools => 'Diğer';
  @override
  String get tabHistory => 'Geçmiş';

  @override
  String get actionCancel => 'İptal';
  @override
  String get actionRetry => 'Tekrar dene';
  @override
  String get actionDone => 'Tamam';
  @override
  String get actionSave => 'Kaydet';
  @override
  String get actionDelete => 'Sil';
  @override
  String get actionCopy => 'Kopyala';
  @override
  String get actionShare => 'Paylaş';
  @override
  String get actionClose => 'Kapat';
  @override
  String get actionSettings => 'Ayarlar';
  @override
  String get actionScan => 'Etiketi tara';

  @override
  String get scanTitle => 'Etiketi yaklaştırın';
  @override
  String get scanHint => 'Etiketi telefonun arkasına tutun';
  @override
  String get scanFound => 'Etiket bulundu';
  @override
  String get scanWorking => 'İşlem sürüyor…';
  @override
  String get scanSuccess => 'İşlem tamamlandı';
  @override
  String get scanFailed => 'İşlem başarısız';

  @override
  String get readEmptyTitle => 'Henüz etiket okunmadı';
  @override
  String get readEmptyDescription =>
      'Bir NFC etiketini telefonun arkasına tutarak içeriğini görüntüleyin.';
  @override
  String get readSectionIdentity => 'Bilgi';
  @override
  String get readSectionNdef => 'NDEF';
  @override
  String get readSectionMemory => 'Bellek';
  @override
  String get readSectionTechnical => 'Teknik';
  @override
  String get readUid => 'UID';
  @override
  String get readUidReversed => 'UID (ters sıra)';
  @override
  String get readUidDecimal => 'UID (ondalık)';
  @override
  String get readChip => 'Yonga';
  @override
  String get readManufacturer => 'Üretici';
  @override
  String get readTechnologies => 'Teknolojiler';
  @override
  String get readCapacity => 'NDEF kapasitesi';
  @override
  String get readWritable => 'Yazılabilir';
  @override
  String get readReadOnly => 'Salt okunur';
  @override
  String get readFormatted => 'Biçimlendirilmiş';
  @override
  String get readNotFormatted => 'Biçimlendirilmemiş';
  @override
  String get readPasswordProtected => 'Şifre korumalı';
  @override
  String get readNoRecords => 'Etikette NDEF kaydı yok';

  @override
  String get readActionOpenLink => 'Bağlantıyı aç';
  @override
  String get readActionCall => 'Ara';
  @override
  String get readActionEmail => 'E-posta gönder';
  @override
  String get readActionSms => 'SMS gönder';
  @override
  String get readActionMap => 'Haritada aç';
  @override
  String get readActionWifiInfo => 'Wi-Fi bilgilerini gör';
  @override
  String get readActionShareContact => 'Kişi olarak paylaş';
  @override
  String get readWifiDialogTitle => 'Wi-Fi bilgileri';
  @override
  String get readWifiSsid => 'Ağ adı (SSID)';
  @override
  String get readWifiPassword => 'Parola';
  @override
  String get readWifiSecurity => 'Güvenlik';
  @override
  String get readActionFailed => 'Bu eylem gerçekleştirilemedi.';

  @override
  String get readContinuousStart => 'Sürekli tarama';
  @override
  String get readContinuousStop => 'Sürekli taramayı durdur';
  @override
  String get readContinuousTitle => 'Sürekli tarama';
  @override
  String get readContinuousHint => 'Etiketleri sırayla telefonun arkasına tutun';
  @override
  String readContinuousCount(int count) => '$count etiket okundu';

  @override
  String get readShareJson => 'JSON olarak paylaş';
  @override
  String get readShareResult => 'Okuma sonucu';

  @override
  String get writeEmptyTitle => 'Kayıt eklenmedi';
  @override
  String get writeEmptyDescription =>
      'Etikete yazmak istediğiniz kayıtları ekleyin, sonra “Yaz” deyin.';
  @override
  String get writeAddRecord => 'Kayıt ekle';
  @override
  String get writeAction => 'Etikete yaz';
  @override
  String get writeLockAfterWrite => 'Yazdıktan sonra kilitle';

  @override
  String get toolsTitle => 'Etiket araçları';
  @override
  String get toolsGroupSafe => 'Güvenli';
  @override
  String get toolsGroupContent => 'İçerik';
  @override
  String get toolsGroupConfig => 'Yapılandırma';
  @override
  String get toolsGroupIrreversible => 'Geri alınamaz';
  @override
  String get toolsExpertModeRequired =>
      'Bu araçlar için Ayarlar’dan uzman modunu açın.';

  @override
  String get historyEmptyTitle => 'Geçmiş boş';
  @override
  String get historyEmptyDescription =>
      'Okuduğunuz etiketler burada listelenir.';
  @override
  String get historyToday => 'Bugün';
  @override
  String get historyYesterday => 'Dün';
  @override
  String get historyThisWeek => 'Bu hafta';
  @override
  String get historyOlder => 'Daha eski';
  @override
  String get historySearchHint => 'UID, takma ad veya içerikte ara';
  @override
  String get historyFilterAll => 'Tümü';
  @override
  String get historyTabScans => 'Taramalar';
  @override
  String get historyTabDumps => 'Dökümler';
  @override
  String get historySetAlias => 'Takma ad ver';
  @override
  String get historyAliasDialogTitle => 'Takma ad';
  @override
  String get historyAliasHint => 'Örn. Ofis kapısı';
  @override
  String get historyLoadToWrite => 'Yazma ekranına yükle';
  @override
  String get historyLoadToWriteUnavailable =>
      'Bu kayıtta yüklenebilecek NDEF verisi yok';
  @override
  String get historyExportAll => 'Geçmişi dışa aktar';
  @override
  String get historyImportAll => 'Geçmişi içe aktar';
  @override
  String get historyNoExportsFound => 'Daha önce dışa aktarım bulunamadı';
  @override
  String get dumpArchiveEmptyTitle => 'Döküm arşivi boş';
  @override
  String get dumpArchiveEmptyDescription =>
      'Kaydedilen bellek dökümleri burada listelenir.';
  @override
  String get dumpRename => 'Yeniden adlandır';
  @override
  String get dumpExport => 'Dosyaya aktar';
  @override
  String historyExportSuccess(String path) => 'Dışa aktarıldı: $path';
  @override
  String historyImportSuccess(int count) => '$count kayıt içe aktarıldı';
  @override
  String dumpExportSuccess(String path) => 'Döküm dışa aktarıldı: $path';

  @override
  String get settingsTitle => 'Ayarlar';
  @override
  String get settingsAppearance => 'Görünüm';
  @override
  String get settingsTheme => 'Tema';
  @override
  String get settingsThemeSystem => 'Sistem';
  @override
  String get settingsThemeLight => 'Açık';
  @override
  String get settingsThemeDark => 'Koyu';
  @override
  String get settingsDynamicColor => 'Dinamik renk';
  @override
  String get settingsLanguage => 'Dil';
  @override
  String get settingsFeedback => 'Geri bildirim';
  @override
  String get settingsHaptic => 'Titreşim';
  @override
  String get settingsSound => 'Ses';
  @override
  String get settingsScanning => 'Tarama';
  @override
  String get settingsAutoSaveHistory => 'Taramaları geçmişe kaydet';
  @override
  String get settingsDeepRead => 'Derin okuma (yavaş, daha fazla bilgi)';
  @override
  String get settingsSafety => 'Güvenlik';
  @override
  String get settingsExpertMode => 'Uzman modu';
  @override
  String get settingsExpertModeDescription =>
      'Geri alınamaz araçları görünür yapar. Yanlış kullanım etiketi kalıcı '
      'olarak bozabilir.';
  @override
  String get settingsAutoBackup => 'Yıkıcı işlemlerden önce yedek al';
  @override
  String get settingsAbout => 'Hakkında';
  @override
  String get settingsVersion => 'Sürüm';
  @override
  String get settingsLicenses => 'Lisanslar';

  @override
  String get dangerIrreversible => 'BU İŞLEM GERİ ALINAMAZ';
  @override
  String get dangerSlideToConfirm => 'Onaylamak için kaydırın';
  @override
  String get dangerTakeBackup => 'Önce yedek al';

  @override
  String get errorNfcUnsupported => 'Bu cihazda NFC yok.';
  @override
  String get errorNfcDisabled => 'NFC kapalı. Ayarlardan açmanız gerekiyor.';
  @override
  String get errorNfcDisabledAction => 'NFC ayarlarını aç';
  @override
  String get errorTagLost =>
      'Etiket çekildi. Etiketi işlem bitene kadar sabit tutun.';
  @override
  String get errorTagNotSupported =>
      'Bu işlem bu etiket tipinde desteklenmiyor.';
  @override
  String get errorTagReadOnly => 'Etiket yazma korumalı.';
  @override
  String get errorAuthRequired => 'Bu işlem için etiketin şifresi gerekiyor.';
  @override
  String get errorAuthFailed => 'Şifre yanlış.';
  @override
  String get errorCancelled => 'İşlem iptal edildi.';
  @override
  String get errorTimeout => 'Süre doldu, etiket bulunamadı.';
  @override
  String get errorVerificationFailed =>
      'Yazma doğrulanamadı — etikette okunan veri yazılanla eşleşmiyor.';
  @override
  String get errorMalformedData => 'Etiketteki veri okunamadı veya bozuk.';
  @override
  String get errorStorage => 'Veri kaydedilemedi.';
  @override
  String get errorUnknown => 'Beklenmeyen bir hata oluştu.';
  @override
  String get errorNotImplemented => 'Bu özellik henüz hazır değil.';

  @override
  String errorInsufficientSpace(int needed, int available) => available < 0
      ? 'İçerik etikete sığmıyor.'
      : 'İçerik etikete sığmıyor: $needed byte gerekli, $available byte var.';
}
