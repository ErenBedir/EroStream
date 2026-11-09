import 'dart:js_interop';

import 'td_transport.dart';

TdTransport createTransport() => WebTdTransport();

/// Defined in `web/td_bridge.js`.
@JS('erostreamTd')
external _Bridge? get _bridge;

extension type _Bridge._(JSObject _) implements JSObject {
  external bool available();
  external void create(JSString options, JSFunction onMessage);
  external void send(JSString json);
  external void close();
}

class WebTdTransport implements TdTransport {
  @override
  bool get isAvailable => _bridge?.available() ?? false;

  @override
  String get unavailableReason => 'tdweb is not bundled with this build.';

  @override
  Future<void> start(void Function(String json) onMessage) async {
    final b = _bridge;
    if (b == null || !b.available()) return;
    void handler(JSString s) => onMessage(s.toDart);
    b.create('{"instanceName":"erostream","jsLogVerbosityLevel":"error","logVerbosityLevel":1}'.toJS, handler.toJS);
  }

  @override
  void send(String json) => _bridge?.send(json.toJS);

  @override
  String? execute(String json) => null;

  @override
  Future<void> dispose() async => _bridge?.close();
}
