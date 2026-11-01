# Flatpak

`dev.dhivalabs.keydeck_desktop.yml` packages the files the `.deb` installs as
a Flatpak on the GNOME 51 runtime, so the Flatpak runs the same binary as
every other Linux format. The app id is the GTK application id the desktop
host already uses (`desktop/linux/CMakeLists.txt`).

## What a sandbox means for KeyDeck

KeyDeck exists to act on your desktop: it types hotkeys and text into
whatever window has focus, using xdotool (X11) or ydotool (Wayland), and its
"Command" keys run shell commands. A Flatpak sandbox blocks all of that
(there is no xdotool in the runtime, a sandboxed xdotool could not reach a
Wayland session, and a sandboxed shell cannot start your apps). So this
Flatpak goes through the host:

- `/app/bin/which`, `/app/bin/xdotool` and `/app/bin/ydotool` are
  `host-tool.sh`, which runs the host's tool of the same name with
  `flatpak-spawn --host`. The app finds and drives the keystroke tool exactly
  as from the `.deb`, so xdotool or ydotool must be installed on the system.
- "Command" keys run `flatpak-spawn --host /bin/sh -c <command>` when the
  app sees `/.flatpak-info` (`KeyInjector.commandLine` in
  `desktop/lib/injector.dart`).
- That needs `--talk-name=org.freedesktop.Flatpak`, which lets the app run
  any command as you. **The Flatpak is therefore not a security boundary for
  KeyDeck**; it is a packaging format. Use it for that, not for isolation.

The other permissions: `--share=network` (the phone connects to the pad
server on port 8737) and `--system-talk-name=org.bluez` (Bluetooth pairing).
Key images are picked with the file chooser portal and stored inside the
app's config, so no filesystem permission is needed.

## How CI builds it

The `flatpak` job in `.github/workflows/desktop.yml`, on x86_64 and aarch64:

1. takes the installed tree of that architecture's `.deb` from the `distros`
   job and unpacks it into `packaging/flatpak/tree/` (ignored by git);
2. builds the manifest with `flatpak/flatpak-github-actions/flatpak-builder`
   in Flathub's builder image and exports `keydeck-<version>-<arch>.flatpak`,
   with Flathub as the runtime repo;
3. runs `smoke.sh`: installs the bundle with `flatpak install --user`, runs
   ldd on every ELF file inside the sandbox, starts the app and checks that
   it drew its window (colours in Xvfb's framebuffer, `xwd-colours.py`),
   that the pad server listens on 8737, and that its `which xdotool` ran on
   the host; then that `xdotool key ...` from the sandbox and a Command
   key's `flatpak-spawn --host /bin/sh -c ...` both run on the host (stub
   tools on the container's PATH record the calls).

A real key press is not sent: the phone authenticates with a per-launch
token that only the on-screen QR code carries.

Install with:

```sh
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user ./keydeck-<version>-<arch>.flatpak
flatpak run dev.dhivalabs.keydeck_desktop
```

## Submitting to Flathub

Not done; the user decides. Flathub reviews `--talk-name=org.freedesktop.Flatpak`
case by case and would want the reasons above. Other differences:

- the `tree` dir source becomes the release `.deb` of each architecture (a
  `type: file` source with `only-arches`, url and sha256, unpacked with
  `bsdtar` in the build commands), or a build from source with the Flutter
  SDK as a module;
- the repository needs a licence (the metainfo says
  `LicenseRef-proprietary`, as the `.deb` says proprietary freeware),
  `<releases>` must list each new version, and Flathub wants screenshots.
