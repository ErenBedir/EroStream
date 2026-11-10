import 'dart:io';

import 'package:media_kit/media_kit.dart';

Future<void> tune(Player player, {required String subtitleLanguages}) async {
  final p = player.platform;
  if (p is! NativePlayer) return;
  Future<void> set(String k, String v) async {
    try {
      await p.setProperty(k, v);
    } catch (_) {}
  }

  await set('network-timeout', '60');
  await set('cache', 'yes');
  await set('demuxer-readahead-secs', '60');
  await set('demuxer-max-back-bytes', '${48 * 1024 * 1024}');
  await set('slang', subtitleLanguages);
  await set('sub-ass-override', 'scale');
  await set('audio-channels', 'stereo');
  await set('audio-normalize-downmix', 'yes');
  if (Platform.isAndroid) {
    await set('framedrop', 'decoder+vo');
    await set('vd-lavc-threads', '0');
  }
}
