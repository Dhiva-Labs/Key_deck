#!/usr/bin/env bash
# Builds KeyDeck-<version>-linux-<arch>.tar.gz from the Linux release bundle.
#
# Run from anywhere after `flutter build linux --release` in desktop/:
#
#     desktop/tool/build_tarball.sh [output-dir]    # default: desktop/dist/
#
# <arch> is Flutter's name for the build machine (x64 or arm64), which is also
# the only architecture `flutter build linux` can target. The archive holds the
# bundle in a single KeyDeck-<version>-linux-<arch>/ directory; run
# ./keydeck_desktop from inside it.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT_DIR="${1:-dist}"
case "$(uname -m)" in
  x86_64) ARCH=x64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *)
    echo "error: unsupported machine '$(uname -m)' (x86_64 or aarch64)" >&2
    exit 1
    ;;
esac
RELEASE_DIR="build/linux/$ARCH/release"
VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)"

[ -x "$RELEASE_DIR/bundle/keydeck_desktop" ] || {
  echo "error: $RELEASE_DIR/bundle/keydeck_desktop not found - run 'flutter build linux --release' first" >&2
  exit 1
}

NAME="KeyDeck-${VERSION}-linux-${ARCH}"
mkdir -p "$OUT_DIR"
TARBALL="$OUT_DIR/$NAME.tar.gz"
tar -czf "$TARBALL" --owner=0 --group=0 --sort=name \
  --transform "s,^bundle,$NAME," -C "$RELEASE_DIR" bundle
echo "built $TARBALL"
