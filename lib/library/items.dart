/// Scanned files, grouped titles and watch progress.
library;

enum ItemKind { tv, movie, other }

/// One playable file (a Telegram message or a local file).
class MediaItem {
  const MediaItem({
    required this.id,
    required this.libraryId,
    required this.sourceKey,
    required this.titleKey,
    required this.kind,
    required this.fileName,
    this.chatId = 0,
    this.messageId = 0,
    this.topicId = 0,
    this.path = '',
    this.size = 0,
    this.duration = 0,
    this.season,
    this.episode,
    this.episodeEnd,
    this.label = '',
    this.date = 0,
  });

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        id: j['id'] as String,
        libraryId: j['lib'] as String,
        sourceKey: j['src'] as String,
        titleKey: j['t'] as String,
        kind: ItemKind.values.asNameMap()[j['k']] ?? ItemKind.other,
        fileName: '${j['n'] ?? ''}',
        chatId: (j['c'] as num?)?.toInt() ?? 0,
        messageId: (j['m'] as num?)?.toInt() ?? 0,
        topicId: (j['tp'] as num?)?.toInt() ?? 0,
        path: '${j['p'] ?? ''}',
        size: (j['sz'] as num?)?.toInt() ?? 0,
        duration: (j['d'] as num?)?.toInt() ?? 0,
        season: (j['s'] as num?)?.toInt(),
        episode: (j['e'] as num?)?.toInt(),
        episodeEnd: (j['e2'] as num?)?.toInt(),
        label: '${j['l'] ?? ''}',
        date: (j['dt'] as num?)?.toInt() ?? 0,
      );

  /// `tg:<chat>:<message>` or `local:<path>`.
  final String id;
  final String libraryId;
  final String sourceKey;

  /// Groups episodes / versions into one title, see [TitleEntry.key].
  final String titleKey;
  final ItemKind kind;
  final String fileName;
  final int chatId;
  final int messageId;
  final int topicId;
  final String path;
  final int size;

  /// Seconds, 0 = unknown.
  final int duration;
  final int? season;
  final int? episode;
  final int? episodeEnd;

  /// Version label, e.g. `1080p NF DUAL`.
  final String label;

  /// Unix seconds (message date or file mtime).
  final int date;

  bool get isTelegram => chatId != 0;

  /// Same episode in different versions shares this key.
  String get episodeKey => '$titleKey|${season ?? 0}|${episode ?? 0}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'lib': libraryId,
        'src': sourceKey,
        't': titleKey,
        'k': kind.name,
        'n': fileName,
        if (chatId != 0) 'c': chatId,
        if (messageId != 0) 'm': messageId,
        if (topicId != 0) 'tp': topicId,
        if (path.isNotEmpty) 'p': path,
        if (size != 0) 'sz': size,
        if (duration != 0) 'd': duration,
        if (season != null) 's': season,
        if (episode != null) 'e': episode,
        if (episodeEnd != null) 'e2': episodeEnd,
        if (label.isNotEmpty) 'l': label,
        if (date != 0) 'dt': date,
      };
}

/// A show or movie built from one or more items, optionally matched to TMDB.
class TitleEntry {
  TitleEntry({
    required this.key,
    required this.kind,
    required this.name,
    this.year,
    this.tmdbId,
    this.tmdbTitle,
    this.posterPath,
    this.backdropPath,
    this.overview = '',
    this.tmdbYear,
    this.score = 0,
    this.locked = false,
    this.matchedAt = 0,
    this.candidates = const [],
  });

  factory TitleEntry.fromJson(Map<String, dynamic> j) => TitleEntry(
        key: j['key'] as String,
        kind: ItemKind.values.asNameMap()[j['kind']] ?? ItemKind.other,
        name: '${j['name'] ?? ''}',
        year: (j['year'] as num?)?.toInt(),
        tmdbId: (j['tmdb'] as num?)?.toInt(),
        tmdbTitle: j['tmdb_title'] as String?,
        posterPath: j['poster'] as String?,
        backdropPath: j['backdrop'] as String?,
        overview: '${j['overview'] ?? ''}',
        tmdbYear: (j['tmdb_year'] as num?)?.toInt(),
        score: (j['score'] as num?)?.toDouble() ?? 0,
        locked: j['locked'] == true,
        matchedAt: (j['matched_at'] as num?)?.toInt() ?? 0,
        candidates: [
          for (final c in (j['cands'] as List? ?? const [])) (c as Map).cast<String, dynamic>(),
        ],
      );

  /// `tv:<folded show>`, `movie:<folded title>:<year>`, `other:<folded name>`.
  final String key;
  final ItemKind kind;

  /// Name from the file / topic.
  String name;
  int? year;
  int? tmdbId;
  String? tmdbTitle;
  String? posterPath;
  String? backdropPath;
  String overview;
  int? tmdbYear;
  double score;

  /// Set by a manual choice; never re-matched automatically.
  bool locked;

  /// Unix seconds of the last match attempt, 0 = never tried.
  int matchedAt;

  /// Top TMDB candidates for low-confidence matches (TmdbHit JSON).
  List<Map<String, dynamic>> candidates;

  String get displayName => tmdbTitle?.isNotEmpty == true ? tmdbTitle! : name;
  int? get displayYear => tmdbYear ?? year;
  bool get needsReview => tmdbId == null && candidates.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'key': key,
        'kind': kind.name,
        'name': name,
        if (year != null) 'year': year,
        if (tmdbId != null) 'tmdb': tmdbId,
        if (tmdbTitle != null) 'tmdb_title': tmdbTitle,
        if (posterPath != null) 'poster': posterPath,
        if (backdropPath != null) 'backdrop': backdropPath,
        if (overview.isNotEmpty) 'overview': overview,
        if (tmdbYear != null) 'tmdb_year': tmdbYear,
        if (score != 0) 'score': double.parse(score.toStringAsFixed(3)),
        if (locked) 'locked': true,
        if (matchedAt != 0) 'matched_at': matchedAt,
        if (candidates.isNotEmpty) 'cands': candidates,
      };
}

class WatchProgress {
  const WatchProgress({required this.position, required this.duration, required this.updatedAt});

  factory WatchProgress.fromJson(Map<String, dynamic> j) => WatchProgress(
        position: (j['p'] as num).toInt(),
        duration: (j['d'] as num?)?.toInt() ?? 0,
        updatedAt: (j['u'] as num?)?.toInt() ?? 0,
      );

  /// Seconds.
  final int position;
  final int duration;
  final int updatedAt;

  double get fraction => duration <= 0 ? 0 : (position / duration).clamp(0, 1).toDouble();

  /// Past 92 % counts as watched.
  bool get finished => duration > 0 && position >= duration * 0.92;

  /// Worth resuming: started and not finished.
  bool get resumable => position > 30 && !finished;

  Map<String, dynamic> toJson() => {'p': position, 'd': duration, 'u': updatedAt};
}
