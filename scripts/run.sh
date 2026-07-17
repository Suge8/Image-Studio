#!/usr/bin/env bash
# Open installed app, or build+install then open.
# Usage: scripts/run.sh [--rebuild]
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

if [[ "${1:-}" == "--rebuild" ]] || [[ ! -d "$INSTALL_APP" ]]; then
  "$(cd "$(dirname "$0")" && pwd)/install.sh" ${1:+"$1"}
fi

open "$INSTALL_APP"
