/// Turns Telegram / local file names into show+episode or movie+year.
///
/// Rules were tuned on a 73k-entry channel dump. Supported episode forms:
/// `S01E05`, `S01E01-02`, `S0101`, `1x05`, `S02B03`, `S01 BL02`,
/// `1.Sezon 4.Bolum`, `41.BLM`, `E07`, `Name - 1008`.
library;

import 'fold.dart';

const _ext = r'(?:mkv|mp4|avi|m4v|ts|mov|webm|wmv|flv|mpg|mpeg)';

const videoExtensions = <String>[
  '.mkv', '.mp4', '.avi', '.m4v', '.ts', '.mov', '.webm', '.wmv', '.flv', '.mpg', '.mpeg',
];

const subtitleExtensions = <String>['.srt', '.ass', '.ssa', '.vtt', '.sub'];

final _junk = RegExp(
  r'(?<![^\s\-\[\(])(?:'
  r'm?(?:2160|1080|720|576|480|360)[pi]|4k|uhd|hdr10?\+?|xvid|divx|'
  r'web[\s\-]?dl|webrip|blu[\s\-]?ray|bdrip|brrip|hdtv|dvdrip|hdrip|remux|'
  r'nf|amzn|dsnp|dsny|atvp|hmax|blutv|exxen|tod|tabii|tab[iİ]{2}|tv\+|bein|mubi|dsgo|puhutv|pcok|trt|'
  r'x26[45]|h\s?26[45]|hevc|avc|aac[\d.]*|ac3|eac3|ddp?[\d.+]*|dd\+[\d.]*|dts|atmos|truehd|'
  r'dual|dua?l|multi|triple|trsub|tr\s?altyaz[iı]l?[iı]?|altyaz[iı]|t[uü]rk[cç]e|dublaj|yerli|sans[uü]rs[uü]z|'
  r'repack|proper|unrated|remastered|internal|10bit|8bit'
  r')(?![^\s\-\]\)\.])',
  caseSensitive: false,
);

final _tags = RegExp(
  r'(-\s*\[archived by[^\]]*\]-|#\s*turkseed|turkseed\.com|\[?hdt\]?$|bitturk|\[[^\]]*\]|\{[^}]*\})',
  caseSensitive: false,
);

final _pSE = RegExp(
  r'\bS0?(\d{1,2})\s?[\.\-]?\s?(?:E|BL|B|x)\s?(\d{1,4})(?:(?:\s?-\s?E?|E)(\d{1,4}))?\b|\bS(\d{2})(\d{2})\b|\b(\d{1,2})x(\d{2,3})\b',
  caseSensitive: false,
);
final _pBL = RegExp(r'(?:^|\s)BL\s?(\d{1,4})\b', caseSensitive: false);
final _pDash = RegExp(r'^(.+?\D)\s-\s(\d{1,4})\b');
final _pTrSE = RegExp(
  r'\b(\d{1,2})\s?\.?\s?Sezon\s?(\d{1,4})\s?\.?\s?(?:B[öo]l[üu]m|BLM)\b',
  caseSensitive: false,
);
final _pTrB = RegExp(
  r'\b(\d{1,4})\s?\.?\s?(?:B[öo]l[üu]m|BLM)\b|\bB[öo]l[üu]m\s?(\d{1,4})\b',
  caseSensitive: false,
);
final _pTrS = RegExp(r'\b(\d{1,2})\s?\.?\s?Sezon\b', caseSensitive: false);
final _pE = RegExp(r'(?:^|\s|-)(?:E|Ep|Episode|B)\s?(\d{1,4})\b', caseSensitive: false);
final _pYear = RegExp(r'\b((?:19[2-9]|20[0-3])\d)\b');
final _yearOnly = RegExp(r'^(?:19[2-9]|20[0-3])\d$');

sealed class ParsedName {
  const ParsedName(this.clean);

  /// File name after cleanup (separators normalized, extension removed).
  final String clean;

  Map<String, Object?> toJson();
}

class ParsedEpisode extends ParsedName {
  const ParsedEpisode({
    required this.show,
    required this.season,
    required this.episode,
    this.episodeEnd,
    required String clean,
  }) : super(clean);

