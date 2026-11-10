import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../library/items.dart';
import '../../metadata/tmdb.dart';
import '../../ui/media_cards.dart';
import '../../ui/theme.dart';
import '../player/player_screen.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.titleKey});

  final String titleKey;

  static Future<void> open(BuildContext context, String key) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(titleKey: key)));

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  int? _season;
  final _seasonData = <int, Map<int, Map<String, dynamic>>>{};

  Future<void> _loadSeason(TitleEntry t, int season) async {
    if (t.tmdbId == null || _seasonData.containsKey(season)) return;
    _seasonData[season] = {};
    final client = context.services.sync.tmdb(Localizations.localeOf(context).languageCode);
    if (client == null) return;
    try {
      final r = await client.season(t.tmdbId!, season);
      final eps = <int, Map<String, dynamic>>{
        for (final e in (r['episodes'] as List? ?? const []).cast<Map<String, dynamic>>())
          (e['episode_number'] as num).toInt(): e,
      };
      if (mounted) setState(() => _seasonData[season] = eps);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final t = s.store.title(widget.titleKey);
        if (t == null) return const Scaffold();
        final eps = s.store.episodesOf(t.key);
        final seasons = {for (final e in eps) e.season ?? 1}.toList()..sort();
        final season = _season ?? (s.store.lastWatchedOf(t.key)?.season ?? (seasons.isEmpty ? 1 : seasons.first));
        if (t.kind == ItemKind.tv) _loadSeason(t, season);
        final seasonEps = eps.where((e) => (e.season ?? 1) == season).toList();

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            actions: [
              if (t.kind != ItemKind.other)
                IconButton(
                  tooltip: L.of(context).fixMatch,
                  icon: const Icon(Icons.manage_search_rounded),
                  onPressed: () => _fixMatch(context, t),
                ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(title: t, episodes: eps)),
              if (t.kind == ItemKind.tv && seasons.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 56,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: _pad(context), vertical: Space.s),
                      children: [
                        for (final n in seasons)
                          Padding(
                            padding: const EdgeInsets.only(right: Space.s),
                            child: ChoiceChip(
                              label: Text(L.of(context).seasonN(n)),
                              selected: n == season,
                              onSelected: (_) => setState(() => _season = n),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (t.kind == ItemKind.tv)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(_pad(context), Space.m, _pad(context), Space.xxxl),
                  sliver: SliverList.separated(
                    itemCount: seasonEps.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Space.l),
                    itemBuilder: (context, i) => _EpisodeRow(
                      title: t,
                      item: seasonEps[i],
                      meta: _seasonData[season]?[seasonEps[i].episode],
                    ),
                  ),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: Space.xxxl)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fixMatch(BuildContext context, TitleEntry t) async {
    final hit = await showModalBottomSheet<TmdbHit>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MatchSheet(title: t),
    );
    if (hit != null && context.mounted) context.services.sync.chooseMatch(t, hit);
  }
}

double _pad(BuildContext c) => Breakpoints.isWide(c) ? Space.xxl : Space.xl;

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.episodes});

  final TitleEntry title;
  final List<MediaItem> episodes;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final l = L.of(context);
    final tt = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);
    final wide = Breakpoints.isWide(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final last = s.store.lastWatchedOf(title.key);
    final lastP = last == null ? null : s.store.progressOf(last.id);
    final MediaItem? target = switch (last) {
      null => episodes.isEmpty ? null : episodes.first,
      final MediaItem x when lastP?.resumable ?? false => x,
      final MediaItem x when lastP?.finished ?? false => s.store.nextEpisode(x) ?? x,
      _ => episodes.isEmpty ? null : episodes.first,
    };
    final resume = target != null && (s.store.progressOf(target.id)?.resumable ?? false);
    final versions = title.kind == ItemKind.tv || target == null ? const <MediaItem>[] : s.store.versionsOf(target.episodeKey);

    final meta = [
      if (title.displayYear != null) '${title.displayYear}',
      title.kind == ItemKind.tv ? l.series : l.movie,
      if (title.kind == ItemKind.tv) l.episodesCount(episodes.length),
      if (title.kind != ItemKind.tv && target != null && target.label.isNotEmpty) target.label,
      if (title.needsReview) l.needsReview,
    ].join('  ·  ');

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title.displayName, style: tt.displaySmall?.copyWith(fontSize: wide ? 38 : 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: Space.s),
        Text(meta, style: tt.labelLarge?.copyWith(color: Palette.textDim)),
        if (title.overview.isNotEmpty) ...[
          const SizedBox(height: Space.m),
          Text(title.overview, maxLines: 5, overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium?.copyWith(color: Palette.text.withValues(alpha: 0.85))),
        ],
        const SizedBox(height: Space.l),
        Wrap(
          spacing: Space.m,
          runSpacing: Space.s,
          children: [
            if (target != null)
              FilledButton.icon(
                autofocus: true,
                onPressed: () => PlayerScreen.open(context, target),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(resume
                    ? (title.kind == ItemKind.tv && target.episode != null
                        ? '${l.resume} · ${l.episodeCode(target.season ?? 1, target.episode!)}'
                        : l.resume)
                    : l.play),
              ),
            if (resume)
              OutlinedButton(
                onPressed: () => PlayerScreen.open(context, target, startOver: true),
                child: Text(l.startOver),
              ),
            if (versions.length > 1)
              OutlinedButton.icon(
                onPressed: () => showVersions(context, versions),
                icon: const Icon(Icons.layers_outlined, size: 18),
                label: Text(l.versionsCount(versions.length)),
              ),
          ],
        ),
      ],
    );

    final height = wide ? (size.height * 0.62).clamp(420.0, 640.0) : (size.width * 1.1).clamp(420.0, 560.0);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TmdbImage(
            title.backdropPath,
            size: wide ? 'w1280' : 'w780',
            decodeWidth: (size.width * dpr).round(),
            fallback: const ColoredBox(color: Palette.surface),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99141312), Color(0x33141312), Color(0xCC141312), Palette.bg],
                stops: [0, 0.3, 0.7, 1],
              ),
            ),
          ),
          if (wide)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xEE141312), Color(0x00141312)], stops: [0.1, 0.7]),
              ),
            ),
          Positioned(
            left: _pad(context),
            right: _pad(context),
            bottom: Space.xl,
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 180,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.m),
                          child: AspectRatio(
                            aspectRatio: 2 / 3,
                            child: TmdbImage(title.posterPath, decodeWidth: (180 * dpr).round(),
                                fallback: TitleFallback(title.displayName)),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.xxl),
                      Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: info)),
                    ],
                  )
                : info,
          ),
        ],
      ),
    );
  }
}

