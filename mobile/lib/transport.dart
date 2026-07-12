/// A connection to the desktop host, independent of the medium.
abstract class PadTransport {
  /// Decoded protocol messages arriving from the desktop.
  Stream<Map<String, dynamic>> get messages;

  /// Fires when the link is ready for the `hello` handshake. For WiFi that is
  /// immediately after the socket opens; for Bluetooth it is when the desktop
  /// subscribes to the TX characteristic.
  Stream<void> get readyForHello;

  /// Fires once when the underlying link drops.
  Stream<void> get closed;

  String get mediumName;

  Future<void> send(Map<String, dynamic> msg);

  Future<void> close();
}
