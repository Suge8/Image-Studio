#!/usr/bin/env bash
# Build Image Studio (default: Release).
# Usage: scripts/build.sh [Debug|Release]
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

CONFIGURATION="${1:-$CONFIGURATION}"
export CONFIGURATION
echo "→ build $CONFIGURATION → $DERIVED_DATA_PATH"
xcode_build "$CONFIGURATION"
echo "✓ $APP_PATH"
