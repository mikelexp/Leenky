PYTHON := .venv/bin/python
SCRIPTS := scripts

.PHONY: help run version set-version install-deps install-build-deps build-standalone build-onefile aur-publish aur-update clean clean-build install uninstall uninstall-purge

help:
	@echo "Targets:"
	@echo "  run              Run Leenky"
	@echo "  version          Print the current app version"
	@echo "  set-version      Set project and PKGBUILD version (use VERSION=x.y.z)"
	@echo "  install-deps     Create venv and install build dependencies"
	@echo "  build-standalone Build a standalone Linux distribution"
	@echo "  build-onefile    Build the Linux onefile binary"
	@echo "  aur-publish      Publish the current GitHub release to AUR"
	@echo "  aur-update       Alias for aur-publish"
	@echo "  clean            Remove venv and build artifacts"
	@echo "  clean-build      Remove build artifacts only"
	@echo "  install          Install a built Leenky version for this user"
	@echo "  uninstall        Remove the installed Leenky version"
	@echo "  uninstall-purge  Remove the installed Leenky version and app data"

run: $(PYTHON)
	$(PYTHON) app.py

version:
	@python3 $(SCRIPTS)/version.py

set-version:
	@test -n "$(VERSION)" || (echo "Usage: make set-version VERSION=x.y.z"; exit 1)
	@python3 $(SCRIPTS)/set-version.py "$(VERSION)"

install-deps:
	@bash $(SCRIPTS)/install-build-deps.sh

install-build-deps: install-deps

build-standalone: $(PYTHON)
	@bash $(SCRIPTS)/build-standalone.sh

build-onefile: $(PYTHON)
	@bash $(SCRIPTS)/build-onefile.sh

aur-publish:
	@bash $(SCRIPTS)/aur-publish.sh

aur-update: aur-publish

clean:
	rm -rf .venv build dist

clean-build:
	@bash $(SCRIPTS)/clean-build.sh

install:
	@bash $(SCRIPTS)/install.sh

uninstall:
	@bash $(SCRIPTS)/uninstall.sh

uninstall-purge:
	@bash $(SCRIPTS)/uninstall.sh --purge

$(PYTHON):
	$(MAKE) install-deps
