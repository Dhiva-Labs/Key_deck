import 'dart:convert';
import 'dart:io';

import 'package:keydeck_protocol/keydeck_protocol.dart';
import 'package:path_provider/path_provider.dart';

/// One pad key as the desktop sees it: the visual definition that gets pushed
/// to the phone plus the action executed locally on a tap.
class DeckKey {
  PadKeyDef def;
  KeyAction action;

  DeckKey({required this.def, this.action = const KeyAction()});

  Map<String, dynamic> toJson() =>
      {'def': def.toJson(), 'action': action.toJson()};

  factory DeckKey.fromJson(Map<String, dynamic> json) => DeckKey(
        def: PadKeyDef.fromJson((json['def'] as Map).cast()),
        action: KeyAction.fromJson((json['action'] as Map?)?.cast() ?? {}),
      );
}

const _defaultColors = [
  0xFF3F51B5, 0xFF00897B, 0xFFE65100, 0xFF6A1B9A, 0xFF2E7D32,
  0xFFC62828, 0xFF00838F, 0xFF9E9D24, 0xFF4527A0, 0xFF37474F,
];

/// One programmable grid: shape, orientation preference and its keys.
class DeckLayout {
  String name;
  int rows;
  int cols;
  String orientation;
  final List<DeckKey> keys;

  DeckLayout({
    required this.name,
    required this.rows,
    required this.cols,
    this.orientation = 'auto',
    List<DeckKey>? keys,
  }) : keys = keys ?? [] {
    _fitKeys();
  }

  int get size => rows * cols;

  /// Grow/shrink [keys] to match rows*cols, keeping existing programming.
  void _fitKeys() {
    while (keys.length < size) {
      final i = keys.length;
      keys.add(DeckKey(
        def: PadKeyDef(
          id: i,
          label: 'Key ${i + 1}',
          color: _defaultColors[i % _defaultColors.length],
        ),
      ));
    }
    if (keys.length > size) keys.removeRange(size, keys.length);
  }

  void resize(int newRows, int newCols) {
    rows = newRows;
    cols = newCols;
    _fitKeys();
  }

  PadLayoutDef toPadLayout() => PadLayoutDef(
        rows: rows,
        cols: cols,
        orientation: orientation,
        keys: keys.map((k) => k.def).toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'rows': rows,
        'cols': cols,
        'orientation': orientation,
        'keys': keys.map((k) => k.toJson()).toList(),
      };

  factory DeckLayout.fromJson(Map<String, dynamic> json) => DeckLayout(
        name: json['name'] as String? ?? 'Pad',
        rows: json['rows'] as int? ?? 2,
        cols: json['cols'] as int? ?? 3,
        orientation: json['orientation'] as String? ?? 'auto',
        keys: (json['keys'] as List? ?? const [])
            .map((k) => DeckKey.fromJson((k as Map).cast()))
            .toList(),
      );
}

List<DeckLayout> _defaultLayouts() => [
      DeckLayout(name: '4 keys', rows: 2, cols: 2),
      DeckLayout(name: '6 keys', rows: 2, cols: 3),
      DeckLayout(name: '8 keys', rows: 2, cols: 4),
      DeckLayout(name: '10 keys', rows: 2, cols: 5),
    ];

/// All programmed layouts. Every layout keeps its own keys, so switching
/// between them never loses work.
class DeckConfig {
  int active;
  final List<DeckLayout> layouts;

  DeckConfig({this.active = 1, List<DeckLayout>? layouts})
      : layouts = (layouts == null || layouts.isEmpty)
            ? _defaultLayouts()
            : layouts {
    if (active < 0 || active >= this.layouts.length) active = 0;
  }

  DeckLayout get activeLayout => layouts[active];

  Map<String, dynamic> toJson() => {
        'version': 2,
        'active': active,
        'layouts': layouts.map((l) => l.toJson()).toList(),
      };

  factory DeckConfig.fromJson(Map<String, dynamic> json) {
    final rawLayouts = json['layouts'];
    // v1 stored layouts as a size-keyed map ({"4": [keys]}); port the keys
    // into the matching preset.
    if (rawLayouts is Map) {
      final layouts = _defaultLayouts();
      for (final entry in rawLayouts.entries) {
        final size = int.tryParse(entry.key as String);
        final target = layouts.where((l) => l.size == size).firstOrNull;
        if (target == null) continue;
        final keys = (entry.value as List)
            .map((k) => DeckKey.fromJson((k as Map).cast()))
            .toList();
        for (var i = 0; i < keys.length && i < target.keys.length; i++) {
          target.keys[i] = keys[i];
        }
      }
      final oldSize = json['activeSize'] as int? ?? 6;
      return DeckConfig(
        active: layouts.indexWhere((l) => l.size == oldSize).clamp(0, 3),
        layouts: layouts,
      );
    }
    return DeckConfig(
      active: json['active'] as int? ?? 0,
      layouts: (rawLayouts as List? ?? const [])
          .map((l) => DeckLayout.fromJson((l as Map).cast()))
          .toList(),
    );
  }
}

/// Loads and saves the config as JSON in the app-support directory.
class ConfigStore {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/keydeck.json');
  }

  Future<DeckConfig> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        return DeckConfig.fromJson(
            jsonDecode(await f.readAsString()) as Map<String, dynamic>);
      }
    } catch (_) {}
    return DeckConfig();
  }

  Future<void> save(DeckConfig config) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(config.toJson()));
  }
}
