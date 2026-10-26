# Repository notes

- This is a Linux Flutter desktop app. Use FVM: `./run.sh` runs it; `fvm flutter test test/url_tools_test.dart` runs the focused test; `fvm flutter analyze` and `fvm dart format lib test` check Dart; `fvm flutter build linux --release` builds without installing desktop files.
- `./compile.sh` builds and also installs/overwrites the current user's `leenky.desktop` and `leenky.png` under `${XDG_DATA_HOME:-~/.local/share}`. Use the direct Flutter build command when only a build is wanted.
- Dart UI and clipboard/theme wiring are in `lib/main.dart`; URL extraction is in `lib/url_tools.dart`; XDG file dialogs are implemented over D-Bus in `lib/portal_file_chooser.dart`. File dialogs require the desktop's XDG portal and intentionally have no GTK fallback.
- Linux window behavior lives in `linux/runner/my_application.cc`. `flutter analyze` excludes `linux/**`, so verify native runner edits with `fvm flutter build linux --release` (or `./compile.sh` if desktop registration is intended). Default and minimum window size are both 600x400.
- Keep `APPLICATION_ID` in `linux/CMakeLists.txt` as a valid reverse-DNS GApplication ID. The Wayland window separately announces app ID `leenky`; keep that aligned with `leenky.desktop` and the installed `leenky.png` so Wayland can resolve the icon.
- Automated tests currently cover URL extraction only. Portal dialogs, desktop theme detection, Klipper, and window decorations require manual desktop-session checks.
