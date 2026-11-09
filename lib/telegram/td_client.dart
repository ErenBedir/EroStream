import 'dart:async';
import 'dart:convert';

import 'transport/td_transport.dart';

typedef TdObject = Map<String, dynamic>;

class TdError implements Exception {
  TdError(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'TdError($code): $message';
}

/// Request/response matching over a [TdTransport] using `@extra`.
class TdClient {
  TdClient(this.transport);

  final TdTransport transport;
  final _pending = <String, Completer<TdObject>>{};
  final _updates = StreamController<TdObject>.broadcast();
  int _seq = 0;
  bool _started = false;

  Stream<TdObject> get updates => _updates.stream;

  bool get isAvailable => transport.isAvailable;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await transport.start(_onMessage);
  }

  Future<TdObject> send(TdObject query, {Duration timeout = const Duration(seconds: 60)}) {
    final id = 'q${++_seq}';
    final c = Completer<TdObject>();
    _pending[id] = c;
    transport.send(jsonEncode({...query, '@extra': id}));
    return c.future.timeout(timeout, onTimeout: () {
      _pending.remove(id);
      throw TdError(408, 'Request timed out: ${query['@type']}');
    });
  }

  void _onMessage(String raw) {
    final TdObject m;
    try {
      m = jsonDecode(raw) as TdObject;
    } catch (_) {
      return;
    }
    final extra = m['@extra'];
    if (extra is String) {
      final c = _pending.remove(extra);
      if (c != null) {
        if (m['@type'] == 'error') {
          c.completeError(TdError((m['code'] as num?)?.toInt() ?? 0, '${m['message']}'));
        } else {
          c.complete(m);
        }
        return;
      }
    }
    _updates.add(m);
  }

  Future<void> dispose() async {
    for (final c in _pending.values) {
      c.completeError(TdError(499, 'Client closed'));
    }
    _pending.clear();
    await transport.dispose();
    await _updates.close();
  }
}
