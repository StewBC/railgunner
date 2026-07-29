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

**Protocol:** `C64M/6` (localhost TCP, one client at a time). Bumps that matter
for this repo: **C64M/3** flight recorder (`history-*`), **C64M/4** guarded
breakpoints (`when=`), **C64M/5** frame ring (`frame-ring-*`, `get-frame-at`),
**C64M/6** VIC ring (`vic-ring-*` — per-line latched sprite X / derived state).
`hello` / `version` advertise `protocol=C64M/6`; `capabilities` includes
`history`, `frame-ring`, and `vic-ring`. Rebuild `../c64m/build/c64m` if
`hello` still says C64M/5.

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
2. `assemble basic-run=1 reset=1 <abs>/src/main.asm` — assembles, then fixes the
   BASIC pointers (from the emitted origin+end) and pastes `RUN` so BASIC does
   `SYS 2061` → `start`. **One command**; no manual `set-memory`/paste ceremony.
   (**Keep `reset=1`** when re-assembling into a running emulator — c64m skips
   the reset only when already at a fresh READY, e.g. right after launch.)
3. Debug: breakpoints, `get-memory`, `get-cpu`, `get-frame`, …

Do **not** poke PC to `$080D` via assembler auto-run (use `basic-run` instead).
Never `--headless`.

```bash
tools/agent_session.py              # start + boot (assemble basic-run=1)
tools/agent_session.py --attach     # already running; re-assemble + basic-run
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
N assemble [address=<hex>] [run-address=<hex>] [auto-run=0|1] [basic-run=0|1] [reset=0|1] <source-path>
```

| Option | Default | RailGunner guidance |
|--------|---------|---------------------|
| `address` | `$8000` | Host default only. Our `src/main.asm` sets segments (`BASIC` `$0801`, `CODE` `$080d`); source origin wins once it emits / sets `* =` / `.org`. Safe to pass `address=$0801` or omit and rely on source. The success line reports the **actual emitted origin** (`ok address=$0801`), not this default. |
| `run-address` | same as `address` | Entry for auto-run — use code start (`$080d` / `start` once symbols work) when `auto-run=1` |
| `auto-run` | `0` | Pokes PC into ML (skips BASIC). We **avoid** this — leaves KERNAL state wrong. Prefer `basic-run`. |
| `basic-run` | `0` | **The boot button for this project.** `1` = fix BASIC pointers (from emitted origin+end) + paste `RUN`, i.e. assemble-as-LOAD for our `10 SYS 2061` stub. Mutually exclusive with `auto-run` (both `=1` → `bad-args`). Skips a redundant reset when already at a fresh READY. |
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
# From RailGunner root — playable PRG for humans:
make prg                    # or: tools/build-prg.sh
# → build/railgunner.raw  (c64masm memory image @ $0801)
# → build/railgunner.prg  (2-byte load $0801 + raw)  ← only this is --prg safe

# Assemble-only check (do NOT use this path as the play PRG):
tools/c64masm -i src/main.asm -o build/railgunner.raw -s build/symbols.txt
```

**Never** `c64masm -o build/railgunner.prg`. The CLI writes a raw image; a C64
`.prg` needs a little-endian load address prefix. A raw file left as `.prg`
keeps Make “up to date” while `make play` / `--autorun` loads garbage and RUN
does nothing — until `make clean && make`. `make prg` / `play.sh` now reject a
missing `$01 $08` header and rebuild.

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
print(c.cmd("hello"))       # ('ok', 'name=c64m protocol=C64M/6')

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

### 6.5b Guarded breakpoints (`when=`) — stop on *nuance*, not just address

Address + access alone is too coarse for time-critical bugs (write only inside
IRQ, only on a raster band, only when the written byte clears a bit). **`when=`**
adds a **bounded AND-list of up to 4 terms**, evaluated *after* the
address/access/mapping match. No OR, no grouping, no precedence — arm two
breakpoints if you need OR.

```text
when=<term>[,<term>...]      term = <lhs><op><imm>
```

| LHS | Meaning |
|-----|---------|
| `a` `x` `y` `sp` `p` | CPU registers |
| `n` `v` `b` `d` `i` `z` `c` | individual P flags as 0/1 |
| `value` | byte carried by the matching access (not valid on `exec`) |
| `mem($addr)` | one CPU-map byte at match time |
| `raster` | VIC-II raster line |
| `vic_cycle` | cycle within the line |

| Op | Meaning |
|----|---------|
| `==` `!=` `<` `>` `<=` `>=` | integer compare |
| `&` | mask set: `(lhs & imm) != 0` |
| `!&` | mask clear: `(lhs & imm) == 0` |

**No whitespace** inside the condition. Immediates: `$hex`, `0x`, decimal.
Guards round-trip through the debug `.ini` with `;` between terms (INI values
are already comma-lists). The **frontend breakpoint dialog cannot edit guards**
and **clears them on save** — arm/update guards only over the control port.

```text
# Write $D021 only with I set (typical IRQ handler)
1 break-create write $D021 actions=break when=i==1

