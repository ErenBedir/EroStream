import '../core/settings.dart';
import '../library/items.dart';
import '../telegram/telegram_service.dart';
import 'stream_server.dart';

StreamServer create(TelegramService telegram, Settings settings) => _NoStream();

/// Web: Telegram playback goes through a service worker (not done yet).
class _NoStream implements StreamServer {
  @override
  bool get supportsTelegram => false;

  @override
  Future<Uri?> urlFor(MediaItem item) async => item.path.isEmpty ? null : Uri.tryParse(item.path);

  @override
  Future<void> release(MediaItem item) async {}

  @override
  Future<void> dispose() async {}
}
