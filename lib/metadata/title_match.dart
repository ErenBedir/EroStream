/// Title normalization, search candidates and similarity used by the TMDB matcher.
library;

import '../media/fold.dart';

/// Auto-apply threshold. Lower scores go to the review queue.
const autoMatchThreshold = 0.82;

String normTitle(String? s) {
  var x = (s ?? '').toLowerCase().replaceAll('ı', 'i').replaceAll('&', 'and');
  x = foldText(x);
  x = x.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  return x.replaceAll(RegExp(r'\s+'), ' ').trim();
}

final _trChar = RegExp(r'[çğıöşüÇĞİÖŞÜ]');
final _junkWords =
    r'(?:netflix|disney\+?|hbo|amazon|blutv|exxen|gain|tabii|bbc earth|bbc|national geographic|nat geo|dual|altyaz[iı]l[iı]|dublaj|the complete series|complete series|box ?set|blm|bolum|bölüm)';

class TitleCandidates {
  const TitleCandidates(this.queries, this.year);

  final List<String> queries;
  final int? year;
}

/// Search strings to try for a raw show/movie name, best first.
TitleCandidates titleCandidates(String name) {
  int? year;
  final ym = RegExp(r'\(?\b((?:19|20)\d\d)\b\)?').firstMatch(name);
  if (ym != null) year = int.parse(ym.group(1)!);

  name = name.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
  String base0(String n) {
    n = n.replaceAll(RegExp(r'\(?\b(?:19|20)\d\d(?:\s*-\s*(?:19|20)?\d\d)?\b\)?'), ' ');
    n = n.replaceAll(RegExp(r'[\(\)\[\]]'), ' ');
    return _strip(n.replaceAll(RegExp(r'\s+'), ' '), ' -');
  }

  final raw = base0(name);
  // Platform / tag words only at the edges ("Max Steel", "Prime Suspect" stay intact).
  var base = raw;
  final edge = RegExp('^\\s*$_junkWords\\b\\s*|\\s*\\b$_junkWords\\s*\$', caseSensitive: false);
  for (var i = 0; i < 3; i++) {
    base = _strip(base.replaceAll(edge, ' '), ' -');
  }
  final c = <String>[base, raw];
  final parts = base
      .split(RegExp(r'\s+-\s*|\s*-\s+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length > 1) c.addAll(parts); // bilingual: both sides

  for (final p in [base, ...parts]) {
    // "7 Toughest Days 7 Zorlu Gun Gabon" -> English prefix before the first Turkish word.
    final w = p.split(' ');
    for (var i = 0; i < w.length; i++) {
      if (_trChar.hasMatch(w[i])) {
        final pre = w.sublist(0, i).join(' ');
        if (i >= 2 && !_trChar.hasMatch(pre) && RegExp(r'[A-Za-z]{3,}').allMatches(pre).length >= 2) {
          c.add(pre);
        }
        break;
      }
    }
    final m2 = RegExp(r'^(.*?\D)\s+\d{1,3}\s+\S.*$').firstMatch(p);
    if (m2 != null && m2.group(1)!.split(' ').length >= 2) c.add(m2.group(1)!.trim());
  }

  final out = <String>[];
  final seen = <String>{};
  for (var x in c) {
    x = _strip(x.trim(), ' -.');
    final n = normTitle(x);
    if (n.length >= 2 && seen.add(n)) out.add(x);
  }
  return TitleCandidates(out, year);
}

/// Same value as Python's `difflib.SequenceMatcher(None, a, b).ratio()` on normalized titles.
double titleSimilarity(String a, String b) {
  a = normTitle(a);
  b = normTitle(b);
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 1.0;
  return sequenceRatio(a, b);
}

/// Ratcliff/Obershelp ratio, same block search order as difflib (no junk heuristics).
double sequenceRatio(String a, String b) {
  final la = a.length, lb = b.length;
  if (la + lb == 0) return 1.0;
  final b2j = <int, List<int>>{};
  for (var j = 0; j < lb; j++) {
    (b2j[b.codeUnitAt(j)] ??= <int>[]).add(j);
  }

  (int, int, int) longest(int alo, int ahi, int blo, int bhi) {
    var besti = alo, bestj = blo, bestsize = 0;
    var j2len = <int, int>{};
    for (var i = alo; i < ahi; i++) {
      final newj2len = <int, int>{};
      for (final j in b2j[a.codeUnitAt(i)] ?? const <int>[]) {
        if (j < blo) continue;
        if (j >= bhi) break;
        final k = (j2len[j - 1] ?? 0) + 1;
        newj2len[j] = k;
        if (k > bestsize) {
          besti = i - k + 1;
          bestj = j - k + 1;
          bestsize = k;
        }
      }
      j2len = newj2len;
    }
    return (besti, bestj, bestsize);
  }

  var matches = 0;
  final queue = <(int, int, int, int)>[(0, la, 0, lb)];
  while (queue.isNotEmpty) {
    final (alo, ahi, blo, bhi) = queue.removeLast();
    final (i, j, k) = longest(alo, ahi, blo, bhi);
    if (k > 0) {
      matches += k;
      if (alo < i && blo < j) queue.add((alo, i, blo, j));
      if (i + k < ahi && j + k < bhi) queue.add((i + k, ahi, j + k, bhi));
    }
  }
  return 2.0 * matches / (la + lb);
}

String _strip(String s, String chars) {
  var a = 0, b = s.length;
  while (a < b && chars.contains(s[a])) {
    a++;
  }
  while (b > a && chars.contains(s[b - 1])) {
    b--;
  }
  return s.substring(a, b);
}
