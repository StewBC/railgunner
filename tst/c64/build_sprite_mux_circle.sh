#!/usr/bin/env bash
# Assemble the standalone clockwise-orbit sprite-multiplexer PRG.

set -euo pipefail

TST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RG_ROOT="$(cd "${TST_DIR}/../.." && pwd)"
SRC="${TST_DIR}/sprite_mux_circle.asm"
OUT_DIR="${RG_ROOT}/build"
RAW="${OUT_DIR}/sprite_mux_circle.raw"
PRG="${OUT_DIR}/sprite_mux_circle.prg"
SYM="${OUT_DIR}/sprite_mux_circle.symbols.txt"

mkdir -p "${OUT_DIR}"
"${RG_ROOT}/tools/c64/c64masm" -i "${SRC}" -o "${RAW}" -s "${SYM}"

python3 - "${RAW}" "${PRG}" <<'PY'
import sys
from pathlib import Path

raw_path, prg_path = map(Path, sys.argv[1:])
raw = raw_path.read_bytes()
prg_path.write_bytes(bytes((0x01, 0x08)) + raw)
print(f"wrote {prg_path} ({len(raw) + 2} bytes, load $0801)")
PY
