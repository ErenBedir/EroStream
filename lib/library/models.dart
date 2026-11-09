/// Library configuration. Scanned items live in the item store (next milestone).
library;

enum LibraryKind { movies, shows, mixed }

/// How files inside a forum topic are interpreted.
enum TopicMode {
  /// Topic title = series name; titles with movie keywords become movies.
  auto,

  /// Topic title = series name, file name gives season/episode.
  tv,

  /// Every file is a movie, parsed from its file name.
  movie,

  /// Ignore the topic title, parse each file name on its own.
  fromName,

  /// Do not index this topic.
  skip,
}

class TopicRule {
  const TopicRule({this.mode = TopicMode.auto, this.name = ''});

  factory TopicRule.fromJson(Map<String, dynamic> j) => TopicRule(
        mode: TopicMode.values.asNameMap()[j['mode']] ?? TopicMode.auto,
        name: '${j['name'] ?? ''}',
      );

  final TopicMode mode;

  /// Overrides the topic title as series name. Empty = use the title.
  final String name;

  bool get isDefault => mode == TopicMode.auto && name.isEmpty;

  TopicRule copyWith({TopicMode? mode, String? name}) => TopicRule(mode: mode ?? this.mode, name: name ?? this.name);

  Map<String, dynamic> toJson() => {'mode': mode.name, if (name.isNotEmpty) 'name': name};
}

sealed class SourceConfig {
  const SourceConfig();

  factory SourceConfig.fromJson(Map<String, dynamic> j) => switch (j['type']) {
        'telegram' => TelegramSource.fromJson(j),
        'local' => LocalFolderSource.fromJson(j),
        _ => UnknownSource(j),
      };

  String get type;
  String get key;
  String get displayName;
  Map<String, dynamic> toJson();
}

class TelegramSource extends SourceConfig {
  const TelegramSource({
    required this.chatId,
    required this.title,
    this.isForum = false,
    this.isChannel = false,
    this.topics = const {},
    this.lastMessageId = 0,
  });

  factory TelegramSource.fromJson(Map<String, dynamic> j) => TelegramSource(
        chatId: (j['chat_id'] as num).toInt(),
        title: '${j['title'] ?? ''}',
        isForum: j['forum'] == true,
        isChannel: j['channel'] == true,
        topics: {
          for (final e in ((j['topics'] as Map?) ?? const {}).entries)
            int.parse('${e.key}'): TopicRule.fromJson((e.value as Map).cast<String, dynamic>()),
        },
        lastMessageId: (j['last_message_id'] as num?)?.toInt() ?? 0,
      );

  final int chatId;
  final String title;
  final bool isForum;
  final bool isChannel;

  /// Only non-default rules are stored.
  final Map<int, TopicRule> topics;

  /// Incremental sync cursor.
  final int lastMessageId;

  TopicRule ruleFor(int topicId) => topics[topicId] ?? const TopicRule();

  TelegramSource copyWith({Map<int, TopicRule>? topics, int? lastMessageId, String? title}) => TelegramSource(
        chatId: chatId,
        title: title ?? this.title,
        isForum: isForum,
        isChannel: isChannel,
        topics: topics ?? this.topics,
        lastMessageId: lastMessageId ?? this.lastMessageId,
      );

  @override
  String get type => 'telegram';

  @override
  String get key => 'tg:$chatId';

  @override
  String get displayName => title;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'chat_id': chatId,
        'title': title,
        'forum': isForum,
        'channel': isChannel,
        if (topics.isNotEmpty) 'topics': {for (final e in topics.entries) '${e.key}': e.value.toJson()},
        if (lastMessageId != 0) 'last_message_id': lastMessageId,
      };
}

class LocalFolderSource extends SourceConfig {
  const LocalFolderSource({required this.path, this.label = ''});

  factory LocalFolderSource.fromJson(Map<String, dynamic> j) =>
      LocalFolderSource(path: '${j['path']}', label: '${j['label'] ?? ''}');

  /// File system path, or a content:// tree URI on Android.
  final String path;
  final String label;

  @override
  String get type => 'local';

  @override
  String get key => 'local:$path';

  @override
  String get displayName => label.isNotEmpty ? label : path;

  @override
  Map<String, dynamic> toJson() => {'type': type, 'path': path, if (label.isNotEmpty) 'label': label};
}

/// Keeps configs written by newer versions or plugins intact.
class UnknownSource extends SourceConfig {
  const UnknownSource(this.raw);

  final Map<String, dynamic> raw;

  @override
  String get type => '${raw['type']}';

  @override
  String get key => '$type:${raw.hashCode}';

  @override
  String get displayName => type;

  @override
  Map<String, dynamic> toJson() => raw;
}

class MediaLibrary {
  const MediaLibrary({required this.id, required this.name, required this.kind, this.sources = const []});

  factory MediaLibrary.fromJson(Map<String, dynamic> j) => MediaLibrary(
        id: '${j['id']}',
        name: '${j['name']}',
        kind: LibraryKind.values.asNameMap()[j['kind']] ?? LibraryKind.mixed,
        sources: [
          for (final s in (j['sources'] as List? ?? const [])) SourceConfig.fromJson((s as Map).cast<String, dynamic>()),
        ],
      );

  final String id;
  final String name;
  final LibraryKind kind;
  final List<SourceConfig> sources;

  MediaLibrary copyWith({String? name, LibraryKind? kind, List<SourceConfig>? sources}) => MediaLibrary(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        sources: sources ?? this.sources,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'sources': [for (final s in sources) s.toJson()],
      };
}
