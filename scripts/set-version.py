#!/usr/bin/env python3
"""Set the project and AUR package version together."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def replace(path: Path, pattern: str, replacement: str) -> None:
    text = path.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, text, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"Expected one version in {path}")
    path.write_text(updated, encoding="utf-8")


if len(sys.argv) != 2 or not re.fullmatch(r"\d+\.\d+\.\d+(?:[A-Za-z0-9.+-]*)?", sys.argv[1]):
    raise SystemExit("Usage: scripts/set-version.py VERSION (for example 1.2.3)")

version = sys.argv[1]
replace(Path("pyproject.toml"), r'^version = "[^"]+"$', f'version = "{version}"')
replace(Path("PKGBUILD"), r"^pkgver=.*$", f"pkgver={version}")
replace(Path("PKGBUILD"), r"^pkgrel=.*$", "pkgrel=1")
