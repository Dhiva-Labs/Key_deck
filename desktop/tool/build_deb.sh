#!/usr/bin/env bash
# Builds keydeck_<version>_<arch>.deb from the Linux release bundle.
#
# Run from anywhere after `flutter build linux --release` in desktop/:
#
#     desktop/tool/build_deb.sh [output-dir]        # default: desktop/dist/
#
# <arch> is the Debian architecture of the build machine (amd64 or arm64),
# which is also the only one `flutter build linux` can target, so the bundle
# is read from build/linux/x64/... on amd64 and build/linux/arm64/... on arm64.
# Needs dpkg-deb.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT_DIR="${1:-dist}"
DEB_ARCH="$(dpkg --print-architecture)"
case "$DEB_ARCH" in
  amd64) FLUTTER_ARCH=x64 ;;
  arm64) FLUTTER_ARCH=arm64 ;;
  *)
    echo "error: unsupported architecture '$DEB_ARCH' (amd64 or arm64)" >&2
    exit 1
    ;;
esac
BUNDLE="build/linux/$FLUTTER_ARCH/release/bundle"
VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)"

[ -x "$BUNDLE/keydeck_desktop" ] || {
  echo "error: $BUNDLE/keydeck_desktop not found - run 'flutter build linux --release' first" >&2
  exit 1
}

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
PKG="$STAGE/keydeck"

mkdir -p \
  "$PKG/DEBIAN" \
  "$PKG/usr/lib/keydeck" \
  "$PKG/usr/bin" \
  "$PKG/usr/share/applications" \
  "$PKG/usr/share/doc/keydeck"

cp -r "$BUNDLE/." "$PKG/usr/lib/keydeck/"

cat > "$PKG/usr/bin/keydeck" <<'WRAPPER'
#!/bin/sh
exec /usr/lib/keydeck/keydeck_desktop "$@"
WRAPPER
chmod 0755 "$PKG/usr/bin/keydeck"

cat > "$PKG/usr/share/applications/keydeck.desktop" <<'ENTRY'
[Desktop Entry]
Type=Application
Name=KeyDeck
Comment=Turn your phone into a programmable macro pad
Exec=keydeck
Icon=input-keyboard
Terminal=false
Categories=Utility;
Keywords=macro;streamdeck;hotkey;keyboard;
ENTRY

cat > "$PKG/usr/share/doc/keydeck/copyright" <<COPYRIGHT
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: keydeck
Source: https://github.com/Dhiva-Labs/Key_deck

Files: *
Copyright: $(date +%Y) Dhiva Labs
License: proprietary-freeware
 Distributed as a free application by Dhiva Labs.
COPYRIGHT

INSTALLED_SIZE="$(du -sk "$PKG/usr" | cut -f1)"
cat > "$PKG/DEBIAN/control" <<CONTROL
Package: keydeck
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${DEB_ARCH}
Maintainer: Dhiva Labs <dhivakar1010@gmail.com>
Installed-Size: ${INSTALLED_SIZE}
Depends: libgtk-3-0t64 | libgtk-3-0
Recommends: xdotool | ydotool
Homepage: https://github.com/Dhiva-Labs/Key_deck
Description: Phone macro pad host for the desktop
 KeyDeck turns a phone into a programmable macro pad. This is the desktop
 host: it shows the pairing QR code, lets you program every key and injects
 the keystrokes. Pair over WiFi or Bluetooth. Keystroke injection needs
 xdotool (X11) or ydotool (Wayland).
CONTROL

mkdir -p "$OUT_DIR"
DEB="$OUT_DIR/keydeck_${VERSION}_${DEB_ARCH}.deb"
dpkg-deb --build --root-owner-group "$PKG" "$DEB" > /dev/null
echo "built $DEB"
