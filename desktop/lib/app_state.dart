import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:keydeck_protocol/keydeck_protocol.dart';

import 'ble_host.dart';
import 'deck_config.dart';
import 'injector.dart';

class AppState extends ChangeNotifier {
  final _store = ConfigStore();
  final KeyInjector injector = KeyInjector.forThisPlatform();

  DeckConfig config = DeckConfig();
  PadServer? server;
  BleHost? ble;
  SessionInfo? session;
  String bleStatus = 'Off';
  bool bleWanted = false;
  final List<String> activityLog = [];
  bool ready = false;

  Future<void> init() async {
    config = await _store.load();
    final token = SessionInfo.newToken();

    server = PadServer(
      token: token,
      onKey: _handleKey,
      onClientsChanged: notifyListeners,
      layoutProvider: () => config.activeLayout.toPadLayout(),
    );
    await server!.start();

    await refreshSession();

    ble = BleHost(
      token: token,
      onKey: _handleKey,
      onStatus: (s) {
        bleStatus = s;
        notifyListeners();
      },
      layoutProvider: () => config.activeLayout.toPadLayout(),
    );

    ready = true;
    notifyListeners();
  }

  /// Re-reads the machine's IP addresses (same token) so the QR picks up
  /// newly appeared interfaces — e.g. after enabling USB tethering.
  Future<void> refreshSession() async {
    final token = server?.token ?? SessionInfo.newToken();
    session = SessionInfo(
      name: 'KeyDeck host',
      ips: await PadServer.localIps(),
      port: server?.port ?? 0,
      token: token,
    );
    notifyListeners();
  }

  void _handleKey(int id) {
    final keys = config.activeLayout.keys;
    final key = id >= 0 && id < keys.length ? keys[id] : null;
    if (key == null) return;
    _log('${key.def.label} → ${key.action.describe()}');
    unawaited(injector.run(key.action));
  }

  void _log(String line) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    activityLog.insert(0, '$ts  $line');
    if (activityLog.length > 60) activityLog.removeLast();
    notifyListeners();
  }

  Future<void> selectLayout(int index) async {
    config.active = index;
    await _persistAndPush();
  }

  Future<void> addLayout(String name, int rows, int cols) async {
    config.layouts.add(DeckLayout(
        name: name.trim().isEmpty ? '${rows * cols} keys' : name.trim(),
        rows: rows,
        cols: cols));
    config.active = config.layouts.length - 1;
    await _persistAndPush();
  }

  Future<void> removeLayout(int index) async {
    if (config.layouts.length <= 1) return;
    config.layouts.removeAt(index);
    if (config.active >= config.layouts.length) {
      config.active = config.layouts.length - 1;
    }
    await _persistAndPush();
  }

  Future<void> resizeActiveLayout(int rows, int cols) async {
    config.activeLayout.resize(rows, cols);
    await _persistAndPush();
  }

  Future<void> setOrientation(String orientation) async {
    config.activeLayout.orientation = orientation;
    await _persistAndPush();
  }

  Future<void> updateKey(int id, {PadKeyDef? def, KeyAction? action}) async {
    final key = config.activeLayout.keys[id];
    if (def != null) key.def = def;
    if (action != null) key.action = action;
    await _persistAndPush();
  }

  Future<void> _persistAndPush() async {
    notifyListeners();
    await _store.save(config);
    server?.broadcastLayout();
    unawaited(ble?.broadcastLayout() ?? Future.value());
  }

  Future<void> toggleBle(bool on) async {
    bleWanted = on;
    notifyListeners();
    if (on) {
      await ble?.enable();
    } else {
      await ble?.disable();
    }
    notifyListeners();
  }
}
