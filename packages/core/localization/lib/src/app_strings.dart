/// Uygulamadaki tum metinlerin sozlesmesi.
///
/// Kod uretimi (gen-l10n) kullanmiyoruz; bu sinif elle yazilir.
/// Gerekce: `.claude/docs/adr/ADR-0003-no-codegen.md`
///
/// **Yeni metin eklerken:** once buraya `abstract` getter ekle. Turkce ve
/// Ingilizce siniflar derlenmez hale gelir; ikisini de doldurunca gecer.
/// Boylece ceviri unutulamaz.
///
/// Terim sozlugu (tutarlilik icin — TR tarafinda hep bunlari kullan):
///   tag = etiket · dump = bellek dokumu · lock = kilitleme
///   format = bicimlendirme · record = kayit · payload = yuk
abstract class AppStrings {
  const AppStrings();

  /// BCP-47 dil kodu.
  String get languageCode;

  // --- Uygulama ---
  String get appName;

  // --- Sekmeler ---
  String get tabRead;
  String get tabWrite;
  String get tabTools;
  String get tabHistory;

  // --- Genel eylemler ---
  String get actionCancel;
  String get actionRetry;
  String get actionDone;
  String get actionSave;
  String get actionDelete;
  String get actionCopy;
  String get actionShare;
  String get actionClose;
  String get actionSettings;
  String get actionScan;

  // --- Tarama ---
  String get scanTitle;
  String get scanHint;
  String get scanFound;
  String get scanWorking;
  String get scanSuccess;
  String get scanFailed;

  // --- Okuma ekrani ---
  String get readEmptyTitle;
  String get readEmptyDescription;
  String get readSectionIdentity;
  String get readSectionNdef;
  String get readSectionMemory;
  String get readSectionTechnical;
  String get readUid;
  String get readUidReversed;
  String get readUidDecimal;
  String get readChip;
  String get readManufacturer;
  String get readTechnologies;
  String get readCapacity;
  String get readWritable;
  String get readReadOnly;
  String get readFormatted;
  String get readNotFormatted;
  String get readPasswordProtected;
  String get readNoRecords;

  // --- Okuma: kayit eylemleri (A10) ---
  String get readActionOpenLink;
  String get readActionCall;
  String get readActionEmail;
  String get readActionSms;
  String get readActionMap;
  String get readActionWifiInfo;
  String get readActionShareContact;
  String get readWifiDialogTitle;
  String get readWifiSsid;
  String get readWifiPassword;
  String get readWifiSecurity;
  String get readActionFailed;

  // --- Okuma: surekli mod (A17) ---
  String get readContinuousStart;
  String get readContinuousStop;
  String get readContinuousTitle;
  String get readContinuousHint;
  String readContinuousCount(int count);

  // --- Okuma: disa aktarma (A18) ---
  String get readShareJson;
  String get readShareResult;

  // --- Yazma ekrani ---
  String get writeEmptyTitle;
  String get writeEmptyDescription;
  String get writeAddRecord;
  String get writeAction;
  String get writeLockAfterWrite;

  // --- Araclar ---
  String get toolsTitle;
  String get toolsGroupSafe;
  String get toolsGroupContent;
  String get toolsGroupConfig;
  String get toolsGroupIrreversible;
  String get toolsExpertModeRequired;

  // --- Gecmis ---
  String get historyEmptyTitle;
  String get historyEmptyDescription;
  String get historyToday;
  String get historyYesterday;
  String get historyThisWeek;
  String get historyOlder;
  String get historySearchHint;
  String get historyFilterAll;
  String get historyTabScans;
  String get historyTabDumps;
  String get historySetAlias;
  String get historyAliasDialogTitle;
  String get historyAliasHint;
  String get historyLoadToWrite;
  String get historyLoadToWriteUnavailable;
  String get historyExportAll;
  String get historyImportAll;
  String get historyNoExportsFound;
  String get dumpArchiveEmptyTitle;
  String get dumpArchiveEmptyDescription;
  String get dumpRename;
  String get dumpExport;

  /// "Dışa aktarıldı: /path/to/file.json"
  String historyExportSuccess(String path);

  /// "12 kayıt içe aktarıldı"
  String historyImportSuccess(int count);

  /// "Döküm dışa aktarıldı: /path/to/file.json"
  String dumpExportSuccess(String path);

  // --- Ayarlar ---
  String get settingsTitle;
  String get settingsAppearance;
  String get settingsTheme;
  String get settingsThemeSystem;
  String get settingsThemeLight;
  String get settingsThemeDark;
  String get settingsDynamicColor;
  String get settingsLanguage;
  String get settingsFeedback;
  String get settingsHaptic;
  String get settingsSound;
  String get settingsScanning;
  String get settingsAutoSaveHistory;
  String get settingsDeepRead;
  String get settingsSafety;
  String get settingsExpertMode;
  String get settingsExpertModeDescription;
  String get settingsAutoBackup;
  String get settingsAbout;
  String get settingsVersion;
  String get settingsLicenses;

  // --- Onay ---
  String get dangerIrreversible;
  String get dangerSlideToConfirm;
  String get dangerTakeBackup;

  // --- Hatalar ---
  String get errorNfcUnsupported;
  String get errorNfcDisabled;
  String get errorNfcDisabledAction;
  String get errorTagLost;
  String get errorTagNotSupported;
  String get errorTagReadOnly;
  String get errorAuthRequired;
  String get errorAuthFailed;
  String get errorCancelled;
  String get errorTimeout;
  String get errorVerificationFailed;
  String get errorMalformedData;
  String get errorStorage;
  String get errorUnknown;
  String get errorNotImplemented;

  /// "Icerik sigmiyor: 180 byte gerekli, 144 byte var"
  String errorInsufficientSpace(int needed, int available);
}
