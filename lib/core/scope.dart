import 'package:flutter/widgets.dart';

import '../library/library_repository.dart';
import '../library/media_store.dart';
import '../library/sync_service.dart';
import '../stream/stream_server.dart';
import '../telegram/telegram_service.dart';
import 'settings.dart';

/// App-wide services. Created once in `main`.
class Services {
  Services({
    required this.settings,
    required this.telegram,
    required this.libraries,
    required this.store,
    required this.sync,
    required this.stream,
  });

  factory Services.create(Settings settings, {TelegramService? telegram, MediaStore? store}) {
    final tg = telegram ?? TelegramService(settings);
    final libs = LibraryRepository(settings);
    final st = store ?? MediaStore();
    return Services(
      settings: settings,
      telegram: tg,
      libraries: libs,
      store: st,
      sync: SyncService(settings: settings, telegram: tg, libraries: libs, store: st),
      stream: createStreamServer(tg, settings),
    );
  }

  final Settings settings;
  final TelegramService telegram;
  final LibraryRepository libraries;
  final MediaStore store;
  final SyncService sync;
  final StreamServer stream;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final Services services;

  static Services of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}

extension ServicesX on BuildContext {
  Services get services => AppScope.of(this);
}
