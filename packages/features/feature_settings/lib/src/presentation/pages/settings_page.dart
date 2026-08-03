import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localization/localization.dart';
import 'package:nfc_core/nfc_core.dart';

import '../../application/settings_controller.dart';

/// Ayarlar ekrani.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          SectionHeader(l10n.settingsAppearance),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l10n.settingsTheme),
            trailing: SegmentedButton<ThemePreference>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemePreference.system,
                  label: Text(l10n.settingsThemeSystem),
                ),
                const ButtonSegment(
                  value: ThemePreference.light,
                  icon: Icon(Icons.light_mode_outlined),
                ),
                const ButtonSegment(
                  value: ThemePreference.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {settings.theme},
              onSelectionChanged: (selection) =>
                  controller.setTheme(selection.first),
            ),
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.color_lens_outlined),
            title: Text(l10n.settingsDynamicColor),
            value: settings.useDynamicColor,
            onChanged: (value) => controller.setDynamicColor(value: value),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.settingsLanguage),
            trailing: DropdownButton<LanguagePreference>(
              value: settings.language,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: LanguagePreference.system,
                  child: Text('Sistem'),
                ),
                DropdownMenuItem(
                  value: LanguagePreference.turkish,
                  child: Text('Turkce'),
                ),
                DropdownMenuItem(
                  value: LanguagePreference.english,
                  child: Text('English'),
                ),
              ],
              onChanged: (value) {
                if (value != null) controller.setLanguage(value);
              },
            ),
          ),

          SectionHeader(l10n.settingsFeedback),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.vibration),
            title: Text(l10n.settingsHaptic),
            value: settings.hapticFeedback,
            onChanged: (value) => controller.setHaptic(value: value),
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(l10n.settingsSound),
            value: settings.soundFeedback,
            onChanged: (value) => controller.setSound(value: value),
          ),

          SectionHeader(l10n.settingsScanning),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.history),
            title: Text(l10n.settingsAutoSaveHistory),
            value: settings.autoSaveHistory,
            onChanged: (value) => controller.setAutoSaveHistory(value: value),
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.travel_explore),
            title: Text(l10n.settingsDeepRead),
            value: settings.readDeepByDefault,
            onChanged: (value) => controller.setDeepRead(value: value),
          ),

          SectionHeader(l10n.settingsSafety),
          SwitchListTile.adaptive(
            secondary: Icon(
              Icons.science_outlined,
              color: settings.expertMode
                  ? AppColors.forRisk(
                      RiskLevel.danger,
                      Theme.of(context).brightness,
                    )
                  : null,
            ),
            title: Text(l10n.settingsExpertMode),
            subtitle: Text(l10n.settingsExpertModeDescription),
            isThreeLine: true,
            value: settings.expertMode,
            onChanged: (value) =>
                _toggleExpertMode(context, controller, enable: value),
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.backup_outlined),
            title: Text(l10n.settingsAutoBackup),
            value: settings.autoBackupBeforeDestructive,
            onChanged: (value) => controller.setAutoBackup(value: value),
          ),

          SectionHeader(l10n.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsVersion),
            subtitle: const Text('0.1.0'),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l10n.settingsLicenses),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appName,
              applicationVersion: '0.1.0',
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _toggleExpertMode(
    BuildContext context,
    SettingsController controller, {
    required bool enable,
  }) async {
    if (!enable) {
      await controller.setExpertMode(value: false);
      return;
    }

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(l10n.settingsExpertMode),
        content: Text(l10n.settingsExpertModeDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Anladim, ac'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await controller.setExpertMode(value: true);
    }
  }
}
