import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keydeck_protocol/keydeck_protocol.dart';

void main() {
  test('phone connects, authenticates, gets layout, sends key', () async {
    final pressed = <int>[];
    final layout = PadLayoutDef(rows: 2, cols: 2, keys: [
      for (var i = 0; i < 4; i++)
        PadKeyDef(id: i, label: 'K$i', color: 0xFF000000),
    ]);
    final server = PadServer(
      token: 'secret',
      onKey: pressed.add,
      onClientsChanged: () {},
      layoutProvider: () => layout,
    );
    await server.start(port: 0);

    final ws = await WebSocket.connect('ws://127.0.0.1:${server.port}');
    final inbox = StreamQueue(ws.map((d) => decodeMsg(d as String)!));

    ws.add(encodeMsg(helloMsg(token: 'secret', device: 'test phone')));
    final ack = await inbox.next;
    expect(ack['t'], MsgType.helloAck);
    expect(ack['ok'], true);

    final layoutMsgIn = await inbox.next;
    expect(layoutMsgIn['t'], MsgType.layout);
    expect(PadLayoutDef.fromJson(layoutMsgIn).keys.length, 4);

    ws.add(encodeMsg(keyMsg(2)));
    await Future.delayed(const Duration(milliseconds: 100));
    expect(pressed, [2]);
    expect(server.clients, hasLength(1));

    await ws.close();
    await Future.delayed(const Duration(milliseconds: 100));
    expect(server.clients, isEmpty);
    await server.stop();
  });

  test('wrong token is rejected', () async {
    final server = PadServer(
      token: 'secret',
      onKey: (_) => fail('must not receive keys'),
      onClientsChanged: () {},
      layoutProvider: () => const PadLayoutDef(rows: 2, cols: 2, keys: []),
    );
    await server.start(port: 0);

    final ws = await WebSocket.connect('ws://127.0.0.1:${server.port}');
    final messages = <Map<String, dynamic>>[];
    final done = Completer<void>();
    ws.listen((d) => messages.add(decodeMsg(d as String)!),
        onDone: done.complete);
    ws.add(encodeMsg(helloMsg(token: 'wrong', device: 'intruder')));
    ws.add(encodeMsg(keyMsg(0)));
    await done.future.timeout(const Duration(seconds: 5));

    expect(messages.single['ok'], false);
    expect(server.clients, isEmpty);
    await server.stop();
  });
}

/// Minimal async queue so the test can await messages in order.
class StreamQueue {
  final StreamController<Map<String, dynamic>> _ctrl = StreamController();
  late final StreamIterator<Map<String, dynamic>> _iter =
      StreamIterator(_ctrl.stream);

  StreamQueue(Stream<Map<String, dynamic>> source) {
    source.listen(_ctrl.add, onDone: _ctrl.close);
  }

  Future<Map<String, dynamic>> get next async {
    if (!await _iter.moveNext()) throw StateError('stream closed');
    return _iter.current;
  }
}
