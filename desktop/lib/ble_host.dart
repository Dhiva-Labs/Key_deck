import 'dart:async';
import 'dart:typed_data';

import 'package:keydeck_protocol/keydeck_protocol.dart';
import 'package:universal_ble/universal_ble.dart';

/// Bluetooth transport. Roles are flipped compared to WiFi: the phone
/// advertises a GATT service (peripheral) and this desktop scans and connects
/// (central). The phone still authenticates by sending `hello` with the
/// session token over the TX characteristic.
class BleHost {
  final String token;
  final void Function(int keyId) onKey;
  final void Function(String status) onStatus;
  final PadLayoutDef Function() layoutProvider;

  BleHost({
    required this.token,
    required this.onKey,
    required this.onStatus,
    required this.layoutProvider,
  });

  bool _enabled = false;
  String? _connectedId;
  bool _authed = false;
  final _assembler = FrameAssembler();
  StreamSubscription<BleDevice>? _scanSub;
  StreamSubscription<Uint8List>? _valueSub;
  StreamSubscription<bool>? _connSub;

  bool get enabled => _enabled;
  bool get connected => _connectedId != null && _authed;

  Future<void> enable() async {
    if (_enabled) return;
    _enabled = true;
    try {
      final state = await UniversalBle.getBluetoothAvailabilityState();
      if (state != AvailabilityState.poweredOn) {
        onStatus('Bluetooth is off ($state)');
        _enabled = false;
        return;
      }
      await _startScan();
    } catch (e) {
      _enabled = false;
      onStatus('Bluetooth error: $e');
    }
  }

  Future<void> _startScan() async {
    onStatus('Scanning for phone…');
    _scanSub?.cancel();
    _scanSub = UniversalBle.scanStream.listen(_onDevice);
    await UniversalBle.startScan(
      scanFilter: ScanFilter(withServices: [BleIds.service]),
    );
  }

  Future<void> _onDevice(BleDevice device) async {
    if (_connectedId != null) return;
    _connectedId = device.deviceId;
    try {
      await UniversalBle.stopScan();
      onStatus('Connecting to ${device.name ?? device.deviceId}…');
      await UniversalBle.connect(device.deviceId,
          timeout: const Duration(seconds: 20));
      await UniversalBle.discoverServices(device.deviceId);
      try {
        await UniversalBle.requestMtu(device.deviceId, 247);
      } catch (_) {}

      _assembler.reset();
      _valueSub = UniversalBle.characteristicValueStream(
              device.deviceId, BleIds.tx)
          .listen((value) => _onChunk(device.deviceId, value));
      _connSub = UniversalBle.connectionStream(device.deviceId)
          .listen((isConnected) {
        if (!isConnected) _onDisconnected();
      });
      await UniversalBle.subscribeNotifications(
          device.deviceId, BleIds.service, BleIds.tx);
      onStatus('Waiting for phone handshake…');
    } catch (e) {
      onStatus('Connect failed: $e');
      _onDisconnected();
    }
  }

  void _onChunk(String deviceId, Uint8List value) {
    for (final raw in _assembler.add(value)) {
      final msg = decodeMsg(raw);
      if (msg == null) continue;
      _onMessage(deviceId, msg);
    }
  }

  Future<void> _onMessage(String deviceId, Map<String, dynamic> msg) async {
    if (!_authed) {
      if (msg['t'] != MsgType.hello || msg['token'] != token) {
        await _send(deviceId, helloAckMsg(ok: false, error: 'Bad token'));
        await UniversalBle.disconnect(deviceId);
        return;
      }
      _authed = true;
      await _send(deviceId, helloAckMsg(ok: true));
      await _send(deviceId, layoutMsg(layoutProvider()));
      onStatus('Connected over Bluetooth');
      return;
    }
    switch (msg['t']) {
      case MsgType.key:
        final id = msg['id'];
        if (id is int) onKey(id);
      case MsgType.ping:
        await _send(deviceId, pongMsg());
    }
  }

  Future<void> _send(String deviceId, Map<String, dynamic> msg) async {
    for (final chunk in frameMessage(encodeMsg(msg))) {
      await UniversalBle.write(
          deviceId, BleIds.service, BleIds.rx, chunk);
    }
  }

  Future<void> broadcastLayout() async {
    final id = _connectedId;
    if (id == null || !_authed) return;
    try {
      await _send(id, layoutMsg(layoutProvider()));
    } catch (_) {}
  }

  void _onDisconnected() {
    _valueSub?.cancel();
    _connSub?.cancel();
    _connectedId = null;
    _authed = false;
    if (_enabled) {
      onStatus('Phone disconnected, rescanning…');
      _startScan();
    }
  }

  Future<void> disable() async {
    _enabled = false;
    _scanSub?.cancel();
    _valueSub?.cancel();
    _connSub?.cancel();
    try {
      await UniversalBle.stopScan();
      final id = _connectedId;
      if (id != null) await UniversalBle.disconnect(id);
    } catch (_) {}
    _connectedId = null;
    _authed = false;
    onStatus('Bluetooth off');
  }
}
