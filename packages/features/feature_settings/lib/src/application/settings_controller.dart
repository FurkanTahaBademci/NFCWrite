/// Ayarlar ozelliginin denetleyicisi ve servis yer tutucusu.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_core/nfc_core.dart';

const String _overrideHint =
    'apps/nfc_toolkit/lib/src/di/providers.dart icinde override edilmeli';

/// Uygulama ayarlari deposu.
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (ref) => throw UnimplementedError(_overrideHint),
    );

/// Guncel ayarlar.
///
/// Uygulamanin tamami bunu izler; tema ve dil degisikligi aninda yansir.
final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Ayarlari okuyup yazan denetleyici.
final class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final repository = ref.watch(settingsRepositoryProvider);

    // Depo disaridan degistirilirse (orn. veri temizleme) durumu tazele.
    final subscription = repository.changes.listen((settings) {
      state = settings;
    });
    ref.onDispose(subscription.cancel);

    return repository.current;
  }

  Future<void> update(AppSettings settings) async {
    state = settings;
    await ref.read(settingsRepositoryProvider).save(settings);
  }

  Future<void> setTheme(ThemePreference theme) =>
      update(state.copyWith(theme: theme));

  Future<void> setLanguage(LanguagePreference language) =>
      update(state.copyWith(language: language));

  Future<void> setDynamicColor({required bool value}) =>
      update(state.copyWith(useDynamicColor: value));

  Future<void> setHaptic({required bool value}) =>
      update(state.copyWith(hapticFeedback: value));

  Future<void> setSound({required bool value}) =>
      update(state.copyWith(soundFeedback: value));

  Future<void> setAutoSaveHistory({required bool value}) =>
      update(state.copyWith(autoSaveHistory: value));

  Future<void> setDeepRead({required bool value}) =>
      update(state.copyWith(readDeepByDefault: value));

  Future<void> setExpertMode({required bool value}) =>
      update(state.copyWith(expertMode: value));

  Future<void> setAutoBackup({required bool value}) =>
      update(state.copyWith(autoBackupBeforeDestructive: value));
}
