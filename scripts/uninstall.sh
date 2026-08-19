#!/usr/bin/env bash
set -euo pipefail

APP_ID="leenky"
INSTALL_BIN="${HOME}/.local/bin"
INSTALL_LIB="${HOME}/.local/lib/${APP_ID}"
INSTALL_APPS="${HOME}/.local/share/applications"
INSTALL_ICONS="${HOME}/.local/share/icons/hicolor/512x512/apps"

rm -f "${INSTALL_BIN}/leenky" "${INSTALL_APPS}/${APP_ID}.desktop" "${INSTALL_ICONS}/${APP_ID}.png"
rm -rf "${INSTALL_LIB}"

if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "${INSTALL_APPS}"
fi
if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor"
fi

if [[ "${1:-}" == "--purge" || "${1:-}" == "-p" ]]; then
  echo "Leenky does not persist application data to remove."
fi

echo "Uninstalled Leenky"
