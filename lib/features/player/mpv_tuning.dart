import 'package:media_kit/media_kit.dart';

import 'mpv_tuning_stub.dart' if (dart.library.io) 'mpv_tuning_io.dart' as impl;

/// mpv options for network playback. No-op on web.
Future<void> tunePlayer(Player player, {required String subtitleLanguages}) =>
    impl.tune(player, subtitleLanguages: subtitleLanguages);
