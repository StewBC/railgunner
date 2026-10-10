#!/usr/bin/env bash
# USER path: ensure PRG is up to date, start windowed c64m with --prg --autorun.
#
# Prefer the root Makefile for the full graph:
#   make play
#
# Direct use still rebuilds via `make prg` (assets + assemble) unless
# RAILGUNNER_SKIP_BUILD=1 (set by `make play` so the PRG is not assembled twice).
#
# No remote API required. The emulator window is yours to play/test.
# Quit the emulator window when done.
#
# Never --headless (see agents/README.md).

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RG_ROOT="$(cd "${TOOLS_DIR}/../.." && pwd)"
C64M_ROOT="${C64M_ROOT:-$(cd "${RG_ROOT}/../c64m" && pwd)}"
C64M_BIN="${TOOLS_DIR}/c64m"
C64M_INI="${C64M_INI:-${RG_ROOT}/c64m.ini}"
PRG="${RG_ROOT}/build/railgunner.prg"

if [[ ! -x "${C64M_BIN}" && ! -L "${C64M_BIN}" ]]; then
  echo "error: missing tools/c64/c64m" >&2
  exit 1
fi

# C64 PRG must start with load address $0801 (bytes 01 08). A raw c64masm
# image written to .prg looks "up to date" to Make but --autorun/RUN fails.
prg_has_load_header() {
  [[ -f "${PRG}" ]] || return 1
  python3 -c "import sys; d=open(sys.argv[1],'rb').read(2); sys.exit(0 if d==b'\\x01\\x08' else 1)" "${PRG}"
}

if [[ "${RAILGUNNER_SKIP_BUILD:-0}" != "1" ]]; then
  # Rebuild assets + PRG when sources changed (same graph as `make prg`).
  make -C "${RG_ROOT}" prg
elif ! prg_has_load_header; then
  echo "play: ${PRG} missing load header — forcing rebuild via make prg" >&2
  make -C "${RG_ROOT}" prg
fi

if [[ ! -f "${PRG}" ]]; then
  echo "error: missing ${PRG} (run: make prg)" >&2
  exit 1
fi
if ! prg_has_load_header; then
  echo "error: ${PRG} is not a C64 PRG (expected load header 01 08)." >&2
  echo "       Do not use: c64masm -o build/railgunner.prg" >&2
  echo "       Use:         make prg   (or tools/c64/build-prg.sh)" >&2
  exit 1
fi

CMD=("${C64M_BIN}")
if [[ -f "${C64M_INI}" ]]; then
  CMD+=(--inifile "${C64M_INI}")
fi
CMD+=(--prg "${PRG}" --autorun "$@")

echo "play: ${CMD[*]}"
echo "      (windowed; no control-port script — you drive)"
cd "${C64M_ROOT}"
export RAILGUNNER_ROOT="${RG_ROOT}"
exec "${CMD[@]}"
