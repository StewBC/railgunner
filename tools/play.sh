#!/usr/bin/env bash
# USER path: build PRG offline, start windowed c64m with --prg --autorun.
#
# No remote API required. The emulator window is yours to play/test.
# Quit the emulator window when done.
#
#   tools/play.sh
#
# Never --headless (see agents/README.md).

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RG_ROOT="$(cd "${TOOLS_DIR}/.." && pwd)"
C64M_ROOT="${C64M_ROOT:-$(cd "${RG_ROOT}/../c64m" && pwd)}"
C64M_BIN="${TOOLS_DIR}/c64m"
C64M_INI="${C64M_INI:-${RG_ROOT}/c64m.ini}"
PRG="${RG_ROOT}/build/railgunner.prg"

if [[ ! -x "${C64M_BIN}" && ! -L "${C64M_BIN}" ]]; then
  echo "error: missing tools/c64m" >&2
  exit 1
fi

"${TOOLS_DIR}/build-prg.sh"

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
