import 'package:flutter/material.dart';
import 'package:keydeck_protocol/keydeck_protocol.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pad_controller.dart';
import 'pad_screen.dart';

const _kLastSessionPref = 'last_session_qr';

/// Scans the QR code shown by the desktop app, then lets the user pick the
/// medium (WiFi or Bluetooth) to start the session.
class ConnectScreen extends StatefulWidget {
  final PadController controller;
  const ConnectScreen({super.key, required this.controller});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  SessionInfo? _scanned;
  SessionInfo? _remembered;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _loadRemembered();
  }

  Future<void> _loadRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = SessionInfo.fromQrString(
        prefs.getString(_kLastSessionPref) ?? '');
    if (saved != null && mounted) setState(() => _remembered = saved);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final session = SessionInfo.fromQrString(barcode.rawValue ?? '');
      if (session != null) {
        _handled = true;
        SharedPreferences.getInstance().then(
            (p) => p.setString(_kLastSessionPref, barcode.rawValue!));
        setState(() {
          _scanned = session;
          _remembered = session;
        });
        return;
      }
    }
  }

  Future<void> _connect(bool viaBluetooth) async {
    final session = _scanned;
    if (session == null) return;
    final controller = widget.controller;
    await controller.connect(session, viaBluetooth: viaBluetooth);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PadScreen(controller: controller)),
    );
    // Back on this screen: reset for a fresh scan.
    await controller.disconnect();
    if (mounted) {
      setState(() {
        _scanned = null;
        _handled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KeyDeck')),
      body: _scanned == null ? _buildScanner() : _buildMediumPicker(),
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(onDetect: _onDetect),
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'Open the KeyDeck desktop app and scan the QR code it shows.',
            textAlign: TextAlign.center,
          ),
        ),
        if (_remembered != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.history),
              label: Text('Reconnect to "${_remembered!.name}"'),
              onPressed: () => setState(() {
                _handled = true;
                _scanned = _remembered;
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildMediumPicker() {
    final s = _scanned!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 64, color: Colors.greenAccent),
          const SizedBox(height: 12),
          Text('Found "${s.name}"',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 32),
          FilledButton.icon(
            icon: const Icon(Icons.wifi),
            label: const Text('Connect over WiFi'),
            onPressed: () => _connect(false),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.bluetooth),
            label: const Text('Connect over Bluetooth'),
            onPressed: () => _connect(true),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => setState(() {
              _scanned = null;
              _handled = false;
            }),
            child: const Text('Scan again'),
          ),
        ],
      ),
    );
  }
}
