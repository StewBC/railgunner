# tools/c64/

Stable entry points into the **c64m** toolchain (sibling of this repo, `../c64m/` from the repo root).

Host orchestration lives in the **root `Makefile`** (`make`, `make play`,
`make assets` / `screens` / `charset` / `sprites`). Scripts here do the work;
Make wires timestamps so a changed `title.png` regenerates `.bin`s before assemble.

| Path | Role |
|------|------|
| `c64m` | symlink → emulator |
| `c64masm` | symlink → `../../../c64m/build/am65` (offline assembler) |
| `c64_control_client.py` | symlink → control-port Python client |
| **`play.sh`** | **User path:** `make prg` (unless `RAILGUNNER_SKIP_BUILD=1`) + windowed `--prg --autorun` |
| **`build-prg.sh`** | Assemble `src/c64/main.asm` → raw + **PRG with `$0801` load header** (only correct way to write `.prg`) |
| **`agent_session.py`** | **Agent path:** windowed + control port + assemble + RUN |
| **`coop.sh`** / **`make coop`** | Build + emu(control-port) + coop watcher (preferred coop entry) |
| **`coop_debug_rg.py`** | Watcher only: coop_watch + game symbols → `build/debug/snap-*.txt` |
| **`analyze_profile.py`** | Summarize `objects::profile_marker` history from a paused coop snap; reports phase cycles with IRQ time separated |
| `coop_watch.py` | symlink → c64m cooperative watcher (generic; prefer `coop_debug_rg.py`). Inbox: `scrub`/`frame` (frame ring), `vic` (VIC ring / latched X), `arm … when=` — see `agents/coop-debug.md` |
| **`png_to_c64_hires.py`** | PNG → C64 hires bitmap + colour-matrix `.bin` (title art) |
| **`png_to_c64_sprite.py`** | PNG → C64 multicolour sprite `.bin` (64 bytes, 12×21) |
| `run-emulator.sh` | Alias → `play.sh` (user path) |

Project config: **`../c64m.ini`**.

See **`agents/README.md`** for user vs agent launch and the no-`--headless` / no-edit-`../c64m` rules.

```bash
# Human play/test (preferred)
make play

# Equivalent without Make's play target
tools/c64/play.sh

# Assemble offline PRG (always use this — not bare c64masm -o …prg)
make prg
# c64masm writes a raw $0801 image; build-prg.sh prepends the 2-byte load
# address. Pointing c64masm -o at build/railgunner.prg skips the header and
# breaks --prg/--autorun (RUN does nothing) until `make clean && make`.
#
# build-prg.sh is strict:
#   - non-zero c64masm exit → fail (log in build/assemble.log)
#   - "Assembly failed" / errors in log → fail even if exit were 0
#   - parses SEGMENTS from symbols.txt; CODE must end before CHARSET ($2800)
#     and SPRITE_BLOCK ($3000). Assembler segment-overlap checks do not cover
#     those runtime regions (they are not .segdef targets).

# Agent debug session
tools/c64/agent_session.py

# Asset converters only
make screens          # railgunner.png → title_hires*.bin
make sprites          # assets/c64/sprites/*.png → *.bin (64-byte MC frames)
make assets           # screens + charset + sprites

# One-off sprite convert (Make uses --fit for oversize art)
tools/c64/png_to_c64_sprite.py assets/c64/sprites/drone1_tiny_native.png
tools/c64/png_to_c64_sprite.py assets/c64/sprites/*.png --fit
```

### Sprite bins

- Input: multicolour-oriented PNGs under `assets/c64/sprites/` (≤3 opaque colours + transparency).
- Output: same-stem `.bin`, 64 bytes (VIC sprite block: 3×21 data + pad).
- Canvas: 12×21 logical pixels. Art larger than that needs `--fit` (Make passes it) until remastered.
- Bit pairs: `00` transparent, `01` MC1 (`$D025`), `10` sprite colour, `11` MC2 (`$D026`).
- Assembler: `src/c64/data/sprites.asm` `.incbin`s each frame into the SPRITES segment (`$3000+`).
