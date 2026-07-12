import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'app_state.dart';
import 'key_editor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  state.init();
  runApp(KeyDeckApp(state: state));
}

class KeyDeckApp extends StatelessWidget {
  final AppState state;
  const KeyDeckApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KeyDeck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF3F51B5),
        useMaterial3: true,
      ),
      home: HomeScreen(state: state),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KeyDeck — desktop host')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (!state.ready) {
            return const Center(child: CircularProgressIndicator());
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 320, child: _ConnectionPanel(state: state)),
              const VerticalDivider(width: 1),
              Expanded(child: _EditorPanel(state: state)),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectionPanel extends StatelessWidget {
  final AppState state;
  const _ConnectionPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final session = state.session!;
    final wifiClients = state.server?.clients ?? const [];
    final injectorIssue = state.injector.unavailableReason;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Scan with the KeyDeck app',
                style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              tooltip: 'Refresh addresses (e.g. after enabling USB tethering)',
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: state.refreshSession,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: session.toQrString(),
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            session.ips.isEmpty
                ? 'No network — connect to WiFi'
                : session.ips.map((ip) => '$ip:${session.port}').join('  ·  '),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.wifi,
                        size: 18,
                        color: wifiClients.isNotEmpty
                            ? Colors.greenAccent
                            : null),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(wifiClients.isEmpty
                          ? 'WiFi / USB: waiting for phone'
                          : 'Connected: ${wifiClients.map((c) => c.device).join(', ')}'),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    Icon(Icons.bluetooth,
                        size: 18,
                        color: (state.ble?.connected ?? false)
                            ? Colors.lightBlueAccent
                            : null),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Bluetooth: ${state.bleStatus}')),
                    Switch(
                      value: state.bleWanted,
                      onChanged: (v) => state.toggleBle(v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (injectorIssue != null)
          Card(
            color: Colors.orange.shade900,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Key injection unavailable.\n$injectorIssue'),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Injection backend: ${state.injector.backendName}',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        const SizedBox(height: 8),
        Text('Activity', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final line in state.activityLog.take(12))
          Text(line,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontFamily: 'monospace')),
      ],
    );
  }
}

class _EditorPanel extends StatelessWidget {
  final AppState state;
  const _EditorPanel({required this.state});

  Future<void> _addLayoutDialog(BuildContext context) async {
    var rows = 3, cols = 4;
    final name = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New layout'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText: 'Name (optional)', hintText: 'e.g. Editing'),
              ),
              const SizedBox(height: 16),
              _Stepper(
                label: 'Rows',
                value: rows,
                min: 1,
                max: 6,
                onChanged: (v) => setState(() => rows = v),
              ),
              _Stepper(
                label: 'Columns',
                value: cols,
                min: 1,
                max: 8,
                onChanged: (v) => setState(() => cols = v),
              ),
              const SizedBox(height: 8),
              Text('${rows * cols} keys',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                state.addLayout(name.text, rows, cols);
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = state.config;
    final layout = config.activeLayout;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < config.layouts.length; i++)
                InputChip(
                  label: Text(
                      '${config.layouts[i].name} (${config.layouts[i].rows}×${config.layouts[i].cols})'),
                  selected: i == config.active,
                  onSelected: (_) => state.selectLayout(i),
                  onDeleted: config.layouts.length > 1
                      ? () => state.removeLayout(i)
                      : null,
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('New layout'),
                onPressed: () => _addLayoutDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Phone orientation:',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'auto', label: Text('Auto')),
                  ButtonSegment(value: 'portrait', label: Text('Portrait')),
                  ButtonSegment(value: 'landscape', label: Text('Landscape')),
                ],
                selected: {layout.orientation},
                onSelectionChanged: (s) => state.setOrientation(s.first),
              ),
              const Spacer(),
              Text('Click a key to program it',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: GridView.count(
                  crossAxisCount: layout.cols,
                  shrinkWrap: true,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    for (final key in layout.keys)
                      _KeyTile(state: state, id: key.def.id),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(width: 24, child: Text('$value', textAlign: TextAlign.center)),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _KeyTile extends StatelessWidget {
  final AppState state;
  final int id;
  const _KeyTile({required this.state, required this.id});

  @override
  Widget build(BuildContext context) {
    final key = state.config.activeLayout.keys[id];
    final icon = key.def.icon;
    return Material(
      color: Color(key.def.color),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showDialog(
          context: context,
          builder: (_) => KeyEditorDialog(
            deckKey: key,
            onSave: (def, action) =>
                state.updateKey(id, def: def, action: action),
          ),
        ),
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
              Text(
                key.def.label,
                textAlign: TextAlign.center,
                maxLines: icon != null ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: icon != null ? 13 : 16),
              ),
              const SizedBox(height: 4),
              Text(
                key.action.describe(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
