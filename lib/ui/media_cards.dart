import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../library/items.dart';
import '../metadata/tmdb.dart';
import 'theme.dart';

/// TMDB image, decoded at display size and cached on disk.
class TmdbImage extends StatelessWidget {
  const TmdbImage(this.path, {super.key, this.size = 'w342', this.decodeWidth, this.fit = BoxFit.cover, this.fallback});

  final String? path;
  final String size;
  final int? decodeWidth;
  final BoxFit fit;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null || p.isEmpty) return fallback ?? const SizedBox.shrink();
    return CachedNetworkImage(
      imageUrl: TmdbClient.image(p, size: size),
      fit: fit,
      memCacheWidth: decodeWidth,
      fadeInDuration: Motion.normal,
      fadeOutDuration: Duration.zero,
      placeholder: (_, _) => const ColoredBox(color: Palette.surface),
      errorWidget: (_, _, _) => fallback ?? const ColoredBox(color: Palette.surface),
    );
  }
}

/// Focus / hover / press handling shared by cards. Grows slightly and shows an
/// accent outline when focused (TV remote, keyboard).
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.radius = Radii.m, this.autofocus = false});

  final Widget child;
  final VoidCallback onTap;
  final double radius;
  final bool autofocus;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _focus = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final lifted = _focus || _hover;
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) {
        setState(() => _focus = v);
        if (v) {
          Scrollable.ensureVisible(context, alignment: 0.5, duration: Motion.normal, curve: Motion.curve);
        }
      },
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap())},
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: lifted ? 1.04 : 1,
          duration: Motion.fast,
          curve: Motion.curve,
          child: AnimatedContainer(
            duration: Motion.fast,
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(color: _focus ? Palette.accent : Colors.transparent, width: 2),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: lifted
                  ? const [BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 8))]
                  : const [],
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(widget.radius), child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Placeholder art: title on a soft gradient derived from the name.
class TitleFallback extends StatelessWidget {
  const TitleFallback(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final h = (title.hashCode % 360).abs().toDouble();
    final a = HSLColor.fromAHSL(1, h, 0.22, 0.20).toColor();
    final b = HSLColor.fromAHSL(1, (h + 40) % 360, 0.18, 0.12).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.m),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.2, color: Palette.text),
          ),
        ),
      ),
    );
  }
}

class PosterCard extends StatelessWidget {
  const PosterCard({super.key, required this.title, required this.onTap, this.width = 140, this.autofocus = false});

  final TitleEntry title;
  final VoidCallback onTap;
  final double width;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(
            autofocus: autofocus,
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: TmdbImage(
                title.posterPath,
                decodeWidth: (width * dpr).round(),
                fallback: TitleFallback(title.displayName),
              ),
            ),
          ),
          const SizedBox(height: Space.s),
          Text(
            title.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Palette.textDim),
          ),
        ],
      ),
    );
  }
}

/// 16:9 card with a progress line, for "continue watching" and episodes.
class LandscapeCard extends StatelessWidget {
  const LandscapeCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.progress = 0,
    this.width = 280,
    this.fallbackTitle,
    this.imageSize = 'w780',
  });

  final String? imagePath;
  final String title;
  final String subtitle;
  final double progress;
  final VoidCallback onTap;
  final double width;
  final String? fallbackTitle;
  final String imageSize;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TmdbImage(
                    imagePath,
                    size: imageSize,
                    decodeWidth: (width * dpr).round(),
                    fallback: TitleFallback(fallbackTitle ?? title),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x99000000)],
                        stops: [0.55, 1],
                      ),
                    ),
                  ),
                  const Center(child: Icon(Icons.play_circle_outline_rounded, size: 40, color: Color(0xCCFFFFFF))),
                  if (progress > 0)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: const Color(0x33FFFFFF),
                        color: Palette.accent,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.s),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium),
          if (subtitle.isNotEmpty)
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
        ],
      ),
    );
  }
}

/// Titled horizontal row.
class Shelf extends StatelessWidget {
  const Shelf({super.key, required this.title, required this.height, required this.children, this.trailing});

  final String title;
  final double height;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pad = Breakpoints.isWide(context) ? Space.xxl : Space.xl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, Space.xl, pad - Space.s, Space.m),
          child: Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
              ?trailing,
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: FocusTraversalGroup(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: Space.xs),
              clipBehavior: Clip.none,
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.l),
              itemBuilder: (_, i) => children[i],
            ),
          ),
        ),
      ],
    );
  }
}
