#!/usr/bin/env bash
# Cooperative live-debug session for RailGunner.
#
#   make coop          # preferred
#   tools/c64/coop.sh      # same
#
# 1. Build PRG + symbols (unless RAILGUNNER_SKIP_BUILD=1)
# 2. If control port is free: start windowed c64m with --control-port, --prg, --autorun
# 3. Run tools/c64/coop_debug_rg.py in the foreground (watcher owns the socket)
#
# You play; pause on a glitch → build/debug/snap-NNN.txt
# Agent steers: echo resume >> build/debug/coop_inbox
# Full protocol: agents/coop-debug.md
#
# Env:
#   C64M_PORT              default 6510
#   RAILGUNNER_SKIP_BUILD  1 = skip make prg (set by make coop after prg)

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RG_ROOT="$(cd "${TOOLS_DIR}/../.." && pwd)"
C64M_ROOT="${C64M_ROOT:-$(cd "${RG_ROOT}/../c64m" && pwd)}"
C64M_BIN="${TOOLS_DIR}/c64m"
C64M_INI="${C64M_INI:-${RG_ROOT}/c64m.ini}"
PRG="${RG_ROOT}/build/railgunner.prg"
PORT="${C64M_PORT:-6510}"
WATCHER="${TOOLS_DIR}/coop_debug_rg.py"

if [[ ! -x "${C64M_BIN}" && ! -L "${C64M_BIN}" ]]; then
  echo "error: missing tools/c64/c64m" >&2
  exit 1
fi
if [[ ! -f "${WATCHER}" ]]; then
  echo "error: missing ${WATCHER}" >&2
  exit 1
fi

port_open() {
  python3 -c "import socket,sys; s=socket.socket(); s.settimeout(0.25);\
import sys as S;\
r=s.connect_ex(('127.0.0.1', int(S.argv[1]))); s.close(); S.exit(0 if r==0 else 1)" "$1" 2>/dev/null
}

if [[ "${RAILGUNNER_SKIP_BUILD:-0}" != "1" ]]; then
  make -C "${RG_ROOT}" prg
fi

if [[ ! -f "${PRG}" ]]; then
  echo "error: missing ${PRG} (run: make prg)" >&2
  exit 1
fi

mkdir -p "${RG_ROOT}/build/debug"

STARTED_EMU=0
if port_open "${PORT}"; then
  echo "coop: control port ${PORT} already open — attaching watcher only"
  echo "      (another client must not hold the socket)"
else
  CMD=("${C64M_BIN}")
  if [[ -f "${C64M_INI}" ]]; then
    CMD+=(--inifile "${C64M_INI}")
  fi
  CMD+=(--control-port="${PORT}" --prg "${PRG}" --autorun)
  echo "coop: starting ${CMD[*]}"
  echo "      cwd=${C64M_ROOT}"
  (
    cd "${C64M_ROOT}"
    export RAILGUNNER_ROOT="${RG_ROOT}"
    exec "${CMD[@]}"
  ) &
  STARTED_EMU=1
  # Wait for control port
  for _ in $(seq 1 80); do
    if port_open "${PORT}"; then
      sleep 0.4
      break
    fi
    sleep 0.15
  done
  if ! port_open "${PORT}"; then
    echo "error: control port ${PORT} did not open" >&2
    exit 1
  fi
  echo "coop: emulator up on port ${PORT}"
fi

echo "coop: watcher → build/debug/snap-*.txt  inbox → build/debug/coop_inbox"
echo "coop: play, pause on glitch; Ctrl-C stops the watcher (emu keeps running if we started it)"
echo ""

export RAILGUNNER_ROOT="${RG_ROOT}"
cd "${RG_ROOT}"
exec python3 "${WATCHER}" --port "${PORT}" --out-dir "${RG_ROOT}/build/debug"
