import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'title_match.dart';

enum MediaKind { movie, tv }

class TmdbHit {
  const TmdbHit({
    required this.id,
    required this.kind,
    required this.title,
    required this.originalTitle,
    this.year,
    this.posterPath,
    this.backdropPath,
    this.overview = '',
    this.popularity = 0,
  });

  factory TmdbHit.fromJson(Map<String, dynamic> j, MediaKind kind) {
    final date = '${j[kind == MediaKind.tv ? 'first_air_date' : 'release_date'] ?? ''}';
    return TmdbHit(
      id: (j['id'] as num).toInt(),
      kind: kind,
      title: '${j[kind == MediaKind.tv ? 'name' : 'title'] ?? ''}',
      originalTitle: '${j[kind == MediaKind.tv ? 'original_name' : 'original_title'] ?? ''}',
      year: date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null,
      posterPath: j['poster_path'] as String?,
      backdropPath: j['backdrop_path'] as String?,
      overview: '${j['overview'] ?? ''}',
      popularity: (j['popularity'] as num?)?.toDouble() ?? 0,
    );
  }

  final int id;
  final MediaKind kind;
  final String title;
  final String originalTitle;
  final int? year;
  final String? posterPath;
  final String? backdropPath;
  final String overview;
  final double popularity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'original_title': originalTitle,
        'year': year,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        'overview': overview,
        'popularity': popularity,
      };
}

class ScoredHit {
  const ScoredHit(this.hit, this.score);

  final TmdbHit hit;
  final double score;
}

class MatchResult {
  const MatchResult(this.candidates);

  /// Best first, at most 5.
  final List<ScoredHit> candidates;

  ScoredHit? get best => candidates.isEmpty ? null : candidates.first;

  bool get isConfident => (best?.score ?? 0) >= autoMatchThreshold;
}

class TmdbException implements Exception {
  TmdbException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => 'TMDB $status: $message';
}

class TmdbClient {
  TmdbClient({required this.key, this.language = 'en-US', http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const imageBase = 'https://image.tmdb.org/t/p/';

  final String key;
  String language;
  final http.Client _http;
  final _cache = <String, Object>{};

  bool get isConfigured => key.isNotEmpty;

  /// v4 read access tokens are JWTs; anything else is treated as a v3 api_key.
  bool get _bearer => key.startsWith('eyJ');

  static String image(String? path, {String size = 'w342'}) => path == null ? '' : '$imageBase$size$path';

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query) async {
    final q = {...query, 'language': language, if (!_bearer) 'api_key': key};
    final uri = Uri.https('api.themoviedb.org', '/3$path', q);
    final cacheKey = uri.toString();
    final hit = _cache[cacheKey];
    if (hit is Map<String, dynamic>) return hit;
    final res = await _http.get(uri, headers: {
      'Accept': 'application/json',
      if (_bearer) 'Authorization': 'Bearer $key',
    });
    if (res.statusCode == 429) {
      await Future<void>.delayed(const Duration(seconds: 2));
      return _get(path, query);
    }
    if (res.statusCode != 200) {
      throw TmdbException(res.statusCode, res.body.length > 200 ? res.body.substring(0, 200) : res.body);
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    _cache[cacheKey] = body;
    return body;
  }

  Future<List<TmdbHit>> search(MediaKind kind, String query, {int? year}) async {
    final params = {'query': query, 'include_adult': 'false', 'page': '1'};
    if (year != null) params[kind == MediaKind.tv ? 'first_air_date_year' : 'primary_release_year'] = '$year';
    final r = await _get(kind == MediaKind.tv ? '/search/tv' : '/search/movie', params);
    return (r['results'] as List).cast<Map<String, dynamic>>().map((j) => TmdbHit.fromJson(j, kind)).toList();
  }

  Future<Map<String, dynamic>> details(MediaKind kind, int id) =>
      _get(kind == MediaKind.tv ? '/tv/$id' : '/movie/$id', const {});

  Future<Map<String, dynamic>> season(int tvId, int season) => _get('/tv/$tvId/season/$season', const {});

  /// Finds the TMDB entry for a parsed show/movie name.
  ///
  /// Tries every title candidate, with and without the year, and scores each
  /// result against the local and original title.
  Future<MatchResult> match(MediaKind kind, String name, {int? year}) async {
    final cands = titleCandidates(name);
    year ??= cands.year;
    final queries = cands.queries.isEmpty ? [name] : cands.queries;
    final seen = <int, ScoredHit>{};

    Future<void> run(String q, int? y) async {
      for (final h in await search(kind, q, year: y)) {
        final s = scoreHit(h, queries, year: year);
        final prev = seen[h.id];
        if (prev == null || prev.score < s) seen[h.id] = ScoredHit(h, s);
      }
    }

    for (final q in queries.take(4)) {
      if (year != null) await run(q, year);
      if (year == null || !_hasConfident(seen)) await run(q, null);
      if (_hasConfident(seen)) break;
    }
    final list = seen.values.toList()..sort((a, b) => b.score.compareTo(a.score));
    return MatchResult(list.take(5).toList());
  }

  static bool _hasConfident(Map<int, ScoredHit> m) => m.values.any((s) => s.score >= 0.97);

  void close() => _http.close();
}

/// 0..1. Title similarity dominates; year and popularity only break ties.
double scoreHit(TmdbHit h, List<String> queries, {int? year}) {
  var best = 0.0;
  for (final q in queries) {
    best = math.max(best, titleSimilarity(q, h.title));
    if (h.originalTitle.isNotEmpty) best = math.max(best, titleSimilarity(q, h.originalTitle));
  }
  if (year != null && h.year != null) {
    final d = (year - h.year!).abs();
    if (d == 0) {
      best += 0.05;
    } else if (d == 1) {
      best += 0.02;
    } else {
      // A show's file year can be a later season; movies should match closely.
      best -= h.kind == MediaKind.movie ? 0.15 : 0.04;
    }
  }
  best += math.min(math.log(h.popularity + 1) / math.ln10 / 100, 0.03);
  return best.clamp(0.0, 1.0).toDouble();
}