# Sprite XMSB cleared while sprite-0 X already high
2 break-create write $D010 actions=break when=value!&1,mem($D000)>$F0

# Store only in the lower border
3 break-create write $00C3 actions=break when=raster>=250

# Count-only: how often $D015 is written above raster 50
4 break-create write $D015 actions=none when=raster>50
```

`hits=` / `counter=` advance only on **guarded** matches. RailGunner mux/sprite
bugs often need this (wrong `$D0xx` write mid-frame) — pair with coop
`arm write $ADDR when=…` (see [`coop-debug.md`](coop-debug.md)).

### 6.6 Joystick poke (port 2 common for games)

Bits: up=1, down=2, left=4, right=8, fire=16.

```text
1 joystick 2 16
2 wait-frame 2 2000
3 joystick 2 0
```

### 6.7 Flight recorder (why did we jump here?)

Always-on bounded in-memory 6510 forensic ring (HST1). Answers “what executed /
what bus traffic happened before the stop.” Does **not** retain pixels — use
the **frame ring** (§6.7b) for “what did the screen show N frames ago.”

```text
1 history-record on
2 history-clear
3 run
4 wait-paused 10000
5 history-find pc=$080D limit=16
6 history-find address=$D015 access=write limit=32
7 history-find opcodes=A9,??,8D limit=16
```

| Command | When |
|---------|------|
| `history-info` / `history-record` / `history-clear` / `history-close` | OK while running |
| `history-find` / `history-next` / `history-read` | **paused** only (`busy machine-running` otherwise) |

Find keys (newest-first by default): `epoch timeline cycle from direction pc
address access value opcodes limit`. Access: `execute`/`opcode`/`operand`/
`data-read`/`data-write`/…; aliases `fetch`, `read`, `write`, `data`.
`opcodes` is 1..32 comma-separated bytes with `?` nibble wildcards.

Decode HST1 via `Ctl.history_find()` / `history_read()` in the Python helper.
Deep format: `../c64m/agents/cpu-flight-recorder.md`. Budget:
`[debug] history_memory_mb` / `--history-memory=` (default large; `0` disables).

Cross-link with the frame ring: each retained frame carries a **machine cycle**;
`history-find cycle=…` (or a cycle range) lines the bus traffic up with that
picture.

### 6.7b Frame ring (what did the screen *show*?)

A human who sees a one-frame glitch and hits pause is ~50 PAL frames late; those
pixels are gone from the live buffer. The **frame ring** keeps the last N
completed native indexed frames in RAM (default **128 MiB ≈ 827 PAL frames ≈
16.5 s** at 50 fps; `[debug] frame_ring_memory_mb`, `0` disables).

```text
N frame-ring-info
N frame-ring-record <on|off>
N frame-ring-clear
N get-frame-at frame=<n>|cycle=<n> [format=argb8888|indexed8]
```

- Target **must** be named: `frame=916` or `cycle=15659138` — a bare number is
  ambiguous and rejected/wrong by design.
- Lookup = nearest retained frame **at or before** the target. Past newest →
  clamp to newest. Older than window → `not-found` (never a substituted
  neighbour).
- Payloads match `get-frame` for the same format (same conversion path).
- Answers **immediately** and work **while running** (own mutex; no deferred
  slot). Pause first if you need a stable window.
- **Warp (turbo 3) does not record** (live pixel rendering off). `load-state`
  clears the ring.
- Cost is mostly resident memory; push is ~+0.22% of turbo-2 free-run.

Agent recipe after a late human pause:

```text
1 pause
2 wait-paused 2000
3 frame-ring-info
4 get-frame-at frame=<newest-from-info> format=indexed8
5 history-find cycle=<cycle-from-that-frame> limit=64
```

Coop inbox: `scrub [count]` dumps PNGs of the retained window;
`frame <n>` pulls one frame + its cycle for history (see coop-debug).

### 6.7c VIC ring (why did that frame look wrong?)

**C64M/6** — per-line end-of-line derived VIC state. The frame ring shows *that*
a frame is wrong; this shows *why*: which sprites had fetched data, badline,
and especially **sprite X including the `$D010` MSB actually latched for
painting that line** (`spr_x=`). A one-frame left-edge flash is often latched
X disagreeing with what the game wrote — pixels + CPU history alone cannot
prove that; the VIC ring can.

```text
N vic-ring-info
N vic-ring-record <on|off>
N vic-ring-clear
N vic-ring-find [frame=<n>] [raster=<line>|<first>-<last>] [limit=1..2048]
```

- Payload: counted `data vic-ring` of **newline key=value text** (agent-readable;
  not HST1 binary). One record per raster line, oldest-first.
- All find keys optional. Omit `frame=` to match a raster window **across**
  retained frames (per-line effect over time).
- Immediate answers, OK while running (own mutex); pause for a stable window.
- `load-state` clears the ring.
- Default budget **16 MiB** (~161k lines ≈ 500 PAL frames / ~10 s);
  `[debug] vic_ring_memory_mb` (`0` disables — only way to recover the line cost).
- Cost ~**2.64%** turbo-2 free-run; negligible at turbo 1.  
  **`vic-ring-record off` stops storing but does not remove the per-line build
  cost** — use budget `0` for free.

Example record fields (abbrev.): `frame= raster= cycle= badline= spr_en=
spr_vis= spr_act= spr_x=0050,... spr_y= spr_ptr=` — eight sprites, index 0 first.

**Full forensic chain (one machine-cycle axis):**

```text
scrub / get-frame-at   → which frame, pixels, cycle=
vic-ring-find frame=N  → latched spr_x / enable per line of that frame
history-find cycle=…   → what the CPU wrote around that moment
```

Coop: `vic <frame> [first-last]` appends the text records into the snap.

Default RAM for history + both rings is large (~400 MiB class). Lower budgets
in `c64m.ini` `[debug]` if the host is tight.

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
7. Observe: get-cpu, get-memory, get-vic, get-frame / get-frame-at,
   vic-ring-find, history-*, break-create … when=… for nuanced stops.
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
| Rebuild + start like a human (BASIC-run) | `assemble basic-run=1 reset=1 /ABS/.../src/main.asm` (fixes pointers + pastes `RUN`) |
| Assemble only, inspect before running | `assemble reset=1 /ABS/.../src/main.asm` then breakpoints / `run` |
| Hot-patch without reset | **Avoid** unless you know state; prefer `reset=1` when re-assembling |
| Offline PRG for human play | `tools/build-prg.sh` / `tools/play.sh` |

**Do not** use `auto-run=1 run-address=$080d` — that pokes PC into ML, skips BASIC
`RUN`/`SYS`, and leaves KERNAL state wrong (e.g. cursor). Prefer `basic-run=1` or
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
| Assembler auto-run to `$080D` | Use `basic-run=1` instead (or offline PRG + `--autorun`) |
| Assemble then plain `RUN` won't start (assemble ≠ LOAD) | `assemble basic-run=1 …` fixes `TXTTAB`/`VARTAB`/`ARYTAB`/`STREND` + pastes RUN for you |
| `screen_put_xy` + loop counters in `tmp1`/`tmp2` | **Never** — put_xy clobbers `tmp*`; use dedicated ZP (`draw_i`, `draw_j`, …) |
| Keyboard Space matrix wrong | Space: PRA=`$7F` (row 7), PRB bit 4 (`$10`) — see `sys/const.asm` |
| Second wait while one active | `error busy` — serialize waits |
| `get-frame` at turbo 3 | Debug-only geometry; use turbo 1 or 2 |
| Frame ring at turbo 3 | Does not record; lower turbo for visual truth |
| Late pause, no ring scrub | Use `frame-ring-info` + `scrub` / `get-frame-at` — aftermath CPU alone misses one-frame glitches |
| Wrong pixels, no VIC ring | After finding the bad frame, `vic <n>` / `vic-ring-find` for latched `spr_x` vs game `$D000`/`$D010` writes |
| `vic-ring-record off` for speed | Does **not** remove line cost; set `vic_ring_memory_mb=0` |
| `when=` with spaces | No whitespace inside the condition; `value` invalid on `exec` |
| Client default port 17652 | Always `Ctl(port=6510)` for this project |
| Edit `../c64m/` | **Never** — read-only reference only |
| `c64masm -o build/railgunner.prg` | Writes **raw** (no load header). Use `make prg` / `build-prg.sh`. Make may skip rebuild; play RUN no-ops |
| Human `make play` after agent session | Agent live-assembles into the emu only; offline PRG is separate — `make prg` if sources changed and you play offline |

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

## 12. Cooperative live debug (intermittent glitches)

When the human sees a rare sprite/mux glitch while playing: **they pause**, the
watcher writes an evidence pack, you analyze and steer via an inbox file.
Full protocol (topology, inbox commands, RailGunner regions):
**[`coop-debug.md`](coop-debug.md)**.

```bash
make coop
# On freeze: build/debug/snap-NNN.txt
# Steer: echo resume >> build/debug/coop_inbox
```

Do not commit coop tooling until a freeze→snap→resume path is proven live.

---

## 13. Quick reference card

```bash
# Human play
tools/play.sh

