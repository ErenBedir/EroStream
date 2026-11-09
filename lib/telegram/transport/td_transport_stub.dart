import 'td_transport.dart';

TdTransport createTransport() => _Unsupported();

class _Unsupported implements TdTransport {
  @override
  bool get isAvailable => false;

  @override
  String get unavailableReason => 'Telegram is not supported on this platform.';

  @override
  Future<void> start(void Function(String json) onMessage) async {}

  @override
  void send(String json) {}

  @override
  String? execute(String json) => null;

  @override
  Future<void> dispose() async {}
}
