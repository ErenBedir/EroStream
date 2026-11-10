/// Turns Telegram messages into library items. Pure functions, no I/O.
library;

import '../media/name_parser.dart';
import 'items.dart';
import 'models.dart';

/// Topic titles containing these words are treated as movie topics in auto mode.
const movieTopicKeywords = ['film', 'sinema', 'movie', 'cinema'];

/// Video file found in a message.
class TgFile {
  const TgFile({
    required this.messageId,
    required this.fileName,
    this.topicId = 0,
    this.caption = '',
    this.size = 0,
    this.duration = 0,
    this.date = 0,
  });

  final int messageId;
  final int topicId;
  final String fileName;
  final String caption;
  final int size;
  final int duration;
  final int date;
}

/// Video files only: `messageVideo`, or `messageDocument` with a video name / mime type.
TgFile? tgFileFromMessage(Map<String, dynamic> m) {
  final content = (m['content'] as Map?)?.cast<String, dynamic>();
  if (content == null) return null;
  String name;
  String mime;
  Map<String, dynamic>? file;
  var duration = 0;
  switch (content['@type']) {
    case 'messageVideo':
      final v = (content['video'] as Map).cast<String, dynamic>();
      name = '${v['file_name'] ?? ''}';
      mime = '${v['mime_type'] ?? ''}';
      file = (v['video'] as Map?)?.cast<String, dynamic>();
      duration = (v['duration'] as num?)?.toInt() ?? 0;
    case 'messageDocument':
      final d = (content['document'] as Map).cast<String, dynamic>();
      name = '${d['file_name'] ?? ''}';
      mime = '${d['mime_type'] ?? ''}';
      file = (d['document'] as Map?)?.cast<String, dynamic>();
      if (!isVideoName(name) && !mime.startsWith('video/')) return null;
    default:
      return null;
  }
  final caption = '${((content['caption'] as Map?)?['text']) ?? ''}'.trim();
  final topic = (m['topic_id'] as Map?)?.cast<String, dynamic>();
  final size = (file?['size'] as num?)?.toInt() ?? 0;
  return TgFile(
    messageId: (m['id'] as num).toInt(),
    topicId: topic?['@type'] == 'messageTopicForum' ? (topic!['forum_topic_id'] as num).toInt() : 0,
    fileName: name,
    caption: caption,
    size: size != 0 ? size : (file?['expected_size'] as num?)?.toInt() ?? 0,
    duration: duration,
    date: (m['date'] as num?)?.toInt() ?? 0,
  );
}

/// Name used for parsing: the file name, or the caption when the file name says nothing.
String bestName(TgFile f) {
  final caption = f.caption.split('\n').first.trim();
  if (f.fileName.isEmpty) return caption;
  if (caption.isNotEmpty && parseName(f.fileName) is ParsedOther && parseName(caption) is! ParsedOther) {
    return caption;
  }
  return f.fileName;
}

String titleKeyFor(ItemKind kind, String name, [String? year]) => switch (kind) {
      ItemKind.tv => 'tv:${foldKey(name)}',
      ItemKind.movie => 'movie:${foldKey(name)}:${year ?? ''}',
      ItemKind.other => 'other:${foldKey(name)}',
    };

class ScanBatch {
  final items = <MediaItem>[];
  final titles = <String, TitleEntry>{};
}

/// Classifies files of one Telegram source.
///
/// [topicNames] maps forum topic ids to titles. [maxEpisode] returns the highest
/// known season-1 episode of a title, for topics whose files carry no number.
ScanBatch classifyTelegram({
  required List<TgFile> files,
  required TelegramSource source,
  required String libraryId,
  Map<int, String> topicNames = const {},
  Set<int> generalTopics = const {},
  int Function(String titleKey)? maxEpisode,
}) {
  final out = ScanBatch();
  final sorted = [...files]..sort((a, b) => a.messageId.compareTo(b.messageId));
  final nextEp = <String, int>{};

  void add(TgFile f, ItemKind kind, String name, String? year, {int? s, int? e, int? e2}) {
    final key = titleKeyFor(kind, name, year);
    out.titles.putIfAbsent(
      key,
      () => TitleEntry(key: key, kind: kind, name: name, year: year == null ? null : int.tryParse(year)),
    );
    out.items.add(MediaItem(
      id: 'tg:${source.chatId}:${f.messageId}',
      libraryId: libraryId,
      sourceKey: source.key,
      titleKey: key,
      kind: kind,
      fileName: f.fileName.isNotEmpty ? f.fileName : bestName(f),
      chatId: source.chatId,
      messageId: f.messageId,
      topicId: f.topicId,
      size: f.size,
      duration: f.duration,
      season: s,
      episode: e,
      episodeEnd: e2,
      label: versionLabel('${f.fileName} ${f.caption}'),
      date: f.date,
    ));
  }

  void fromName(TgFile f) {
    switch (parseName(bestName(f))) {
      case ParsedEpisode p:
        final (show, y) = showBase(p.show);
        add(f, ItemKind.tv, show, y, s: p.season, e: p.episode, e2: p.episodeEnd);
      case ParsedMovie p:
        add(f, ItemKind.movie, p.title, p.year);
      case ParsedOther p:
        add(f, ItemKind.other, p.title, null);
    }
  }

  for (final f in sorted) {
    if (!source.isForum || f.topicId == 0) {
      fromName(f);
      continue;
    }
    final rule = source.ruleFor(f.topicId);
    final title = topicNames[f.topicId] ?? '';
    var mode = rule.mode;
    if (mode == TopicMode.auto) {
      final tl = title.toLowerCase();
      if (title.isEmpty || generalTopics.contains(f.topicId)) {
        mode = TopicMode.fromName;
      } else if (movieTopicKeywords.any(tl.contains)) {
        mode = TopicMode.movie;
      } else {
        mode = TopicMode.tv;
      }
    }
    switch (mode) {
      case TopicMode.skip:
        break;
      case TopicMode.fromName:
      case TopicMode.auto:
        fromName(f);
      case TopicMode.movie:
        final p = parseName(bestName(f));
        if (p is ParsedMovie) {
          add(f, ItemKind.movie, p.title, p.year);
        } else {
          fromName(f);
        }
      case TopicMode.tv:
        final (show, y) = showBase(rule.name.isNotEmpty ? rule.name : title);
        final key = titleKeyFor(ItemKind.tv, show);
        var se = episodeOnly(bestName(f));
        if (se == null) {
          final n = (nextEp[key] ?? maxEpisode?.call(key) ?? 0) + 1;
          nextEp[key] = n;
          se = (1, n);
        } else if (se.$1 == 1) {
          nextEp[key] = (nextEp[key] ?? 0) > se.$2 ? nextEp[key]! : se.$2;
        }
        add(f, ItemKind.tv, show, y, s: se.$1, e: se.$2);
    }
  }
  return out;
}
