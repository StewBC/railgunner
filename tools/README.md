# tools/

Stable entry points into the **c64m** toolchain (sibling repo `../c64m/`).

| Path | Kind | Target / role |
|------|------|----------------|
| `c64m` | symlink | `../../c64m/build/c64m` — emulator, integrated assembler, debugger |
| `c64masm` | symlink | `../../c64m/build/c64masm` — offline CLI assembler |
| `c64_control_client.py` | symlink | `../../c64m/tools/c64_control_client.py` — Python control-port client |
| `run-emulator.sh` | script | Launch c64m with cwd = `../c64m` so `roms/` resolve |

**Agent build/debug workflow:** [`agents/build-debug.md`](../agents/build-debug.md).

If a symlink is broken, rebuild c64m:

```sh
cmake --build ../c64m/build -j
```
