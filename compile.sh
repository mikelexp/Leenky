#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

fvm flutter build linux --release "$@"

BUNDLE_DIR="$ROOT_DIR/build/linux/x64/release/bundle"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
DESKTOP_ID="leenky"
DESKTOP_DIR="$DATA_DIR/applications"
ICON_DIR="$DATA_DIR/icons/hicolor/512x512/apps"

# Wayland compositors look up a window icon using its app_id and a matching
# installed desktop entry; gtk_window_set_icon_from_file alone is not enough.
install -d "$DESKTOP_DIR" "$ICON_DIR"
install -m 644 "$ROOT_DIR/assets/icon.png" "$ICON_DIR/leenky.png"
sed "s|^Exec=leenky$|Exec=\"$BUNDLE_DIR/leenky\"|" \
  "$ROOT_DIR/leenky.desktop" > "$DESKTOP_DIR/$DESKTOP_ID.desktop"
chmod 644 "$DESKTOP_DIR/$DESKTOP_ID.desktop"

# Remove the prior development desktop ID if it still points to this bundle.
OLD_DESKTOP="$DESKTOP_DIR/dev.leenky.leenky.desktop"
if [[ -f "$OLD_DESKTOP" ]] &&
  grep -Fq "Exec=\"$BUNDLE_DIR/leenky\"" "$OLD_DESKTOP"; then
  rm "$OLD_DESKTOP"
fi

echo "Build ready at: $BUNDLE_DIR/"
echo "Desktop entry and icon registered for the current user."