# Agent session
tools/agent_session.py

# Coop glitch hunt (see coop-debug.md)
make coop

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
get-frame-at frame=N|cycle=N [format=…]
frame-ring-info | frame-ring-record on|off | frame-ring-clear
vic-ring-info | vic-ring-find frame=N [raster=A-B] | vic-ring-record on|off
joystick <1|2> <mask>
set-turbo 1|2|3
history-record on|off | history-find ... | history-read ... | history-info
break-create <access> $addr actions=break when=<term>[,<term>…]
save-state <path> | load-state <path>
quit-client
```

Sticky completion events (safe after fast ops):  
`assemble-complete`, `assemble-error`, `step-complete`, `run-complete`,
`reset-complete`, `load-state-complete`, `save-state-complete`, `paused`, `running`.

---

## 14. c64m friction log (dogfood feedback)

RailGunner's second purpose is to **dogfood c64m**: agents are developers using
the tool they built (see [`README.md`](README.md) → Project goal). When using
c64m is awkward, misleading, or forces a repeated workaround, **record it here**
so the c64m team can improve developer-friendliness. This is feedback, not a
patch queue — **never edit `../c64m/`** (repo boundary rule).

**How to add an entry:** date it, describe what you *did*, what c64m *did*, why
it was friction, and a concrete suggested improvement. Keep symptoms
reproducible (exact command + response). Mark severity (papercut / slows-work /
blocks-work). Cross off (`~~struck~~ fixed in c64m <ref>`) when resolved
upstream — do not delete history.

### ~~2026-07-28 — `lsr <zp>` / `lsr $nn` emits opcode only (no operand byte)~~

**Fixed in c64m 638d3c9** (with a related `ldx $nn,y` / `stx $nn,y` promotion
bug). Root cause: `lsr` carried `width = 0` in the assembler opcode table, so
`lsr $nn` wrote a lone `$46`. Also: zeropage,Y was always promoted to
absolute,Y (`ldx $nn,y` grew `$B6`→`$BE`; `stx $nn,y` hard-errored). Standing
`test_assembler_opcode_matrix` + gated regressions. Verified: `c64masm -v` on
`lsr $03` → `46 03`.

- **Severity:** blocks-work (silent wrong code).
- **Did:** assembled `lsr tmp1` / `lsr $4d` / `lsr $03` in game `mul8x8` and in
  minimal repros with `c64masm -v`.
- **c64m did:** emitted a lone `$46` (LSR zp opcode) with **no** address byte.
  Following bytes (`bcc` rel, etc.) were then mis-decoded at runtime. By
  contrast `asl $03`, `ror $03`, `rol $03`, `inc $03`, `lsr a`, and
  absolute `lsr $0300` all emit full instructions.
- **Friction:** silent mis-assembly — no error, PRG “succeeds”, game logic
  reads as random ZP corruption. RailGunner symptom: wave kill quotas became
  `$FE/$FF/$BF`, wave never cleared, only top-half quads (W0 mask) forever.
- **Workaround (historical):** never `lsr <zp>`; use `lda zp / lsr a / sta zp`.
- **Suggested improvement:** (landed) emit ZP operand; zp,Y only when the opcode
  has it; coverage matrix.

### ~~2026-07-26 — ARGB framebuffer read closes the control connection~~

**Resolved in c64m `9607995`.** The native indexed framebuffer now expands through
the shared ARGB path, and nonblocking socket writes retry temporary backpressure.
Leave this historical friction entry struck; a fresh end-to-end recheck is no
longer a prerequisite for using the service.

- **Severity:** slows-work.
- **Did:** paused a visible c64m session, successfully read
  `get-frame format=indexed8` (504×312, 157248 bytes), then opened a new client
  and requested `get-frame format=argb8888`.
- **c64m did:** closed the connection while the vendored client was reading the
  declared payload (`EOFError: connection closed`); no ARGB frame was returned.
- **Friction:** indexed output proves the framebuffer RPC is otherwise
  available, but visual QA needs an additional palette conversion when the
  direct full-colour format disconnects.
- **Suggested improvement:** keep the connection open and return the complete
  ARGB payload, or return a protocol error before the data header if the
  requested payload cannot be delivered.

### ~~2026-07-26 — `message_queue_push` NULL SIGSEGV on runtime thread (control stress)~~

**Resolved 2026-07-27 — two separate concerns:**

- **`run-to-raster` desync + `CLOSE_WAIT` wedge: fixed in c64m febed99.**
  run-to-raster was missing from the response-formatting tail switch, so it
  posted a zeroed reply with wire id `0` (the "unsolicited `0 ok`"); id 0 never
  matched the handler's outstanding set, so on disconnect the sole-client
  connection handler looped forever draining and wedged the port for all future
  clients. Fixed, plus a bounded post-disconnect drain so one lost/misrouted
  response can never wedge the port again. Regression test
  `run_to_raster_control_integration`.
- **NULL SIGSEGV: closed as CNR (could not reproduce).** Did not reproduce under
  ASan+UBSan *or* TSan control-stress matching this report
  (pause/step-frame/run-to-raster/bulk `get-memory`+`set-memory`/joystick,
  turbo 2, no `get-frame`) — 0 races, 0 sanitizer hits. `rt->event_queue` is
  single-producer and joined before destroy (`runtime_destroy` → `runtime_stop`
  → `thread_join` precedes `message_queue_destroy`), so a NULL `items` on a live
  queue implies heap corruption from elsewhere, which stayed unlocated. Reopen
  with a fresh IPS + a concrete repro if it recurs.

- **Severity:** blocks-work (process dies; session must be relaunched).
- **Did:** RailGunner sprite-mux review over the control port (windowed c64m,
  turbo 2): many `pause` / `run` / `step-frame` cycles, `run-to-raster`, bulk
  `get-memory` / `set-memory`, joystick edge fires into PLAY. **No**
  `get-frame` (indexed or ARGB).
- **c64m did:** native crash — macOS IPS `c64m-2026-07-26-233608.ips` (also
  same stack earlier: `c64m-2026-07-26-212813.ips`).
  - `EXC_BAD_ACCESS` / `SIGSEGV`, `KERN_INVALID_ADDRESS at 0x0`
  - Faulting thread: `c64m-runtime`
  - Stack: `_platform_memmove` → `message_queue_push` → `runtime_thread_main`
    → SDL thread wrapper
- **Not the ARGB issue:** that bug closed the control socket mid large
  `get-frame` payload; here the process segfaults with no frame request.
- **Related session friction (may be separate):** `run-to-raster` responses
  interleaved with unsolicited `0 ok`, so the vendored client hit
  `AssertionError: id mismatch` and left the TCP connection in `CLOSE_WAIT`
  until kill/restart — looks like a hang even when the binary has not yet
  crashed.
- **Friction:** agent remote debugging cannot rely on long instrumented
  sessions; a queue push on the runtime thread should never NULL-deref.
- **Suggested improvement:** null-safe / lifetime-safe event publish
  (`rt->event_queue` vs destroy order); ASan/TSan run under pause–step–raster
  control stress; refuse or order-correct teardown while `c64m-runtime` still
  publishes. Separately: stable request-id matching for `run-to-raster` /
  async `ok` events so one desync does not wedge the sole control client.

### 2026-07-26 — `agent_session.py` retains the control server's sole client

- **Severity:** slows-work.
- **Did:** launched `tools/agent_session.py` normally, then opened a second
  `Ctl(port=6510)` process to inspect mux counters while the visible session
  remained active.
- **c64m did:** accepted only the helper's existing connection; the inspection
  client was reset/hung because the control server is single-client.
- **Friction:** the helper says the session is live for breakpoints and memory
  inspection, but it keeps its connection without exposing an interactive
  command path. `--once` releases the client but this execution environment
  reaps the detached emulator, so the practical workaround was to launch
  windowed `tools/c64m` directly and perform boot plus all inspection through
  one client process.
- **Suggested improvement:** give `agent_session.py` an interactive command
  loop, a command-script option, or explicitly release/reconnect its client
  after boot. Alternatively support multiple localhost control clients.

### ~~2026-07-26 — `assemble` success echoes the *default* origin, not where code landed~~

**Fixed in c64m 241cea1.** `assemble-complete` now reports the actual emitted
origin (lowest emitted byte), e.g. `ok address=$0801`, not the requested
`address=` default the source overrides.

- **Severity:** papercut (actively misleading during debugging).
- **Did:** `assemble reset=1 auto-run=0 /ABS/src/main.asm` with **no** `address=`
  (source sets segments: `BASIC $0801`, `CODE $080d`).
- **c64m said:** `ok address=$8000`.
- **Reality:** code assembled to `$080D` and ran from there —
  `find-symbol start` → `$080D`; the game booted and rendered correctly. `$8000`
  is just the ignored host default being echoed back.
- **Friction:** the success line implies code is at `$8000`. An agent trusting
  it would set breakpoints / read memory at the wrong place. The one field in the
  response is the one you'd most want to trust, and it's wrong whenever the
  source overrides the default (which, for any real program, is always).
- **Suggested improvement:** report the **actual emitted origin / entry** (e.g.
  first `.segment`/`* =` origin, or the exported `start`/run-address), or list
  per-segment origins — not the requested `address=` when the source overrode it.

### ~~2026-07-26 — `assemble` ≠ LOAD boot ceremony is unassisted~~

**Fixed in c64m 241cea1.** New `basic-run=1` assemble option (GUI "Run BASIC
(paste RUN)", INI `[assembler] basic_run`) fixes the BASIC pointers as a LOAD
would and RUNs the program through the BASIC editor via paste — no PC poke, no
manual `$2B`/`VARTAB` poking. Mutually exclusive with `auto-run`; it also skips a
redundant reset when the machine is already at a fresh READY prompt. The four
ceremonial steps collapse to `assemble basic-run=1 reset=1 <src>`.

- **Severity:** slows-work (every agent rediscovers it; wrapped by
  `agent_session.py`, but manual over the raw port).
- **Did:** live `assemble` of a BASIC-stub program, then wanted to `RUN` it like
  a loaded PRG.
- **c64m behaviour:** assemble writes bytes to RAM but does **not** update BASIC
  pointers, so `RUN` sees no program. You must poke `$2B` (TXTTAB=`$0801`) and
  `VARTAB/ARYTAB/STREND=$080D`, `run`, then `paste-text-data "RUN\r"`.
- **Friction:** four ceremonial steps between "assembled" and "running like the
  human sees it," with a dedicated pitfalls-table entry (§9) and a hard-won-lesson
  war story (§10) devoted to getting it wrong. That's a lot of doc for a step the
  tool could own.
- **Suggested improvement:** an `assemble` option or one-shot command that stages
  the image *as a LOAD would* (fix BASIC pointers) and optionally `RUN`s it via
  the BASIC path — without the forbidden auto-run-PC poke. Removes a whole class
  of "why won't it start" mistakes.

### 2026-07-28 — Purple Q1 pop on kill/despawn (slot reuse)

**Fixed in RailGunner.** snap-011: purple A SoA Y `$4A`→`0` while VIC flashed
Y=`$CB`. Cause: `retire_and_try_free` freed the slot same tick; spawn recycled
it before the front plan dropped the old pose. Fix: always defer free to `reap`.

### 2026-07-28 — One-frame player jump (mux missed raster)

**Fixed in RailGunner.** Coop snap-009: scrub + VIC ring showed f1019 with
wrong `spr_en`/`spr_vis` and player-looking X while SoA `obj_x` walked
smoothly. Cause: mux command IRQ overrunning past the next job line skips
that command for the frame. Fix: catch-up chain in `mux_irq` + clear/park
sprite X/Y so stale lanes cannot paint.

### 2026-07-28 — Main lag / mux PLAN_BUSY under load (partial game fix)

**Backlog growth fixed; frame-budget overrun separately profiled.** Coop
session snap-007: level 4, 6 mux
commands, `logic_ticks_pending=$C9`, `mux_last_error=PLAN_BUSY`, frame ring
showed motion freezes ~1–2 s before pause while cycle spacing stayed 19656.

- **`game_init_enter`:** `objects::init` wiped `display_hz`; now SEI + re-detect
  + `sprite_mux_irq::init`.
- **`main_loop`:** drop logic-tick backlog (one real-time tick per loop) instead
  of permanent lag.

That prevented permanent accumulated lag but did not make heavy ticks fit.
Snap-021's phase markers measured a six-object mux build at about 14,600
non-IRQ cycles, including 6,873 in the fixed 256-row Y bucket pass and 3,496
in command emission. Gameplay used roughly another 7,000 cycles. The bucket
pass, emission masks, and bullet draw address path were optimized afterward;
repeat the phase capture under the same workload before calling 50 Hz fixed.

### 2026-07-28 — Upstream dogfood wins (use these; do not re-discover)

c64m landed the forensic stack this project was improvising around. Prefer these
over ad-hoc workarounds; keep friction entries only for *remaining* pain.

| Feature | Protocol | RailGunner use |
|---------|----------|----------------|
| Flight recorder `history-*` | C64M/3 | Bus/write forensics after freeze; `hist` in coop |
| Guarded BP `when=` | C64M/4 | IRQ-only / raster-band / value-bit stops; coop `arm … when=` |
| Frame ring `get-frame-at` | C64M/5 | One-frame glitches after late pause; coop `scrub` / `frame` |
| VIC ring `vic-ring-find` | C64M/6 | Latched per-line `spr_x` / enable; coop `vic <frame>` |
| `basic-run=1` assemble | earlier | `agent_session.py` boot — no pointer ceremony |
| Assembler `locked` / `reclaim=` segments | earlier | Pin VIC regions; overlay title RAM intentionally |

If a glitch is visual and the human paused late: **`scrub` → `frame n` →
`vic n` → `hist` on that cycle**. If the glitch is “wrong write under a
condition”: **`when=`** rather than raw address break + hope.
