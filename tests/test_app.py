import os
import tempfile
import unittest
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtWidgets import QApplication

from app import LeenkyWindow, extract_urls


class ExtractUrlsTests(unittest.TestCase):
    def test_extracts_multiple_urls_from_mixed_text(self) -> None:
        text = "Open https://example.com/a, then file:///tmp/report.txt and custom:item."
        self.assertEqual(
            extract_urls(text),
            ["https://example.com/a", "file:///tmp/report.txt", "custom:item"],
        )

    def test_ignores_plain_text(self) -> None:
        self.assertEqual(extract_urls("Nothing to collect here."), [])


class WindowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def setUp(self) -> None:
        self.window = LeenkyWindow()
        self.window.clipboard.clear()

    def tearDown(self) -> None:
        self.window.close()

    def test_window_uses_leenky_name(self) -> None:
        self.assertEqual(self.window.windowTitle(), "Leenky")
        self.assertFalse(self.window.windowIcon().isNull())

    def test_discards_existing_duplicates_by_default(self) -> None:
        self.window.links_text.setPlainText("https://example.com")
        self.window._append_urls(["https://example.com", "https://qt.io"])
        self.assertEqual(
            self.window.links_text.toPlainText(), "https://example.com\nhttps://qt.io"
        )

    def test_keeps_duplicates_when_disabled(self) -> None:
        self.window.discard_duplicates.setChecked(False)
        self.window.links_text.setPlainText("https://example.com")
        self.window._append_urls(["https://example.com"])
        self.assertEqual(self.window.links_text.toPlainText(), "https://example.com\nhttps://example.com")

    def test_clipboard_urls_are_collected_and_then_cleared(self) -> None:
        self.window.clipboard.setText("Read https://example.com, then custom:item.")
        self.app.processEvents()
        self.assertEqual(
            self.window.links_text.toPlainText(), "https://example.com\ncustom:item"
        )
        self.assertEqual(self.window.clipboard.text(), "")

    def test_klipper_text_is_collected_and_cleared(self) -> None:
        clear_calls = []
        self.window._process_text("Read https://example.com", lambda: clear_calls.append(True))
        self.assertEqual(self.window.links_text.toPlainText(), "https://example.com")
        self.assertEqual(clear_calls, [True])

    def test_own_text_copy_is_not_collected(self) -> None:
        self.window._remember_own_copy("https://example.com")
        clear_calls = []
        self.window._process_text("https://example.com", lambda: clear_calls.append(True))
        self.assertEqual(self.window.links_text.toPlainText(), "")
        self.assertEqual(clear_calls, [])

    def test_save_as_adds_txt_extension(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "collected"
            self.window.links_text.setPlainText("https://example.com")
            original = __import__("app").QFileDialog.getSaveFileName
            __import__("app").QFileDialog.getSaveFileName = lambda *args: (str(target), "")
            try:
                self.window.save_as()
            finally:
                __import__("app").QFileDialog.getSaveFileName = original
            self.assertEqual((target.with_suffix(".txt")).read_text(encoding="utf-8"), "https://example.com")

    def test_append_to_preserves_existing_contents(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "collected.txt"
            target.write_text("https://first.example\nhttps://first.example", encoding="utf-8")
            self.window.links_text.setPlainText(
                "https://first.example\nhttps://second.example\nhttps://second.example"
            )
            original = __import__("app").QFileDialog.getOpenFileName
            __import__("app").QFileDialog.getOpenFileName = lambda *args: (str(target), "")
            try:
                self.window.append_to()
            finally:
                __import__("app").QFileDialog.getOpenFileName = original
            self.assertEqual(
                target.read_text(encoding="utf-8"),
                "https://first.example\nhttps://second.example",
            )
