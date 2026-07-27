# tools/

Stable entry points into the **c64m** toolchain (sibling repo `../c64m/`).

Host orchestration lives in the **root `Makefile`** (`make`, `make play`,
`make assets` / `screens` / `charset` / `sprites`). Scripts here do the work;
Make wires timestamps so a changed `title.png` regenerates `.bin`s before assemble.

| Path | Role |
|------|------|
| `c64m` | symlink → emulator |
| `c64masm` | symlink → offline assembler |
| `c64_control_client.py` | symlink → control-port Python client |
| **`play.sh`** | **User path:** `make prg` (unless `RAILGUNNER_SKIP_BUILD=1`) + windowed `--prg --autorun` |
| **`build-prg.sh`** | Assemble `src/main.asm` → `build/railgunner.prg` (no asset graph) |
| **`agent_session.py`** | **Agent path:** windowed + control port + assemble + RUN |
| **`png_to_c64_hires.py`** | PNG → C64 hires bitmap + colour-matrix `.bin` (title art) |
| `run-emulator.sh` | Alias → `play.sh` (user path) |

Project config: **`../c64m.ini`**.

See **`agents/README.md`** for user vs agent launch and the no-`--headless` / no-edit-`../c64m` rules.

```bash
# Human play/test (preferred)
make play

# Equivalent without Make's play target
tools/play.sh

# Agent debug session
tools/agent_session.py

# Asset converters only
make screens          # railgunner.png → title_hires*.bin
make assets           # screens + charset + sprites (placeholders ok)
```