  final String show;
  final int season;
  final int episode;

  /// Last episode for multi-episode files (`S01E01-02`).
  final int? episodeEnd;

  @override
  Map<String, Object?> toJson() =>
      {'kind': 'tv', 'show': show, 's': season, 'e': episode, 'e2': episodeEnd};
}

class ParsedMovie extends ParsedName {
  const ParsedMovie({required this.title, required this.year, required String clean})
      : super(clean);

  final String title;
  final String year;

  @override
  Map<String, Object?> toJson() => {'kind': 'movie', 'title': title, 'year': year};
}

class ParsedOther extends ParsedName {
  const ParsedOther({required this.title, required String clean}) : super(clean);

  final String title;

  @override
  Map<String, Object?> toJson() => {'kind': 'other', 'title': title};
}

bool isVideoName(String? name) {
  if (name == null || name.isEmpty) return false;
  final l = name.toLowerCase();
  return videoExtensions.any(l.endsWith);
}

bool isSubtitleName(String? name) {
  if (name == null || name.isEmpty) return false;
  final l = name.toLowerCase();
  return subtitleExtensions.any(l.endsWith);
}

/// Python-style `str.strip(chars)`.
String stripChars(String s, String chars) {
  var a = 0, b = s.length;
  while (a < b && chars.contains(s[a])) {
    a++;
  }
  while (b > a && chars.contains(s[b - 1])) {
    b--;
  }
  return s.substring(a, b);
}

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

String cleanRaw(String? raw) {
  var t = (raw ?? '').replaceAll('**', ' ').replaceAll('`', ' ');
  t = t.replaceAll(RegExp(r'-\s*\[archived by[^\]]*\]-', caseSensitive: false), ' ');
  final m = RegExp(r'\.' + _ext + r'\b', caseSensitive: false).firstMatch(t);
  if (m != null) {
    t = t.substring(0, m.end);
  } else {
    t = t.trim().split('\n').first.replaceFirst(RegExp(r'\s{2,}.*$'), '');
  }
  t = t.replaceAll(RegExp(r'https?://\S+'), '');
  final slash = t.lastIndexOf('/');
  if (slash >= 0) t = t.substring(slash + 1);
  t = t.trim().replaceFirst(RegExp(r'\.' + _ext + r'$', caseSensitive: false), '');
  t = t.replaceAll(RegExp(r'\.?turkseed\.com', caseSensitive: false), '');
  return stripChars(t, '_ ').trim();
}

String separators(String t) {
  t = t.replaceAllMapped(RegExp(r'(?<!\d)\.|\.(?!\d)'), (_) => ' ');
  t = t.replaceAllMapped(RegExp(r'(?<=\d)\.(?=[A-Za-zÇĞİÖŞÜçğıöşü])'), (_) => '. ');
  t = t.replaceAll('_', ' ');
  return _squash(t).trim();
}

const _titleStrip = ' -–_.,:;([';

String tidyTitle(String s) {
  s = s.replaceAll(_tags, ' ');
  final m = _junk.firstMatch(s);
  if (m != null && m.start > 0) s = s.substring(0, m.start);
  s = s.replaceAll(RegExp(r'#\S*'), '');
  s = s.replaceFirst(RegExp(r'^\d{1,4}\s*-\s*(?=\D)'), '');
  s = stripChars(_squash(s), _titleStrip);
  final tail = RegExp(r'(?:\s|-)+(?:BL|BLM|B[öo]l[üu]m|Episode|Ep|Sezon|Season)$', caseSensitive: false);
  for (var i = 0; i < 3; i++) {
    s = stripChars(s.replaceFirst(tail, ''), _titleStrip);
  }
  return s;
}

/// `'Name (2019)'` -> `('Name', '2019')`.
(String, String?) splitYear(String s) {
  final m = RegExp(r'\(?\b((?:19[2-9]|20[0-3])\d)\b\)?\s*$').firstMatch(s);
  if (m != null && m.start > 0) {
    return (stripChars(s.substring(0, m.start), ' -('), m.group(1));
  }
  return (s, null);
}

