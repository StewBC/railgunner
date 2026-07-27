#!/usr/bin/env bash
# Build and launch the clockwise-orbit sprite-multiplexer demo in visible c64m.

set -euo pipefail

TST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RG_ROOT="$(cd "${TST_DIR}/.." && pwd)"
C64M_ROOT="${C64M_ROOT:-$(cd "${RG_ROOT}/../c64m" && pwd)}"
C64M_BIN="${RG_ROOT}/tools/c64m"
PRG="${RG_ROOT}/build/sprite_mux_circle.prg"

for arg in "$@"; do
    if [[ "${arg}" == "--headless" || "${arg}" == --headless=* ]]; then
        echo "error: RailGunner tests never use --headless" >&2
        exit 2
    fi
done

"${TST_DIR}/build_sprite_mux_circle.sh"

cmd=("${C64M_BIN}")
if [[ -f "${RG_ROOT}/c64m.ini" ]]; then
    cmd+=(--inifile "${RG_ROOT}/c64m.ini")
fi
cmd+=(--prg "${PRG}" --autorun "$@")

echo "play mux circle: ${cmd[*]}"
cd "${C64M_ROOT}"
export RAILGUNNER_ROOT="${RG_ROOT}"
exec "${cmd[@]}"
