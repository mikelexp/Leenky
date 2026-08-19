"""Leenky desktop application."""

from __future__ import annotations

import logging
import os
import re
import subprocess
import sys
from collections.abc import Callable
from pathlib import Path

from PySide6.QtCore import QLibraryInfo, QSettings, QTimer, QUrl, SLOT, Signal, Slot, qVersion
from PySide6.QtDBus import QDBusConnection, QDBusInterface
from PySide6.QtGui import QClipboard, QColor, QGuiApplication, QIcon, QPalette
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QFileDialog,
    QHBoxLayout,
    QMainWindow,
    QPlainTextEdit,
    QPushButton,
    QStyleFactory,
    QVBoxLayout,
    QWidget,
)


APP_NAME = "Leenky"
ICON_PATH = Path(__file__).with_name("icon.png")
KLIPPER_SERVICE = "org.kde.klipper"
KLIPPER_PATH = "/klipper"
KLIPPER_INTERFACE = "org.kde.klipper.klipper"
URL_PATTERN = re.compile(
    r"(?<![\w@])([A-Za-z][A-Za-z0-9+.-]*:(?://)?[^\s<>'\"`]+)"
)
SYSTEM_PLUGIN_PATHS = (
    Path("/usr/lib/qt6/plugins"),
    Path("/usr/lib64/qt6/plugins"),
    Path("/usr/lib/x86_64-linux-gnu/qt6/plugins"),
)


def _system_qt_version() -> str:
    for command in (("qtpaths6", "--qt-version"), ("qmake6", "-query", "QT_VERSION")):
        try:
            result = subprocess.run(
                command, capture_output=True, check=True, text=True, timeout=2
            )
        except (FileNotFoundError, subprocess.SubprocessError):
            continue
        version = result.stdout.strip()
        if version:
            return version
    return ""


def _is_plasma_session() -> bool:
    desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").lower()
    return "kde" in desktop or "plasma" in desktop


def _system_kde_plugin_path() -> Path | None:
    """Return a compatible KDE plugin directory, without replacing PySide plugins."""
    if _system_qt_version() != qVersion():
        return None

    for plugin_path in SYSTEM_PLUGIN_PATHS:
        themes = plugin_path / "platformthemes"
        if themes.is_dir() and any("kde" in item.name.lower() for item in themes.iterdir()):
            return plugin_path
    return None


def _kde_widget_style() -> str:
    settings_path = Path.home() / ".config" / "kdeglobals"
    if settings_path.is_file():
        style = QSettings(str(settings_path), QSettings.Format.IniFormat).value(
            "KDE/widgetStyle", "", type=str
        ).strip()
        if style:
            return style

    try:
        result = subprocess.run(
            ("kreadconfig6", "--file", "kdeglobals", "--group", "KDE", "--key", "widgetStyle"),
            capture_output=True,
            check=True,
            text=True,
            timeout=2,
        )
    except (FileNotFoundError, subprocess.SubprocessError):
        return ""
    return result.stdout.strip()


def _has_style_plugin(plugin_path: Path, style: str) -> bool:
    styles_path = plugin_path / "styles"
    style_name = style.lower()
    return styles_path.is_dir() and any(
        style_name in item.name.lower() for item in styles_path.iterdir()
    )


def configure_qt_theme() -> str:
    """Prepare desktop integration before QApplication exists."""
    bundled_plugins = str(QLibraryInfo.path(QLibraryInfo.LibraryPath.PluginsPath))
    plugin_path_is_user_override = "QT_PLUGIN_PATH" in os.environ
    user_plugin_path = os.environ.get("QT_PLUGIN_PATH", "")

    if not plugin_path_is_user_override or user_plugin_path:
        plugin_paths = [bundled_plugins]
        if user_plugin_path:
            plugin_paths.extend(path for path in user_plugin_path.split(os.pathsep) if path)
        os.environ["QT_PLUGIN_PATH"] = os.pathsep.join(dict.fromkeys(plugin_paths))

    if not _is_plasma_session():
        return "user override" if "QT_QPA_PLATFORMTHEME" in os.environ else "default"

    # An explicitly empty plugin path is a user choice; do not make KDE loading fail.
    if plugin_path_is_user_override and not user_plugin_path:
        return "user override" if "QT_QPA_PLATFORMTHEME" in os.environ else "default"

    kde_plugin_path = _system_kde_plugin_path()
    if kde_plugin_path is None:
        return "user override" if "QT_QPA_PLATFORMTHEME" in os.environ else "default"

    if not plugin_path_is_user_override or user_plugin_path:
        plugin_paths = os.environ["QT_PLUGIN_PATH"].split(os.pathsep)
        if str(kde_plugin_path) not in plugin_paths:
            os.environ["QT_PLUGIN_PATH"] += os.pathsep + str(kde_plugin_path)
    if "QT_QPA_PLATFORMTHEME" not in os.environ:
        os.environ["QT_QPA_PLATFORMTHEME"] = "kde"

    if "QT_STYLE_OVERRIDE" not in os.environ:
        style = _kde_widget_style()
        if style and _has_style_plugin(kde_plugin_path, style):
            os.environ["QT_STYLE_OVERRIDE"] = style
            return f"kde/{style}"
    return "kde"


