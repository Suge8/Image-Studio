# Image Studio — thin wrappers over scripts/
# make build | test | install | package | run | clean

.PHONY: build test install package run clean help

help:
	@echo "Targets:"
	@echo "  make build     Release build → build/"
	@echo "  make test      Unit tests"
	@echo "  make install   Install to ~/Applications/Image Studio.app"
	@echo "  make package   Release zip → dist/Image-Studio-macOS.zip"
	@echo "  make run       Open installed app (install if missing)"
	@echo "  make clean     Remove build/ and dist/"

build:
	@scripts/build.sh Release

test:
	@scripts/test.sh

install:
	@scripts/install.sh --rebuild

package:
	@scripts/package.sh

run:
	@scripts/run.sh

clean:
	rm -rf build dist
