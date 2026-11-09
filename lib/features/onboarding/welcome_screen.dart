import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onDone});

  final Future<void> Function() onDone;

  Future<void> _telegram(BuildContext context) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen()));
    if (ok == true) await onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Readable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Wordmark(size: 28),
              const SizedBox(height: Space.xxl),
              Text(l.welcomeTitle, style: t.displaySmall),
              const SizedBox(height: Space.m),
              Text(l.welcomeBody, style: t.bodyLarge?.copyWith(color: Palette.textDim)),
              const SizedBox(height: Space.xxl),
              FilledButton.icon(
                autofocus: true,
                onPressed: () => _telegram(context),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(l.loginWithTelegram),
              ),
              const SizedBox(height: Space.m),
              OutlinedButton(onPressed: onDone, child: Text(l.skipForNow)),
            ],
          ),
        ),
      ),
    );
  }
}
