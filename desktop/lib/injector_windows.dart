import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'injector.dart';

const _inputKeyboard = 1;
const _keyeventfKeyup = 0x0002;
const _keyeventfUnicode = 0x0004;

/// Matches the 64-bit layout of Win32 INPUT with the KEYBDINPUT union arm:
/// DWORD type + 4 padding, then WORD wVk, WORD wScan, DWORD dwFlags,
/// DWORD time, ULONG_PTR dwExtraInfo, padded to the 40-byte union size.
final class _Input extends Struct {
  @Uint32()
  external int type;
  @Uint32()
  external int pad0;
  @Uint16()
  external int wVk;
  @Uint16()
  external int wScan;
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int time;
  @IntPtr()
  external int dwExtraInfo;
  @Uint64()
  external int pad1;
}

typedef _SendInputC = Uint32 Function(
    Uint32 cInputs, Pointer<_Input> pInputs, Int32 cbSize);
typedef _SendInputDart = int Function(
    int cInputs, Pointer<_Input> pInputs, int cbSize);

/// Injects input on Windows via user32 SendInput.
class WindowsInjector extends KeyInjector {
  static final _SendInputDart? _sendInput = _load();

  static _SendInputDart? _load() {
    if (!Platform.isWindows) return null;
    try {
      return DynamicLibrary.open('user32.dll')
          .lookupFunction<_SendInputC, _SendInputDart>('SendInput');
    } catch (_) {
      return null;
    }
  }

  @override
  String get backendName => 'SendInput';

  @override
  String? get unavailableReason =>
      _sendInput == null ? 'user32.dll SendInput unavailable' : null;

  void _send(List<({int vk, int scan, int flags})> events) {
    final send = _sendInput;
    if (send == null || events.isEmpty) return;
    final arr = calloc<_Input>(events.length);
    for (var i = 0; i < events.length; i++) {
      final e = arr[i];
      e.type = _inputKeyboard;
      e.wVk = events[i].vk;
      e.wScan = events[i].scan;
      e.dwFlags = events[i].flags;
    }
    send(events.length, arr, sizeOf<_Input>());
    calloc.free(arr);
  }

  @override
  Future<void> pressHotkey(List<String> modifiers, String key) async {
    final vks = [
      ...modifiers.map((m) => _vk[m]),
      _vk[key],
    ].whereType<int>().toList();
    if (vks.isEmpty) return;
    _send([
      for (final vk in vks) (vk: vk, scan: 0, flags: 0),
      for (final vk in vks.reversed) (vk: vk, scan: 0, flags: _keyeventfKeyup),
    ]);
  }

  @override
  Future<void> typeText(String text) async {
    final events = <({int vk, int scan, int flags})>[];
    for (final unit in text.codeUnits) {
      events.add((vk: 0, scan: unit, flags: _keyeventfUnicode));
      events.add((vk: 0, scan: unit, flags: _keyeventfUnicode | _keyeventfKeyup));
    }
    _send(events);
  }

  /// keydeck key name -> Windows virtual-key code.
  static final _vk = <String, int>{
    'ctrl': 0x11, 'shift': 0x10, 'alt': 0x12, 'super': 0x5B,
    for (var c = 0x41; c <= 0x5A; c++)
      String.fromCharCode(c + 32): c, // a-z
    for (var c = 0x30; c <= 0x39; c++) String.fromCharCode(c): c, // 0-9
    for (var f = 1; f <= 12; f++) 'f$f': 0x70 + f - 1,
    'enter': 0x0D, 'esc': 0x1B, 'tab': 0x09, 'space': 0x20,
    'backspace': 0x08, 'delete': 0x2E,
    'up': 0x26, 'down': 0x28, 'left': 0x25, 'right': 0x27,
    'home': 0x24, 'end': 0x23, 'pageup': 0x21, 'pagedown': 0x22,
    'volumeup': 0xAF, 'volumedown': 0xAE, 'mute': 0xAD,
    'playpause': 0xB3, 'nextsong': 0xB0, 'prevsong': 0xB1,
    'comma': 0xBC, 'period': 0xBE, 'slash': 0xBF, 'semicolon': 0xBA,
    'quote': 0xDE, 'minus': 0xBD, 'equal': 0xBB,
  };
}
