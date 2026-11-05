#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build-app.sh" "${1:-debug}"

shift || true
open "$ROOT/dist/Foundry.app" "$@"
