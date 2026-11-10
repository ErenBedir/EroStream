import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/settings.dart';
import '../metadata/tmdb.dart';
import '../telegram/td_client.dart';
import '../telegram/telegram_service.dart';
import 'items.dart';
import 'library_repository.dart';
import 'media_store.dart';
import 'models.dart';
import 'telegram_scan.dart';

/// Scans sources and matches titles to TMDB. One run at a time.
class SyncService extends ChangeNotifier {
  SyncService({required this.settings, required this.telegram, required this.libraries, required this.store});

  final Settings settings;
  final TelegramService telegram;
  final LibraryRepository libraries;
  final MediaStore store;

  bool running = false;
  String status = '';
  int found = 0;
  String? lastError;
  TmdbClient? _tmdb;
  String _tmdbSig = '';

  TmdbClient? tmdb(String uiLanguage) {
    final key = settings.tmdbKey;
    if (key.isEmpty) return null;
    final lang = settings.tmdbLanguage.isNotEmpty ? settings.tmdbLanguage : _tmdbLanguage(uiLanguage);
    final sig = '$key|$lang';
    if (_tmdb == null || sig != _tmdbSig) {
      _tmdb?.close();
      _tmdb = TmdbClient(key: key, language: lang);
      _tmdbSig = sig;
    }
    return _tmdb;
  }

  static String _tmdbLanguage(String code) => switch (code) {
        'tr' => 'tr-TR',
        'en' => 'en-US',
        'de' => 'de-DE',
        'fr' => 'fr-FR',
        'es' => 'es-ES',
        'pt' => 'pt-BR',
        _ => code.isEmpty ? 'en-US' : code,
      };

  void _status(String s) {
    status = s;
    notifyListeners();
  }

  Future<void> syncAll({required String uiLanguage}) async {
    if (running) return;
    running = true;
    lastError = null;
    found = 0;
    notifyListeners();
    try {
      for (final lib in libraries.libraries) {
        await _syncLibrary(lib.id);
      }
      await matchPending(uiLanguage: uiLanguage);
    } catch (e) {
      lastError = '$e';
    } finally {
      running = false;
      status = '';
      notifyListeners();
      unawaited(store.flush());
    }
  }

  Future<void> _syncLibrary(String libraryId) async {
    final lib = libraries.libraries.where((l) => l.id == libraryId).firstOrNull;
    if (lib == null) return;
    for (final src in lib.sources) {
      // The library may have been edited or deleted meanwhile.
      final current = libraries.libraries.where((l) => l.id == libraryId).firstOrNull;
      if (current == null) return;
      if (src is TelegramSource && telegram.isReady && current.sources.any((x) => x.key == src.key)) {
        try {
          await _syncTelegram(current, src);
        } on TdError catch (e) {
          lastError = '${src.title}: ${e.message}';
        }
      }
    }
  }

  Future<void> _syncTelegram(MediaLibrary lib, TelegramSource src) async {
    _status(src.title);
    final topicNames = <int, String>{};
    final general = <int>{};
    if (src.isForum) {
      for (final t in await telegram.listTopics(src.chatId)) {
        topicNames[t.id] = t.name;
        if (t.isGeneral) general.add(t.id);
      }
    }
    final files = <int, TgFile>{};
    var maxId = src.lastMessageId;
    for (final filter in const ['searchMessagesFilterVideo', 'searchMessagesFilterDocument']) {
      var from = 0;
      for (var page = 0; page < 2000; page++) {
        final r = await telegram.client.send({
          '@type': 'searchChatMessages',
          'chat_id': src.chatId,
          'topic_id': null,
          'query': '',
          'sender_id': null,
          'from_message_id': from,
          'offset': 0,
          'limit': 100,
          'filter': {'@type': filter},
        });
        final msgs = (r['messages'] as List).cast<Map<String, dynamic>>();
        var reachedOld = false;
        for (final m in msgs) {
          final id = (m['id'] as num).toInt();
          if (id <= src.lastMessageId) {
            reachedOld = true;
            continue;
          }
          if (id > maxId) maxId = id;
          final f = tgFileFromMessage(m);
          if (f != null) files[f.messageId] = f;
        }
        found = files.length;
        _status('${src.title} · ${files.length}');
        from = (r['next_from_message_id'] as num?)?.toInt() ?? 0;
        if (reachedOld || from == 0 || msgs.isEmpty) break;
      }
    }

    if (files.isNotEmpty) {
      final batch = classifyTelegram(
        files: files.values.toList(),
        source: src,
        libraryId: lib.id,
        topicNames: topicNames,
        generalTopics: general,
        maxEpisode: (key) => store
            .itemsOfTitle(key)
            .where((i) => (i.season ?? 1) == 1)
            .fold<int>(0, (m, i) => (i.episode ?? 0) > m ? i.episode! : m),
      );
      store.putItems(batch.items, batch.titles);
    }
    if (maxId != src.lastMessageId) {
      final current = libraries.libraries.where((l) => l.id == lib.id).firstOrNull;
      if (current != null) {
        await libraries.upsert(current.copyWith(sources: [
          for (final s in current.sources) s.key == src.key && s is TelegramSource ? s.copyWith(lastMessageId: maxId) : s,
        ]));
      }
    }
  }

  /// Matches titles never tried before (and retries old misses after a week).
  Future<void> matchPending({required String uiLanguage}) async {
    final client = tmdb(uiLanguage);
    if (client == null) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final todo = store.titles
        .where((t) =>
            t.kind != ItemKind.other &&
            !t.locked &&
            t.tmdbId == null &&
            (t.matchedAt == 0 || now - t.matchedAt > 7 * 86400))
        .toList();
    for (var i = 0; i < todo.length; i++) {
      final t = todo[i];
      _status('TMDB ${i + 1}/${todo.length}');
      try {
        final r = await client.match(
          t.kind == ItemKind.tv ? MediaKind.tv : MediaKind.movie,
          t.name,
          year: t.year,
        );
        t.matchedAt = now;
        if (r.isConfident) {
          _apply(t, r.best!.hit, r.best!.score);
        } else {
          t.candidates = [for (final c in r.candidates.take(3)) {...c.hit.toJson(), 'score': c.score}];
          store.updateTitle(t);
        }
      } on TmdbException catch (e) {
        lastError = 'TMDB: $e';
        if (e.status == 401) return;
      } catch (e) {
        lastError = 'TMDB: $e';
      }
    }
  }

  void _apply(TitleEntry t, TmdbHit hit, double score, {bool manual = false}) {
    t
      ..tmdbId = hit.id
      ..tmdbTitle = hit.title
      ..tmdbYear = hit.year
      ..posterPath = hit.posterPath
      ..backdropPath = hit.backdropPath
      ..overview = hit.overview
      ..score = score
      ..candidates = const []
      ..locked = manual || t.locked;
    store.updateTitle(t);
  }

  /// Manual choice from the review list or search.
  void chooseMatch(TitleEntry t, TmdbHit hit) => _apply(t, hit, 1, manual: true);

  @override
  void dispose() {
    _tmdb?.close();
    super.dispose();
  }
}
