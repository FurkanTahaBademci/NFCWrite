import 'package:meta/meta.dart';

/// Tema tercihi.
enum ThemePreference { system, light, dark }

/// Dil tercihi.
enum LanguagePreference {
  system(null),
  turkish('tr'),
  english('en');

  const LanguagePreference(this.languageCode);

  /// BCP-47 dil kodu. Sistem tercihi icin null.
  final String? languageCode;
}

/// Uygulama ayarlari.
@immutable
final class AppSettings {
  const AppSettings({
    this.theme = ThemePreference.system,
    this.language = LanguagePreference.system,
    this.useDynamicColor = true,
    this.hapticFeedback = true,
    this.soundFeedback = true,
    this.autoSaveHistory = true,
    this.duplicateScanCooldown = const Duration(seconds: 3),
    this.expertMode = false,
    this.autoBackupBeforeDestructive = true,
    this.simplifyConfirmationsInExpertMode = false,
    this.readDeepByDefault = false,
  });

  final ThemePreference theme;
  final LanguagePreference language;

  /// Android 12+ dinamik renk kullanilsin mi?
  final bool useDynamicColor;

  final bool hapticFeedback;
  final bool soundFeedback;

  /// Her tarama otomatik olarak gecmise kaydedilsin mi?
  final bool autoSaveHistory;

  /// Ayni etiketin tekrar okunmasi icin beklenecek sure.
  final Duration duplicateScanCooldown;

  /// Uzman modu — geri alinamaz araclari gorunur yapar.
  ///
  /// Kapaliyken kilitleme, CFGLCK ve AUTHLIM arayuzde **hic gorunmez**.
  final bool expertMode;

  /// Yikici islemlerden once otomatik yedek alinsin mi?
  ///
  /// Varsayilan acik. Kapatmak kullanicinin acik tercihidir (ADR-0005).
  final bool autoBackupBeforeDestructive;

  /// Uzman modunda onay diyaloglari sadelestirilsin mi?
  ///
  /// Sadelestirilse bile uyari metni ve hedef UID gosterilmeye devam eder;
  /// yalnizca kaydirma hareketi tek dokunusa iner.
  final bool simplifyConfirmationsInExpertMode;

  /// Okuma varsayilan olarak tam bellek dokumu de alsin mi?
  ///
  /// Acikken okuma yavaslar ama daha fazla bilgi verir.
  final bool readDeepByDefault;

  AppSettings copyWith({
    ThemePreference? theme,
    LanguagePreference? language,
    bool? useDynamicColor,
    bool? hapticFeedback,
    bool? soundFeedback,
    bool? autoSaveHistory,
    Duration? duplicateScanCooldown,
    bool? expertMode,
    bool? autoBackupBeforeDestructive,
    bool? simplifyConfirmationsInExpertMode,
    bool? readDeepByDefault,
  }) => AppSettings(
    theme: theme ?? this.theme,
    language: language ?? this.language,
    useDynamicColor: useDynamicColor ?? this.useDynamicColor,
    hapticFeedback: hapticFeedback ?? this.hapticFeedback,
    soundFeedback: soundFeedback ?? this.soundFeedback,
    autoSaveHistory: autoSaveHistory ?? this.autoSaveHistory,
    duplicateScanCooldown: duplicateScanCooldown ?? this.duplicateScanCooldown,
    expertMode: expertMode ?? this.expertMode,
    autoBackupBeforeDestructive:
        autoBackupBeforeDestructive ?? this.autoBackupBeforeDestructive,
    simplifyConfirmationsInExpertMode:
        simplifyConfirmationsInExpertMode ??
        this.simplifyConfirmationsInExpertMode,
    readDeepByDefault: readDeepByDefault ?? this.readDeepByDefault,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.theme == theme &&
      other.language == language &&
      other.useDynamicColor == useDynamicColor &&
      other.hapticFeedback == hapticFeedback &&
      other.soundFeedback == soundFeedback &&
      other.autoSaveHistory == autoSaveHistory &&
      other.duplicateScanCooldown == duplicateScanCooldown &&
      other.expertMode == expertMode &&
      other.autoBackupBeforeDestructive == autoBackupBeforeDestructive &&
      other.simplifyConfirmationsInExpertMode ==
          simplifyConfirmationsInExpertMode &&
      other.readDeepByDefault == readDeepByDefault;

  @override
  int get hashCode => Object.hash(
    theme,
    language,
    useDynamicColor,
    hapticFeedback,
    soundFeedback,
    autoSaveHistory,
    duplicateScanCooldown,
    expertMode,
    autoBackupBeforeDestructive,
    simplifyConfirmationsInExpertMode,
    readDeepByDefault,
  );
}
