#!/bin/sh
# Installed in the Flatpak as /app/bin/which, /app/bin/xdotool and
# /app/bin/ydotool. KeyDeck runs these by name to find and drive the
# keystroke tool; they must act on the user's session, so each runs the
# host's tool of the same name.
exec flatpak-spawn --host "$(basename "$0")" "$@"
