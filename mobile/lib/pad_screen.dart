import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keydeck_protocol/keydeck_protocol.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'pad_controller.dart';

/// The macro pad itself: a fullscreen grid of big keys.
class PadScreen extends StatefulWidget {
  final PadController controller;
  const PadScreen({super.key, required this.controller});

  @override
  State<PadScreen> createState() => _PadScreenState();
}

class _PadScreenState extends State<PadScreen> {
  String _appliedOrientation = '';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    widget.controller.addListener(_applyOrientation);
    _applyOrientation();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_applyOrientation);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WakelockPlus.disable();
    super.dispose();
  }

  /// Honors the layout's orientation preference: `portrait`/`landscape`
  /// lock the screen, `auto` follows the phone.
  void _applyOrientation() {
    final o = widget.controller.layout?.orientation ?? 'auto';
    if (o == _appliedOrientation) return;
    _appliedOrientation = o;
    SystemChrome.setPreferredOrientations(switch (o) {
      'portrait' => [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown
        ],
      'landscape' => [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ],
      _ => DeviceOrientation.values,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final c = widget.controller;
            return switch (c.phase) {
              PadPhase.connecting => _Message(
                  icon: const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator()),
                  text: c.status,
                ),
              PadPhase.failed => _Message(
                  icon: const Icon(Icons.error_outline,
                      size: 48, color: Colors.redAccent),
                  text: c.status,
                  action: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back'),
                  ),
                ),
              PadPhase.idle => _Message(
                  icon: const Icon(Icons.link_off, size: 48),
                  text: 'Not connected',
                  action: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back'),
                  ),
                ),
              PadPhase.connected => c.layout == null
                  ? const Center(child: CircularProgressIndicator())
                  : _buildPad(context, c),
            };
          },
        ),
      ),
    );
  }

  Widget _buildPad(BuildContext context, PadController c) {
    final layout = c.layout!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(
                c.mediumName == 'Bluetooth' ? Icons.bluetooth : Icons.wifi,
                size: 16,
                color: Colors.greenAccent,
              ),
              const SizedBox(width: 6),
              Text('${c.hostName} · ${layout.rows}×${layout.cols}',
                  style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final landscape = constraints.maxWidth > constraints.maxHeight;
                // Match the desktop's arrangement in landscape; transpose in
                // portrait so keys stay big.
                final cols = landscape ? layout.cols : layout.rows;
                final rows = (layout.size / cols).ceil();
                final tileW =
                    (constraints.maxWidth - (cols - 1) * 10) / cols;
                final tileH =
                    (constraints.maxHeight - (rows - 1) * 10) / rows;
                return GridView.count(
                  crossAxisCount: cols,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: tileW / tileH,
                  children: [
                    for (final key in layout.keys)
                      _PadKey(
                        def: key,
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          c.pressKey(key.id);
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PadKey extends StatelessWidget {
  final PadKeyDef def;
  final VoidCallback onPressed;
  const _PadKey({required this.def, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final icon = def.icon;
    return Material(
      color: Color(def.color),
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null)
                Expanded(
                  child: Image.memory(base64Decode(icon),
                      fit: BoxFit.contain, gaplessPlayback: true),
                ),
              if (icon == null || def.label.isNotEmpty)
                Text(
                  def.label,
                  textAlign: TextAlign.center,
                  maxLines: icon != null ? 1 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: icon != null ? 14 : 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final Widget icon;
  final String text;
  final Widget? action;
  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 20),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
