import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:keydeck_protocol/keydeck_protocol.dart';

import 'deck_config.dart';
import 'injector.dart';

const kKeyColors = [
  0xFF3F51B5, 0xFF1976D2, 0xFF00838F, 0xFF00897B, 0xFF2E7D32,
  0xFF9E9D24, 0xFFE65100, 0xFFC62828, 0xFFAD1457, 0xFF6A1B9A,
  0xFF4527A0, 0xFF37474F,
];

/// Dialog for programming one pad key: label, color, face image and the
/// bound action.
class KeyEditorDialog extends StatefulWidget {
  final DeckKey deckKey;
  final void Function(PadKeyDef def, KeyAction action) onSave;

  const KeyEditorDialog(
      {super.key, required this.deckKey, required this.onSave});

  @override
  State<KeyEditorDialog> createState() => _KeyEditorDialogState();
}

class _KeyEditorDialogState extends State<KeyEditorDialog> {
  late final TextEditingController _label =
      TextEditingController(text: widget.deckKey.def.label);
  late final TextEditingController _text = TextEditingController(
      text: widget.deckKey.action.type == KeyActionType.text
          ? widget.deckKey.action.text
          : '');
  late final TextEditingController _command = TextEditingController(
      text: widget.deckKey.action.type == KeyActionType.command
          ? widget.deckKey.action.text
          : '');
  late final TextEditingController _hotKey = TextEditingController(
      text: widget.deckKey.action.key.isEmpty ? 'a' : widget.deckKey.action.key);
  late int _color = widget.deckKey.def.color;
  late String? _icon = widget.deckKey.def.icon;
  late KeyActionType _type = widget.deckKey.action.type;
  late Set<String> _mods = widget.deckKey.action.modifiers.toSet();
  String? _imageError;

  @override
  void initState() {
    super.initState();
    // Re-validate the Save button as the user types a key name.
    _hotKey.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _label.dispose();
    _text.dispose();
    _command.dispose();
    _hotKey.dispose();
    super.dispose();
  }

  /// The typed/selected hotkey, if it names a real key.
  String? get _validHotKey {
    final k = _hotKey.text.trim().toLowerCase();
    return kHotkeyKeys.contains(k) ? k : null;
  }

  KeyAction _buildAction() => switch (_type) {
        KeyActionType.none => const KeyAction(),
        KeyActionType.hotkey => KeyAction(
            type: KeyActionType.hotkey,
            modifiers:
                kModifiers.where(_mods.contains).toList(), // stable order
            key: _validHotKey ?? 'a',
          ),
        KeyActionType.text =>
          KeyAction(type: KeyActionType.text, text: _text.text),
        KeyActionType.command =>
          KeyAction(type: KeyActionType.command, text: _command.text),
      };

  Future<void> _pickImage() async {
    final file = await openFile(acceptedTypeGroups: [
      const XTypeGroup(
          label: 'Images', extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp']),
    ]);
    if (file == null) return;
    try {
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) throw Exception('unsupported format');
      final resized = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? 144 : null,
        height: decoded.height > decoded.width ? 144 : null,
      );
      setState(() {
        _icon = base64Encode(img.encodePng(resized));
        _imageError = null;
      });
    } catch (e) {
      setState(() => _imageError = 'Could not read that image ($e)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Key ${widget.deckKey.def.id + 1}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _label,
                decoration: const InputDecoration(
                    labelText: 'Label (shown on the phone)'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Color(_color),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _icon != null
                        ? Image.memory(base64Decode(_icon!),
                            fit: BoxFit.contain, gaplessPlayback: true)
                        : const Icon(Icons.image_outlined,
                            color: Colors.white38),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: Text(_icon == null ? 'Add image' : 'Change image'),
                    onPressed: _pickImage,
                  ),
                  if (_icon != null)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove'),
                      onPressed: () => setState(() => _icon = null),
                    ),
                ],
              ),
              if (_imageError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_imageError!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12)),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in kKeyColors)
                    InkWell(
                      onTap: () => setState(() => _color = c),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: _color == c
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SegmentedButton<KeyActionType>(
                segments: const [
                  ButtonSegment(
                      value: KeyActionType.hotkey, label: Text('Hotkey')),
                  ButtonSegment(value: KeyActionType.text, label: Text('Text')),
                  ButtonSegment(
                      value: KeyActionType.command, label: Text('Command')),
                  ButtonSegment(value: KeyActionType.none, label: Text('None')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              ..._actionFields(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _type == KeyActionType.hotkey && _validHotKey == null
              ? null
              : () {
                  widget.onSave(
                    PadKeyDef(
                      id: widget.deckKey.def.id,
                      label: _label.text.trim().isEmpty
                          ? 'Key ${widget.deckKey.def.id + 1}'
                          : _label.text.trim(),
                      color: _color,
                      icon: _icon,
                    ),
                    _buildAction(),
                  );
                  Navigator.pop(context);
                },
          child: const Text('Save'),
        ),
      ],
    );
  }

  List<Widget> _actionFields() => switch (_type) {
        KeyActionType.none => const [
            Text('This key does nothing when pressed.'),
          ],
        KeyActionType.hotkey => [
            Wrap(
              spacing: 8,
              children: [
                for (final m in kModifiers)
                  FilterChip(
                    label: Text(m[0].toUpperCase() + m.substring(1)),
                    selected: _mods.contains(m),
                    onSelected: (v) => setState(() {
                      _mods = {..._mods};
                      v ? _mods.add(m) : _mods.remove(m);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownMenu<String>(
              controller: _hotKey,
              initialSelection: _hotKey.text,
              label: const Text('Key'),
              helperText: _validHotKey == null
                  ? 'Unknown key — type e.g. "f5", "enter", or pick from the list'
                  : 'Type a key name or pick from the list',
              requestFocusOnTap: true,
              enableFilter: true,
              menuHeight: 320,
              dropdownMenuEntries: [
                for (final k in kHotkeyKeys)
                  DropdownMenuEntry(value: k, label: k),
              ],
              onSelected: (_) => setState(() {}),
            ),
          ],
        KeyActionType.text => [
            TextField(
              controller: _text,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Text to type',
                helperText: 'Typed into the focused window on each press',
              ),
            ),
          ],
        KeyActionType.command => [
            TextField(
              controller: _command,
              decoration: const InputDecoration(
                labelText: 'Shell command',
                helperText: 'Runs detached, e.g. "firefox" or "code ~/project"',
              ),
            ),
          ],
      };
}
