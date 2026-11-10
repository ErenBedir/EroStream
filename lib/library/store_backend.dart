import 'store_backend_prefs.dart' if (dart.library.io) 'store_backend_io.dart' as impl;

/// Where the item store is persisted: a JSON file on native, preferences on web.
abstract class StoreBackend {
  Future<String?> read();
  Future<void> write(String data);
}

StoreBackend createStoreBackend() => impl.create();
