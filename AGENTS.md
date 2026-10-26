# Repository notes

- Linux Flutter desktop app; use FVM. `./run.sh` runs it, `fvm flutter test test/url_tools_test.dart` runs the focused test, and `fvm flutter analyze` checks Dart. Format with `fvm dart format lib test`.
- For a build without desktop-registration side effects, use `fvm flutter build linux --release`. `./build.sh` also installs/overwrites this user's `leenky.desktop` and icon under `${XDG_DATA_HOME:-~/.local/share}`.
- `lib/main.dart` wires the UI, clipboard and theme; URL extraction is in `lib/url_tools.dart`; XDG file chooser dialogs are in `lib/portal_file_chooser.dart`. Dialogs require the desktop's XDG portal and intentionally have no GTK fallback.
- Clipboard updates on KDE Plasma Wayland use Klipper over D-Bus when available; other sessions use Flutter's clipboard API. Desktop-session behavior is not covered by automated tests.
- Native window integration lives in `linux/runner/my_application.cc`; `flutter analyze` does not validate native runner code, so verify those edits with `fvm flutter build linux --release`. Keep `APPLICATION_ID` in `linux/CMakeLists.txt` a valid reverse-DNS ID and the Wayland app ID `leenky` aligned with `leenky.desktop` and the installed icon. Window size minimum/default is 600x400.
- Version for GitHub tags is `pubspec.yaml`; keep `PKGBUILD`'s `pkgver` aligned. `.github/workflows/release.yml` handles `v*` tags and manual runs; `scripts/aur-publish.sh` downloads the matching GitHub release and pushes `leenky-bin` to AUR, so running it publishes externally.
