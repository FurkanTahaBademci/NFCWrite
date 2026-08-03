import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:localization/localization.dart';

/// Alt gezinme cubugunu tasiyan kabuk.
///
/// Sekme durumlari `StatefulShellRoute.indexedStack` sayesinde korunur:
/// sekme degistirip geri donunce ekran sifirlanmaz.
class ShellPage extends StatelessWidget {
  const ShellPage({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
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
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
