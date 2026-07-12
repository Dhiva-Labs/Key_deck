import 'dart:async';
import 'dart:io';

import 'messages.dart';
import 'models.dart';

class PadClient {
  final WebSocket socket;
  final String device;
  PadClient(this.socket, this.device);
}

/// WiFi transport: a WebSocket server the phone connects to. The phone must
/// send a `hello` carrying the session token (from the QR code) within five
/// seconds or the socket is dropped.
class PadServer {
  final String token;
  final void Function(int keyId) onKey;
  final void Function() onClientsChanged;
  final PadLayoutDef Function() layoutProvider;

  HttpServer? _http;
  final List<PadClient> clients = [];

  PadServer({
    required this.token,
    required this.onKey,
    required this.onClientsChanged,
    required this.layoutProvider,
  });

  int get port => _http?.port ?? 0;
  bool get running => _http != null;

  Future<void> start({int port = 8737}) async {
    if (_http != null) return;
    try {
      _http = await HttpServer.bind(InternetAddress.anyIPv4, port);
    } on SocketException {
      // Port taken (another instance?) — let the OS pick one.
      _http = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _http!.listen(_handleRequest, onError: (_) {});
  }

  Future<void> _handleRequest(HttpRequest req) async {
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      req.response
        ..statusCode = HttpStatus.ok
        ..write('KeyDeck host');
      await req.response.close();
      return;
    }
    final ws = await WebSocketTransformer.upgrade(req);
    _handshake(ws);
  }

  void _handshake(WebSocket ws) {
    PadClient? client;
    var rejected = false;
    final timeout = Timer(const Duration(seconds: 5), () {
      if (client == null) ws.close();
    });

    ws.listen((data) {
      if (rejected) return;
      final msg = data is String ? decodeMsg(data) : null;
      if (msg == null) return;
      if (client == null) {
        if (msg['t'] != MsgType.hello || msg['token'] != token) {
          rejected = true;
          ws.add(encodeMsg(helloAckMsg(ok: false, error: 'Bad token')));
          ws.close();
          return;
        }
        timeout.cancel();
        client = PadClient(ws, msg['device'] as String? ?? 'Phone');
        clients.add(client!);
        ws.add(encodeMsg(
            helloAckMsg(ok: true, host: Platform.localHostname)));
        ws.add(encodeMsg(layoutMsg(layoutProvider())));
        onClientsChanged();
        return;
      }
      switch (msg['t']) {
        case MsgType.key:
          final id = msg['id'];
          if (id is int) onKey(id);
        case MsgType.ping:
          ws.add(encodeMsg(pongMsg()));
      }
    }, onDone: () {
      timeout.cancel();
      if (client != null) {
        clients.remove(client);
        onClientsChanged();
      }
    }, onError: (_) => ws.close());
  }

  void broadcastLayout() {
    final frame = encodeMsg(layoutMsg(layoutProvider()));
    for (final c in clients) {
      c.socket.add(frame);
    }
  }

  /// Non-loopback IPv4 addresses of this machine, for the QR payload.
  static Future<List<String>> localIps() async {
    final out = <String>[];
    for (final ni in await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false)) {
      for (final addr in ni.addresses) {
        out.add(addr.address);
      }
    }
    // Prefer private-LAN addresses over anything exotic (VPN tunnels etc.).
    out.sort((a, b) {
      int rank(String ip) =>
          ip.startsWith('192.168.') || ip.startsWith('10.') ? 0 : 1;
      return rank(a).compareTo(rank(b));
    });
    return out;
  }

  Future<void> stop() async {
    for (final c in clients) {
      await c.socket.close();
    }
    clients.clear();
    await _http?.close(force: true);
    _http = null;
  }
}
