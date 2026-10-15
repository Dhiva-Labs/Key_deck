# KeyDeck

[![ARM64 builds](https://github.com/Dhiva-Labs/Key_deck/actions/workflows/desktop.yml/badge.svg?branch=main)](https://github.com/Dhiva-Labs/Key_deck/actions/workflows/desktop.yml)
![Linux x64 | arm64](https://img.shields.io/badge/Linux-x64%20%7C%20arm64-informational?logo=linux&logoColor=white)
![Windows x64 | arm64](https://img.shields.io/badge/Windows-x64%20%7C%20arm64-informational?logo=windows&logoColor=white)

Turn your phone into a programmable macro pad (a Stream Deck replacement) for
your Ubuntu or Windows machine.

- **Mobile app** (Android/iOS, Flutter) — the pad itself. Grids of 4, 6, 8 or
  10 big keys. Tap a key and the desktop executes whatever you programmed.
- **Desktop app** (Ubuntu/Windows on x64 and arm64, Flutter) — the host. Shows the pairing QR
  code, lets you program every key, and injects the keystrokes.
- **Connect over WiFi or Bluetooth** — same session token, either medium.
- **QR pairing** — the desktop shows a QR code; scan it with the phone to
  start a session. The QR carries the host IPs, port and a per-launch secret
  token, so nothing on your network can send you keystrokes uninvited.

## Repo layout

| Directory   | What it is                                                    |
|-------------|---------------------------------------------------------------|
| `protocol/` | Pure-Dart shared package: models, wire messages, QR payload, BLE framing |
| `desktop/`  | Flutter desktop host (Linux + Windows, x64 + arm64)           |
| `mobile/`   | Flutter mobile pad (Android + iOS)                            |

## How it works

```
┌────────── phone ──────────┐              ┌───────── desktop ─────────┐
│ scan QR → SessionInfo     │              │ shows QR (ips+port+token) │
│                           │   WiFi       │                           │
│ WsTransport ── hello ─────┼──────────────▶ PadServer (WebSocket)     │
│              ◀─ ack+layout┤              │                           │
│ tap key ──── key ─────────┼──────────────▶ KeyInjector executes      │
│                           │              │                           │
│ BleTransport (peripheral, │   Bluetooth  │ BleHost (central, scans   │
│ advertises GATT service)  ◀──────────────┤ and connects)             │
└───────────────────────────┘              └───────────────────────────┘
```

Key programming lives entirely on the desktop; the phone only ever receives
labels and colors. Actions per key:

- **Hotkey** — e.g. `Ctrl+Shift+T`, media keys included
- **Text** — types a snippet into the focused window
- **Command** — runs a shell command (launch apps, scripts…)

Each pad size (4/6/8/10) keeps its own set of programmed keys, and edits sync
to a connected phone live.

## Running

### Download the desktop app

The desktop host is built for Linux and Windows on both x64 and arm64. GitHub
releases published after the CI workflow was added carry these files (the x64
`.deb` is still attached by hand); every CI run also keeps all of them as
workflow artifacts:

| Platform             | File                                                        |
|----------------------|-------------------------------------------------------------|
| Ubuntu/Debian x64    | `keydeck_<version>_amd64.deb`                               |
| Ubuntu/Debian arm64  | `keydeck_<version>_arm64.deb`                               |
| Linux (any distro)   | `KeyDeck-<version>-linux-x64.tar.gz`, `KeyDeck-<version>-linux-arm64.tar.gz` |
| Windows              | `KeyDeck-<version>-windows-x64.zip`, `KeyDeck-<version>-windows-arm64.zip`   |

```bash
sudo apt install ./keydeck_<version>_arm64.deb   # or _amd64.deb; pulls in GTK, recommends xdotool
```

The tarball and zip hold the whole app folder: unpack and run `keydeck_desktop`
(`keydeck_desktop.exe` on Windows). Keystroke injection still needs xdotool or
ydotool on Linux.

### Desktop (Ubuntu)

```bash
# Keystroke injection backend (pick one):
sudo apt install xdotool     # X11 sessions
sudo apt install ydotool     # Wayland sessions (needs ydotoold running)

cd desktop
flutter run -d linux          # or: flutter build linux --release
```

On Windows: `flutter build windows --release` — injection uses the built-in
Win32 `SendInput`, nothing to install.

Flutter cannot cross-compile desktop apps, so an arm64 build is made on an
arm64 machine (`build/linux/arm64/...`, `build\windows\arm64\...`); the same
commands work there unchanged.

### Mobile (Android)

```bash
cd mobile
flutter run                   # or: flutter build apk --release
```

1. Start the desktop app — it shows a QR code.
2. In the phone app, scan the QR code.
3. Pick **WiFi** (both devices on the same network) or **Bluetooth**
   (flip the Bluetooth switch on in the desktop app so it scans for the phone).
4. Tap keys. Program them from the desktop at any time.

## Testing

```bash
cd protocol && dart test      # wire format, framing, QR payload
cd desktop && flutter test    # real WebSocket server handshake + auth
```

GitHub Actions (`.github/workflows/desktop.yml`) runs both suites, builds the
desktop app and starts it, on Linux x64, Linux arm64, Windows x64 and Windows
arm64, each on a native runner. It also packages the `.deb`, tarball and zip
listed above.

## Notes

- The WebSocket port defaults to 8737 (falls back to a random free port).
- The session token rotates on every desktop app launch, invalidating old QRs.
- Bluetooth uses BLE GATT: the phone advertises the KeyDeck service as a
  peripheral and the desktop connects as a central, so it works without
  classic Bluetooth pairing.
