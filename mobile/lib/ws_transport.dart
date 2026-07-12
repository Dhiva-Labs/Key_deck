import 'dart:async';
import 'dart:io';

import 'package:keydeck_protocol/keydeck_protocol.dart';

import 'transport.dart';

/// WiFi transport: dials the desktop's WebSocket server, trying each
/// advertised IP until one answers.
class WsTransport implements PadTransport {
  final WebSocket _socket;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _ready = StreamController<void>.broadcast();
  final _closed = StreamController<void>.broadcast();

  WsTransport._(this._socket) {
    _socket.listen(
      (data) {
        if (data is! String) return;
        final msg = decodeMsg(data);
        if (msg != null) _messages.add(msg);
      },
      onDone: () => _closed.add(null),
      onError: (_) => _closed.add(null),
    );
    // The socket is already open; signal hello-readiness on next microtask so
    // listeners attached right after construction still get it.
    scheduleMicrotask(() => _ready.add(null));
  }

  static Future<WsTransport> connect(SessionInfo session) async {
    Object? lastError;
    for (final ip in session.ips) {
      try {
        final ws = await WebSocket.connect('ws://$ip:${session.port}')
            .timeout(const Duration(seconds: 4));
        return WsTransport._(ws);
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception(
        'Could not reach the desktop on ${session.ips.join(", ")} '
        '(port ${session.port}). Are both devices on the same network? '
        '($lastError)');
  }

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  Stream<void> get readyForHello => _ready.stream;

  @override
  Stream<void> get closed => _closed.stream;

  @override
  String get mediumName => 'WiFi';

  @override
  Future<void> send(Map<String, dynamic> msg) async {
    _socket.add(encodeMsg(msg));
  }

  @override
  Future<void> close() async {
    await _socket.close();
  }
}
