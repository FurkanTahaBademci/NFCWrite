import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:localization/localization.dart';

import '../update/update_dialog.dart';
import '../update/update_service.dart';

/// Alt gezinme cubugunu tasiyan kabuk.
///
/// Sekme durumlari `StatefulShellRoute.indexedStack` sayesinde korunur:
/// sekme degistirip geri donunce ekran sifirlanmaz.
class ShellPage extends StatefulWidget {
  const ShellPage({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  late final UpdateService _updateService = UpdateService();
  bool _hasCheckedForUpdate = false;

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasCheckedForUpdate) {
      return;
    }

    _hasCheckedForUpdate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.nfc_outlined),
            selectedIcon: const Icon(Icons.nfc),
            label: l10n.tabRead,
          ),
          NavigationDestination(
            icon: const Icon(Icons.edit_outlined),
            selectedIcon: const Icon(Icons.edit),
            label: l10n.tabWrite,
          ),
          NavigationDestination(
            icon: const Icon(Icons.handyman_outlined),
            selectedIcon: const Icon(Icons.handyman),
            label: l10n.tabTools,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: l10n.tabHistory,
          ),
        ],
      ),
    );
  }

  void _onDestinationSelected(int index) {
    // Ayni sekmeye tekrar dokunmak o sekmenin koküne doner.
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> _checkForUpdate() async {
    final result = await _updateService.checkForUpdate();
    if (!mounted || !result.hasUpdate) {
      return;
    }

    await showUpdateDialog(
      context: context,
      info: result.info!,
      currentVersion: result.currentVersion!,
      currentBuildNumber: result.currentBuildNumber!,
      service: _updateService,
    );
  }
}
