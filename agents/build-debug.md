# Build, run, and debug — agent handoff

**Role:** How an agent **debugs** RailGunner over the remote control port after
a user bug report. Humans **play** with `tools/play.sh` (no agent attached).
Agents use `tools/agent_session.py` to assemble, instrument, observe, and fix.

See [`README.md`](README.md) for the two-path model and project goal.

| Related docs | |
|--------------|--|
| Design | [`railgunner.md`](railgunner.md) |
| Source tree | [`repo-layout.md`](repo-layout.md) |
| Assembler **syntax** | [`assembler-syntax.md`](assembler-syntax.md) |
| Protocol depth (c64m) | `../c64m/agents/control-port.md`, `../c64m/agents/runtime-control.md` |
| User manual Remote/Assembler | `../c64m/manual/manual.md` |

If this handoff and c64m disagree, **trust c64m** (source/tests/manual) and update
this file.

**Protocol:** `C64M/3` (localhost TCP, one client at a time).

---

## 1. Tool locations (stable paths in this repo)

Do **not** hard-code absolute build paths elsewhere. Use these:

| Path | Points at | Use |
|------|-----------|-----|
| `tools/c64m` | `../../c64m/build/c64m` | Emulator + in-process assembler + debugger |
| `tools/c64masm` | `../../c64m/build/c64masm` | Offline assemble |
| `tools/c64_control_client.py` | `../../c64m/tools/c64_control_client.py` | Control-port helper (`Ctl`) |
| `tools/play.sh` | user | Offline PRG + `--prg --autorun` (human play) |
| `tools/build-prg.sh` | build | `src/main.asm` → `build/railgunner.prg` |
| `tools/agent_session.py` | agent | Windowed + port 6510 + assemble + paste RUN |
| `tools/run-emulator.sh` | alias | → `play.sh` |
| `c64m.ini` | config | ROMs, Assembler tab; `auto_run=no` |

Rebuild c64m **in its own repo** if the symlink target is missing (do not edit c64m
from RailGunner sessions):

```sh
cmake --build ../c64m/build -j
```

### Agent boot sequence (`agent_session.py`)

1. Start windowed c64m with `c64m.ini` + `--control-port 6510`
2. `assemble reset=1 auto-run=0` absolute path to `src/main.asm`  
   (**Always reset when re-assembling without relaunching** — default in
   `agent_session.py`. Without reset, leftover PC/IRQ/game state fights the new image.)
3. `set-memory` BASIC pointers (`TXTTAB=$0801`, end=`$080D`) — assemble ≠ LOAD
4. `run` + paste `RUN\r` so BASIC does `SYS 2061` → `start`
5. Debug: breakpoints, `get-memory`, `get-cpu`, `get-frame`, …

Do **not** poke PC to `$080D` via assembler auto-run. Never `--headless`.

```bash
tools/agent_session.py              # start + boot (assemble reset=1)
tools/agent_session.py --attach     # already running; re-assemble with reset
tools/agent_session.py --verify     # smoke title, exit
tools/play.sh                       # human only — offline PRG, no control port
```

---

## 2. Working directory and paths

| Concern | Rule |
|---------|------|
| Emulator process cwd | `../c64m` (so ROMs resolve; scripts set this) |
| Live assemble path | **Absolute** `src/main.asm` (emu cwd is c64m) |
| Offline PRG | `tools/build-prg.sh` → `build/railgunner.prg` |
| Default control port | **6510** (agent sessions) |

Resolve the game root once per session:

```bash
RG="$(cd "$(dirname "$0")/.." && pwd)"   # if inside a script under tools/
# or:
RG="/absolute/path/to/railgunner"
```

---

## 3. Launch modes

### A. Agent session (control port)

```sh
tools/agent_session.py
```

Windowed + port 6510. Kill the **emulator process** when the session ends —
`quit-client` only drops the TCP client.

### B. Human play (no agent)

```sh
tools/play.sh
```

### C. Attach

```sh
tools/agent_session.py --attach
```

### Turbo modes (agents)

