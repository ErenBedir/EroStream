import 'package:erostream/library/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('library config round-trips through JSON', () {
    const lib = MediaLibrary(
      id: 'a1',
      name: 'Series',
      kind: LibraryKind.shows,
      sources: [
        TelegramSource(
          chatId: -1001234567890,
          title: 'Archive',
          isForum: true,
          topics: {12: TopicRule(mode: TopicMode.movie), 40: TopicRule(name: 'Dark')},
        ),
        LocalFolderSource(path: '/storage/emulated/0/Movies'),
      ],
    );
    final back = MediaLibrary.fromJson(lib.toJson());
    expect(back.toJson(), lib.toJson());
    final tg = back.sources.first as TelegramSource;
    expect(tg.ruleFor(12).mode, TopicMode.movie);
    expect(tg.ruleFor(40).name, 'Dark');
    expect(tg.ruleFor(99).isDefault, isTrue);
  });

  test('unknown source types are kept', () {
    final lib = MediaLibrary.fromJson({
      'id': 'x',
      'name': 'X',
      'kind': 'mixed',
      'sources': [
        {'type': 'webdav', 'url': 'https://example.org/dav'},
      ],
    });
    expect(lib.sources.single, isA<UnknownSource>());
    expect(lib.toJson()['sources'], [
      {'type': 'webdav', 'url': 'https://example.org/dav'},
    ]);
  });
}
