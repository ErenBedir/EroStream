import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/scope.dart';
import 'core/settings.dart';
import 'library/library_repository.dart';
import 'telegram/telegram_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Settings.load();
  final services = Services(
    settings: settings,
    telegram: TelegramService(settings),
    libraries: LibraryRepository(settings),
  );
  runApp(AppScope(services: services, child: const EroStreamApp()));
  await _startTelegram(services);
}

Future<void> _startTelegram(Services s) async {
  var db = 'tdlib/db', files = 'tdlib/files', system = 'web';
  if (!kIsWeb) {
    final dir = await getApplicationSupportDirectory();
    db = '${dir.path}/tdlib/db';
    files = '${dir.path}/tdlib/files';
    system = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }
  final lang = s.settings.localeCode.isNotEmpty
      ? s.settings.localeCode
      : WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  await s.telegram.start(databaseDir: db, filesDir: files, languageCode: lang, systemVersion: system);
}
