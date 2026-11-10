import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/scope.dart';
import 'core/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final settings = await Settings.load();
  final services = Services.create(settings);
  await services.store.load();
  runApp(AppScope(services: services, child: const EroStreamApp()));
  await _startTelegram(services);
  // Pick up new files once the account is ready.
  void onReady() {
    if (services.telegram.isReady) {
      services.telegram.removeListener(onReady);
      services.sync.syncAll(uiLanguage: _lang(services));
    }
  }

  services.telegram.addListener(onReady);
  onReady();
}

String _lang(Services s) => s.settings.localeCode.isNotEmpty
    ? s.settings.localeCode
    : WidgetsBinding.instance.platformDispatcher.locale.languageCode;

Future<void> _startTelegram(Services s) async {
  var db = 'tdlib/db', files = 'tdlib/files', system = 'web';
  if (!kIsWeb) {
    final dir = await getApplicationSupportDirectory();
    db = '${dir.path}/tdlib/db';
    files = '${dir.path}/tdlib/files';
    system = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }
  await s.telegram.start(databaseDir: db, filesDir: files, languageCode: _lang(s), systemVersion: system);
}
