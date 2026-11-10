import 'package:erostream/library/items.dart';
import 'package:erostream/library/media_store.dart';
import 'package:erostream/library/store_backend.dart';
import 'package:flutter_test/flutter_test.dart';

class _Mem implements StoreBackend {
  String? data;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String d) async => data = d;
}

MediaItem ep(int msg, int e, {int size = 100, String label = ''}) => MediaItem(
      id: 'tg:1:$msg',
      libraryId: 'L',
      sourceKey: 'tg:1',
      titleKey: 'tv:dark',
      kind: ItemKind.tv,
      fileName: 'Dark.S01E0$e.mkv',
      chatId: 1,
      messageId: msg,
      size: size,
      season: 1,
      episode: e,
      label: label,
      date: msg,
    );

void main() {
  test('episodes, versions, next episode, continue watching, persistence', () async {
    final mem = _Mem();
    final s = MediaStore(backend: mem);
    s.putItems(
      [ep(1, 1), ep(2, 2, size: 50, label: '720p'), ep(3, 2, size: 90, label: '1080p'), ep(4, 3)],
      {'tv:dark': TitleEntry(key: 'tv:dark', kind: ItemKind.tv, name: 'Dark')},
    );
    expect(s.episodesOf('tv:dark').map((i) => i.messageId), [1, 3, 4]);
    expect(s.versionsOf('tv:dark|1|2').map((i) => i.label), ['1080p', '720p']);
    expect(s.nextEpisode(ep(1, 1))!.messageId, 3);

    s.setProgress('tg:1:2', 600, 3000);
    expect(s.preferredVersion('tv:dark|1|2')!.messageId, 2);
    expect(s.continueWatching().single.id, 'tg:1:2');
    expect(s.titlesOfLibrary('L').single.name, 'Dark');

    await s.flush();
    final again = MediaStore(backend: mem);
    await again.load();
    expect(again.itemsOfTitle('tv:dark').length, 4);
    expect(again.progressOf('tg:1:2')!.position, 600);

    again.removeSource('L', 'tg:1');
    expect(again.titles, isEmpty);
  });
}
