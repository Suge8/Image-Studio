#!/usr/bin/env bash
# Run unit tests.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "→ test (Debug)"
xcode_test
echo "✓ tests finished"
