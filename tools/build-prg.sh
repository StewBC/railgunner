#!/usr/bin/env bash
# Offline assemble → build/railgunner.prg (C64 PRG: 2-byte load address + image).
#
# c64masm emits a raw memory image starting at $0801 (BASIC stub). A loadable
# .prg must prepend little-endian $0801. Writing c64masm -o build/railgunner.prg
# directly produces a RAW file that Make may treat as "up to date" while
# --prg/--autorun fails (RUN does nothing). Always use this script or `make prg`.
#
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
if len(raw) < 14:
    raise SystemExit(f"error: raw image too small ({len(raw)} bytes)")
# Sanity: raw should start with a BASIC next-line pointer into $0801+ space
# (typical stub begins 0b 08 …), not a PRG header (01 08).
if raw[:2] == b"\x01\x08":
    # Already wrapped — write as-is (idempotent if someone pointed -o at a PRG)
    Path(prg_path).write_bytes(raw)
    print(f"wrote {prg_path} ({len(raw)} bytes, already had load header)")
else:
    Path(prg_path).write_bytes(bytes((0x01, 0x08)) + raw)
    print(f"wrote {prg_path} ({len(raw) + 2} bytes, load $0801)")
PY
