python := '.venv/bin/python'
scripts := 'scripts'

default:
    @just --list

version:
    @python3 {{ scripts }}/version.py

set-version VERSION:
    @python3 {{ scripts }}/set-version.py "{{ VERSION }}"

run: _ensure-python
    {{ python }} app.py

install-deps:
    bash {{ scripts }}/install-build-deps.sh

install-build-deps:
    bash {{ scripts }}/install-build-deps.sh

build-standalone: _ensure-python
    bash {{ scripts }}/build-standalone.sh

build-onefile: _ensure-python
    bash {{ scripts }}/build-onefile.sh

aur-publish:
    bash {{ scripts }}/aur-publish.sh

aur-update:
    bash {{ scripts }}/aur-publish.sh

clean:
    rm -rf .venv build dist

clean-build:
    bash {{ scripts }}/clean-build.sh

install:
    bash {{ scripts }}/install.sh

uninstall:
    bash {{ scripts }}/uninstall.sh

uninstall-purge:
    bash {{ scripts }}/uninstall.sh --purge

_ensure-python:
    @if [ ! -f '{{ python }}' ]; then just install-build-deps; fi
