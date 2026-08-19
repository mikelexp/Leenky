#!/usr/bin/env python3
"""Print the project version declared in pyproject.toml."""

from __future__ import annotations

import re
from pathlib import Path


match = re.search(r'^version = "([^"]+)"$', Path("pyproject.toml").read_text(encoding="utf-8"), re.MULTILINE)
if match is None:
    raise SystemExit("Could not read version from pyproject.toml")
print(match.group(1))
