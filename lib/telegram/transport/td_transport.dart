import 'td_transport_stub.dart'
    if (dart.library.ffi) 'td_transport_native.dart'
    if (dart.library.js_interop) 'td_transport_web.dart' as impl;

/// Raw TDLib JSON pipe. Native builds talk to libtdjson over FFI,
/// web builds talk to tdweb through `web/td_bridge.js`.
abstract class TdTransport {
  /// False when the TDLib binary is not bundled with this build.
  bool get isAvailable;

  /// Short reason shown to the user when [isAvailable] is false.
  String get unavailableReason;

  /// Creates the TDLib client. Every incoming JSON object is passed to [onMessage].
  Future<void> start(void Function(String json) onMessage);

  void send(String json);

  /// Synchronous TDLib call (only a few methods support it). Null on web.
  String? execute(String json);

  Future<void> dispose();
}

TdTransport createTdTransport() => impl.createTransport();