| Mode | Name | When to use |
|------|------|-------------|
| `1` | normal | Real-time; human watching |
| `2` | max | Free-run, **live** ARGB — preferred for automated frame checks |
| `3` | warp | Fastest free-run; **`get-frame` is debug geometry only** — do not use for pixel truth |

```text
N set-turbo 2
```

---

## 4. Building: integrated assembler (primary)

The **same** two-pass assembler as the GUI Assembler tab is exposed as:

```text
N assemble [address=<hex>] [run-address=<hex>] [auto-run=0|1] [reset=0|1] <source-path>
```

| Option | Default | RailGunner guidance |
|--------|---------|---------------------|
| `address` | `$8000` | Host default only. Our `src/main.asm` sets segments (`BASIC` `$0801`, `CODE` `$080d`); source origin wins once it emits / sets `* =` / `.org`. Safe to pass `address=$0801` or omit and rely on source. |
| `run-address` | same as `address` | Entry for auto-run — use code start (`$080d` / `start` once symbols work) when `auto-run=1` |
| `auto-run` | `0` | Use `0` for inspect-then-run; `1` only when you want an immediate jump |
| `reset` | `1` | Prefer **`reset=1`** for clean BASIC-ready RAM before a full game build |

**Always pause is automatic:** the control port pauses before assemble.

### Success / failure

```text
1 assemble reset=1 /abs/path/railgunner/src/main.asm
1 ok address=$0801

2 assemble reset=0 /abs/path/broken.asm
2 error assemble-error File: ... L:00012 C:004: ...
```

Treat any `assemble-error` as a hard fail: fix source, re-assemble. Do not run
stale RAM.

### Symbols after assemble

```text
N find-symbol start
N ok address=$080D name=start
```

- Exact name only (no fuzzy match).
- `error not-found` / `error not-ready` if missing or no assembly yet.
- Labels land in the debugger symbol table (GUI Disasm) the same way.

### Offline CLI assemble (secondary)

Useful for CI-ish “does it assemble?” without a live machine:

```sh
# From RailGunner root:
tools/c64masm -i src/main.asm -o build/main.bin -s build/symbols.txt
```

`C64MASM` is predefined to `1` in this path (see assembler syntax).  
**Primary game loop for agents remains live `assemble` into the emulator** so
breakpoints, PC, and memory match what you run.

---

## 5. Minimal Python control session

Use the vendored helper (symlink):

```python
import sys
from pathlib import Path

RG = Path("/absolute/path/to/railgunner")  # set per machine
sys.path.insert(0, str(RG / "tools"))
from c64_control_client import Ctl

SRC = (RG / "src" / "main.asm").resolve()

c = Ctl(port=6510)          # default in upstream helper is 17652 — always pass 6510
print(c.cmd("hello"))       # ('ok', 'name=c64m protocol=C64M/3')

# Build into the machine (absolute path — emulator cwd is ../c64m)
r = c.cmd(f"assemble reset=1 {SRC}")
assert r[0] == "ok", r

# Resolve entry and break
sym = c.cmd("find-symbol start")
# ('ok', 'address=$080D name=start') or not-found if not exported yet
c.cmd("break-clear-all")
c.ok("break-exec $080D")    # or address from find-symbol

c.ok("run")
c.ok("wait-paused 10000")   # sticky pause events; prefer wait over blind sleep
print(c.cmd("get-cpu"))
print(c.cmd("get-state"))

c.cmd("quit-client")
# then: kill the emulator process when the session is finished
```

Wire rules agents must not violate:

1. One outstanding **wait** at a time (`wait-paused` / `wait-frame` / `wait-event`).
2. Correlate responses by **request id** if pipelining; sequential `cmd()` is fine.
3. `run` / `step-*` return `accepted=1` **before** completion — always wait.
4. `quit-client` ≠ process exit.

---

## 6. Debug recipes (copy-paste patterns)

### 6.1 Assemble, run to label, inspect

```text
1 assemble reset=1 /ABS/railgunner/src/main.asm
2 find-symbol start
3 break-clear-all
4 break-exec $080D
5 run
6 wait-paused 10000
7 get-cpu
8 get-memory $0400 1000 map
```

### 6.2 Single-step a routine

```text
1 pause
2 wait-paused 2000
3 step-instruction
4 wait-event step-complete 2000
5 get-cpu
```

