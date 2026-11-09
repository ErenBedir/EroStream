import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../library/library_repository.dart';
import '../../library/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../onboarding/login_screen.dart';
import 'chat_picker.dart';
import 'topic_rules_screen.dart';

class LibraryEditor extends StatefulWidget {
  const LibraryEditor({super.key, this.initial});

  final MediaLibrary? initial;

  @override
  State<LibraryEditor> createState() => _LibraryEditorState();
}

class _LibraryEditorState extends State<LibraryEditor> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late LibraryKind _kind = widget.initial?.kind ?? LibraryKind.shows;
  late List<SourceConfig> _sources = [...?widget.initial?.sources];

  bool get _isNew => widget.initial == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final repo = context.services.libraries;
    final lib = (widget.initial ?? MediaLibrary(id: LibraryRepository.newId(), name: name, kind: _kind))
        .copyWith(name: name, kind: _kind, sources: _sources);
    await repo.upsert(lib);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l = L.of(context);
    final ok = await confirm(context, l.deleteLibraryConfirm(widget.initial!.name), yes: l.delete, no: l.cancel);
    if (!ok || !mounted) return;
    await context.services.libraries.remove(widget.initial!.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addSource() async {
    final l = L.of(context);
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              autofocus: true,
              leading: const Icon(Icons.send_rounded),
              title: Text(l.sourceTelegram),
              onTap: () => Navigator.pop(c, 'telegram'),
            ),
            ListTile(
              enabled: false,
              leading: const Icon(Icons.folder_outlined),
              title: Text(l.sourceLocal),
              subtitle: Text(l.comingSoon),
            ),
            const SizedBox(height: Space.l),
          ],
        ),
      ),
    );
    if (!mounted || type != 'telegram') return;

    final tg = context.services.telegram;
    if (!tg.isReady) {
      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (ok != true || !mounted) return;
    }
    final chat = await Navigator.of(context).push<TelegramSource>(MaterialPageRoute(builder: (_) => const ChatPicker()));
    if (chat == null || !mounted) return;
    if (_sources.any((s) => s.key == chat.key)) return;
    setState(() => _sources = [..._sources, chat]);
    if (chat.isForum) await _editTopics(_sources.length - 1);
  }

  Future<void> _editTopics(int index) async {
    final src = _sources[index] as TelegramSource;
    final updated = await Navigator.of(context).push<TelegramSource>(
      MaterialPageRoute(builder: (_) => TopicRulesScreen(source: src)),
    );
    if (updated != null && mounted) setState(() => _sources = [..._sources]..[index] = updated);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l.addLibrary : l.editLibrary),
        actions: [
          if (!_isNew) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded), tooltip: l.delete),
          Padding(
            padding: const EdgeInsets.only(right: Space.s),
            child: TextButton(onPressed: _save, child: Text(_isNew ? l.create : l.save)),
          ),
        ],
      ),
      body: Readable(
        maxWidth: 640,
        padding: const EdgeInsets.fromLTRB(Space.xl, Space.s, Space.xl, Space.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: _isNew,
              decoration: InputDecoration(labelText: l.libraryName, hintText: l.libraryNameHint),
            ),
            const SizedBox(height: Space.xl),
            Text(l.libraryKind, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: Space.s),
            SegmentedButton<LibraryKind>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: LibraryKind.shows, label: Text(l.kindShows)),
                ButtonSegment(value: LibraryKind.movies, label: Text(l.kindMovies)),
                ButtonSegment(value: LibraryKind.mixed, label: Text(l.kindMixed)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: Space.xl),
            Row(
              children: [
                Expanded(child: Text(l.sources, style: Theme.of(context).textTheme.labelLarge)),
                TextButton.icon(
                  onPressed: _addSource,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l.addSource),
                ),
              ],
            ),
            const SizedBox(height: Space.s),
            if (_sources.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.l),
                child: Text(l.noSources, style: Theme.of(context).textTheme.bodySmall),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < _sources.length; i++) _sourceTile(context, i),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sourceTile(BuildContext context, int i) {
    final l = L.of(context);
    final s = _sources[i];
    final (icon, sub) = switch (s) {
      TelegramSource(isForum: true) => (Icons.forum_outlined, l.forumGroup),
      TelegramSource(isChannel: true) => (Icons.campaign_outlined, l.channel),
      TelegramSource() => (Icons.group_outlined, l.group),
      LocalFolderSource() => (Icons.folder_outlined, l.sourceLocal),
      UnknownSource() => (Icons.extension_outlined, s.type),
    };
    return ListTile(
      leading: Icon(icon),
      title: Text(s.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(sub),
      onTap: s is TelegramSource && s.isForum ? () => _editTopics(i) : null,
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded, size: 18),
        tooltip: l.delete,
        onPressed: () => setState(() => _sources = [..._sources]..removeAt(i)),
      ),
    );
  }
}
