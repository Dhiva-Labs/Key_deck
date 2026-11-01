#!/usr/bin/env bash
# Installs the Flatpak bundle the way a user does and runs KeyDeck in it.
# CI runs this in the flatpak-builder container right after the build (the
# GNOME runtime is already installed there from Flathub).
#
# usage: smoke.sh <bundle.flatpak>
#
#   1. `flatpak install --user` the bundle;
#   2. ldd every ELF file under /app inside the sandbox: no "not found";
#   3. under Xvfb, start the app. Flutter must draw the window (counted in
#      Xvfb's framebuffer, where an empty screen has one colour; the
#      container has no xdotool), the Dart pad server must listen on port
#      8737, and the app's lookup of its keystroke tool (`which xdotool`)
#      must have run on the host: the container's PATH starts with stub
#      `which` and `xdotool` scripts that log their calls, which only a
#      process outside the sandbox can reach;
#   4. the two other host paths the app uses: `xdotool key ...` through the
#      /app/bin/xdotool wrapper, and a "Command" key's
#      `flatpak-spawn --host /bin/sh -c ...`, each leaving a file in a host
#      directory the sandbox cannot see.
# A key press itself cannot be sent from here: the phone authenticates
# with a token that only the on-screen QR code carries.
set -euo pipefail
APP_ID=dev.dhivalabs.keydeck_desktop
[ $# -eq 1 ] || { echo "usage: $0 <bundle.flatpak>" >&2; exit 2; }
bundle="$(readlink -f "$1")"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
mkdir -p -m 0700 "$XDG_RUNTIME_DIR"

echo "::group::flatpak install --user $(basename "$bundle")"
flatpak install --user -y --noninteractive "$bundle"
flatpak info --user "$APP_ID"
flatpak info --user --show-permissions "$APP_ID"
# Flutter draws through OpenGL. A user's Flatpak installs the runtime's GL
# extension (Mesa) from Flathub along with the runtime; the builder image
# has the runtime without it, and the app then draws nothing ("No GL
# implementation is available"). Install the branch the runtime asks for.
runtime="$(flatpak info --user --show-runtime "$APP_ID")"
gl="$(flatpak info --show-metadata "$runtime" |
  sed -n '/^\[Extension org.freedesktop.Platform.GL\]/,/^\[/s/^versions=\([^;]*\).*/\1/p')"
[ -n "$gl" ] || { echo "no GL extension version in $runtime's metadata" >&2; exit 1; }
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y --noninteractive flathub "org.freedesktop.Platform.GL.default//$gl"
echo "::endgroup::"

echo "::group::ldd inside the sandbox"
flatpak run --command=bash "$APP_ID" -c '
  set -euo pipefail
  mapfile -d "" elfs < <(find /app -type f -print0)
  libdirs="$(find /app -name "*.so*" -type f -printf "%h\n" | sort -u | paste -sd:)"
  n=0; bad=0
  for f in "${elfs[@]}"; do
    [ "$(head -c 4 "$f" | od -An -tx1 | tr -d " \n")" = 7f454c46 ] || continue
    n=$((n + 1))
    if LD_LIBRARY_PATH="$libdirs" ldd "$f" 2>&1 | grep "not found" > /dev/null; then
      echo "missing libraries for $f:"
      LD_LIBRARY_PATH="$libdirs" ldd "$f" | grep "not found"
      bad=1
    fi
  done
  echo "$n ELF files checked with ldd in the sandbox"
  [ "$n" -gt 0 ] && [ "$bad" = 0 ]'
echo "::endgroup::"

# Host side: stub tools first on PATH. The session bus, and the Flatpak
# session helper it starts, inherit this PATH, so flatpak-spawn --host
# finds them.
fb="$(mktemp -d)"
mkdir -p "$fb/hostbin"
cat > "$fb/hostbin/which" <<EOS
#!/bin/sh
echo "\$*" >> "$fb/host-which.log"
for tool in "\$@"; do command -v "\$tool" || exit 1; done
EOS
cat > "$fb/hostbin/xdotool" <<EOS
#!/bin/sh
echo "\$*" >> "$fb/host-xdotool.log"
EOS
chmod +x "$fb/hostbin/which" "$fb/hostbin/xdotool"
export PATH="$fb/hostbin:$PATH"

cat > "$fb/run.sh" <<'EOS'
set -euo pipefail
app_id="$1"; fb="$2"; here="$3"

# flatpak-spawn --host needs the Flatpak session helper on the session bus.
# A desktop starts it by D-Bus activation; start it by hand if this bus
# cannot.
if ! timeout 30 flatpak run --command=flatpak-spawn "$app_id" --host true; then
  helper=""
  for h in /usr/libexec/flatpak-session-helper /app/libexec/flatpak-session-helper; do
    if [ -x "$h" ]; then helper="$h"; break; fi
  done
  [ -n "$helper" ] || { echo "no flatpak-session-helper in this container"; exit 1; }
  echo "starting $helper"
  "$helper" > "$fb/helper.log" 2>&1 &
  sleep 3
  timeout 30 flatpak run --command=flatpak-spawn "$app_id" --host true
fi
echo "flatpak-spawn --host works"

listening() {
  { cat /proc/net/tcp; cat /proc/net/tcp6 2> /dev/null || :; } |
    awk '$4 == "0A" && $2 ~ /:2221$/ { up = 1 } END { exit !up }'
}
log="$fb/app.log"
flatpak run "$app_id" > "$log" 2>&1 &
pid=$!
ok=0
for i in $(seq 1 120); do
  kill -0 "$pid" 2> /dev/null || { echo "the app exited early"; break; }
  colours="$(python3 "$here/xwd-colours.py" "$fb/Xvfb_screen0")"
  if [ "$colours" -ge 16 ] && listening && grep -qsx 'xdotool' "$fb/host-which.log"; then
    echo "after ${i}s: the screen shows $colours colours, the pad server listens on 8737," \
      "and the app's 'which xdotool' ran on the host"
    ok=1
    break
  fi
  sleep 1
done
if [ "$ok" = 1 ]; then
  sleep 5
  kill -0 "$pid" 2> /dev/null || { echo "the app died after it came up"; ok=0; }
else
  echo "not up after 120s: screen colours ${colours:-?}; listening: $(listening && echo yes || echo no)"
  echo "host which calls:"; cat "$fb/host-which.log" 2> /dev/null || echo "(none)"
fi
kill "$pid" 2> /dev/null || :
cat "$log"
if grep -E 'error while loading shared libraries|cannot open shared object|undefined symbol' "$log"; then ok=0; fi
[ "$ok" = 1 ]

# The hotkey path: the app runs `xdotool key ...` by name.
flatpak run --command=xdotool "$app_id" key --clearmodifiers ctrl+shift+t
grep -qx -- 'key --clearmodifiers ctrl+shift+t' "$fb/host-xdotool.log"
echo "xdotool in the sandbox reached the host's xdotool"
# The "Command" path: exactly what KeyInjector.commandLine returns there.
flatpak run --command=flatpak-spawn "$app_id" --host /bin/sh -c "touch '$fb/command-ran'"
[ -f "$fb/command-ran" ]
echo "a Command key's shell command ran on the host"
EOS
echo "::group::run under Xvfb"
xvfb-run -a -s "-screen 0 1280x800x24 -br -fbdir $fb" \
  dbus-run-session -- bash "$fb/run.sh" "$APP_ID" "$fb" "$here"
echo "::endgroup::"
rm -rf "$fb"
echo "Flatpak bundle $(basename "$bundle"): OK"
