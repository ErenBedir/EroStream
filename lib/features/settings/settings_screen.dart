import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/scope.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../telegram/telegram_service.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../onboarding/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const repoUrl = 'https://github.com/ErenBedir/EroStream';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final s = context.services;
    return ListenableBuilder(
      listenable: Listenable.merge([s.settings, s.telegram]),
      builder: (context, _) {
        final tg = s.telegram;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.s, Space.l, Space.s, Space.xxxl),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.l),
                  child: Text(l.settings, style: Theme.of(context).textTheme.headlineSmall),
                ),
                SectionLabel(l.language),
                const _LanguageTile(),
                SectionLabel(l.account),
                ListTile(
                  leading: const Icon(Icons.send_rounded),
                  title: Text(tg.isReady ? l.signedInAs(tg.meName) : l.notSignedIn),
                  subtitle: tg.step == AuthStep.unavailable ? Text(l.telegramUnavailable) : null,
                  trailing: tg.isReady
                      ? TextButton(
                          onPressed: () async {
                            if (await confirm(context, l.signOutConfirm, yes: l.signOut, no: l.cancel)) {
                              await tg.logOut();
                            }
                          },
                          child: Text(l.signOut),
                        )
                      : tg.step == AuthStep.unavailable
                          ? null
                          : TextButton(
                              onPressed: () => Navigator.of(context)
                                  .push(MaterialPageRoute<bool>(builder: (_) => const LoginScreen())),
                              child: Text(l.signIn),
                            ),
                ),
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: Text(l.credentialsTitle),
                  subtitle: Text(s.settings.apiIdOverride != 0 ? '${s.settings.apiIdOverride}' : '—'),
                  onTap: () => _editCredentials(context),
                ),
                SectionLabel(l.metadata),
                _TextSettingTile(
                  icon: Icons.movie_filter_outlined,
                  title: l.tmdbKey,
                  help: l.tmdbKeyHelp,
                  value: s.settings.tmdbKeyOverride,
                  obscure: true,
                  onSave: (v) => s.settings.tmdbKeyOverride = v,
                ),
                _TextSettingTile(
                  icon: Icons.translate_rounded,
                  title: l.metadataLanguage,
                  help: l.metadataLanguageHelp,
                  value: s.settings.tmdbLanguage,
                  onSave: (v) => s.settings.tmdbLanguage = v,
                ),
                SectionLabel(l.storage),
                ListTile(
                  leading: const Icon(Icons.sd_storage_outlined),
                  title: Text(l.cacheLimit),
                  trailing: DropdownButton<int>(
                    value: s.settings.cacheLimitMb,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(Radii.m),
                    items: [
                      for (final mb in const [512, 1024, 2048, 4096, 8192, 16384])
                        DropdownMenuItem(value: mb, child: Text(l.megabytes(mb))),
                    ],
                    onChanged: (v) => s.settings.cacheLimitMb = v ?? 2048,
                  ),
                ),
                SectionLabel(l.about),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text(AppConfig.appName),
                  subtitle: Text(l.versionText(AppConfig.version)),
                ),
                const ListTile(
                  leading: Icon(Icons.code_rounded),
                  title: SelectableText(repoUrl),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
                  child: Text(l.tmdbNotice, style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editCredentials(BuildContext context) async {
    final l = L.of(context);
    final s = context.services;
    final id = TextEditingController(text: s.settings.apiIdOverride == 0 ? '' : '${s.settings.apiIdOverride}');
    final hash = TextEditingController(text: s.settings.apiHashOverride);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.credentialsTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.credentialsBody, style: Theme.of(c).textTheme.bodySmall),
            const SizedBox(height: Space.l),
            TextField(controller: id, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.apiId)),
            const SizedBox(height: Space.m),
            TextField(controller: hash, decoration: InputDecoration(labelText: l.apiHash)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.save)),
        ],
      ),
    );
    if (ok == true) {
      await s.settings.setTelegramCredentials(int.tryParse(id.text.trim()) ?? 0, hash.text);
      if (s.telegram.step == AuthStep.missingCredentials) await s.telegram.retry();
    }
    id.dispose();
    hash.dispose();
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final settings = context.services.settings;
    return ListTile(
      leading: const Icon(Icons.language_rounded),
      title: Text(l.language),
      trailing: DropdownButton<String>(
        value: settings.localeCode,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(Radii.m),
        items: [
          DropdownMenuItem(value: '', child: Text(l.systemLanguage)),
          // Each language shows its own name; new ARB files appear here automatically.
          for (final loc in L.supportedLocales)
            DropdownMenuItem(value: loc.languageCode, child: Text(lookupL(loc).languageName)),
        ],
        onChanged: (v) => settings.localeCode = v ?? '',
      ),
    );
  }
}

class _TextSettingTile extends StatelessWidget {
  const _TextSettingTile({
    required this.icon,
    required this.title,
    required this.help,
    required this.value,
    required this.onSave,
    this.obscure = false,
  });

  final IconData icon;
  final String title;
  final String help;
  final String value;
  final bool obscure;
  final void Function(String) onSave;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final shown = value.isEmpty ? '—' : (obscure ? '•' * 8 : value);
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text('$shown\n$help'),
      isThreeLine: true,
      onTap: () async {
        final c = TextEditingController(text: value);
        final v = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: TextField(controller: c, autofocus: true, decoration: InputDecoration(helperText: help, helperMaxLines: 3)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(l.save)),
            ],
          ),
        );
        c.dispose();
        if (v != null) onSave(v);
      },
    );
  }
}
