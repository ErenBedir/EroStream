import 'package:erostream/library/items.dart';
import 'package:erostream/library/models.dart';
import 'package:erostream/library/telegram_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('channel files are parsed from their names', () {
    const src = TelegramSource(chatId: -100, title: 'c');
    final b = classifyTelegram(
      libraryId: 'L',
      source: src,
      files: const [
        TgFile(messageId: 2, fileName: 'Dark.S01E02.1080p.NF.WEB-DL.mkv', size: 20),
        TgFile(messageId: 1, fileName: 'Dark.S01E01.720p.mkv', size: 10),
        TgFile(messageId: 3, fileName: 'Inception.2010.1080p.BluRay.mkv'),
      ],
    );
    expect(b.items.map((i) => i.id), ['tg:-100:1', 'tg:-100:2', 'tg:-100:3']);
    expect(b.titles.keys, containsAll(['tv:dark', 'movie:inception:2010']));
    final e2 = b.items[1];
    expect([e2.season, e2.episode, e2.label], [1, 2, '1080p NF']);
  });

  test('forum topics: title is the show, numbers from file, fallback numbering, skip, movies', () {
    const src = TelegramSource(
      chatId: -200,
      title: 'g',
      isForum: true,
      topics: {30: TopicRule(mode: TopicMode.skip), 40: TopicRule(name: 'Kurtlar Vadisi Pusu')},
    );
    final b = classifyTelegram(
      libraryId: 'L',
      source: src,
      topicNames: {10: 'Yalı Çapkını (2022)', 20: 'Filmler', 30: 'Sohbet', 40: 'KVP'},
      files: const [
        TgFile(messageId: 1, topicId: 10, fileName: '41.Bolum.mp4'),
        TgFile(messageId: 2, topicId: 10, fileName: 'final.mp4'),
        TgFile(messageId: 3, topicId: 20, fileName: 'Ayla 2017 1080p.mp4'),
        TgFile(messageId: 4, topicId: 30, fileName: 'x.mp4'),
        TgFile(messageId: 5, topicId: 40, fileName: 'S02E03.mkv'),
      ],
    );
    expect(b.items.length, 4);
    final yc = b.items.where((i) => i.titleKey == 'tv:yalicapkini').toList();
    expect(yc.map((i) => i.episode), [41, 42]);
    expect(b.titles['tv:yalicapkini']!.year, 2022);
    expect(b.items.any((i) => i.titleKey == 'movie:ayla:2017'), isTrue);
    final kvp = b.items.singleWhere((i) => i.messageId == 5);
    expect([kvp.titleKey, kvp.season, kvp.episode], ['tv:kurtlarvadisipusu', 2, 3]);
  });

  test('caption is used when the file name says nothing', () {
    const f = TgFile(messageId: 1, fileName: 'video.mp4', caption: 'Breaking Bad S05E14\n#dizi');
    expect(bestName(f), 'Breaking Bad S05E14');
  });

  test('tgFileFromMessage reads documents and skips non-video', () {
    final doc = tgFileFromMessage({
      'id': 9,
      'date': 100,
      'topic_id': {'@type': 'messageTopicForum', 'forum_topic_id': 7},
      'content': {
        '@type': 'messageDocument',
        'document': {
          'file_name': 'Dark.S01E01.mkv',
          'mime_type': 'video/x-matroska',
          'document': {'id': 1, 'size': 123, 'expected_size': 123},
        },
        'caption': {'text': ''},
      },
    })!;
    expect([doc.messageId, doc.topicId, doc.size, doc.fileName], [9, 7, 123, 'Dark.S01E01.mkv']);
    expect(
      tgFileFromMessage({
        'id': 1,
        'content': {
          '@type': 'messageDocument',
          'document': {'file_name': 'a.pdf', 'mime_type': 'application/pdf', 'document': {'size': 1}},
        },
      }),
      isNull,
    );
    expect(ItemKind.values.length, 3);
  });
}
