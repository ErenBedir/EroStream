import 'package:flutter/material.dart';

import 'theme.dart';

/// Centered column with a readable max width. Used by forms and empty states.
class Readable extends StatelessWidget {
  const Readable({super.key, required this.child, this.maxWidth = 440, this.padding = const EdgeInsets.all(Space.xl)});

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
        ),
      );
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'Ero'),
          TextSpan(text: 'Stream', style: TextStyle(color: Palette.accent, fontSize: size)),
        ]),
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: Palette.text),
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.l, Space.xl, Space.l, Space.s),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Palette.textFaint, letterSpacing: 1)),
      );
}

class ErrorLine extends StatelessWidget {
  const ErrorLine(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: Motion.fast,
        child: message == null || message!.isEmpty
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: Space.m),
                child: Text(message!, style: const TextStyle(color: Palette.danger, fontSize: 13)),
              ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Readable(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Palette.textFaint),
          const SizedBox(height: Space.l),
          Text(title, style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: Space.s),
          Text(body, style: t.bodyMedium?.copyWith(color: Palette.textDim), textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: Space.xl), action!],
        ],
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String message, {required String yes, required String no}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(no)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
      ],
    ),
  );
  return r ?? false;
}
