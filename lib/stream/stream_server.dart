import '../core/settings.dart';
import '../library/items.dart';
import '../telegram/telegram_service.dart';
import 'stream_server_stub.dart' if (dart.library.io) 'stream_server_io.dart' as impl;

/// Turns library items into URLs the player can open.
///
/// Native: Telegram files are served from a loopback HTTP server that downloads
/// only the byte ranges the player asks for.
abstract class StreamServer {
  bool get supportsTelegram;

  /// Null when the item can't be played on this platform.
  Future<Uri?> urlFor(MediaItem item);

  /// Stops background downloading for [item] and trims the cache.
  Future<void> release(MediaItem item);

  Future<void> dispose();
}

StreamServer createStreamServer(TelegramService telegram, Settings settings) => impl.create(telegram, settings);
