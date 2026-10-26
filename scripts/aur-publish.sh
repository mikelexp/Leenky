#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="$(sed -n 's/^version: \([0-9.]\+\)\+.*/\1/p' "${ROOT_DIR}/pubspec.yaml")"
REPO_NAME="leenky-bin"
AUR_SSH="ssh://aur@aur.archlinux.org/${REPO_NAME}.git"
ARCHIVE="leenky-${APP_VERSION}-linux-x86_64.tar.gz"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/aur-publish-XXXXX")"

cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

echo "Publishing ${REPO_NAME} ${APP_VERSION} to AUR..."
gh release download "v${APP_VERSION}" --repo mikelexp/Leenky --pattern "${ARCHIVE}" --clobber --dir "${WORK_DIR}"
HASH="$(sha256sum "${WORK_DIR}/${ARCHIVE}" | cut -d' ' -f1)"
git clone "${AUR_SSH}" "${WORK_DIR}"
cp "${ROOT_DIR}/PKGBUILD" "${WORK_DIR}/"

cd "${WORK_DIR}"
sed -i "s/^pkgver=.*/pkgver=${APP_VERSION}/" PKGBUILD
sed -i "s/^pkgrel=.*/pkgrel=1/" PKGBUILD
sed -i "s/^sha256sums=('[^']*')/sha256sums=('${HASH}')/" PKGBUILD
makepkg --printsrcinfo > .SRCINFO
git add PKGBUILD .SRCINFO
git commit -m "bump to v${APP_VERSION}"
git push origin master