Future<void> showVersions(BuildContext context, List<MediaItem> versions) => showModalBottomSheet<void>(
      context: context,
      builder: (c) {
        final l = L.of(c);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.s),
                child: Text(l.versions, style: Theme.of(c).textTheme.titleMedium),
              ),
              for (final (i, v) in versions.indexed)
                ListTile(
                  autofocus: i == 0,
                  leading: const Icon(Icons.play_arrow_rounded),
                  title: Text(v.label.isEmpty ? v.fileName : v.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${v.fileName}\n${_sizeText(v.size)}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.pop(c);
                    PlayerScreen.open(context, v);
                  },
                ),
              const SizedBox(height: Space.l),
            ],
          ),
        );
      },
    );

String _sizeText(int b) {
  if (b <= 0) return '';
  if (b >= 1 << 30) return '${(b / (1 << 30)).toStringAsFixed(2)} GB';
  return '${(b / (1 << 20)).round()} MB';
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.title, required this.item, this.meta});

  final TitleEntry title;
  final MediaItem item;
  final Map<String, dynamic>? meta;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final l = L.of(context);
    final tt = Theme.of(context).textTheme;
    final p = s.store.progressOf(item.id);
    final versions = s.store.versionsOf(item.episodeKey);
    final name = '${meta?['name'] ?? ''}';
    final overview = '${meta?['overview'] ?? ''}';
    final runtime = (meta?['runtime'] as num?)?.toInt() ?? (item.duration > 0 ? item.duration ~/ 60 : 0);
    final wide = Breakpoints.isWide(context);
    final thumbW = wide ? 260.0 : 150.0;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final heading = [
      l.episodeN(item.episode ?? 0),
      if (name.isNotEmpty) name,
    ].join(' · ');
    final sub = [
      if (runtime > 0) l.minutes(runtime),
      if (versions.length > 1) l.versionsCount(versions.length) else if (item.label.isNotEmpty) item.label,
    ].join('  ·  ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: thumbW,
          child: Pressable(
            onTap: () => PlayerScreen.open(context, item),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TmdbImage(
                    (meta?['still_path'] as String?) ?? title.backdropPath,
                    size: 'w300',
                    decodeWidth: (thumbW * dpr).round(),
                    fallback: TitleFallback(l.episodeN(item.episode ?? 0)),
                  ),
                  const Center(child: Icon(Icons.play_arrow_rounded, size: 32, color: Color(0xDDFFFFFF))),
                  if (p != null)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: LinearProgressIndicator(
                        value: p.finished ? 1 : p.fraction,
                        minHeight: 3,
                        backgroundColor: const Color(0x33FFFFFF),
                        color: p.finished ? Palette.textDim : Palette.accent,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: Space.l),
        Expanded(
          child: GestureDetector(
            onLongPress: versions.length > 1 ? () => showVersions(context, versions) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.titleMedium),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: tt.bodySmall),
                ],
                if (overview.isNotEmpty) ...[
                  const SizedBox(height: Space.xs),
                  Text(overview, maxLines: wide ? 3 : 2, overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: Palette.textDim)),
                ],
                if (versions.length > 1)
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                    onPressed: () => showVersions(context, versions),
                    child: Text(l.versions),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MatchSheet extends StatefulWidget {
  const _MatchSheet({required this.title});

  final TitleEntry title;

  @override
  State<_MatchSheet> createState() => _MatchSheetState();
}