Repeat `step-instruction` / `step-over` / `step-out` as needed.

### 6.3 One frame of stable video

```text
1 set-turbo 2
2 step-frame
3 wait-event run-complete 5000
4 get-frame format=indexed8
```

Prefer **`step-frame`** over free-run `wait-frame` when you need consecutive
frames without aliasing. Mid-raster `get-frame` is a **partial** buffer — for a
full frame, `step-frame` or `run-to-raster` into a quiet line first.

### 6.4 Run until raster (IRQ / mux work)

```text
1 run-to-raster 50
2 wait-event run-complete 5000
3 get-vic
4 get-cpu
```

Breakpoints and BRK still win over raster stop.

### 6.5 Watch a memory write (rail / sprite registers)

```text
1 break-create write $D015 actions=break
2 run
3 wait-paused 10000
4 get-cpu
5 break-list
```

`access` in list payloads: **1=exec, 2=read, 4=write** (not VICE’s mask order).

Count-only (no pause) for rate measurement:

```text
1 break-create exec $EA31 actions=none
2 run
3 wait-frame 50 30000
4 pause
5 wait-paused 2000
6 break-list
```

### 6.6 Joystick poke (port 2 common for games)

Bits: up=1, down=2, left=4, right=8, fire=16.

```text
1 joystick 2 16
2 wait-frame 2 2000
3 joystick 2 0
```

### 6.7 Flight recorder (why did we jump here?)

```text
1 history-record on
2 history-clear
3 run
4 wait-paused 10000
5 history-find pc=$080D limit=16
```

`history-find` / `next` / `read` require **paused**. Decode HST1 via
`Ctl.history_find()` in the Python helper. Deep format:
`../c64m/agents/cpu-flight-recorder.md`.

### 6.8 Save a reproducible machine snapshot

```text
1 save-state /ABS/railgunner/build/slice.c64state
2 wait-event save-state-complete 10000
```

Restore later with `load-state` + `wait-event load-state-complete`.

---

## 7. Recommended agent workflow (game work)

```text
1. Ensure tools/c64m exists (rebuild c64m in its own repo if needed).
2. Start agent session: tools/agent_session.py  (or --attach if already up).
3. Human reports bug (what they saw vs expected); do not require them to read asm.
4. Edit src/** (syntax per assembler-syntax.md).
5. Re-boot: assemble reset=1 + pointer fix + paste RUN (agent_session --attach).
6. find-symbol / break-exec / joystick N mask / get-memory as needed.
7. Observe: get-cpu, get-memory, get-vic, get-frame, history-*.
8. One kill criterion; one change; re-assemble with reset; re-measure.
9. Ask human to re-test with tools/play.sh.
10. quit-client; kill emulator process when the session ends.
```

**Human playtest:** `tools/play.sh` only. Do not claim “feels good” from memory
dumps alone — that feedback is the human’s job.

**Vertical slice focus** (from design/layout): prove rail draw, one drone type,
bullet cells, `$D01F` disambiguation, then mux — instrument those labels first.

---

## 8. Assemble option cheat sheet for this project

| Goal | Command shape |
|------|----------------|
| Clean rebuild into live machine | `assemble reset=1 auto-run=0 /ABS/.../src/main.asm` |
| Then start game like a human | Fix BASIC pointers + `run` + paste `RUN\r` (see `agent_session.py`) |
| Hot-patch without reset | **Avoid** unless you know state; prefer `reset=1` when re-assembling |
| Offline PRG for human play | `tools/build-prg.sh` / `tools/play.sh` |

**Do not** use `auto-run=1 run-address=$080d` — that pokes PC into ML, skips BASIC
`RUN`/`SYS`, and leaves KERNAL state wrong (e.g. cursor). Prefer paste `RUN` or
offline `--prg --autorun`.

---

## 9. Pitfalls (read once)

