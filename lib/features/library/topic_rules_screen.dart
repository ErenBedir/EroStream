import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../library/models.dart';
import '../../telegram/td_client.dart';
import '../../telegram/telegram_service.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Per-topic mode and series name for a forum group. Pops with the updated source.
class TopicRulesScreen extends StatefulWidget {
  const TopicRulesScreen({super.key, required this.source});

  final TelegramSource source;

  @override
  State<TopicRulesScreen> createState() => _TopicRulesScreenState();
}

class _TopicRulesScreenState extends State<TopicRulesScreen> {
  late Map<int, TopicRule> _rules = {...widget.source.topics};
  List<TgTopic>? _topics;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await context.services.telegram.listTopics(widget.source.chatId);
      if (mounted) setState(() => _topics = t);
    } on TdError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _set(int id, TopicRule r) {
    setState(() {
      _rules = {..._rules};
      if (r.isDefault) {
        _rules.remove(id);
      } else {
        _rules[id] = r;
      }
    });
  }

  Future<void> _rename(TgTopic t) async {
    final c = TextEditingController(text: _rules[t.id]?.name ?? '');
    final l = L.of(context);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.name),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: t.name),
          onSubmitted: (x) => Navigator.pop(ctx, x),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(l.save)),
        ],
      ),
    );
    c.dispose();
    if (v != null) _set(t.id, (_rules[t.id] ?? const TopicRule()).copyWith(name: v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final modes = {
      TopicMode.auto: l.topicModeAuto,
      TopicMode.tv: l.topicModeTv,
      TopicMode.movie: l.topicModeMovie,
      TopicMode.fromName: l.topicModeFromName,
      TopicMode.skip: l.topicModeSkip,
    };
    final topics = _topics;
    return PopScope<TelegramSource>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(widget.source.copyWith(topics: _rules));
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.source.title)),
        body: topics == null
            ? (_error != null ? EmptyState(icon: Icons.error_outline, title: l.errorText(_error!), body: '') : const Center(child: CircularProgressIndicator()))
            : ListView(
                padding: const EdgeInsets.only(bottom: Space.xxl),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.xl, Space.s, Space.xl, Space.l),
                    child: Text('${l.topicsCount(topics.length)} · ${l.topicRulesHint}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  for (final t in topics)
                    ListTile(
                      title: Text(
                        (_rules[t.id]?.name.isNotEmpty ?? false) ? _rules[t.id]!.name : t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _rules[t.id]?.mode == TopicMode.skip ? Palette.textFaint : null),
                      ),
                      subtitle: (_rules[t.id]?.name.isNotEmpty ?? false) ? Text(t.name) : null,
                      onTap: () => _rename(t),
                      trailing: DropdownButton<TopicMode>(
                        value: _rules[t.id]?.mode ?? TopicMode.auto,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(Radii.m),
                        items: [for (final e in modes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                        onChanged: (m) => _set(t.id, (_rules[t.id] ?? const TopicRule()).copyWith(mode: m)),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
