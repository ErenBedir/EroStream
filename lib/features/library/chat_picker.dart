import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../library/models.dart';
import '../../media/name_parser.dart';
import '../../telegram/td_client.dart';
import '../../telegram/telegram_service.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Lists channels and supergroups of the signed-in account. Pops with a [TelegramSource].
class ChatPicker extends StatefulWidget {
  const ChatPicker({super.key});

  @override
  State<ChatPicker> createState() => _ChatPickerState();
}

class _ChatPickerState extends State<ChatPicker> {
  final _q = TextEditingController();
  List<TgChat>? _chats;
  String? _error;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final c = await context.services.telegram.listMediaChats();
      if (mounted) setState(() => _chats = c);
    } on TdError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool get _looksLikeLink => RegExp(r'^(@|https?://|t\.me/)').hasMatch(_q.text.trim());

  Future<void> _resolve() async {
    setState(() {
      _resolving = true;
      _error = null;
    });
    try {
      final c = await context.services.telegram.resolvePublicChat(_q.text);
      if (!mounted) return;
      if (c == null) {
        setState(() => _error = L.of(context).noSources);
      } else {
        _pick(c);
      }
    } on TdError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _pick(TgChat c) => Navigator.of(context).pop(
        TelegramSource(chatId: c.id, title: c.title, isForum: c.isForum, isChannel: c.isChannel),
      );

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final key = foldKey(_q.text);
    final chats = (_chats ?? const <TgChat>[]).where((c) => key.isEmpty || foldKey(c.title).contains(key)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.pickChat)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.s),
            child: TextField(
              controller: _q,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _looksLikeLink ? _resolve() : null,
              decoration: InputDecoration(
                hintText: l.searchChats,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _looksLikeLink
                    ? IconButton(
                        onPressed: _resolving ? null : _resolve,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      )
                    : null,
              ),
            ),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.symmetric(horizontal: Space.l), child: ErrorLine(_error)),
          Expanded(
            child: _chats == null && _error == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.s),
                    itemCount: chats.length,
                    itemBuilder: (context, i) {
                      final c = chats[i];
                      return ListTile(
                        leading: Icon(c.isForum
                            ? Icons.forum_outlined
                            : c.isChannel
                                ? Icons.campaign_outlined
                                : Icons.group_outlined),
                        title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(c.isForum ? l.forumGroup : (c.isChannel ? l.channel : l.group)),
                        onTap: () => _pick(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