/// Cleans show names that carry an episode title or year:
/// `'Mammals - Memeli Canlilar -Karanlik- (2024)'` -> `('Mammals - Memeli Canlilar', '2024')`.
(String, String?) showBase(String name) {
  var (n, y) = splitYear(name);
  n = n.replaceAll(RegExp(r'\s*\((?:19|20)\d\d\)\s*'), ' ').trim();
  final m = RegExp(r'^(.*?\S)\s+-\S.*$').firstMatch(n);
  if (m != null) n = stripChars(m.group(1)!, ' -');
  return (n, y);
}

(int, int, int?) _seGroups(RegExpMatch m) {
  if (m.group(1) != null) {
    return (int.parse(m.group(1)!), int.parse(m.group(2)!), m.group(3) == null ? null : int.parse(m.group(3)!));
  }
  if (m.group(4) != null) return (int.parse(m.group(4)!), int.parse(m.group(5)!), null);
  return (int.parse(m.group(6)!), int.parse(m.group(7)!), null);
}

ParsedName parseName(String? raw) {
  final t = separators(cleanRaw(raw));

  var m = _pSE.firstMatch(t);
  if (m != null && m.start > 0) {
    final (s, e, e2raw) = _seGroups(m);
    final e2 = (e2raw != null && e2raw > e) ? e2raw : null;
    return ParsedEpisode(show: tidyTitle(t.substring(0, m.start)), season: s, episode: e, episodeEnd: e2, clean: t);
  }

  m = _pTrSE.firstMatch(t);
  if (m != null && m.start > 0) {
    return ParsedEpisode(
      show: tidyTitle(t.substring(0, m.start)),
      season: int.parse(m.group(1)!),
      episode: int.parse(m.group(2)!),
      clean: t,
    );
  }

  m = _pTrB.firstMatch(t);
  if (m != null) {
    final e = int.parse(m.group(1) ?? m.group(2)!);
    var pre = t.substring(0, m.start);
    final sm = _pTrS.firstMatch(pre);
    final s = sm != null ? int.parse(sm.group(1)!) : 1;
    if (sm != null) pre = pre.substring(0, sm.start);
    if (tidyTitle(pre).isNotEmpty) {
      return ParsedEpisode(show: tidyTitle(pre), season: s, episode: e, clean: t);
    }
  }

  for (final rx in [_pBL, _pDash]) {
    final mm = rx.firstMatch(t);
    final isDash = identical(rx, _pDash);
    if (mm != null && (mm.start > 0 || isDash)) {
      final pre = isDash ? mm.group(1)! : t.substring(0, mm.start);
      final ep = isDash ? mm.group(2)! : mm.group(1)!;
      if (tidyTitle(pre).isNotEmpty && !_yearOnly.hasMatch(ep)) {
        return ParsedEpisode(show: tidyTitle(pre), season: 1, episode: int.parse(ep), clean: t);
      }
    }
  }

  m = _pE.firstMatch(t);
  if (m != null && m.start > 0 && tidyTitle(t.substring(0, m.start)).isNotEmpty) {
    return ParsedEpisode(
      show: tidyTitle(t.substring(0, m.start)),
      season: 1,
      episode: int.parse(m.group(1)!),
      clean: t,
    );
  }

  final title = tidyTitle(t);
  final ys = _pYear.allMatches(t).where((y) => y.start > 0).toList();
  if (ys.isNotEmpty) {
    var y = ys.last;
    for (final cand in ys) {
      if (tidyTitle(t.substring(0, cand.start)).isNotEmpty && cand.start >= title.length - 6) {
        y = cand;
        break;
      }
    }
    final name = tidyTitle(t.substring(0, y.start));
    if (name.isNotEmpty) return ParsedMovie(title: name, year: y.group(1)!, clean: t);
  }
  return ParsedOther(title: title.isNotEmpty ? title : t, clean: t);
}

