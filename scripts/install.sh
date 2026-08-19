#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID="leenky"
INSTALL_BIN="${HOME}/.local/bin"
INSTALL_LIB="${HOME}/.local/lib/${APP_ID}"
INSTALL_APPS="${HOME}/.local/share/applications"
INSTALL_ICONS="${HOME}/.local/share/icons/hicolor/512x512/apps"

DIST_DIR=""
for candidate in "${ROOT_DIR}"/dist/*.dist; do
  if [[ -f "${candidate}/leenky" ]]; then
    DIST_DIR="${candidate}"
    break
  fi
done

if [[ -n "${DIST_DIR}" ]]; then
  MODE="standalone"
elif [[ -f "${ROOT_DIR}/dist/leenky" ]]; then
  MODE="onefile"
else
  echo "Error: no Leenky build found. Run build-standalone or build-onefile first." >&2
  exit 1
fi

mkdir -p "${INSTALL_BIN}" "${INSTALL_APPS}" "${INSTALL_ICONS}"

if [[ "${MODE}" == "standalone" ]]; then
  rm -rf "${INSTALL_LIB}"
  cp -r "${DIST_DIR}" "${INSTALL_LIB}"
  chmod +x "${INSTALL_LIB}/leenky"
  ln -sfn "${INSTALL_LIB}/leenky" "${INSTALL_BIN}/leenky"
else
  install -Dm755 "${ROOT_DIR}/dist/leenky" "${INSTALL_BIN}/leenky"
fi

sed "s|^Exec=.*|Exec=${INSTALL_BIN}/leenky|" "${ROOT_DIR}/leenky.desktop" > "${INSTALL_APPS}/${APP_ID}.desktop"
install -Dm644 "${ROOT_DIR}/icon.png" "${INSTALL_ICONS}/${APP_ID}.png"

if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "${INSTALL_APPS}"
fi
if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor"
fi

echo "Installed Leenky (${MODE}) at ${INSTALL_BIN}/leenky"
