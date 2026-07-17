#!/usr/bin/env bash
# Build (if needed) and install to ~/Applications/Image Studio.app
# Usage: scripts/install.sh [--rebuild]
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

REBUILD=0
for arg in "$@"; do
  case "$arg" in
    --rebuild|-f) REBUILD=1 ;;
    -h|--help)
      echo "Usage: scripts/install.sh [--rebuild]"
      exit 0
      ;;
  esac
done

if [[ "$REBUILD" -eq 1 ]] || [[ ! -d "$APP_PATH" ]]; then
  echo "→ build $CONFIGURATION"
  xcode_build "$CONFIGURATION"
fi

ensure_app_built
sign_app "$APP_PATH"

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_APP"
cp -R "$APP_PATH" "$INSTALL_APP"
sign_app "$INSTALL_APP"

echo "✓ installed: $INSTALL_APP"
echo "  open: open \"$INSTALL_APP\""
