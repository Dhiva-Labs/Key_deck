import 'dart:convert';
import 'dart:math';

const _qrPrefix = 'KEYDECK1:';

/// Fixed BLE identifiers shared by both apps. The phone advertises this
/// service as a GATT peripheral; the desktop scans for it as a central.
abstract final class BleIds {
  static const service = '8e0efa2f-7d5b-4a1e-9d40-5c8f21f7a001';

  /// Desktop -> phone (desktop writes, phone receives).
  static const rx = '8e0efa2f-7d5b-4a1e-9d40-5c8f21f7a002';

  /// Phone -> desktop (phone notifies, desktop subscribes).
  static const tx = '8e0efa2f-7d5b-4a1e-9d40-5c8f21f7a003';
}

/// Everything the phone needs to reach the desktop, carried by the QR code.
class SessionInfo {
  final String name;
  final List<String> ips;
  final int port;
  final String token;

  const SessionInfo({
    required this.name,
    required this.ips,
    required this.port,
    required this.token,
  });

  static String newToken() {
    final rnd = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(24, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  String toQrString() => _qrPrefix +
      base64Url.encode(utf8.encode(jsonEncode({
        'v': 1,
        'name': name,
        'ips': ips,
        'port': port,
        'token': token,
      })));

  static SessionInfo? fromQrString(String raw) {
    if (!raw.startsWith(_qrPrefix)) return null;
    try {
      final json = jsonDecode(
              utf8.decode(base64Url.decode(raw.substring(_qrPrefix.length))))
          as Map<String, dynamic>;
      return SessionInfo(
        name: json['name'] as String? ?? 'Desktop',
        ips: (json['ips'] as List? ?? const []).cast<String>(),
        port: json['port'] as int? ?? 0,
        token: json['token'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
