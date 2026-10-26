#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$ROOT_DIR/build/linux/x64/release/bundle"
INSTALL_DIR="/usr/lib/leenky"
DESKTOP_ID="leenky"
TEMP_DESKTOP="$(mktemp)"
trap 'rm -f "$TEMP_DESKTOP"' EXIT

if [[ ! -x "$BUNDLE_DIR/leenky" ]]; then
  echo "Error: Linux release bundle not found. Run ./compile.sh first." >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "Error: sudo is required to install Leenky system-wide." >&2
  exit 1
fi

# Keep the complete Flutter bundle together so its bundled libraries and data
# remain next to the executable. /usr/bin/leenky points into this directory.
sudo install -d -o root -g root -m 755 "$INSTALL_DIR"
sudo cp -R "$BUNDLE_DIR/." "$INSTALL_DIR/"
sudo ln -sfn "$INSTALL_DIR/leenky" "/usr/bin/$DESKTOP_ID"
sudo install -Dm644 "$ROOT_DIR/assets/icon.png" \
  "/usr/share/icons/hicolor/512x512/apps/$DESKTOP_ID.png"

# Do not let the user-level build entry (created by compile.sh) shadow the
# system entry with an Exec path into this checkout.
USER_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
USER_DESKTOP="$USER_DATA_DIR/applications/$DESKTOP_ID.desktop"
if [[ -f "$USER_DESKTOP" ]] &&
  grep -Fq "Exec=\"$BUNDLE_DIR/leenky\"" "$USER_DESKTOP"; then
  rm "$USER_DESKTOP"
fi

sed 's|^Exec=.*$|Exec=leenky|' "$ROOT_DIR/$DESKTOP_ID.desktop" > "$TEMP_DESKTOP"
sudo install -Dm644 "$TEMP_DESKTOP" \
  "/usr/share/applications/$DESKTOP_ID.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
  sudo update-desktop-database /usr/share/applications
fi

echo "Leenky installed. Run it with: leenky"
