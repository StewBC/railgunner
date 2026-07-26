# tools/

Stable entry points into the **c64m** toolchain (sibling repo `../c64m/`).

| Path | Role |
|------|------|
| `c64m` | symlink → emulator |
| `c64masm` | symlink → offline assembler |
| `c64_control_client.py` | symlink → control-port Python client |
| **`play.sh`** | **User path:** offline PRG + windowed `--prg --autorun` |
| **`build-prg.sh`** | Assemble `src/main.asm` → `build/railgunner.prg` |
| **`agent_session.py`** | **Agent path:** windowed + control port + assemble + RUN |
| `run-emulator.sh` | Alias → `play.sh` (user path) |

Project config: **`../c64m.ini`**.

See **`agents/README.md`** for user vs agent launch and the no-`--headless` / no-edit-`../c64m` rules.

```bash
# Human play/test
tools/play.sh

# Agent debug session
tools/agent_session.py
```
