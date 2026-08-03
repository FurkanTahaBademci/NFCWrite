import 'dart:async';

import 'package:nfc_core/nfc_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_utils/shared_utils.dart';

/// [SettingsRepository] arayuzunun `shared_preferences` uygulamasi.
///
/// Ayarlar acilista bir kez yuklenir ve bellekte tutulur; boylece
/// arayuz senkron olarak okuyabilir.
final class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._preferences);

  /// Ayar deposunu acar ve mevcut degerleri yukler.
  static Future<SettingsRepositoryImpl> open() async {
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepositoryImpl(preferences);
    await repository.load();
    return repository;
  }

  static const AppLogger _log = AppLogger('storage.settings');

  static const String _keyTheme = 'settings.theme';
  static const String _keyLanguage = 'settings.language';
  static const String _keyDynamicColor = 'settings.dynamicColor';
  static const String _keyHaptic = 'settings.haptic';
  static const String _keySound = 'settings.sound';
  static const String _keyAutoSaveHistory = 'settings.autoSaveHistory';
  static const String _keyDuplicateCooldown = 'settings.duplicateCooldownMs';
  static const String _keyExpertMode = 'settings.expertMode';
  static const String _keyAutoBackup = 'settings.autoBackup';
  static const String _keySimplifyConfirmations = 'settings.simplifyConfirm';
  static const String _keyReadDeep = 'settings.readDeep';

  final SharedPreferences _preferences;
  final StreamController<AppSettings> _changes =
      StreamController<AppSettings>.broadcast();

  AppSettings _current = const AppSettings();

  @override
  AppSettings get current => _current;

  @override
  Stream<AppSettings> get changes => _changes.stream;

  @override
  Future<Result<AppSettings>> load() async {
    try {
      const defaults = AppSettings();
      _current = AppSettings(
        theme: _readEnum(_keyTheme, ThemePreference.values, defaults.theme),
        language: _readEnum(
          _keyLanguage,
          LanguagePreference.values,
          defaults.language,
        ),
        useDynamicColor:
            _preferences.getBool(_keyDynamicColor) ?? defaults.useDynamicColor,
        hapticFeedback:
            _preferences.getBool(_keyHaptic) ?? defaults.hapticFeedback,
        soundFeedback:
            _preferences.getBool(_keySound) ?? defaults.soundFeedback,
        autoSaveHistory:
            _preferences.getBool(_keyAutoSaveHistory) ??
            defaults.autoSaveHistory,
        duplicateScanCooldown: Duration(
          milliseconds:
              _preferences.getInt(_keyDuplicateCooldown) ??
              defaults.duplicateScanCooldown.inMilliseconds,
        ),
        expertMode: _preferences.getBool(_keyExpertMode) ?? defaults.expertMode,
        autoBackupBeforeDestructive:
            _preferences.getBool(_keyAutoBackup) ??
            defaults.autoBackupBeforeDestructive,
        simplifyConfirmationsInExpertMode:
            _preferences.getBool(_keySimplifyConfirmations) ??
            defaults.simplifyConfirmationsInExpertMode,
        readDeepByDefault:
            _preferences.getBool(_keyReadDeep) ?? defaults.readDeepByDefault,
      );
      return Ok(_current);
    } on Object catch (e, s) {
      _log.error('Ayarlar yuklenemedi', e, s);
      return Err(StorageError('Ayarlar yuklenemedi', cause: e));
    }
  }

  @override
  Future<Result<void>> save(AppSettings settings) async {
    try {
      await Future.wait([
        _preferences.setString(_keyTheme, settings.theme.name),
        _preferences.setString(_keyLanguage, settings.language.name),
        _preferences.setBool(_keyDynamicColor, settings.useDynamicColor),
        _preferences.setBool(_keyHaptic, settings.hapticFeedback),
        _preferences.setBool(_keySound, settings.soundFeedback),
        _preferences.setBool(_keyAutoSaveHistory, settings.autoSaveHistory),
        _preferences.setInt(
          _keyDuplicateCooldown,
          settings.duplicateScanCooldown.inMilliseconds,
        ),
        _preferences.setBool(_keyExpertMode, settings.expertMode),
        _preferences.setBool(
          _keyAutoBackup,
          settings.autoBackupBeforeDestructive,
        ),
        _preferences.setBool(
          _keySimplifyConfirmations,
          settings.simplifyConfirmationsInExpertMode,
        ),
        _preferences.setBool(_keyReadDeep, settings.readDeepByDefault),
      ]);
      _current = settings;
      _changes.add(settings);
      return okVoid;
    } on Object catch (e, s) {
      _log.error('Ayarlar kaydedilemedi', e, s);
      return Err(StorageError('Ayarlar kaydedilemedi', cause: e));
    }
  }

  /// Kaynaklari birakir. Uygulama kapanirken cagrilir.
  Future<void> dispose() => _changes.close();

  T _readEnum<T extends Enum>(String key, List<T> values, T fallback) {
    final stored = _preferences.getString(key);
    if (stored == null) return fallback;
    for (final value in values) {
      if (value.name == stored) return value;
    }
    return fallback;
  }
}
