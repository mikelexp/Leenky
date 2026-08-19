# Links Collector

Linux desktop application that collects URLs copied to the clipboard.

On Plasma Wayland, Links Collector uses the running Klipper service to detect
clipboard changes while the window is unfocused. Other desktops use Qt's
standard clipboard integration, which Wayland compositors may limit when the
application is in the background.

## Run

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -e .
.venv/bin/python app.py
```

## Test

```bash
.venv/bin/python -m unittest discover -s tests
```