class _MatchSheetState extends State<_MatchSheet> {
  late final _q = TextEditingController(text: widget.title.name);
  late List<TmdbHit> _hits = [
    for (final c in widget.title.candidates)
      TmdbHit.fromJson(
        {
          ...c,
          widget.title.kind == ItemKind.tv ? 'name' : 'title': c['title'],
          widget.title.kind == ItemKind.tv ? 'original_name' : 'original_title': c['original_title'],
          widget.title.kind == ItemKind.tv ? 'first_air_date' : 'release_date':
              c['year'] == null ? '' : '${c['year']}-01-01',
        },
        widget.title.kind == ItemKind.tv ? MediaKind.tv : MediaKind.movie,
      ),
  ];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final client = context.services.sync.tmdb(Localizations.localeOf(context).languageCode);
    if (client == null) {
      setState(() => _error = L.of(context).tmdbMissing);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await client.search(widget.title.kind == ItemKind.tv ? MediaKind.tv : MediaKind.movie, _q.text.trim());
      if (mounted) setState(() => _hits = r);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.s),
                child: TextField(
                  controller: _q,
                  autofocus: _hits.isEmpty,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: l.searchTmdb,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward_rounded)),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(Space.l),
                  child: Text(_error!, style: const TextStyle(color: Palette.danger)),
                ),
              Expanded(
                child: _hits.isEmpty && !_busy
                    ? Center(child: Text(l.noResults, style: Theme.of(context).textTheme.bodySmall))
                    : ListView.builder(
                        itemCount: _hits.length,
                        itemBuilder: (context, i) {
                          final h = _hits[i];
                          return ListTile(
                            autofocus: i == 0,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(Radii.s),
                              child: SizedBox(
                                width: 40,
                                height: 60,
                                child: TmdbImage(h.posterPath, size: 'w92', decodeWidth: (40 * dpr).round(),
                                    fallback: const ColoredBox(color: Palette.surfaceHigh)),
                              ),
                            ),
                            title: Text(h.title),
                            subtitle: Text([
                              if (h.year != null) '${h.year}',
                              if (h.originalTitle.isNotEmpty && h.originalTitle != h.title) h.originalTitle,
                            ].join(' · ')),
                            onTap: () => Navigator.pop(context, h),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
