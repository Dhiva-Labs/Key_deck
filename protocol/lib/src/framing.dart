import 'dart:convert';
import 'dart:typed_data';

/// BLE characteristics cap writes/notifications well below one JSON message,
/// so messages are sent as UTF-8 bytes behind a 4-byte big-endian length
/// prefix and split into MTU-sized chunks. [FrameAssembler] rebuilds them.
class FrameAssembler {
  final _buffer = BytesBuilder(copy: true);

  /// Feed raw bytes from the transport; returns any complete messages.
  List<String> add(List<int> chunk) {
    _buffer.add(chunk);
    final out = <String>[];
    var bytes = _buffer.toBytes();
    while (bytes.length >= 4) {
      final len = ByteData.sublistView(bytes, 0, 4).getUint32(0);
      if (bytes.length < 4 + len) break;
      out.add(utf8.decode(bytes.sublist(4, 4 + len), allowMalformed: true));
      bytes = bytes.sublist(4 + len);
    }
    _buffer.clear();
    _buffer.add(bytes);
    return out;
  }

  void reset() => _buffer.clear();
}

/// Encode one message and split it into chunks of at most [mtu] bytes.
List<Uint8List> frameMessage(String message, {int mtu = 180}) {
  final payload = utf8.encode(message);
  final framed = Uint8List(4 + payload.length);
  ByteData.sublistView(framed, 0, 4).setUint32(0, payload.length);
  framed.setRange(4, framed.length, payload);
  final chunks = <Uint8List>[];
  for (var i = 0; i < framed.length; i += mtu) {
    chunks.add(framed.sublist(i, i + mtu > framed.length ? framed.length : i + mtu));
  }
  return chunks;
}
