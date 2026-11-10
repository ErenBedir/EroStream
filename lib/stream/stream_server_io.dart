import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/settings.dart';
import '../library/items.dart';
import '../telegram/td_client.dart';
import '../telegram/telegram_service.dart';
import 'stream_server.dart';

StreamServer create(TelegramService telegram, Settings settings) => IoStreamServer(telegram, settings);

class _FileRef {
  _FileRef(this.id, this.size, this.at);

  final int id;
  final int size;
  final DateTime at;
}

/// `GET /tg/<chat>/<message>/<name>` with Range support, backed by TDLib partial downloads.
class IoStreamServer implements StreamServer {
  IoStreamServer(this.telegram, this.settings);

  final TelegramService telegram;
  final Settings settings;

  static const _chunk = 512 * 1024;
  static const _wait = Duration(seconds: 90);

  HttpServer? _server;
  Future<HttpServer>? _starting;
  final _refs = <String, _FileRef>{};

  TdClient get _td => telegram.client;

  @override
  bool get supportsTelegram => true;

  Future<HttpServer> _ensure() {
    final s = _server;
    if (s != null) return Future.value(s);
    return _starting ??= HttpServer.bind(InternetAddress.loopbackIPv4, 0).then((srv) {
      _server = srv;
      srv.listen(_handle, onError: (Object e) => debugPrint('stream server: $e'));
      return srv;
    });
  }

  @override
  Future<Uri?> urlFor(MediaItem item) async {
    if (!item.isTelegram) return item.path.isEmpty ? null : Uri.file(item.path);
    final srv = await _ensure();
    final name = Uri.encodeComponent(item.fileName.isEmpty ? 'video.mkv' : item.fileName);
    return Uri.parse('http://127.0.0.1:${srv.port}/tg/${item.chatId}/${item.messageId}/$name');
  }

  Future<_FileRef> _resolve(int chat, int msg) async {
    final k = '$chat:$msg';
    final cached = _refs[k];
    if (cached != null && DateTime.now().difference(cached.at) < const Duration(minutes: 30)) return cached;
    final m = await _td.send({'@type': 'getMessage', 'chat_id': chat, 'message_id': msg});
    final c = (m['content'] as Map).cast<String, dynamic>();
    final Map<String, dynamic>? f = switch (c['@type']) {
      'messageVideo' => ((c['video'] as Map)['video'] as Map).cast<String, dynamic>(),
      'messageDocument' => ((c['document'] as Map)['document'] as Map).cast<String, dynamic>(),
      _ => null,
    };
    if (f == null) throw TdError(404, 'not a video message');
    final size = (f['size'] as num?)?.toInt() ?? 0;
    final ref = _FileRef(
      (f['id'] as num).toInt(),
      size != 0 ? size : (f['expected_size'] as num?)?.toInt() ?? 0,
      DateTime.now(),
    );
    _refs[k] = ref;
    return ref;
  }

  static String _mime(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.mp4') || n.endsWith('.m4v')) return 'video/mp4';
    if (n.endsWith('.webm')) return 'video/webm';
    if (n.endsWith('.avi')) return 'video/x-msvideo';
    if (n.endsWith('.ts')) return 'video/mp2t';
    if (n.endsWith('.mov')) return 'video/quicktime';
    return 'video/x-matroska';
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    RandomAccessFile? raf;
    try {
      final seg = req.uri.pathSegments;
      if (seg.length < 3 || seg[0] != 'tg') {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }
      final ref = await _resolve(int.parse(seg[1]), int.parse(seg[2]));
      final size = ref.size;
      var start = 0, end = size - 1;
      final range = req.headers.value(HttpHeaders.rangeHeader);
      final m = range == null ? null : RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range);
      if (m != null) {
        if (m.group(1)!.isEmpty) {
          start = math.max(0, size - int.parse(m.group(2)!)); // suffix range
        } else {
          start = int.parse(m.group(1)!);
          if (m.group(2)!.isNotEmpty) end = math.min(int.parse(m.group(2)!), size - 1);
        }
        if (start >= size) {
          res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$size');
          await res.close();
          return;
        }
        res.statusCode = HttpStatus.partialContent;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$size');
      }
      res.headers
        ..set(HttpHeaders.acceptRangesHeader, 'bytes')
        ..set(HttpHeaders.contentTypeHeader, _mime(seg.length > 3 ? seg[3] : ''))
        ..contentLength = end - start + 1;
      if (req.method == 'HEAD') {
        await res.close();
        return;
      }

      var pos = start;
      String? openPath;
      while (pos <= end) {
        final want = math.min(_chunk, end - pos + 1);
        final path = await _waitFor(ref, pos, want);
        if (raf == null || openPath != path) {
          await raf?.close();
          raf = await File(path).open();
          openPath = path;
        }
        await raf.setPosition(pos);
        final bytes = await raf.read(want);
        if (bytes.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          continue;
        }
        res.add(bytes);
        await res.flush();
        pos += bytes.length;
      }
      await res.close();
    } catch (e) {
      // Player closed the connection or seeked away; nothing to report.
      try {
        await res.close();
      } catch (_) {}
    } finally {
      await raf?.close();
    }
  }

  /// Returns the local path once [want] bytes from [offset] are on disk.
  Future<String> _waitFor(_FileRef ref, int offset, int want) async {
    final deadline = DateTime.now().add(_wait);
    var requested = false;
    var path = '';
    var n = 0;
    while (true) {
      final f = await _td.send({'@type': 'getFile', 'file_id': ref.id});
      final local = (f['local'] as Map).cast<String, dynamic>();
      path = '${local['path'] ?? ''}';
      if (local['is_downloading_completed'] == true && path.isNotEmpty) return path;
      final have = (await _td.send({'@type': 'getFileDownloadedPrefixSize', 'file_id': ref.id, 'offset': offset}))['size'];
      if (path.isNotEmpty && ((have as num?)?.toInt() ?? 0) >= want) return path;
      // Ask TDLib to download from here to the end; it keeps going while we read.
      if (!requested || (local['is_downloading_active'] != true && n % 25 == 0)) {
        await _td.send({
          '@type': 'downloadFile',
          'file_id': ref.id,
          'priority': 32,
          'offset': offset,
          'limit': 0,
          'synchronous': false,
        });
        requested = true;
      }
      if (DateTime.now().isAfter(deadline)) throw TimeoutException('download stalled at $offset');
      n++;
      await Future<void>.delayed(Duration(milliseconds: n < 20 ? 40 : 120));
    }
  }

  @override
  Future<void> release(MediaItem item) async {
    if (!item.isTelegram) return;
    final ref = _refs['${item.chatId}:${item.messageId}'];
    try {
      if (ref != null) await _td.send({'@type': 'cancelDownloadFile', 'file_id': ref.id, 'only_if_pending': false});
      await _td.send({
        '@type': 'optimizeStorage',
        'size': settings.cacheLimitMb * 1024 * 1024,
        'ttl': -1,
        'count': -1,
        'immunity_delay': -1,
        'file_types': null,
        'chat_ids': null,
        'exclude_chat_ids': null,
        'return_deleted_file_statistics': false,
        'chat_limit': -1,
      }, timeout: const Duration(minutes: 2));
    } catch (e) {
      debugPrint('release: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
    _starting = null;
  }
}
