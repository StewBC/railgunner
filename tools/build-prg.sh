#!/usr/bin/env bash
# Offline assemble → build/railgunner.prg (C64 PRG: 2-byte load address + image).
#
# c64masm emits a raw memory image starting at $0801 (BASIC stub). A loadable
# .prg must prepend little-endian $0801. Writing c64masm -o build/railgunner.prg
# directly produces a RAW file that Make may treat as "up to date" while
# --prg/--autorun fails (RUN does nothing). Always use this script or `make prg`.
#
# Also enforces project runtime layout: CODE must not grow into CHARSET ($2800)
# or SPRITE_BLOCK ($3000). Those regions are not separate .segdef targets, so
# the assembler will not report an overflow on its own.

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RG_ROOT="$(cd "${TOOLS_DIR}/.." && pwd)"
SRC="${RG_ROOT}/src/main.asm"
OUT_DIR="${RG_ROOT}/build"
RAW="${OUT_DIR}/railgunner.raw"
PRG="${OUT_DIR}/railgunner.prg"
SYM="${OUT_DIR}/symbols.txt"
ASM_LOG="${OUT_DIR}/assemble.log"

# Runtime floors (keep in sync with src/sys/const.asm / memory.asm)
CHARSET_RAM=0x2800
SPRITE_BLOCK=0x3000
PLAYER_BUF=0x3E00

mkdir -p "${OUT_DIR}"

if [[ ! -x "${TOOLS_DIR}/c64masm" && ! -L "${TOOLS_DIR}/c64masm" ]]; then
  echo "error: missing tools/c64masm" >&2
  exit 1
fi

fail() {
  echo "error: $*" >&2
  rm -f "${PRG}"
  exit 1
}

echo "assemble: ${SRC}"
set +e
"${TOOLS_DIR}/c64masm" -i "${SRC}" -o "${RAW}" -s "${SYM}" >"${ASM_LOG}" 2>&1
asm_rc=$?
set -e
cat "${ASM_LOG}"

if [[ "${asm_rc}" -ne 0 ]]; then
  fail "c64masm exited ${asm_rc} (see ${ASM_LOG})"
fi

# Belt-and-suspenders: some tool builds may print failure without non-zero exit
if grep -Eiq 'Assembly failed|Assembly errors:|error:|segment overflow|overflows' "${ASM_LOG}"; then
  fail "assembler reported errors (see ${ASM_LOG})"
fi

if [[ ! -f "${RAW}" || ! -s "${RAW}" ]]; then
  fail "missing or empty raw output ${RAW}"
fi

if [[ ! -f "${SYM}" ]]; then
  fail "missing symbols file ${SYM}"
fi

# Parse SEGMENTS block from symbols (c64masm writes e.g. CODE [080D-20F1))
python3 - "${SYM}" "${CHARSET_RAM}" "${SPRITE_BLOCK}" "${PLAYER_BUF}" <<'PY'
import re
import sys
from pathlib import Path

sym_path = Path(sys.argv[1])
charset = int(sys.argv[2], 0)
sprite = int(sys.argv[3], 0)
player = int(sys.argv[4], 0)

text = sym_path.read_text(encoding="utf-8", errors="replace")
# Prefer the last SEGMENTS block (file may list symbols then summary)
blocks = list(re.finditer(
    r"SEGMENTS\s*->\s*[^{\n]+\{([^}]*)\}",
    text,
    re.IGNORECASE | re.DOTALL,
))
if not blocks:
    print("error: no SEGMENTS summary in symbols file — cannot verify layout", file=sys.stderr)
    sys.exit(1)

body = blocks[-1].group(1)
# NAME [start-end) optional (noemit)
pat = re.compile(
    r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\[\s*([0-9A-Fa-f]+)\s*-\s*([0-9A-Fa-f]+)\s*\)",
    re.MULTILINE,
)
segs = {}
for m in pat.finditer(body):
    name = m.group(1).upper()
    start = int(m.group(2), 16)
    end = int(m.group(3), 16)  # exclusive
    segs[name] = (start, end)
    print(f"  segment {name}: ${start:04X}–${end:04X} ({end - start} bytes)")

if "CODE" not in segs:
    print("error: CODE segment missing from SEGMENTS summary", file=sys.stderr)
    sys.exit(1)

code_start, code_end = segs["CODE"]
# code_end is exclusive first free address after CODE
limits = [
    ("CHARSET_RAM", charset, "move font or shrink CODE"),
    ("SPRITE_BLOCK", sprite, "CODE must stay below sprite bank"),
    ("PLAYER_BUF", player, "CODE must stay below player sprite buffers"),
]
failed = False
for label, addr, hint in limits:
    if code_end > addr:
        print(
            f"error: CODE ends at ${code_end:04X}, overlaps runtime {label} ${addr:04X} — {hint}",
            file=sys.stderr,
        )
        failed = True
    else:
        room = addr - code_end
        print(f"  layout OK: CODE ends ${code_end:04X}, {room} bytes free before {label} ${addr:04X}")

# Soft warning if getting tight (< 256 bytes before charset)
room_cs = charset - code_end
if not failed and room_cs < 256:
    print(
        f"warning: only {room_cs} bytes free before CHARSET_RAM ${charset:04X} — plan a split soon",
        file=sys.stderr,
    )

sys.exit(1 if failed else 0)
PY

# Standard C64 PRG: 16-bit little-endian load address, then payload
python3 - "${RAW}" "${PRG}" <<'PY'
import sys
from pathlib import Path
raw_path, prg_path = sys.argv[1], sys.argv[2]
raw = Path(raw_path).read_bytes()
if len(raw) < 14:
    raise SystemExit(f"error: raw image too small ({len(raw)} bytes)")
if raw[:2] == b"\x01\x08":
    Path(prg_path).write_bytes(raw)
    print(f"wrote {prg_path} ({len(raw)} bytes, already had load header)")
else:
    Path(prg_path).write_bytes(bytes((0x01, 0x08)) + raw)
    print(f"wrote {prg_path} ({len(raw) + 2} bytes, load $0801)")
PY

echo "assemble OK → ${PRG}"
