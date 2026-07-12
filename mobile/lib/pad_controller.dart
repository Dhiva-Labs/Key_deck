import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:keydeck_protocol/keydeck_protocol.dart';

import 'ble_transport.dart';
import 'transport.dart';
import 'ws_transport.dart';

enum PadPhase { idle, connecting, connected, failed }

/// Owns the transport and runs the session: hello handshake, layout updates,
/// key presses.
class PadController extends ChangeNotifier {
  SessionInfo? session;
  PadTransport? _transport;
  PadLayoutDef? layout;
  PadPhase phase = PadPhase.idle;
  String status = '';
  String hostName = '';

  final List<StreamSubscription> _subs = [];
  Timer? _keepalive;
  DateTime _lastRx = DateTime.now();

  String get mediumName => _transport?.mediumName ?? '';

  Future<void> connect(SessionInfo s, {required bool viaBluetooth}) async {
    await disconnect();
    session = s;
    phase = PadPhase.connecting;
    status = viaBluetooth
        ? 'Advertising to the desktop over Bluetooth…\n'
            '(enable Bluetooth on the desktop app)'
        : 'Connecting over WiFi…';
    notifyListeners();

    try {
      final t = viaBluetooth
          ? await BleTransport.start()
          : await WsTransport.connect(s);
      _attach(t, s);
    } catch (e) {
      phase = PadPhase.failed;
      status = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  void _attach(PadTransport t, SessionInfo s) {
    _transport = t;
    _subs.add(t.readyForHello.listen((_) {
      t.send(helloMsg(token: s.token, device: _deviceName()));
    }));
    _subs.add(t.messages.listen(_onMessage));
    _subs.add(t.closed.listen((_) {
      if (phase == PadPhase.connected || phase == PadPhase.connecting) {
        phase = PadPhase.failed;
        status = 'Connection lost';
        notifyListeners();
      }
    }));
  }

  /// Wire an already-created transport, bypassing the QR/medium plumbing.
  @visibleForTesting
  void attachForTest(PadTransport t, SessionInfo s) {
    phase = PadPhase.connecting;
    _attach(t, s);
  }

  static String _deviceName() {
    if (Platform.isAndroid) return 'Android phone';
    if (Platform.isIOS) return 'iPhone';
    return 'Phone';
  }

  void _onMessage(Map<String, dynamic> msg) {
    _lastRx = DateTime.now();
    switch (msg['t']) {
      case MsgType.helloAck:
        if (msg['ok'] == true) {
          phase = PadPhase.connected;
          hostName = msg['host'] as String? ?? 'Desktop';
          status = 'Connected';
          _startKeepalive();
        } else {
          phase = PadPhase.failed;
          status = msg['error'] as String? ?? 'Rejected by desktop';
        }
        notifyListeners();
      case MsgType.layout:
        layout = PadLayoutDef.fromJson(msg);
        notifyListeners();
    }
  }

  /// Pings the desktop so half-dead links (WiFi sleep, out of BLE range) are
  /// noticed instead of silently eating key presses.
  void _startKeepalive() {
    _keepalive?.cancel();
    _lastRx = DateTime.now();
    _keepalive = Timer.periodic(const Duration(seconds: 10), (_) {
      if (phase != PadPhase.connected) return;
      if (DateTime.now().difference(_lastRx) > const Duration(seconds: 25)) {
        phase = PadPhase.failed;
        status = 'Connection lost (no response from desktop)';
        _keepalive?.cancel();
        notifyListeners();
        return;
      }
      unawaited(_transport?.send(pingMsg()) ?? Future.value());
    });
  }

  void pressKey(int id) {
    final t = _transport;
    if (t == null || phase != PadPhase.connected) return;
    unawaited(t.send(keyMsg(id)));
  }

  Future<void> disconnect() async {
    _keepalive?.cancel();
    _keepalive = null;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _transport?.close();
    _transport = null;
    layout = null;
    phase = PadPhase.idle;
    status = '';
    notifyListeners();
  }
}
