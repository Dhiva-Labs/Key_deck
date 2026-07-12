import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:keydeck_mobile/pad_controller.dart';
import 'package:keydeck_mobile/transport.dart';
import 'package:keydeck_protocol/keydeck_protocol.dart';

class FakeTransport implements PadTransport {
  final incoming = StreamController<Map<String, dynamic>>.broadcast();
  final ready = StreamController<void>.broadcast();
  final closedCtrl = StreamController<void>.broadcast();
  final sent = <Map<String, dynamic>>[];
  bool closeCalled = false;

  @override
  Stream<Map<String, dynamic>> get messages => incoming.stream;
  @override
  Stream<void> get readyForHello => ready.stream;
  @override
  Stream<void> get closed => closedCtrl.stream;
  @override
  String get mediumName => 'Fake';

  @override
  Future<void> send(Map<String, dynamic> msg) async => sent.add(msg);

  @override
  Future<void> close() async => closeCalled = true;
}

/// Wires a controller directly to a fake transport, mirroring what
/// [PadController.connect] does after the transport is created.
void attach(PadController c, FakeTransport t, SessionInfo s) {
  c.session = s;
  c.attachForTest(t, s);
}

void main() {
  final session = SessionInfo(
      name: 'Test PC', ips: ['1.2.3.4'], port: 1, token: 'tok');

  test('handshake: hello on ready, connected on ack, layout applied',
      () async {
    final c = PadController();
    final t = FakeTransport();
    attach(c, t, session);

    t.ready.add(null);
    await pumpEventQueue();
    expect(t.sent.single['t'], MsgType.hello);
    expect(t.sent.single['token'], 'tok');

    t.incoming.add(helloAckMsg(ok: true, host: 'Test PC'));
    t.incoming.add(layoutMsg(PadLayoutDef(rows: 2, cols: 2, keys: [
      for (var i = 0; i < 4; i++)
        PadKeyDef(id: i, label: 'K$i', color: 1),
    ])));
    await pumpEventQueue();

    expect(c.phase, PadPhase.connected);
    expect(c.hostName, 'Test PC');
    expect(c.layout!.keys, hasLength(4));

    c.pressKey(2);
    await pumpEventQueue();
    expect(t.sent.last, {'t': MsgType.key, 'id': 2});

    await c.disconnect();
    expect(t.closeCalled, isTrue);
    expect(c.phase, PadPhase.idle);
  });

  test('rejection puts the controller in failed state', () async {
    final c = PadController();
    final t = FakeTransport();
    attach(c, t, session);

    t.ready.add(null);
    t.incoming.add(helloAckMsg(ok: false, error: 'Bad token'));
    await pumpEventQueue();

    expect(c.phase, PadPhase.failed);
    expect(c.status, 'Bad token');

    c.pressKey(0); // must be ignored while not connected
    await pumpEventQueue();
    expect(t.sent.where((m) => m['t'] == MsgType.key), isEmpty);
  });

  test('transport drop marks the session lost', () async {
    final c = PadController();
    final t = FakeTransport();
    attach(c, t, session);

    t.ready.add(null);
    t.incoming.add(helloAckMsg(ok: true));
    await pumpEventQueue();
    expect(c.phase, PadPhase.connected);

    t.closedCtrl.add(null);
    await pumpEventQueue();
    expect(c.phase, PadPhase.failed);
    expect(c.status, 'Connection lost');
  });
}
