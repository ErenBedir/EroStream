import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'td_transport.dart';

TdTransport createTransport() => NativeTdTransport();

typedef _CreateIdC = Int32 Function();
typedef _CreateIdD = int Function();
typedef _SendC = Void Function(Int32, Pointer<Utf8>);
typedef _SendD = void Function(int, Pointer<Utf8>);
typedef _ReceiveC = Pointer<Utf8> Function(Double);
typedef _ReceiveD = Pointer<Utf8> Function(double);
typedef _ExecuteC = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _ExecuteD = Pointer<Utf8> Function(Pointer<Utf8>);

/// `EROSTREAM_TDJSON` overrides the library path (desktop development).
DynamicLibrary _open() {
  final override = Platform.environment['EROSTREAM_TDJSON'];
  if (override != null && override.isNotEmpty) return DynamicLibrary.open(override);
  if (Platform.isIOS) return DynamicLibrary.process();
  if (Platform.isMacOS) return DynamicLibrary.open('libtdjson.dylib');
  if (Platform.isWindows) return DynamicLibrary.open('tdjson.dll');
  return DynamicLibrary.open('libtdjson.so');
}

class _Lib {
  _Lib(DynamicLibrary l)
      : createClientId = l.lookupFunction<_CreateIdC, _CreateIdD>('td_create_client_id'),
        send = l.lookupFunction<_SendC, _SendD>('td_send'),
        receive = l.lookupFunction<_ReceiveC, _ReceiveD>('td_receive'),
        execute = l.lookupFunction<_ExecuteC, _ExecuteD>('td_execute');

  final _CreateIdD createClientId;
  final _SendD send;
  final _ReceiveD receive;
  final _ExecuteD execute;
}

/// td_receive blocks, so it runs on its own isolate and forwards raw JSON.
void _receiveLoop(SendPort out) {
  final lib = _Lib(_open());
  while (true) {
    final p = lib.receive(1.0);
    if (p != nullptr) out.send(p.toDartString());
  }
}

class NativeTdTransport implements TdTransport {
  _Lib? _lib;
  String _error = '';
  int _clientId = 0;
  Isolate? _isolate;
  ReceivePort? _port;

  _Lib? get _loaded {
    if (_lib != null || _error.isNotEmpty) return _lib;
    try {
      _lib = _Lib(_open());
    } catch (e) {
      _error = 'TDLib library not found ($e).';
    }
    return _lib;
  }

  @override
  bool get isAvailable => _loaded != null;

  @override
  String get unavailableReason => _error;

  @override
  Future<void> start(void Function(String json) onMessage) async {
    final lib = _loaded;
    if (lib == null) return;
    execute(jsonEncode({'@type': 'setLogVerbosityLevel', 'new_verbosity_level': 1}));
    _clientId = lib.createClientId();
    final port = ReceivePort();
    _port = port;
    final id = _clientId;
    port.listen((msg) {
      if (msg is! String) return;
      // All clients share td_receive; keep only ours.
      final tag = '"@client_id":$id';
      if (msg.contains('"@client_id"') && !msg.contains(tag)) return;
      onMessage(msg);
    });
    _isolate = await Isolate.spawn(_receiveLoop, port.sendPort, debugName: 'td_receive');
    // A client starts only after its first request.
    send(jsonEncode({'@type': 'getOption', 'name': 'version'}));
  }

  @override
  void send(String json) {
    final lib = _lib;
    if (lib == null) return;
    final p = json.toNativeUtf8();
    try {
      lib.send(_clientId, p);
    } finally {
      malloc.free(p);
    }
  }

  @override
  String? execute(String json) {
    final lib = _loaded;
    if (lib == null) return null;
    final p = json.toNativeUtf8();
    try {
      final r = lib.execute(p);
      return r == nullptr ? null : r.toDartString();
    } finally {
      malloc.free(p);
    }
  }

  @override
  Future<void> dispose() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port?.close();
    _port = null;
  }
}
