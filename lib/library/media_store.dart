import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'items.dart';
import 'store_backend.dart';

/// In-memory index of scanned items, titles and progress, persisted as JSON.
class MediaStore extends ChangeNotifier {
  MediaStore({StoreBackend? backend}) : _backend = backend ?? createStoreBackend();

  final StoreBackend _backend;
  final Map<String, MediaItem> _items = {};
  final Map<String, TitleEntry> _titles = {};
  final Map<String, WatchProgress> _progress = {};
  Timer? _saveTimer;
  bool loaded = false;

  Future<void> load() async {
    try {
      final raw = await _backend.read();
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        for (final i in (j['items'] as List? ?? const [])) {
          final it = MediaItem.fromJson((i as Map).cast<String, dynamic>());
          _items[it.id] = it;
        }
        for (final t in (j['titles'] as List? ?? const [])) {
          final te = TitleEntry.fromJson((t as Map).cast<String, dynamic>());
          _titles[te.key] = te;
        }
        for (final e in ((j['progress'] as Map?) ?? const {}).entries) {
          _progress['${e.key}'] = WatchProgress.fromJson((e.value as Map).cast<String, dynamic>());
        }
      }
    } catch (e) {
      debugPrint('item store unreadable: $e');
    }
    loaded = true;
    notifyListeners();
  }

  void _changed({bool save = true}) {
    notifyListeners();
    if (!save) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    final data = jsonEncode({
      'v': 1,
      'items': [for (final i in _items.values) i.toJson()],
      'titles': [for (final t in _titles.values) t.toJson()],
      'progress': {for (final e in _progress.entries) e.key: e.value.toJson()},
    });
    await _backend.write(data);
  }

  // ---- queries -------------------------------------------------------------

  bool get isEmpty => _items.isEmpty;
  MediaItem? item(String id) => _items[id];
  TitleEntry? title(String key) => _titles[key];
  WatchProgress? progressOf(String itemId) => _progress[itemId];
  Iterable<TitleEntry> get titles => _titles.values;

  List<MediaItem> itemsOfTitle(String key) {
    final list = _items.values.where((i) => i.titleKey == key).toList()..sort(_episodeOrder);
    return list;
  }

  /// Titles that have items in [libraryId], newest first.
  List<TitleEntry> titlesOfLibrary(String libraryId) {
    final latest = <String, int>{};
    for (final i in _items.values) {
      if (i.libraryId != libraryId) continue;
      final d = latest[i.titleKey] ?? 0;
      if (i.date > d || !latest.containsKey(i.titleKey)) latest[i.titleKey] = i.date;
    }
    final keys = latest.keys.toList()..sort((a, b) => latest[b]!.compareTo(latest[a]!));
    return [for (final k in keys) if (_titles[k] != null) _titles[k]!];
  }

  int itemCountOfLibrary(String libraryId) => _items.values.where((i) => i.libraryId == libraryId).length;

  /// Last started, unfinished item per title.
  List<MediaItem> continueWatching({int limit = 20}) {
    final entries = _progress.entries.where((e) => e.value.resumable && _items.containsKey(e.key)).toList()
      ..sort((a, b) => b.value.updatedAt.compareTo(a.value.updatedAt));
    final seen = <String>{};
    final out = <MediaItem>[];
    for (final e in entries) {
      final it = _items[e.key]!;
      if (seen.add(it.titleKey)) out.add(it);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Most recently watched item of a title (finished or not).
  MediaItem? lastWatchedOf(String titleKey) {
    MediaItem? best;
    var at = -1;
    for (final e in _progress.entries) {
      final it = _items[e.key];
      if (it == null || it.titleKey != titleKey) continue;
      if (e.value.updatedAt > at) {
        at = e.value.updatedAt;
        best = it;
      }
    }
    return best;
  }

  /// Next episode after [item] (different season/episode), best version.
  MediaItem? nextEpisode(MediaItem item) {
    if (item.kind != ItemKind.tv) return null;
    final eps = itemsOfTitle(item.titleKey);
    final cur = (item.season ?? 0) * 100000 + (item.episodeEnd ?? item.episode ?? 0);
    for (final e in eps) {
      final n = (e.season ?? 0) * 100000 + (e.episode ?? 0);
      if (n > cur) return preferredVersion(e.episodeKey);
    }
    return null;
  }

  /// Versions of one episode / movie, largest file first (usually best quality).
  List<MediaItem> versionsOf(String episodeKey) =>
      _items.values.where((i) => i.episodeKey == episodeKey).toList()..sort((a, b) => b.size.compareTo(a.size));

  /// The version with progress, otherwise the largest one.
  MediaItem? preferredVersion(String episodeKey) {
    final v = versionsOf(episodeKey);
    if (v.isEmpty) return null;
    for (final i in v) {
      if (_progress.containsKey(i.id)) return i;
    }
    return v.first;
  }

  /// One item per episode (preferred version), in episode order.
  List<MediaItem> episodesOf(String titleKey) {
    final seen = <String>{};
    final out = <MediaItem>[];
    for (final i in itemsOfTitle(titleKey)) {
      if (seen.add(i.episodeKey)) out.add(preferredVersion(i.episodeKey)!);
    }
    return out;
  }

  static int _episodeOrder(MediaItem a, MediaItem b) {
    final s = (a.season ?? 0).compareTo(b.season ?? 0);
    if (s != 0) return s;
    final e = (a.episode ?? 0).compareTo(b.episode ?? 0);
    if (e != 0) return e;
    return b.size.compareTo(a.size);
  }

  // ---- updates -------------------------------------------------------------

  /// Adds or replaces items. Titles are created on first sight.
  void putItems(Iterable<MediaItem> items, Map<String, TitleEntry> newTitles) {
    for (final t in newTitles.values) {
      _titles.putIfAbsent(t.key, () => t);
    }
    for (final i in items) {
      _items[i.id] = i;
    }
    _changed();
  }

  /// Drops every item of a source (source removed or full rescan).
  void removeSource(String libraryId, String sourceKey) {
    _items.removeWhere((_, i) => i.libraryId == libraryId && i.sourceKey == sourceKey);
    _pruneTitles();
    _changed();
  }

  void removeLibrary(String libraryId) {
    _items.removeWhere((_, i) => i.libraryId == libraryId);
    _pruneTitles();
    _changed();
  }

  void _pruneTitles() {
    final used = {for (final i in _items.values) i.titleKey};
    _titles.removeWhere((k, _) => !used.contains(k));
  }

  void updateTitle(TitleEntry t) {
    _titles[t.key] = t;
    _changed();
  }

  void setProgress(String itemId, int position, int duration) {
    _progress[itemId] = WatchProgress(
      position: position,
      duration: duration,
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    _changed();
  }

  void clearProgress(String itemId) {
    if (_progress.remove(itemId) != null) _changed();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
