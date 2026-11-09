import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/scope.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/welcome_screen.dart';
import 'l10n/gen/app_localizations.dart';
import 'ui/theme.dart';

class EroStreamApp extends StatelessWidget {
  const EroStreamApp({super.key});

  static final _theme = buildTheme();

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return ListenableBuilder(
      listenable: s.settings,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (c) => L.of(c).appTitle,
        debugShowCheckedModeBanner: false,
        theme: _theme,
        darkTheme: _theme,
        themeMode: ThemeMode.dark,
        locale: s.settings.locale,
        supportedLocales: L.supportedLocales,
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        shortcuts: {
          ...WidgetsApp.defaultShortcuts,
          // TV remotes send "select" for OK.
          const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        },
        home: const _Root(),
      ),
    );
  }
}

/// First run shows the welcome/login flow, afterwards the library.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final libs = context.services.libraries;
    return ListenableBuilder(
      listenable: libs,
      builder: (context, _) => AnimatedSwitcher(
        duration: Motion.normal,
        child: libs.onboarded ? const HomeShell() : WelcomeScreen(onDone: libs.setOnboarded),
      ),
    );
  }
}
