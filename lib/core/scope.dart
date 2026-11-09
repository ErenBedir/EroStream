import 'package:flutter/widgets.dart';

import '../library/library_repository.dart';
import '../telegram/telegram_service.dart';
import 'settings.dart';

/// App-wide services. Created once in `main`.
class Services {
  Services({required this.settings, required this.telegram, required this.libraries});

  final Settings settings;
  final TelegramService telegram;
  final LibraryRepository libraries;
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
