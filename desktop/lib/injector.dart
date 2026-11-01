import 'dart:io';

import 'package:keydeck_protocol/keydeck_protocol.dart';

import 'injector_linux.dart';
import 'injector_windows.dart';

/// Key names offered in the hotkey editor. Every entry must be mapped in all
/// platform injectors.
final List<String> kHotkeyKeys = [
  ...'abcdefghijklmnopqrstuvwxyz'.split(''),
  ...'0123456789'.split(''),
  'f1', 'f2', 'f3', 'f4', 'f5', 'f6', 'f7', 'f8', 'f9', 'f10', 'f11', 'f12',
  'enter', 'esc', 'tab', 'space', 'backspace', 'delete',
  'up', 'down', 'left', 'right', 'home', 'end', 'pageup', 'pagedown',
  'volumeup', 'volumedown', 'mute', 'playpause', 'nextsong', 'prevsong',
  'comma', 'period', 'slash', 'semicolon', 'quote', 'minus', 'equal',
];

const List<String> kModifiers = ['ctrl', 'shift', 'alt', 'super'];

/// Executes [KeyAction]s on the host OS.
abstract class KeyInjector {
  /// Short label shown in the UI, e.g. `xdotool` or `SendInput`.
  String get backendName;

  /// Null when ready; otherwise a message telling the user what to install.
  String? get unavailableReason;

  Future<void> pressHotkey(List<String> modifiers, String key);
  Future<void> typeText(String text);

  Future<void> run(KeyAction action) async {
    switch (action.type) {
      case KeyActionType.hotkey:
        await pressHotkey(action.modifiers, action.key);
      case KeyActionType.text:
        await typeText(action.text);
      case KeyActionType.command:
        await _runCommand(action.text);
      case KeyActionType.none:
        break;
    }
  }

  Future<void> _runCommand(String command) async {
    if (command.trim().isEmpty) return;
    final argv = commandLine(command,
        windows: Platform.isWindows,
        flatpak: File('/.flatpak-info').existsSync());
    await Process.start(argv.first, argv.sublist(1),
        mode: ProcessStartMode.detached);
  }

  /// The process that runs a key's shell [command]. Inside the Flatpak
  /// sandbox `/bin/sh` is the runtime's and cannot start the user's apps or
  /// scripts, so the command goes to the host through `flatpak-spawn
  /// --host`, the way it runs from every other package.
  static List<String> commandLine(String command,
      {required bool windows, required bool flatpak}) {
    if (windows) return ['cmd', '/c', command];
    if (flatpak) return ['flatpak-spawn', '--host', '/bin/sh', '-c', command];
    return ['/bin/sh', '-c', command];
  }

  static KeyInjector forThisPlatform() =>
      Platform.isWindows ? WindowsInjector() : LinuxInjector();
}
