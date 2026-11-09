import 'dart:convert';
import 'dart:io';

import 'package:erostream/media/name_parser.dart';
import 'package:erostream/metadata/title_match.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden values produced by the reference Python implementation.
final Map<String, dynamic> golden =
    jsonDecode(File('test/fixtures/golden.json').readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> cases(String key) => (golden[key] as List).cast<Map<String, dynamic>>();

void main() {
  group('parseName', () {
    for (final c in cases('parse')) {
      test(c['in'], () {
        expect(parseName(c['in'] as String).toJson(), c['out']);
      });
    }
  });

  group('episodeOnly', () {
    for (final c in cases('episode_only')) {
      test(c['in'], () {
        final r = episodeOnly(c['in'] as String);
        expect(r == null ? null : [r.$1, r.$2], c['out']);
      });
    }
  });

  group('versionLabel', () {
    const renamed = {'Surum': '', 'TR Dublaj': 'TR Dub', 'Altyazili': 'Sub'};
    for (final c in cases('label')) {
      test(c['in'], () {
        var want = c['out'] as String;
        renamed.forEach((k, v) => want = want.replaceAll(k, v));
        expect(versionLabel(c['in'] as String), want.trim());
      });
    }
  });

  group('foldKey', () {
    for (final c in cases('fold')) {
      test(c['in'], () => expect(foldKey(c['in'] as String), c['out']));
    }
  });

  group('titleCandidates', () {
    for (final c in cases('candidates')) {
      test(c['in'], () {
        final r = titleCandidates(c['in'] as String);
        expect(r.queries, c['out']);
        expect(r.year, c['year']);
      });
    }
  });

  group('titleSimilarity', () {
    for (final c in cases('ratio')) {
      test('${c['a']} ~ ${c['b']}', () {
        expect(titleSimilarity(c['a'] as String, c['b'] as String), closeTo((c['out'] as num).toDouble(), 1e-6));
      });
    }
  });

  test('showBase strips episode title and year', () {
    expect(showBase('Mammals - Memeli Canlilar -Karanlik- (2024)'), ('Mammals - Memeli Canlilar', '2024'));
    expect(showBase('Shogun 2024'), ('Shogun', '2024'));
  });
}
