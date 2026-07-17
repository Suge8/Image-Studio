#!/usr/bin/env bash
# Build Release app and zip to dist/Image-Studio-macOS.zip
# Usage: scripts/package.sh [--install]
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

CONFIGURATION=Release
export CONFIGURATION
DO_INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --install) DO_INSTALL=1 ;;
    -h|--help)
      echo "Usage: scripts/package.sh [--install]"
      echo "  Builds Release, signs ad-hoc, writes dist/$ZIP_NAME"
      echo "  --install  also copy to ~/Applications"
      exit 0
      ;;
  esac
done

echo "→ build Release"
xcode_build Release
sign_app "$APP_PATH"

mkdir -p "$DIST_DIR"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH"
# ditto preserves resource forks / quarantine-friendly zip for .app
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "✓ package: $ZIP_PATH"
echo "  app:     $APP_PATH"

if [[ "$DO_INSTALL" -eq 1 ]]; then
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALL_APP"
  cp -R "$APP_PATH" "$INSTALL_APP"
  sign_app "$INSTALL_APP"
  echo "✓ installed: $INSTALL_APP"
fi
