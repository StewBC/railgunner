#!/usr/bin/env bash
# Launch c64m with ROMs resolved correctly.
#
# c64m looks for roms/ relative to its process cwd. This wrapper always starts
# with cwd = the sibling ../c64m repo, while keeping a stable path from RailGunner.
#
# Usage (from anywhere):
#   tools/run-emulator.sh [c64m args...]
#
# Common agent launches:
#   tools/run-emulator.sh --headless --control-port 6510
#   tools/run-emulator.sh --control-port 6510          # windowed + remote API
#
# Environment:
#   C64M_PORT   default control port if you also pass nothing (not auto-added)
#   C64M_ROOT   override path to the c64m repo (default: <railgunner>/../c64m)

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAILGUNNER_ROOT="$(cd "${TOOLS_DIR}/.." && pwd)"
C64M_ROOT="${C64M_ROOT:-$(cd "${RAILGUNNER_ROOT}/../c64m" && pwd)}"
C64M_BIN="${TOOLS_DIR}/c64m"

if [[ ! -x "${C64M_BIN}" && ! -L "${C64M_BIN}" ]]; then
  echo "error: missing tools/c64m symlink (expected -> ../../c64m/build/c64m)" >&2
  exit 1
fi
if [[ ! -d "${C64M_ROOT}/roms" ]]; then
  echo "error: no roms/ under C64M_ROOT=${C64M_ROOT}" >&2
  exit 1
fi

export RAILGUNNER_ROOT
cd "${C64M_ROOT}"
exec "${C64M_BIN}" "$@"
