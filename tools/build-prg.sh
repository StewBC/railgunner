#!/usr/bin/env bash
# Offline assemble → build/railgunner.prg (load address $0801).
# Used by the user "play" path and available to agents for a clean PRG.

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RG_ROOT="$(cd "${TOOLS_DIR}/.." && pwd)"
SRC="${RG_ROOT}/src/main.asm"
OUT_DIR="${RG_ROOT}/build"
RAW="${OUT_DIR}/railgunner.raw"
PRG="${OUT_DIR}/railgunner.prg"
SYM="${OUT_DIR}/symbols.txt"

mkdir -p "${OUT_DIR}"

if [[ ! -x "${TOOLS_DIR}/c64masm" && ! -L "${TOOLS_DIR}/c64masm" ]]; then
  echo "error: missing tools/c64masm" >&2
  exit 1
fi

"${TOOLS_DIR}/c64masm" -i "${SRC}" -o "${RAW}" -s "${SYM}"
# Standard C64 PRG: 16-bit little-endian load address, then payload
python3 - "${RAW}" "${PRG}" <<'PY'
import sys
from pathlib import Path
raw_path, prg_path = sys.argv[1], sys.argv[2]
raw = Path(raw_path).read_bytes()
# Segments start at BASIC $0801
Path(prg_path).write_bytes(bytes((0x01, 0x08)) + raw)
print(f"wrote {prg_path} ({len(raw) + 2} bytes, load $0801)")
PY
