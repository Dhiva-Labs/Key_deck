import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:keydeck_mobile/pad_controller.dart';
import 'package:keydeck_protocol/keydeck_protocol.dart';

/// Runs on a real Android device/emulator: spins up the actual desktop-side
/// [PadServer] on loopback and drives it with the app's real [PadController]
/// + WebSocket transport — the full WiFi session end to end.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full WiFi session on device: pair, layout, key press',
      (tester) async {
    final pressed = <int>[];
    final layout = PadLayoutDef(rows: 2, cols: 3, keys: [
      for (var i = 0; i < 6; i++)
        PadKeyDef(id: i, label: 'K$i', color: 0xFF3F51B5),
    ]);
    final server = PadServer(
      token: 'e2e-token',
      onKey: pressed.add,
      onClientsChanged: () {},
      layoutProvider: () => layout,
    );
    await server.start(port: 0);

    final controller = PadController();
    await controller.connect(
      SessionInfo(
        name: 'e2e host',
        ips: ['127.0.0.1'],
        port: server.port,
        token: 'e2e-token',
      ),
      viaBluetooth: false,
    );

    // Wait for the handshake + layout to land.
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while ((controller.phase != PadPhase.connected ||
            controller.layout == null) &&
        DateTime.now().isBefore(deadline)) {
      await tester.runAsync(() => Future.delayed(
          const Duration(milliseconds: 50)));
    }

    expect(controller.phase, PadPhase.connected,
        reason: 'status: ${controller.status}');
    expect(controller.layout!.size, 6);
    expect(controller.layout!.cols, 3);
    expect(controller.layout!.keys, hasLength(6));

    controller.pressKey(4);
    await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 300)));
    expect(pressed, [4]);

    await controller.disconnect();
    await server.stop();
  });
}
