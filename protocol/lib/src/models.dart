/// How the phone should hold the pad for this layout.
/// `auto` follows the phone's rotation; the other two lock it.
const kOrientations = ['auto', 'portrait', 'landscape'];

/// What the desktop does when a key is pressed.
enum KeyActionType { hotkey, text, command, none }

/// A programmable action bound to one pad key. Lives on the desktop only;
/// it is never sent to the phone.
class KeyAction {
  final KeyActionType type;

  /// Modifiers for [KeyActionType.hotkey]: any of `ctrl`, `shift`, `alt`, `super`.
  final List<String> modifiers;

  /// Main key for a hotkey, lower case (e.g. `c`, `f5`, `enter`, `tab`).
  final String key;

  /// Payload for [KeyActionType.text] (typed literally) or
  /// [KeyActionType.command] (run in a shell).
  final String text;

  const KeyAction({
    this.type = KeyActionType.none,
    this.modifiers = const [],
    this.key = '',
    this.text = '',
  });

  bool get isEmpty => type == KeyActionType.none;

  /// Human-readable summary, e.g. `Ctrl+Shift+T` or `Type "hello"`.
  String describe() => switch (type) {
        KeyActionType.none => 'Not set',
        KeyActionType.hotkey =>
          [...modifiers.map(_capitalize), key.toUpperCase()].join('+'),
        KeyActionType.text =>
          'Type "${text.length > 24 ? '${text.substring(0, 24)}…' : text}"',
        KeyActionType.command =>
          'Run ${text.length > 24 ? '${text.substring(0, 24)}…' : text}',
      };

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (modifiers.isNotEmpty) 'mods': modifiers,
        if (key.isNotEmpty) 'key': key,
        if (text.isNotEmpty) 'text': text,
      };

  factory KeyAction.fromJson(Map<String, dynamic> json) => KeyAction(
        type: KeyActionType.values.asNameMap()[json['type']] ??
            KeyActionType.none,
        modifiers: (json['mods'] as List?)?.cast<String>() ?? const [],
        key: json['key'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );

  KeyAction copyWith({
    KeyActionType? type,
    List<String>? modifiers,
    String? key,
    String? text,
  }) =>
      KeyAction(
        type: type ?? this.type,
        modifiers: modifiers ?? this.modifiers,
        key: key ?? this.key,
        text: text ?? this.text,
      );
}

/// The visual definition of one pad key, as shown on the phone.
class PadKeyDef {
  final int id;
  final String label;

  /// ARGB color used as the key tint on the phone.
  final int color;

  /// Optional base64-encoded PNG shown on the key face.
  final String? icon;

  const PadKeyDef({
    required this.id,
    required this.label,
    required this.color,
    this.icon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'color': color,
        if (icon != null) 'icon': icon,
      };

  factory PadKeyDef.fromJson(Map<String, dynamic> json) => PadKeyDef(
        id: json['id'] as int,
        label: json['label'] as String? ?? '',
        color: json['color'] as int? ?? 0xFF455A64,
        icon: json['icon'] as String?,
      );

  PadKeyDef copyWith({
    String? label,
    int? color,
    String? Function()? icon,
  }) =>
      PadKeyDef(
        id: id,
        label: label ?? this.label,
        color: color ?? this.color,
        icon: icon != null ? icon() : this.icon,
      );
}

/// The layout pushed from desktop to phone: grid shape, orientation
/// preference and key visuals. Keys are laid out row by row, [cols] per row,
/// as seen on the desktop editor in landscape.
class PadLayoutDef {
  final int rows;
  final int cols;

  /// One of [kOrientations].
  final String orientation;
  final List<PadKeyDef> keys;

  const PadLayoutDef({
    required this.rows,
    required this.cols,
    this.orientation = 'auto',
    required this.keys,
  });

  int get size => keys.length;

  Map<String, dynamic> toJson() => {
        'rows': rows,
        'cols': cols,
        'orientation': orientation,
        'keys': keys.map((k) => k.toJson()).toList(),
      };

  factory PadLayoutDef.fromJson(Map<String, dynamic> json) => PadLayoutDef(
        rows: json['rows'] as int? ?? 2,
        cols: json['cols'] as int? ?? 3,
        orientation: json['orientation'] as String? ?? 'auto',
        keys: (json['keys'] as List? ?? const [])
            .map((k) => PadKeyDef.fromJson((k as Map).cast<String, dynamic>()))
            .toList(),
      );
}
