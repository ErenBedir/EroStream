import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/scope.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../library/items.dart';
import '../../ui/theme.dart';
import 'mpv_tuning.dart';

/// Full-screen player with its own overlay (touch, mouse and TV remote).
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.item, this.startOver = false});

  final MediaItem item;
  final bool startOver;

  static Future<void> open(BuildContext context, MediaItem item, {bool startOver = false}) =>
      Navigator.of(context).push(PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => PlayerScreen(item: item, startOver: startOver),
        transitionDuration: Motion.normal,
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ));

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player = Player(configuration: const PlayerConfiguration(bufferSize: 32 * 1024 * 1024));
  late final VideoController _video = VideoController(_player);
  final _focus = FocusNode();
  final _subs = <StreamSubscription<Object?>>[];

  late final Services _s = context.services;
  late MediaItem _item = widget.item;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _playing = false;
  bool _buffering = true;
  bool _overlay = true;
  String? _error;
  Timer? _hide;
  Timer? _save;
  MediaItem? _upNext;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _subs.addAll([
      _player.stream.position.listen((p) => setState(() => _pos = p)),
      _player.stream.duration.listen((d) => setState(() => _dur = d)),
      _player.stream.playing.listen((p) => setState(() => _playing = p)),
      _player.stream.buffering.listen((b) => setState(() => _buffering = b)),
      _player.stream.completed.listen((c) {
        if (c) _onCompleted();
      }),
      _player.stream.error.listen((e) {
        if (_dur == Duration.zero) setState(() => _error = e);
      }),
    ]);
    _s.toString(); // resolve services while the element is active
    _save = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open(_item, startOver: widget.startOver);
    });
  }

  Future<void> _open(MediaItem item, {bool startOver = false}) async {
    final s = _s;
    final lang = Localizations.localeOf(context).languageCode;
    setState(() {
      _item = item;
      _error = null;
      _upNext = null;
      _buffering = true;
      _pos = Duration.zero;
      _dur = Duration.zero;
    });
    final url = await s.stream.urlFor(item);
    if (!mounted) return;
    if (url == null) {
      setState(() => _error = L.of(context).playbackUnsupported);
      return;
    }
    await tunePlayer(_player, subtitleLanguages: lang == 'tr' ? 'tur,tr,turkish,eng,en' : '$lang,eng,en');
    final p = s.store.progressOf(item.id);
    final start = !startOver && p != null && p.resumable ? Duration(seconds: p.position) : null;
    await _player.open(Media(url.toString(), start: start));
    _kick();
  }

  void _saveProgress() {
    if (_dur.inSeconds <= 0 || _pos.inSeconds <= 0) return;
    _s.store.setProgress(_item.id, _pos.inSeconds, _dur.inSeconds);
  }

  void _onCompleted() {
    _saveProgress();
    final next = _s.store.nextEpisode(_item);
    if (next == null) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _upNext = next;
      _countdown = 8;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_countdown <= 1) {
        t.cancel();
        _playNext();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _playNext() {
    final n = _upNext ?? _s.store.nextEpisode(_item);
    _countdownTimer?.cancel();
    if (n == null) return;
    _saveProgress();
    unawaited(_s.stream.release(_item));
    _open(n);
  }

  void _kick() {
    _hide?.cancel();
    if (!_overlay) setState(() => _overlay = true);
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted && _playing) setState(() => _overlay = false);
    });
  }

  void _seekBy(int seconds) {
    final t = _pos + Duration(seconds: seconds);
    _player.seek(t < Duration.zero ? Duration.zero : (_dur > Duration.zero && t > _dur ? _dur : t));
    _kick();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (_upNext != null && (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter)) {
      _playNext();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.mediaPlayPause) {
      if (!_overlay) {
        _kick();
      } else {
        _player.playOrPause();
        _kick();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.mediaRewind) {
      _seekBy(-10);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.mediaFastForward) {
      _seekBy(30);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) {
      _kick();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _tracks() async {
    _hide?.cancel();
    final l = L.of(context);
    final tracks = _player.state.tracks;
    final cur = _player.state.track;
    String name(String? title, String? lang, String id) =>
        [title, lang].where((x) => x != null && x.isNotEmpty).join(' · ').ifEmpty(id);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.surface,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: Space.l),
          children: [
            _SheetLabel(l.audio),
            for (final t in tracks.audio.where((t) => t.id != 'auto' && t.id != 'no'))
              ListTile(
                autofocus: t == cur.audio,
                title: Text(name(t.title, t.language, t.id)),
                trailing: t == cur.audio ? const Icon(Icons.check_rounded, color: Palette.accent) : null,
                onTap: () {
                  _player.setAudioTrack(t);
                  Navigator.pop(c);
                },
              ),
            _SheetLabel(l.subtitles),
            ListTile(
              title: Text(l.off),
              trailing: cur.subtitle.id == 'no' ? const Icon(Icons.check_rounded, color: Palette.accent) : null,
              onTap: () {
                _player.setSubtitleTrack(SubtitleTrack.no());
                Navigator.pop(c);
              },
            ),
            for (final t in tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no'))
              ListTile(
                title: Text(name(t.title, t.language, t.id)),
                trailing: t == cur.subtitle ? const Icon(Icons.check_rounded, color: Palette.accent) : null,
                onTap: () {
                  _player.setSubtitleTrack(t);
                  Navigator.pop(c);
                },
              ),
          ],
        ),
      ),
    );
    _kick();
  }

  @override
  void dispose() {
    _saveProgress();
    unawaited(_s.store.flush());
    unawaited(_s.stream.release(_item));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    for (final s in _subs) {
      s.cancel();
    }
    _hide?.cancel();
    _save?.cancel();
    _countdownTimer?.cancel();
    _focus.dispose();
    _player.dispose();
    super.dispose();
  }

  String _subtitle(L l) {
    final i = _item;
    final parts = <String>[
      if (i.kind == ItemKind.tv && i.episode != null) l.episodeCode(i.season ?? 1, i.episode!),
      if (i.label.isNotEmpty) i.label,
    ];
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final title = _s.store.title(_item.titleKey)?.displayName ?? _item.fileName;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          onHover: (_) => _kick(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _overlay ? setState(() => _overlay = false) : _kick(),
            onDoubleTapDown: (d) {
              final w = MediaQuery.sizeOf(context).width;
              _seekBy(d.globalPosition.dx < w / 2 ? -10 : 10);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Video(controller: _video, controls: NoVideoControls, fill: Colors.black),
                if (_buffering && _error == null)
                  const Center(child: SizedBox.square(dimension: 44, child: CircularProgressIndicator(strokeWidth: 2.5))),
                AnimatedOpacity(
                  opacity: _overlay || !_playing ? 1 : 0,
                  duration: Motion.normal,
                  child: IgnorePointer(
                    ignoring: !(_overlay || !_playing),
                    child: _Overlay(
                      title: title,
                      subtitle: _subtitle(l),
                      pos: _pos,
                      dur: _dur,
                      playing: _playing,
                      hasNext: _s.store.nextEpisode(_item) != null,
                      onBack: () => Navigator.of(context).maybePop(),
                      onPlayPause: () {
                        _player.playOrPause();
                        _kick();
                      },
                      onSeek: (d) {
                        _player.seek(d);
                        _kick();
                      },
                      onRewind: () => _seekBy(-10),
                      onForward: () => _seekBy(30),
                      onTracks: _tracks,
                      onNext: _playNext,
                    ),
                  ),
                ),
                if (_error != null) _ErrorView(message: _error!, onRetry: () => _open(_item)),
                if (_upNext != null)
                  Positioned(
                    right: Space.xxl,
                    bottom: Space.xxxl * 2,
                    child: _UpNextCard(
                      item: _upNext!,
                      seconds: _countdown,
                      onPlay: _playNext,
                      onCancel: () {
                        _countdownTimer?.cancel();
                        setState(() => _upNext = null);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

String _fmt(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  String two(int x) => x.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.title,
    required this.subtitle,
    required this.pos,
    required this.dur,
    required this.playing,
    required this.hasNext,
    required this.onBack,
    required this.onPlayPause,
    required this.onSeek,
    required this.onRewind,
    required this.onForward,
    required this.onTracks,
    required this.onNext,
  });

  final String title;
  final String subtitle;
  final Duration pos;
  final Duration dur;
  final bool playing;
  final bool hasNext;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onRewind;
  final VoidCallback onForward;
  final VoidCallback onTracks;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final max = dur.inMilliseconds.toDouble();
    final value = pos.inMilliseconds.toDouble().clamp(0, max <= 0 ? 1 : max).toDouble();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB3000000), Color(0x00000000), Color(0x00000000), Color(0xCC000000)],
          stops: [0, 0.25, 0.6, 1],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.l),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (subtitle.isNotEmpty) Text(subtitle, style: t.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(iconSize: 36, onPressed: onRewind, icon: const Icon(Icons.replay_10_rounded)),
                  const SizedBox(width: Space.xxl),
                  IconButton.filled(
                    iconSize: 44,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(Space.l),
                    ),
                    onPressed: onPlayPause,
                    icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  ),
                  const SizedBox(width: Space.xxl),
                  IconButton(iconSize: 36, onPressed: onForward, icon: const Icon(Icons.forward_30_rounded)),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Text(_fmt(pos), style: t.labelMedium),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: Palette.accent,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Palette.accent,
                      ),
                      child: Slider(
                        value: value,
                        max: max <= 0 ? 1 : max,
                        onChanged: max <= 0 ? null : (v) => onSeek(Duration(milliseconds: v.round())),
                      ),
                    ),
                  ),
                  Text(_fmt(dur), style: t.labelMedium),
                  const SizedBox(width: Space.m),
                  IconButton(onPressed: onTracks, icon: const Icon(Icons.subtitles_outlined)),
                  if (hasNext) IconButton(onPressed: onNext, icon: const Icon(Icons.skip_next_rounded)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.item, required this.seconds, required this.onPlay, required this.onCancel});

  final MediaItem item;
  final int seconds;
  final VoidCallback onPlay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(
        color: Palette.surfaceHigh.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(Radii.l),
        border: Border.all(color: Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.upNextIn(seconds), style: t.labelMedium?.copyWith(color: Palette.accent)),
          const SizedBox(height: Space.xs),
          Text(l.episodeCode(item.season ?? 1, item.episode ?? 0), style: t.titleMedium),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Expanded(child: FilledButton(autofocus: true, onPressed: onPlay, child: Text(l.play))),
              const SizedBox(width: Space.s),
              Expanded(child: OutlinedButton(onPressed: onCancel, child: Text(l.cancel))),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: Palette.textFaint),
              const SizedBox(height: Space.l),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Palette.textDim)),
              const SizedBox(height: Space.xl),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(l.back)),
                  const SizedBox(width: Space.m),
                  FilledButton(autofocus: true, onPressed: onRetry, child: Text(l.retry)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.xl, Space.l, Space.xl, Space.xs),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Palette.textFaint, letterSpacing: 1)),
      );
}
