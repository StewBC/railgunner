# Build, run, and debug — agent handoff

**Role:** How an agent **builds** RailGunner with c64m’s integrated assembler and
**drives** the emulator/debugger over the remote control port. The human owns
gameplay feel and product feedback; the agent owns assemble → instrument → run
→ observe → fix loops.

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
| `tools/c64masm` | `../../c64m/build/c64masm` | Offline assemble to a host binary (optional) |
| `tools/c64_control_client.py` | `../../c64m/tools/c64_control_client.py` | Python control-port helper (`Ctl`) |
| `tools/run-emulator.sh` | wrapper | **Preferred launch** — sets cwd so ROMs resolve |

Rebuild c64m in its own repo if the symlink target is missing:

```sh
cmake --build ../c64m/build -j
```

### Why `run-emulator.sh`?

c64m loads `roms/` relative to the **process current directory**. Starting
`tools/c64m` from the RailGunner tree will fail ROM lookup. The wrapper `cd`s to
`../c64m` then `exec`s the binary. It also exports `RAILGUNNER_ROOT` for scripts.

---

## 2. Working directory and paths

| Concern | Rule |
|---------|------|
| Emulator process cwd | `../c64m` (via `tools/run-emulator.sh`) |
| Assemble root source | **Absolute path** to `src/main.asm` (cwd is c64m, not RailGunner) |
| Optional offline PRG | `tools/c64masm -i src/main.asm -o build/main.bin` from **RailGunner** root |
| Default control port | **6510** (convention for this project) |

Resolve the game root once per session:

```bash
RG="$(cd "$(dirname "$0")/.." && pwd)"   # if inside a script under tools/
# or:
RG="/absolute/path/to/railgunner"
```

---

## 3. Launch modes

### A. Headless + control port (agent default)

No window, no host audio device; full runtime + frames for `get-frame`. Best
latency for automation.

```sh
# From RailGunner repo root:
tools/run-emulator.sh --headless --control-port 6510
```

Keep this process running for the session. **Kill the process** when done —
`quit-client` only closes the TCP client, **not** the emulator.

### B. Windowed + control port (human watches, agent drives)

```sh
tools/run-emulator.sh --control-port 6510
```

Same remote API; SDL window open for the human. Prefer headless when only the
agent is observing memory/CPU/frames.

### C. Human-only GUI (no remote)

```sh
tools/run-emulator.sh
```

Use Assembler tab / Shift+Opt+A as a human would. Agents should still prefer the
control port so builds are reproducible in scripts.

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
# then: kill the emulator process if headless session is finished
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
1. Ensure tools/c64m exists (rebuild c64m if needed).
2. Start: tools/run-emulator.sh --headless --control-port 6510
3. Connect Ctl(port=6510); hello / ping.
4. Edit src/** (syntax per assembler-syntax.md).
5. assemble reset=1 <abs>/src/main.asm
   - on assemble-error: fix and repeat (do not run).
6. find-symbol for the routine under test; break-exec that address.
7. run → wait-paused (or step-frame / run-to-raster).
8. Observe: get-cpu, get-memory, get-vic, get-frame, history-*.
9. Form one kill criterion; change one thing; re-assemble; re-measure.
10. quit-client; kill emulator process when the session ends.
```

**Human playtest:** launch windowed (`tools/run-emulator.sh --control-port 6510`
or without control port), assemble with `auto-run=1` or let the human `RUN` /
SYS. Do not claim “feels good” from memory dumps alone — that feedback is the
human’s job.

**Vertical slice focus** (from design/layout): prove rail draw, one drone type,
bullet cells, `$D01F` disambiguation, then mux — instrument those labels first.

---

## 8. Assemble option cheat sheet for this project

| Goal | Command shape |
|------|----------------|
| Clean full rebuild into RAM | `assemble reset=1 /ABS/.../src/main.asm` |
| Hot-patch without reboot (advanced) | `assemble reset=0 ...` — only if you know machine state |
| Build and jump to code | `assemble reset=1 auto-run=1 run-address=$080d /ABS/.../src/main.asm` |
| Iterative BP on one-shots | GUI “Rearm one-shots” or control `rearm-oneshots` before re-run |

After `reset=1` assemble, machine has been through BASIC warm path; code bytes
are in RAM at segment addresses. If the game is SYS-started, either auto-run at
`start` or `break-exec` + set PC via running through stub / `run-to`.

---

## 9. Pitfalls (read once)

| Pitfall | Correct behavior |
|---------|------------------|
| Launch c64m from RailGunner cwd | Use `tools/run-emulator.sh` |
| Relative `assemble src/main.asm` with cwd=c64m | Pass **absolute** path to RailGunner `src/main.asm` |
| `quit-client` ends session forever | Only closes socket; **kill process** for headless teardown |
| Second wait while one active | `error busy` — serialize waits |
| `get-frame` at turbo 3 | Debug-only geometry; use turbo 1 or 2 |
| Free-run `wait-frame` for consecutive frames | Prefer `step-frame` |
| Mid-frame `get-frame` | Partial buffer; finish frame first |
| Assume VICE breakpoint access masks | c64m: exec=1, read=2, write=4 |
| Offline `c64masm` only | Fine for syntax check; **live test needs** `assemble` into emulator |
| Client default port 17652 | Always construct `Ctl(port=6510)` for this project |

---

## 10. What not to do

- Do not invent a second assembler or non-c64m syntax.
- Do not bind control servers to non-localhost or multi-client fanout.
- Do not treat this doc as a full protocol dump — for rare commands (drive CPU,
  paste-events, full HST1 layout) open `../c64m/agents/control-port.md`.
- Do not commit `build/*.bin` / snapshots unless explicitly wanted (see `.gitignore`).

---

## 11. Quick reference card

```bash
# Start (agent)
tools/run-emulator.sh --headless --control-port 6510

# Offline syntax/link check
tools/c64masm -i src/main.asm -o build/main.bin -s build/symbols.txt
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
