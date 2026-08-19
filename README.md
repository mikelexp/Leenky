# Leenky

Leenky is a lightweight Linux desktop application that collects URLs copied to
your clipboard. Keep collecting while you browse, review the list in one place,
then save it as a text file or append it to an existing one.

## Features

- Collects absolute URLs from copied text and URL clipboard data.
- Keeps URLs in their original order and can discard duplicates automatically.
- Clears the clipboard only after recognizing at least one URL.
- Lets you save the current list or append it to a text file while preserving
  the first occurrence of each URL.
- Uses the desktop clipboard integration on Linux.
- On KDE Plasma Wayland, integrates with Klipper so it can receive clipboard
  updates while its window is unfocused.

## Requirements

- Linux
- Python 3.10 or newer
- `PySide6==6.11.1` (installed from `requirements.txt`)

## Run From Source

```bash
git clone https://github.com/mikelexp/Leenky.git
cd Leenky
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python app.py
```

Alternatively, use the included task runners. `just run` and `make run` create
the virtual environment and install the build dependencies when needed.

```bash
just run
# or
make run
```

## Clipboard Behavior

Leenky recognizes URLs in copied text and in clipboard URL data. Once one or
more URLs are collected, it clears that clipboard entry to avoid collecting it
again. Content copied from Leenky itself is excluded from collection.

Wayland compositors can restrict clipboard access for unfocused applications.
On KDE Plasma Wayland, Leenky uses the running Klipper D-Bus service when it
is available. On other desktop environments it falls back to Qt's standard
clipboard API.

## Testing

Run the test suite headlessly:

```bash
QT_QPA_PLATFORM=offscreen .venv/bin/python -m unittest discover -s tests
```

## Build And Install

Install the build dependencies and create a distributable binary with Nuitka:

```bash
just install-deps
just build-onefile
# or: just build-standalone
```

The same commands are available through Make:

```bash
make install-deps
make build-onefile
# or: make build-standalone
```

Install a locally built version for the current user:

```bash
just install
# or
make install
```

This installs the executable under `~/.local/bin`, the desktop entry under
`~/.local/share/applications`, and the icon in the local hicolor icon theme.
Use `just uninstall` or `make uninstall` to remove it.

## Releases And AUR

Pushing a tag named `vX.Y.Z` triggers the GitHub Actions release workflow. The
tag must match the version in `pyproject.toml`. The workflow publishes a Linux
x86_64 tarball containing the binary, desktop entry, and icon.

The AUR package source is provided as `PKGBUILD` for `leenky-bin`. After a
GitHub release is available and AUR SSH access is configured, publish it with:

```bash
just aur-publish
# or
make aur-publish
```

`aur-update` is an alias for the same command.

## AI Disclaimer

This application was created with the assistance of AI. I personally reviewed,
validated, and tested the resulting code and behavior.
