#!/usr/bin/env bash
# Shared paths and xcodebuild defaults for Image Studio.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="ImageStudio.xcodeproj"
SCHEME="ImageStudio"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-platform=macOS}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT/build}"
PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION"
APP_NAME="ImageStudio.app"
APP_PATH="$PRODUCTS_DIR/$APP_NAME"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
INSTALL_APP="$INSTALL_DIR/Image Studio.app"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
ZIP_NAME="${ZIP_NAME:-Image-Studio-macOS.zip}"

require_xcodebuild() {
  if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "error: xcodebuild not found. Install Xcode or Command Line Tools." >&2
    exit 1
  fi
}

xcode_build() {
  require_xcodebuild
  local config="${1:-$CONFIGURATION}"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$config" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
}

xcode_test() {
  require_xcodebuild
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    test
}

sign_app() {
  local app="$1"
  # Local ad-hoc signature (daily use). Not for notarized distribution.
  codesign --force --deep --sign - "$app"
}

ensure_app_built() {
  if [[ ! -d "$APP_PATH" ]]; then
    echo "→ building $CONFIGURATION …"
    xcode_build "$CONFIGURATION"
  fi
  if [[ ! -d "$APP_PATH" ]]; then
    echo "error: app not found at $APP_PATH" >&2
    exit 1
  fi
}
