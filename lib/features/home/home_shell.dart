import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../settings/settings_screen.dart';
import 'home_page.dart';

/// Side rail on wide screens (TV, desktop, tablet), bottom bar on phones.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final wide = Breakpoints.isWide(context);
    final pages = [const HomePage(), const SettingsScreen()];
    final body = IndexedStack(index: _tab, children: pages);

    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                labelType: NavigationRailLabelType.all,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: Space.xl),
                  child: Wordmark(size: 16),
                ),
                destinations: [
                  NavigationRailDestination(icon: const Icon(Icons.video_library_outlined), selectedIcon: const Icon(Icons.video_library_rounded), label: Text(l.home)),
                  NavigationRailDestination(icon: const Icon(Icons.tune_outlined), selectedIcon: const Icon(Icons.tune_rounded), label: Text(l.settings)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.video_library_outlined), selectedIcon: const Icon(Icons.video_library_rounded), label: l.home),
          NavigationDestination(icon: const Icon(Icons.tune_outlined), selectedIcon: const Icon(Icons.tune_rounded), label: l.settings),
        ],
      ),
    );
  }
}