/// Forum topics already name the show; only season/episode is read from the file name.
(int, int)? episodeOnly(String? raw) {
  final t = separators(cleanRaw(raw));
  var m = _pSE.firstMatch(t);
  if (m != null) {
    final (s, e, _) = _seGroups(m);
    return (s, e);
  }
  m = _pTrSE.firstMatch(t);
  if (m != null) return (int.parse(m.group(1)!), int.parse(m.group(2)!));
  m = _pTrB.firstMatch(t);
  if (m != null) {
    final sm = _pTrS.firstMatch(t.substring(0, m.start));
    return (sm != null ? int.parse(sm.group(1)!) : 1, int.parse(m.group(1) ?? m.group(2)!));
  }
  final sm = _pTrS.firstMatch(t);
  m = _pE.firstMatch(t) ?? _pBL.firstMatch(t);
  if (m != null) return (sm != null ? int.parse(sm.group(1)!) : 1, int.parse(m.group(1)!));
  return null;
}

const _sources = <(String, String)>[
  (r'BLU-?RAY|BDRIP|BRRIP|REMUX', 'BluRay'),
  (r'\bNF\b|NETFLIX', 'NF'),
  (r'\bAMZN\b', 'AMZN'),
  (r'\bDSNP\b|\bDSNY\b', 'Disney+'),
  (r'\bATVP\b|TV\+', 'AppleTV'),
  (r'\bHMAX\b|\bMAX\b', 'Max'),
  (r'BLUTV', 'BluTV'),
  (r'\bGAIN\b|GAİN', 'Gain'),
  (r'\bTOD\b|BEIN', 'TOD'),
  (r'EXXEN', 'Exxen'),
  (r'MUBI', 'Mubi'),
  (r'TABI|TABİİ', 'Tabii'),
  (r'HDTV', 'HDTV'),
  (r'DVDRIP', 'DVD'),
  (r'WEB-?DL|WEBRIP|\bWEB\b', 'WEB'),
];

final _groups = RegExp(
  r'(TURG|HdT|SnyoR|Mnike|HDM|BTRG|FLUX|NOVA|OpeD|TEPES|playWEB|NTb|KiNGS|EDITH|DUSKLiGHT|TSRG|TORK|YTS|SKBy|EbP|BITTURK)',
  caseSensitive: false,
);

/// Version label shown next to alternative files: `'1080p NF DUAL TURG'`.
String versionLabel(String? raw) {
  final t = (raw ?? '')
      .replaceAll(RegExp(r'-\s*\[archived by[^\]]*\]-', caseSensitive: false), ' ')
      .replaceAll('*', ' ')
      .replaceAll('`', ' ');
  final u = t.toUpperCase();
  final parts = <String>[];
  final res = RegExp(r'(2160|1080|720|576|480)[PI]').firstMatch(u);
  if (res != null) {
    parts.add(res.group(1) == '2160' ? '4K' : '${res.group(1)}p');
  } else if (RegExp(r'\b4K\b|\bUHD\b').hasMatch(u)) {
    parts.add('4K');
  }
  for (final (k, v) in _sources) {
    if (RegExp(k).hasMatch(u)) {
      parts.add(v);
      break;
    }
  }
  if (RegExp(r'X265|HEVC|H\.?265').hasMatch(u)) parts.add('HEVC');
  if (RegExp(r'ATMOS').hasMatch(u)) parts.add('Atmos');
  if (RegExp(r'DUAL|MULTI|TRIPLE|TR-EN|\[TR-EN').hasMatch(u)) {
    parts.add('DUAL');
  } else if (RegExp(r'DUBLAJ|\bTR\b(?!SUB)|\[TR\]').hasMatch(u) && !RegExp(r'TRSUB|ALTYAZ').hasMatch(u)) {
    parts.add('TR Dub');
  } else if (RegExp(r'TRSUB|ALTYAZ|TR SUB').hasMatch(u)) {
    parts.add('Sub');
  }
  final g = _groups.firstMatch(t);
  if (g != null) parts.add(g.group(1)!);
  return parts.isEmpty ? '' : parts.join(' ');
}

/// Comparison key: lower case, no diacritics, punctuation or years.
String foldKey(String? s) {
  var x = foldText((s ?? '').toLowerCase().replaceAll('ı', 'i').replaceAll('İ', 'i'));
  x = x.replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)'), ' ');
  x = x.replaceAll(RegExp(r'\b(19|20)\d\d\b'), '');
  return x.replaceAll('&', 'and').replaceAll(RegExp(r'[^a-z0-9]'), '');
}
