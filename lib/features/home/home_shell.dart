import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../library/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../library/library_editor.dart';
import '../settings/settings_screen.dart';

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
    final pages = [const _LibrariesPage(), const SettingsScreen()];
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
                  NavigationRailDestination(icon: const Icon(Icons.video_library_outlined), selectedIcon: const Icon(Icons.video_library_rounded), label: Text(l.libraries)),
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
          NavigationDestination(icon: const Icon(Icons.video_library_outlined), selectedIcon: const Icon(Icons.video_library_rounded), label: l.libraries),
          NavigationDestination(icon: const Icon(Icons.tune_outlined), selectedIcon: const Icon(Icons.tune_rounded), label: l.settings),
        ],
      ),
    );
  }
}

class _LibrariesPage extends StatelessWidget {
  const _LibrariesPage();

  void _open(BuildContext context, [MediaLibrary? lib]) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => LibraryEditor(initial: lib)));

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final repo = context.services.libraries;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final libs = repo.libraries;
        if (libs.isEmpty) {
          return EmptyState(
            icon: Icons.video_library_outlined,
            title: l.homeEmptyTitle,
            body: l.homeEmptyBody,
            action: FilledButton.icon(
              autofocus: true,
              onPressed: () => _open(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l.addLibrary),
            ),
          );
        }
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.l, Space.s),
                child: Row(
                  children: [
                    if (!Breakpoints.isWide(context)) ...[const Wordmark(), const Spacer()]
                    else Expanded(child: Text(l.libraries, style: Theme.of(context).textTheme.headlineSmall)),
                    TextButton.icon(
                      onPressed: () => _open(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(l.addLibrary),
                    ),
                  ],
                ),
              ),
            ),
            SliverList.builder(
              itemCount: libs.length,
              itemBuilder: (context, i) => _LibrarySection(lib: libs[i], onEdit: () => _open(context, libs[i])),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.xxxl)),
          ],
        );
      },
    );
  }
}

class _LibrarySection extends StatelessWidget {
  const _LibrarySection({required this.lib, required this.onEdit});

  final MediaLibrary lib;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final t = Theme.of(context).textTheme;
    final kind = switch (lib.kind) {
      LibraryKind.movies => l.kindMovies,
      LibraryKind.shows => l.kindShows,
      LibraryKind.mixed => l.kindMixed,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.l, Space.xl, Space.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: lib.name, style: t.titleLarge),
                    TextSpan(text: '   $kind · ${lib.sources.length}', style: t.bodySmall),
                  ]),
                ),
              ),
              IconButton(onPressed: onEdit, icon: const Icon(Icons.more_horiz_rounded), tooltip: l.editLibrary),
            ],
          ),
          const SizedBox(height: Space.s),
          SizedBox(
            height: 150,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Palette.surface,
                borderRadius: BorderRadius.circular(Radii.m),
                border: Border.all(color: Palette.line),
              ),
              child: Text(l.nothingScanned, style: t.bodySmall),
            ),
          ),
        ],
      ),
    );
  }
}
