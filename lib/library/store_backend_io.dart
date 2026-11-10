import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'store_backend.dart';

StoreBackend create() => _FileBackend();

class _FileBackend implements StoreBackend {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/library_items.json');
  }

  @override
  Future<String?> read() async {
    final f = await _file();
    return await f.exists() ? f.readAsString() : null;
  }

  /// Write to a temp file and rename, so a crash never leaves half a file.
  @override
  Future<void> write(String data) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(f.path);
  }
}