| Pitfall | Correct behavior |
|---------|------------------|
| Launch c64m from RailGunner cwd without scripts | Use `tools/play.sh` or `tools/agent_session.py` (they set cwd / INI) |
| Relative `assemble src/main.asm` (cwd=c64m) | Pass **absolute** path to RailGunner `src/main.asm` |
| `quit-client` ends session forever | Only closes socket; **kill emulator process** to tear down |
| `--headless` | **Forbidden** on RailGunner — always windowed |
| Re-assemble without reset | Use **`reset=1`** when the emu is already running |
| Assembler auto-run to `$080D` | Paste `RUN` instead (or offline PRG + `--autorun`) |
| Assemble without fixing BASIC end pointers | After live assemble, set `TXTTAB=$0801`, `VARTAB/ARYTAB/STREND=$080D` (assemble ≠ LOAD) |
| `screen_put_xy` + loop counters in `tmp1`/`tmp2` | **Never** — put_xy clobbers `tmp*`; use dedicated ZP (`draw_i`, `print_col`, …) |
| Keyboard Space matrix wrong | Space: PRA=`$7F` (row 7), PRB bit 4 (`$10`) — see `sys/const.asm` |
| Second wait while one active | `error busy` — serialize waits |
| `get-frame` at turbo 3 | Debug-only geometry; use turbo 1 or 2 |
| Client default port 17652 | Always `Ctl(port=6510)` for this project |
| Edit `../c64m/` | **Never** — read-only reference only |

---

## 10. Hard-won lessons (scaffold era)

### Bug: title fire seemed dead / freeze after fire

**Symptom:** Title shows “PRESS FIRE”; joystick/space appear to do nothing (or UI freezes).

**Causes found:**
1. **`screen_draw_playfield` hung** after fire → stage init. Loop counters lived in
   `tmp1`/`tmp2`, which `screen_put_xy` overwrites → infinite loop. Main loop never
   ran again. Fix: `draw_i` / `draw_j` in ZP.
2. **Keyboard Space scan used wrong matrix bits** (row/col swapped vs CIA). Fix:
   PRA select row 7 (`$7F`), PRB test bit 4 (`$10`). Joy port 2 fire is PRA bit 4;
   also accept port 1 fire as fallback.

**How we proved fire:** control-port `joystick 2 16` (fire down), then `0` (release);
watch ZP `game_mode` (`0` title → `3` play) and border colour (blue → green).

### Game mode IDs (scaffold)

| Value | Mode |
|------:|------|
| 0 | TITLE |
| 1 | GAME_INIT |
| 2 | STAGE_INIT |
| 3 | PLAY |
| 7 | GAME_OVER |

Symbols: `game_mode`, `input_fire`, `input_fire_edge` (see `sys/zeropage.asm`).

### BASIC stub

`10 SYS 2061` → `$080D` = `start`. Offline PRG load updates BASIC pointers; live
`assemble` does **not**.

---

## 11. What not to do

- Do not invent a second assembler or non-c64m syntax.
- Do not bind control servers to non-localhost or multi-client fanout.
- Do not treat this doc as a full protocol dump — for rare commands open
  `../c64m/agents/control-port.md` (**read-only**).
- Do not commit `build/*` outputs (see `.gitignore`).
- Do not use assembler auto-run as a substitute for `RUN`.

---

## 12. Quick reference card

```bash
# Human play
tools/play.sh

# Agent session
tools/agent_session.py

# Offline PRG / symbols
tools/build-prg.sh
```

```text
hello | ping | get-state | get-cpu | get-vic | get-cia 1
assemble reset=1 /ABS/src/main.asm
find-symbol <name>
break-exec $addr | break-create ... | break-list | break-clear-all
run | pause | step-instruction | step-over | step-out | step-frame
run-to $addr | run-to-raster <line> | run-cycles N | run-instructions N
wait-paused [ms] | wait-running | wait-frame <delta> [ms] | wait-event <name> [ms]
get-memory $addr <len> map|ram
set-memory $addr <len> map|ram  + raw payload
get-frame [format=indexed8|argb8888]
joystick <1|2> <mask>
set-turbo 1|2|3
history-record on|off | history-find ... | history-read ...
save-state <path> | load-state <path>
quit-client
```

Sticky completion events (safe after fast ops):  
`assemble-complete`, `assemble-error`, `step-complete`, `run-complete`,
`reset-complete`, `load-state-complete`, `save-state-complete`, `paused`, `running`.
