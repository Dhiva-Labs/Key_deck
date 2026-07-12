import 'dart:convert';

import 'models.dart';

/// Wire messages are JSON objects with a `t` discriminator. The same frames
/// travel over WebSocket (one text frame per message) and BLE (length-prefixed
/// chunks, see framing.dart).
abstract final class MsgType {
  static const hello = 'hello';
  static const helloAck = 'helloAck';
  static const layout = 'layout';
  static const key = 'key';
  static const ping = 'ping';
  static const pong = 'pong';
}

String encodeMsg(Map<String, dynamic> msg) => jsonEncode(msg);

Map<String, dynamic>? decodeMsg(String raw) {
  try {
    final v = jsonDecode(raw);
    if (v is Map<String, dynamic> && v['t'] is String) return v;
  } catch (_) {}
  return null;
}

/// Phone -> desktop, first message on any transport.
Map<String, dynamic> helloMsg({required String token, required String device}) =>
    {'t': MsgType.hello, 'token': token, 'device': device, 'v': 1};

/// Desktop -> phone, accepts or rejects the session.
Map<String, dynamic> helloAckMsg({
  required bool ok,
  String host = '',
  String error = '',
}) =>
    {
      't': MsgType.helloAck,
      'ok': ok,
      if (host.isNotEmpty) 'host': host,
      if (error.isNotEmpty) 'error': error,
    };

/// Desktop -> phone, pushed on connect and whenever keys are reprogrammed.
Map<String, dynamic> layoutMsg(PadLayoutDef layout) =>
    {'t': MsgType.layout, ...layout.toJson()};

/// Phone -> desktop, a pad key was tapped.
Map<String, dynamic> keyMsg(int id) => {'t': MsgType.key, 'id': id};

Map<String, dynamic> pingMsg() => {'t': MsgType.ping};
Map<String, dynamic> pongMsg() => {'t': MsgType.pong};
