import 'package:flutter_test/flutter_test.dart';

import 'package:keydeck_desktop/injector.dart';

void main() {
  test('commands run through the platform shell', () {
    expect(
      KeyInjector.commandLine('notify-send hi', windows: false, flatpak: false),
      ['/bin/sh', '-c', 'notify-send hi'],
    );
    expect(
      KeyInjector.commandLine('start notepad', windows: true, flatpak: false),
      ['cmd', '/c', 'start notepad'],
    );
  });

  test('inside the Flatpak, commands run on the host', () {
    expect(KeyInjector.commandLine('firefox', windows: false, flatpak: true), [
      'flatpak-spawn',
      '--host',
      '/bin/sh',
      '-c',
      'firefox',
    ]);
  });
}
