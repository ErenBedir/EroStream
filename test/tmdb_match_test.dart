import 'dart:convert';

import 'package:erostream/metadata/tmdb.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});

void main() {
  test('picks the exact title over a more popular near match', () async {
    final client = TmdbClient(
      key: 'k',
      httpClient: MockClient((req) async {
        expect(req.url.path, '/3/search/tv');
        return _json({
          'results': [
            {'id': 1, 'name': 'Darkness', 'original_name': 'Darkness', 'first_air_date': '2017-01-01', 'popularity': 900},
            {'id': 2, 'name': 'Dark', 'original_name': 'Dark', 'first_air_date': '2017-12-01', 'popularity': 50},
          ],
        });
      }),
    );
    final r = await client.match(MediaKind.tv, 'Dark');
    expect(r.best!.hit.id, 2);
    expect(r.isConfident, isTrue);
  });

  test('matches a Turkish title through the original title', () async {
    final client = TmdbClient(
      key: 'eyJtoken',
      httpClient: MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer eyJtoken');
        expect(req.url.queryParameters.containsKey('api_key'), isFalse);
        return _json({
          'results': [
            {'id': 7, 'name': 'Golden Boy', 'original_name': 'Yalı Çapkını', 'first_air_date': '2022-09-23', 'popularity': 40},
          ],
        });
      }),
    );
    final r = await client.match(MediaKind.tv, 'Yali Capkini');
    expect(r.best!.hit.id, 7);
    expect(r.isConfident, isTrue);
  });

  test('wrong movie year is penalized', () {
    const right = TmdbHit(id: 1, kind: MediaKind.movie, title: 'Dune', originalTitle: 'Dune', year: 2021);
    const wrong = TmdbHit(id: 2, kind: MediaKind.movie, title: 'Dune', originalTitle: 'Dune', year: 1984);
    expect(scoreHit(right, ['Dune'], year: 2021), greaterThan(scoreHit(wrong, ['Dune'], year: 2021)));
  });

  test('weak match goes to review', () async {
    final client = TmdbClient(
      key: 'k',
      httpClient: MockClient((_) async => _json({
            'results': [
              {'id': 3, 'title': 'Something Else Entirely', 'original_title': 'X', 'release_date': '2001-01-01'},
            ],
          })),
    );
    final r = await client.match(MediaKind.movie, 'Random Home Video');
    expect(r.isConfident, isFalse);
  });
}
