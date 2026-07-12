import 'package:keydeck_protocol/keydeck_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('session round-trips through QR string', () {
    final s = SessionInfo(
      name: 'My PC',
      ips: ['192.168.1.10', '10.0.0.3'],
      port: 8737,
      token: SessionInfo.newToken(),
    );
    final back = SessionInfo.fromQrString(s.toQrString())!;
    expect(back.name, s.name);
    expect(back.ips, s.ips);
    expect(back.port, s.port);
    expect(back.token, s.token);
    expect(SessionInfo.fromQrString('https://example.com'), isNull);
  });

  test('messages encode and decode', () {
    final layout = PadLayoutDef(rows: 2, cols: 3, orientation: 'landscape',
        keys: [
      for (var i = 0; i < 6; i++)
        PadKeyDef(id: i, label: 'K$i', color: 0xFF112233 + i,
            icon: i == 0 ? 'aWNvbg==' : null),
    ]);
    final decoded = decodeMsg(encodeMsg(layoutMsg(layout)))!;
    expect(decoded['t'], MsgType.layout);
    final back = PadLayoutDef.fromJson(decoded);
    expect(back.rows, 2);
    expect(back.cols, 3);
    expect(back.orientation, 'landscape');
    expect(back.size, 6);
    expect(back.keys[3].label, 'K3');
    expect(back.keys[0].icon, 'aWNvbg==');
    expect(back.keys[1].icon, isNull);
    expect(decodeMsg('not json'), isNull);
  });

  test('key action describes itself', () {
    const a = KeyAction(
        type: KeyActionType.hotkey, modifiers: ['ctrl', 'shift'], key: 't');
    expect(a.describe(), 'Ctrl+Shift+T');
    expect(KeyAction.fromJson(a.toJson()).describe(), 'Ctrl+Shift+T');
  });

  test('framing reassembles across chunk boundaries', () {
    final msg = encodeMsg(layoutMsg(PadLayoutDef(rows: 2, cols: 5, keys: [
      for (var i = 0; i < 10; i++)
        PadKeyDef(id: i, label: 'Key number $i', color: 0xFFAABBCC),
    ])));
    final chunks = frameMessage(msg, mtu: 20);
    expect(chunks.length, greaterThan(3));
    final assembler = FrameAssembler();
    final results = <String>[];
    for (final c in chunks) {
      results.addAll(assembler.add(c));
    }
    expect(results, [msg]);

    // Two messages arriving glued together in one chunk.
    final a2 = FrameAssembler();
    final both = frameMessage('"one"', mtu: 4096).first +
        frameMessage('"two"', mtu: 4096).first;
    expect(a2.add(both), ['"one"', '"two"']);
  });
}
