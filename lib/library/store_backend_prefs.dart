import 'package:shared_preferences/shared_preferences.dart';

import 'store_backend.dart';

StoreBackend create() => _PrefsBackend();

/// Web: localStorage (about 5 MB). Enough for a few thousand items.
class _PrefsBackend implements StoreBackend {
  static const _key = 'library_items_v1';

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String data) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, data);
    } catch (_) {
      // quota exceeded: keep working from memory
    }
  }
}
