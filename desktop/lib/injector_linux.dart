import 'dart:io';

import 'injector.dart';

/// Uses `xdotool` on X11 sessions and `ydotool` on Wayland (or as fallback).
class LinuxInjector extends KeyInjector {
  String? _cached;

  /// Re-probes while nothing is installed, so installing xdotool/ydotool
  /// starts working without restarting the app.
  String? get _tool => _cached ??= _pickTool();

  static String? _pickTool() {
    final isWayland =
        (Platform.environment['XDG_SESSION_TYPE'] ?? '').toLowerCase() ==
            'wayland';
    final hasX = _exists('xdotool');
    final hasY = _exists('ydotool');
    if (isWayland && hasY) return 'ydotool';
    if (hasX) return 'xdotool';
    if (hasY) return 'ydotool';
    return null;
  }

  static bool _exists(String bin) =>
      Process.runSync('which', [bin]).exitCode == 0;

  @override
  String get backendName => _tool ?? 'none';

  @override
  String? get unavailableReason => _tool != null
      ? null
      : 'Install xdotool (X11) or ydotool (Wayland): sudo apt install xdotool';

  @override
  Future<void> pressHotkey(List<String> modifiers, String key) async {
    if (_tool == 'xdotool') {
      final combo = [...modifiers, _xdoKey[key] ?? key].join('+');
      await Process.run('xdotool', ['key', '--clearmodifiers', combo]);
    } else if (_tool == 'ydotool') {
      final codes = [
        ...modifiers.map((m) => _evdev[m]),
        _evdev[key],
      ].whereType<int>().toList();
      if (codes.isEmpty) return;
      final args = [
        ...codes.map((c) => '$c:1'),
        ...codes.reversed.map((c) => '$c:0'),
      ];
      await Process.run('ydotool', ['key', ...args]);
    }
  }

  @override
  Future<void> typeText(String text) async {
    if (text.isEmpty) return;
    if (_tool == 'xdotool') {
      await Process.run(
          'xdotool', ['type', '--clearmodifiers', '--', text]);
    } else if (_tool == 'ydotool') {
      await Process.run('ydotool', ['type', '--', text]);
    }
  }

  /// keydeck key name -> X keysym where they differ.
  static const _xdoKey = {
    'enter': 'Return',
    'esc': 'Escape',
    'tab': 'Tab',
    'space': 'space',
    'backspace': 'BackSpace',
    'delete': 'Delete',
    'up': 'Up',
    'down': 'Down',
    'left': 'Left',
    'right': 'Right',
    'home': 'Home',
    'end': 'End',
    'pageup': 'Page_Up',
    'pagedown': 'Page_Down',
    'volumeup': 'XF86AudioRaiseVolume',
    'volumedown': 'XF86AudioLowerVolume',
    'mute': 'XF86AudioMute',
    'playpause': 'XF86AudioPlay',
    'nextsong': 'XF86AudioNext',
    'prevsong': 'XF86AudioPrev',
    'comma': 'comma',
    'period': 'period',
    'slash': 'slash',
    'semicolon': 'semicolon',
    'quote': 'apostrophe',
    'minus': 'minus',
    'equal': 'equal',
    'f1': 'F1', 'f2': 'F2', 'f3': 'F3', 'f4': 'F4', 'f5': 'F5', 'f6': 'F6',
    'f7': 'F7', 'f8': 'F8', 'f9': 'F9', 'f10': 'F10', 'f11': 'F11',
    'f12': 'F12',
  };

  /// keydeck key name -> Linux evdev code (input-event-codes.h) for ydotool.
  static const _evdev = <String, int>{
    'ctrl': 29, 'shift': 42, 'alt': 56, 'super': 125,
    'a': 30, 'b': 48, 'c': 46, 'd': 32, 'e': 18, 'f': 33, 'g': 34, 'h': 35,
    'i': 23, 'j': 36, 'k': 37, 'l': 38, 'm': 50, 'n': 49, 'o': 24, 'p': 25,
    'q': 16, 'r': 19, 's': 31, 't': 20, 'u': 22, 'v': 47, 'w': 17, 'x': 45,
    'y': 21, 'z': 44,
    '1': 2, '2': 3, '3': 4, '4': 5, '5': 6, '6': 7, '7': 8, '8': 9, '9': 10,
    '0': 11,
    'f1': 59, 'f2': 60, 'f3': 61, 'f4': 62, 'f5': 63, 'f6': 64, 'f7': 65,
    'f8': 66, 'f9': 67, 'f10': 68, 'f11': 87, 'f12': 88,
    'enter': 28, 'esc': 1, 'tab': 15, 'space': 57, 'backspace': 14,
    'delete': 111,
    'up': 103, 'down': 108, 'left': 105, 'right': 106,
    'home': 102, 'end': 107, 'pageup': 104, 'pagedown': 109,
    'volumeup': 115, 'volumedown': 114, 'mute': 113,
    'playpause': 164, 'nextsong': 163, 'prevsong': 165,
    'comma': 51, 'period': 52, 'slash': 53, 'semicolon': 39, 'quote': 40,
    'minus': 12, 'equal': 13,
  };
}
