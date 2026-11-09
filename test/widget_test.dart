import 'package:erostream/app.dart';
import 'package:erostream/core/scope.dart';
import 'package:erostream/core/settings.dart';
import 'package:erostream/library/library_repository.dart';
import 'package:erostream/telegram/telegram_service.dart';
import 'package:erostream/telegram/transport/td_transport_stub.dart' as stub;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Services> _services(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final settings = await Settings.load();
  return Services(
    settings: settings,
    telegram: TelegramService(settings, transportFactory: stub.createTransport),
    libraries: LibraryRepository(settings),
  );
}

void main() {
  testWidgets('first run shows the welcome screen', (tester) async {
    final s = await _services({'locale': 'en'});
    await tester.pumpWidget(AppScope(services: s, child: const EroStreamApp()));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with Telegram'), findsOneWidget);
    expect(find.text('Local files only'), findsOneWidget);
  });

  testWidgets('local-only start lands on the empty library screen (Turkish)', (tester) async {
    final s = await _services({'locale': 'tr'});
    await tester.pumpWidget(AppScope(services: s, child: const EroStreamApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sadece yerel dosyalar'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz kütüphane yok'), findsOneWidget);
  });

  testWidgets('library can be created', (tester) async {
    final s = await _services({'locale': 'en', 'onboarded': '1'});
    await tester.pumpWidget(AppScope(services: s, child: const EroStreamApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add library'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Series');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(s.libraries.libraries.single.name, 'Series');
    expect(find.text('Nothing scanned yet.'), findsOneWidget);
  });
}
