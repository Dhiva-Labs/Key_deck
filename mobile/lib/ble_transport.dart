import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:keydeck_protocol/keydeck_protocol.dart';
import 'package:permission_handler/permission_handler.dart';

import 'transport.dart';

/// Bluetooth transport. The phone acts as a BLE *peripheral*: it advertises
/// the KeyDeck GATT service and the desktop (central) scans, connects and
/// subscribes. Incoming messages arrive as writes on the RX characteristic;
/// outgoing messages are notified on the TX characteristic.
class BleTransport implements PadTransport {
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _ready = StreamController<void>.broadcast();
  final _closed = StreamController<void>.broadcast();
  final _assembler = FrameAssembler();
  String? _centralId;
  int _mtu = 180;
  bool _open = true;

  BleTransport._();

  static Future<BleTransport> start() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ].request();
      if (statuses.values.any((s) => !s.isGranted)) {
        throw Exception('Bluetooth permission denied');
      }
    }

    final t = BleTransport._();
    await BlePeripheral.initialize();
    if (!await BlePeripheral.isSupported()) {
      throw Exception('BLE peripheral mode is not supported on this phone');
    }

    BlePeripheral.setWriteRequestCallback(
        (deviceId, characteristicId, offset, value) {
      if (characteristicId.toLowerCase() == BleIds.rx && value != null) {
        for (final raw in t._assembler.add(value)) {
          final msg = decodeMsg(raw);
          if (msg != null) t._messages.add(msg);
        }
      }
      return null;
    });

    BlePeripheral.setCharacteristicSubscriptionChangeCallback(
        (deviceId, characteristicId, isSubscribed, name) {
      if (characteristicId.toLowerCase() != BleIds.tx) return;
      if (isSubscribed) {
        t._centralId = deviceId;
        t._assembler.reset();
        t._ready.add(null);
      } else if (deviceId == t._centralId) {
        t._centralId = null;
        t._closed.add(null);
      }
    });

    BlePeripheral.setConnectionStateChangeCallback((deviceId, connected) {
      if (!connected && deviceId == t._centralId) {
        t._centralId = null;
        t._closed.add(null);
      }
    });

    BlePeripheral.setMtuChangeCallback((deviceId, mtu) {
      // Leave headroom for the 3-byte ATT notification header.
      t._mtu = (mtu - 3).clamp(20, 512);
    });

    final serviceAdded = Completer<void>();
    BlePeripheral.setServiceAddedCallback((serviceId, error) {
      if (serviceAdded.isCompleted) return;
      error == null
          ? serviceAdded.complete()
          : serviceAdded.completeError(Exception('addService: $error'));
    });

    await BlePeripheral.addService(
      BleService(
        uuid: BleIds.service,
        primary: true,
        characteristics: [
          BleCharacteristic(
            uuid: BleIds.rx,
            properties: [
              CharacteristicProperties.write.index,
              CharacteristicProperties.writeWithoutResponse.index,
            ],
            permissions: [AttributePermissions.writeable.index],
          ),
          BleCharacteristic(
            uuid: BleIds.tx,
            properties: [CharacteristicProperties.notify.index],
            permissions: [AttributePermissions.readable.index],
          ),
        ],
      ),
    );
    try {
      await serviceAdded.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // Some platforms don't fire the callback; proceed and let advertising
      // surface real failures.
    }

    await BlePeripheral.startAdvertising(
      services: [BleIds.service],
      localName: 'KeyDeck',
    );
    return t;
  }

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  Stream<void> get readyForHello => _ready.stream;

  @override
  Stream<void> get closed => _closed.stream;

  @override
  String get mediumName => 'Bluetooth';

  @override
  Future<void> send(Map<String, dynamic> msg) async {
    for (final chunk in frameMessage(encodeMsg(msg), mtu: _mtu)) {
      await BlePeripheral.updateCharacteristic(
        characteristicId: BleIds.tx,
        value: Uint8List.fromList(chunk),
        deviceId: _centralId,
      );
    }
  }

  @override
  Future<void> close() async {
    if (!_open) return;
    _open = false;
    try {
      await BlePeripheral.stopAdvertising();
      await BlePeripheral.clearServices();
    } catch (_) {}
  }
}
