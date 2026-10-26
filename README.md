# Leenky

Leenky collects URLs copied to the Linux desktop clipboard. Review and edit the
collected list, then save it or append it to an existing text file.

## Features

- Finds absolute URLs in clipboard text and collects them in source order.
- Optionally discards duplicates and clears the clipboard only after finding URLs.
- Provides editable list, Save as, Append to, and Clear actions.
- On KDE Plasma Wayland, subscribes to Klipper clipboard updates over D-Bus when
  the service is available. Other sessions use Flutter's standard clipboard API.
- Follows the desktop light/dark preference via the freedesktop Settings portal
  (GNOME, Plasma, and compatible desktops), updating immediately when it changes.
  If the portal setting is unavailable, it falls back to Flutter's system theme.
- Uses the freedesktop FileChooser portal for save/open dialogs so the desktop
  provides its native chooser (for example, KDE's dialog on Plasma). It does not
  fall back to GTK dialogs if the portal is unavailable.

## Requirements and run

Install Flutter with Linux desktop support and the Linux build prerequisites.
Then from this directory:

```sh
fvm flutter pub get
fvm flutter run -d linux
```

The app polls the regular clipboard while running. Some Wayland compositors only
allow clipboard reads while the app is focused; KDE Plasma can use Klipper to
receive updates while unfocused. Clipboard URL MIME formats not represented as
plain text are not currently read by the Flutter clipboard API.

## Test and build

```sh
fvm flutter test
fvm flutter analyze
fvm flutter build linux --release
```

The release bundle is created under `build/linux/x64/release/bundle/`.
`./compile.sh` also registers `leenky.desktop` and the icon in the current user's
data directory so Wayland compositors can resolve the same app ID as the Python
version.

Install the release system-wide after compiling:

```sh
./install.sh
```

This installs the complete Flutter bundle under `/usr/lib/leenky`, exposes it as
`/usr/bin/leenky`, and installs a system desktop entry using `Exec=leenky`.

## Releases and AUR

Push a `vX.Y.Z` tag matching the version in `pubspec.yaml` to run GitHub Actions.
The workflow tests and analyzes the app, builds its Linux release bundle, and
publishes `leenky-X.Y.Z-linux-x86_64.tar.gz` to a GitHub release.

The existing AUR package remains `leenky-bin`. After the matching GitHub release
is available and AUR SSH access is configured, update it with:

```sh
bash scripts/aur-publish.sh
```