def ensure_placeholder_text_contrast(app: QApplication) -> None:
    """Repair only a desktop placeholder role that has insufficient contrast."""
    palette = app.palette()
    base = palette.color(QPalette.ColorRole.Base)
    placeholder = palette.color(QPalette.ColorRole.PlaceholderText)
    if placeholder.isValid() and placeholder.alpha() > 0 and _contrast_ratio(base, placeholder) >= 3.0:
        return
    palette.setColor(
        QPalette.ColorRole.PlaceholderText,
        palette.color(QPalette.ColorRole.Mid),
    )
    app.setPalette(palette)


def _contrast_ratio(first: QColor, second: QColor) -> float:
    def luminance(color: QColor) -> float:
        channels = []
        for channel in (color.red(), color.green(), color.blue()):
            value = channel / 255
            channels.append(value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4)
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]

    lighter = max(luminance(first), luminance(second))
    darker = min(luminance(first), luminance(second))
    return (lighter + 0.05) / (darker + 0.05)


def verify_qt_theme(app: QApplication, theme_mode: str) -> str:
    """Confirm a requested Plasma widget style loaded, without overriding the user."""
    if not theme_mode.startswith("kde/"):
        return app.style().objectName()

    expected_style = theme_mode.partition("/")[2]
    active_style = app.style().objectName().lower()
    if active_style not in {"fusion", "windows"}:
        return active_style

    available_styles = {style.lower() for style in QStyleFactory.keys()}
    if expected_style.lower() in available_styles and QStyleFactory.create(expected_style):
        app.setStyle(expected_style)
    return app.style().objectName()


def _strip_trailing_punctuation(value: str) -> str:
    while value and value[-1] in ".,;:!?":
        value = value[:-1]
    while value.endswith(")") and value.count("(") < value.count(")"):
        value = value[:-1]
    while value.endswith("]") and value.count("[") < value.count("]"):
        value = value[:-1]
    while value.endswith("}") and value.count("{") < value.count("}"):
        value = value[:-1]
    return value


def extract_urls(text: str) -> list[str]:
    """Extract valid absolute URLs from arbitrary clipboard text in source order."""
    urls: list[str] = []
    for match in URL_PATTERN.finditer(text):
        value = _strip_trailing_punctuation(match.group(1))
        url = QUrl(value)
        if value and url.isValid() and not url.isRelative() and url.scheme():
            if value not in urls:
                urls.append(value)
    return urls


class LeenkyTextEdit(QPlainTextEdit):
    copied = Signal(str)

    def copy(self) -> None:
        text = self.textCursor().selectedText().replace("\u2029", "\n")
        if text:
            self.copied.emit(text)
        super().copy()


class LeenkyWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle(APP_NAME)
        self.setWindowIcon(QIcon(str(ICON_PATH)))
        self.resize(620, 420)
        self._processing_clipboard = False
        self._own_clipboard_text = ""
        self._klipper: QDBusInterface | None = None
        self._klipper_bus: QDBusConnection | None = None

        self.links_text = LeenkyTextEdit()
        self.links_text.setPlaceholderText("Collected links appear here. You can also type links manually.")
        self.links_text.copied.connect(self._remember_own_copy)

        self.discard_duplicates = QCheckBox("Discard duplicates")
        self.discard_duplicates.setChecked(True)
        clear_button = QPushButton("Clear")
        clear_button.clicked.connect(self.links_text.clear)
        save_button = QPushButton("Save As")
        save_button.clicked.connect(self.save_as)
        append_button = QPushButton("Append to")
        append_button.clicked.connect(self.append_to)

        options = QHBoxLayout()
        options.addWidget(self.discard_duplicates)
        options.addStretch()
        options.addWidget(clear_button)
        options.addWidget(save_button)
        options.addWidget(append_button)

        layout = QVBoxLayout()
        layout.addWidget(self.links_text)
        layout.addLayout(options)
        container = QWidget()
        container.setLayout(layout)
        self.setCentralWidget(container)

        self.clipboard = QGuiApplication.clipboard()
        self.clipboard.dataChanged.connect(self.process_clipboard)
        self._connect_klipper()

    def _remember_own_copy(self, text: str) -> None:
        self._own_clipboard_text = text
        QTimer.singleShot(2_000, lambda: self._forget_own_copy(text))

    def _forget_own_copy(self, text: str) -> None:
        if self._own_clipboard_text == text:
            self._own_clipboard_text = ""

    def _is_own_copy(self, text: str) -> bool:
        return bool(self._own_clipboard_text) and text == self._own_clipboard_text

    def _connect_klipper(self) -> None:
        """Use Plasma's privileged clipboard manager when Wayland restricts QClipboard."""
        if not _is_plasma_session() or not QGuiApplication.platformName().startswith("wayland"):
            return

        bus = QDBusConnection.sessionBus()
        if not bus.isConnected():
            return
        klipper = QDBusInterface(KLIPPER_SERVICE, KLIPPER_PATH, KLIPPER_INTERFACE, bus)
        if not klipper.isValid():
            return
        if not bus.connect(
            KLIPPER_SERVICE,
            KLIPPER_PATH,
            KLIPPER_INTERFACE,
            "clipboardHistoryUpdated",
            self,
            SLOT("process_klipper_clipboard()"),
        ):
            logging.warning("Could not subscribe to Klipper clipboard updates")
            return
        self._klipper = klipper
        self._klipper_bus = bus

    def _existing_links(self) -> set[str]:
        return {line.strip() for line in self.links_text.toPlainText().splitlines() if line.strip()}

    def _append_urls(self, urls: list[str]) -> None:
        if self.discard_duplicates.isChecked():
            existing = self._existing_links()
            urls = [url for url in urls if url not in existing]
        if not urls:
            return

        current = self.links_text.toPlainText().rstrip()
        self.links_text.setPlainText("\n".join(filter(None, (current, *urls))))

    def _process_text(self, text: str, clear_clipboard: Callable[[], object]) -> None:
        if self._is_own_copy(text):
            return
        urls = extract_urls(text)
        if not urls:
            return
        self._append_urls(urls)
        self._processing_clipboard = True
        try:
            clear_clipboard()
        finally:
            self._processing_clipboard = False

    def process_clipboard(self) -> None:
        if self._processing_clipboard:
            return

        mime_data = self.clipboard.mimeData(QClipboard.Mode.Clipboard)
        if mime_data is None:
            return
        text = mime_data.text() if mime_data.hasText() else ""
        if self._is_own_copy(text):
            return
        urls = [url.toString() for url in mime_data.urls() if url.isValid() and url.scheme()]
        urls.extend(extract_urls(text))
        urls = list(dict.fromkeys(urls))
        if not urls:
            return

        self._append_urls(urls)
        self._processing_clipboard = True
        try:
            self.clipboard.clear(QClipboard.Mode.Clipboard)
        finally:
            self._processing_clipboard = False

    @Slot()
    def process_klipper_clipboard(self) -> None:
        if self._processing_clipboard or self._klipper is None:
            return
        reply = self._klipper.call("getClipboardContents")
        arguments = reply.arguments()
        if not arguments or not isinstance(arguments[0], str):
            return
        self._process_text(
            arguments[0], lambda: self._klipper.call("clearClipboardContents")
        )

    def save_as(self) -> None:
        file_name, _ = QFileDialog.getSaveFileName(
            self, "Save Links", "links.txt", "Text Files (*.txt)"
        )
        if not file_name:
            return
        if not file_name.lower().endswith(".txt"):
            file_name += ".txt"
        Path(file_name).write_text(self.links_text.toPlainText(), encoding="utf-8")

    def append_to(self) -> None:
        file_name, _ = QFileDialog.getOpenFileName(self, "Append Links", "", "Text Files (*.txt)")
        if not file_name:
            return
        content = self.links_text.toPlainText()
        if not content:
            return

        path = Path(file_name)
        lines = path.read_text(encoding="utf-8").splitlines() + content.splitlines()
        unique_lines = []
        seen_urls = set()
        for line in lines:
            value = line.strip()
            if extract_urls(value) == [value]:
                if value in seen_urls:
                    continue
                seen_urls.add(value)
            unique_lines.append(line)
        path.write_text("\n".join(unique_lines), encoding="utf-8")


def main() -> int:
    theme_mode = configure_qt_theme()
    QApplication.setApplicationName(APP_NAME)
    app = QApplication(sys.argv)
    app.setWindowIcon(QIcon(str(ICON_PATH)))
    ensure_placeholder_text_contrast(app)
    active_style = verify_qt_theme(app, theme_mode)
    if theme_mode.startswith("kde") and active_style.lower() in {"fusion", "windows"}:
        logging.warning("Plasma integration requested (%s), active Qt style is %s", theme_mode, active_style)
    window = LeenkyWindow()
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
