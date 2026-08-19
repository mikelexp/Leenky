#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${ROOT_DIR}/.venv/bin/python" -m nuitka \
  --enable-plugin=pyside6 \
  --mode=onefile \
  --include-data-files="${ROOT_DIR}/icon.png=icon.png" \
  --output-dir="${ROOT_DIR}/dist" \
  --output-filename=leenky \
  "${ROOT_DIR}/app.py"
