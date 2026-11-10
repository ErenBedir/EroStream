import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../library/items.dart';
import '../../library/models.dart';
import '../../ui/media_cards.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../detail/detail_screen.dart';
import '../library/library_editor.dart';
import '../library/library_grid.dart';
import '../player/player_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static void openLibraryEditor(BuildContext context, [MediaLibrary? lib]) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => LibraryEditor(initial: lib)));

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final l = L.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([s.libraries, s.store, s.sync, s.telegram]),
      builder: (context, _) {
        final libs = s.libraries.libraries;
        if (libs.isEmpty) {
          return EmptyState(
            icon: Icons.video_library_outlined,
            title: l.homeEmptyTitle,
            body: l.homeEmptyBody,
            action: FilledButton.icon(
              autofocus: true,
              onPressed: () => openLibraryEditor(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l.addLibrary),
            ),
          );
        }

        final cont = s.store.continueWatching();
        final shelves = [
          for (final lib in libs) (lib, s.store.titlesOfLibrary(lib.id)),
        ].where((e) => e.$2.isNotEmpty).toList();
        final review = s.store.titles.where((t) => t.needsReview).toList();
        final featured = _featured(s, cont, shelves.expand((e) => e.$2));

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: featured == null
                  ? _TopBar(onRefresh: () => _refresh(context), solid: true)
                  : _Hero(title: featured, onRefresh: () => _refresh(context)),
            ),
            if (s.sync.running)
              SliverToBoxAdapter(child: _SyncLine(text: l.scanning(s.sync.status))),
            if (shelves.isEmpty && !s.sync.running)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(Space.xxl),
                  child: Text(
                    s.telegram.isReady ? l.noVideosFound : l.signInToScan,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Palette.textDim),
                  ),
                ),
              ),
            if (s.settings.tmdbKey.isEmpty && shelves.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.xxl, Space.l, Space.xxl, 0),
                  child: Text(l.tmdbMissing, style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            if (cont.isNotEmpty)
              SliverToBoxAdapter(
                child: Shelf(
                  title: l.continueWatching,
                  height: 230,
                  children: [
                    for (final it in cont) _ContinueCard(item: it),
                  ],
                ),
              ),
            for (final (lib, titles) in shelves)
              SliverToBoxAdapter(
                child: Shelf(
                  title: l.recentlyAdded(lib.name),
                  height: 262,
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => LibraryGrid(library: lib))),
                    child: Text(l.seeAll),
                  ),
                  children: [
                    for (final t in titles.take(24))
                      PosterCard(title: t, onTap: () => DetailScreen.open(context, t.key)),
                  ],
                ),
              ),
            if (review.isNotEmpty)
              SliverToBoxAdapter(
                child: Shelf(
                  title: l.matchReview,
                  height: 262,
                  children: [
                    for (final t in review.take(24))
                      PosterCard(title: t, onTap: () => DetailScreen.open(context, t.key)),
                  ],
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xxl, Space.xxl, Space.xxxl),
                child: Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    for (final lib in libs)
                      ActionChip(
                        avatar: const Icon(Icons.tune_rounded, size: 16),
                        label: Text(lib.name),
                        onPressed: () => openLibraryEditor(context, lib),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: Text(l.addLibrary),
                      onPressed: () => openLibraryEditor(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _refresh(BuildContext context) =>
      context.services.sync.syncAll(uiLanguage: Localizations.localeOf(context).languageCode);

  /// Title of the last watched item if it has art, else the newest title with a backdrop.
  static TitleEntry? _featured(Services s, List<MediaItem> cont, Iterable<TitleEntry> recent) {
    for (final it in cont) {
      final t = s.store.title(it.titleKey);
      if (t?.backdropPath != null) return t;
    }
    for (final t in recent) {
      if (t.backdropPath != null) return t;
    }
    return recent.isEmpty ? null : recent.first;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onRefresh, this.solid = false});

  final VoidCallback onRefresh;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final wide = Breakpoints.isWide(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? Space.xxl : Space.xl, Space.l, Space.l, Space.s),
      child: Row(
        children: [
          if (!wide) const Wordmark(),
          const Spacer(),
          IconButton(onPressed: onRefresh, tooltip: l.refresh, icon: const Icon(Icons.refresh_rounded)),
          IconButton(
            onPressed: () => HomePage.openLibraryEditor(context),
            tooltip: l.addLibrary,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.onRefresh});

  final TitleEntry title;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final l = L.of(context);
    final t = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);
    final wide = Breakpoints.isWide(context);
    final height = (size.width * (wide ? 0.42 : 0.9)).clamp(380.0, 620.0);
    final last = s.store.lastWatchedOf(title.key);
    final resume = last != null && (s.store.progressOf(last.id)?.resumable ?? false);
    final eps = s.store.episodesOf(title.key);
    final meta = [
      if (title.displayYear != null) '${title.displayYear}',
      title.kind == ItemKind.tv ? l.series : l.movie,
      if (title.kind == ItemKind.tv) l.episodesCount(eps.length),
    ].join('  ·  ');

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TmdbImage(
            title.backdropPath,
            size: wide ? 'w1280' : 'w780',
            decodeWidth: (size.width * MediaQuery.devicePixelRatioOf(context)).round(),
            fallback: const ColoredBox(color: Palette.surface),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99141312), Color(0x00141312), Color(0xB3141312), Palette.bg],
                stops: [0, 0.3, 0.75, 1],
              ),
            ),
          ),
          if (wide)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xE6141312), Color(0x00141312)],
                  stops: [0, 0.65],
                ),
              ),
            ),
          Align(alignment: Alignment.topCenter, child: _TopBar(onRefresh: onRefresh)),
          Positioned(
            left: wide ? Space.xxl : Space.xl,
            right: Space.xl,
            bottom: Space.xl,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.displaySmall?.copyWith(fontSize: wide ? 40 : 30, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: Space.s),
                  Text(meta, style: t.labelLarge?.copyWith(color: Palette.textDim)),
                  if (title.overview.isNotEmpty) ...[
                    const SizedBox(height: Space.m),
                    Text(
                      title.overview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium?.copyWith(color: Palette.text.withValues(alpha: 0.85)),
                    ),
                  ],
                  const SizedBox(height: Space.l),
                  Row(
                    children: [
                      FilledButton.icon(
                        autofocus: true,
                        onPressed: () {
                          final item = last ?? (eps.isEmpty ? null : eps.first);
                          if (item != null) PlayerScreen.open(context, item);
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(resume ? l.resume : l.play),
                      ),
                      const SizedBox(width: Space.m),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(backgroundColor: const Color(0x33000000)),
                        onPressed: () => DetailScreen.open(context, title.key),
                        child: Text(l.details),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final l = L.of(context);
    final t = s.store.title(item.titleKey);
    final p = s.store.progressOf(item.id);
    return LandscapeCard(
      imagePath: t?.backdropPath,
      title: t?.displayName ?? item.fileName,
      fallbackTitle: t?.displayName ?? item.fileName,
      subtitle: item.kind == ItemKind.tv && item.episode != null ? l.episodeCode(item.season ?? 1, item.episode!) : '',
      progress: p?.fraction ?? 0,
      onTap: () => PlayerScreen.open(context, item),
    );
  }
}

class _SyncLine extends StatelessWidget {
  const _SyncLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.xxl, Space.s, Space.xxl, 0),
        child: Row(
          children: [
            const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      );
}
