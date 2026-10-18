> **IIgs: start with [beam-renderer handoff](iigs-beam-renderer-handoff.md).**
> The current native game flashes; cleanup is done, beam-following repair is not.

# RailGunner agent handoff

The original game is feature-complete. The IIgs port still needs renderer repair;
see the handoff above.

- `src/c64/` is the Commodore 64 game in 6502, developed against **c64m**
  (emulator, debugger, assembler, remote API) at `../c64m/`.
- `src/core/` is the C simulation written from those 6502 sources.
- `src/sdl/` is the first platform frontend on that core. Further ports would
  be new frontends on `src/core/`, siblings of `sdl/`. The user-approved IIgs
  exception uses native ORCA/M65816 gameplay/rendering; see `iigs-beam-renderer-handoff.md`
  and `src/iigs/README.md`. Keep the shared C core for other ports and oracles.

For the IIgs next task, read [`iigs-beam-renderer-handoff.md`](iigs-beam-renderer-handoff.md).

This directory is the concise, implementation-oriented handoff for agents.

Game design and technical intent live here. The c64m **source and tests** remain
authoritative for the toolchain; if a handoff doc and the tool disagree, trust
the tool (and fix the handoff).

## Read in this order

1. **`level-rework.md`** — shipped play loop (levels, HUD, mines, parcels).
2. **`railgunner.md`** — original design brief. Defer to level-rework on conflict.
3. **`roadmap.md`** — historical build map. The game is finished. Do not treat
   an open row as work.
4. **`repo-layout.md`** — where source lives (`src/c64`, `src/core`, `src/sdl`)
   and the include rules.
5. **`assembler-syntax.md`** — **required before writing any `.asm`**. c64m
   assembler language only (not ACME / ca65 / KickAsm / 64tass unless listed
   there). Syntax, directives, macros, scopes, segments (including `locked` /
   `reclaim=`), pitfalls.
6. **`build-debug.md`** — **required before driving the emulator**. Play vs
   agent launch, remote API recipes (protocol **C64M/8**: history, guarded
   `when=` breakpoints, **frame ring**, **VIC ring**), **pitfalls / hard-won
   lessons** (reset, BASIC pointers, ZP clobber, keyboard matrix). Read the
   pitfalls before debugging input or screen code.
7. **`coop-debug.md`** when hunting intermittent visual/mux bugs with a human
   at the window (`make coop`, evidence packs, `scrub` / `frame` / `vic` /
   `when=`).
8. **`archie-port.md`** and **`../src/archie/README.md`** for the completed
   Archimedes frontend, performance decisions, packaging and successful hardware
   evaluation. The execution plan also retains historical measurements.
9. Component handoffs relevant to the task. For graphical objects, hardware
   sprites, the mux, or collision attribution: **`objects-sprites.md`** (ABI)
   plus **`sprite-mux-status.md`** / **`sprite-mux-issues.md`** (historical
   C64 mux record; SDL does not use the mux).
10. Source under `src/c64/` (root unit: `src/c64/main.asm`) and samples under
   `../c64m/samples/` when learning idioms.
11. **`c64-to-sdl.md`** — finished record of the C core and the SDL frontend
    (accepted differences, what was left on the C64). The port is done.

Do not invent assembler syntax. If something is missing from
`assembler-syntax.md`, check `../c64m/manual/manual.md` (Assembler section), then
update the handoff so the next agent does not rediscover it.

## Document index

| Doc | Role |
|-----|------|
| [`level-rework.md`](level-rework.md) | **Shipped loop:** levels, HUD, death/mines, parcels (prefer over the original brief and over roadmap sketches) |
| [`railgunner.md`](railgunner.md) | Original design brief (screen, controls, bonuses vision); defer to level-rework on conflict |
| [`roadmap.md`](roadmap.md) | Historical build map. Feature work is finished |
| [`repo-layout.md`](repo-layout.md) | Repo tree, current C64 files, include rules |
| [`objects-sprites.md`](objects-sprites.md) | Pool/mux design + ABI (implemented; the game consumes it) |
| [`sprite-mux-status.md`](sprite-mux-status.md) | C64 mux implementation record and demos. Historical |
| [`sprite-mux-issues.md`](sprite-mux-issues.md) | Mux review findings / integration hazards |
| [`assembler-syntax.md`](assembler-syntax.md) | c64m 6502 assembler syntax for all game source |
| [`build-debug.md`](build-debug.md) | Launch emulator, remote assemble, **C64M/8** recipes (history, `when=`, frame + VIC rings, inspect mode), friction log |
| [`coop-debug.md`](coop-debug.md) | **Cooperative live debug** — human pause, `scrub`/`frame`/`vic`, guarded `arm`, evidence packs |
| [`archie-port.md`](archie-port.md) | Archimedes implementation and release record, accepted performance limits, passed hardware evaluation |
| [`c64-to-sdl.md`](c64-to-sdl.md) | **Finished port record:** `src/core` from the 6502 sources, `src/sdl` as the first platform frontend |

**Optional / not in the handoff path:** [`reviews/`](reviews/) holds post-stage
code reviews (historical + disposition tables). They are not a work queue.
`roadmap.md` is not one either.

## Source tree (summary)

| Path | Role |
|------|------|
| `src/c64/` | Commodore 64 game. Sole assemble root is `src/c64/main.asm` |
| `src/core/` | Portable C11 simulation of the C64 rules. No SDL. Headless driver is `src/core/main.c` |
| `src/sdl/` | First platform frontend on the core: window, blit, samples, keys. See [`c64-to-sdl.md`](c64-to-sdl.md) |
| `src/archie/` | Archimedes frontend, native sound and packaged application; emulator and A3010 hardware evaluation passed. See [`archie-port.md`](archie-port.md) and `src/archie/README.md` |
| `src/iigs/` | Native IIgs port in progress; see [beam-renderer handoff](iigs-beam-renderer-handoff.md) |
| `src/c64/main.asm` | Sole C64 assemble root; includes everything else |
| `src/c64/boot/` | Cold init / bring-up |
| `src/c64/sys/` | ZP, constants, IRQ, input, memory map |
| `src/c64/frontend/` | Title, high scores, score entry, game over, victory |
| `src/c64/game/` | Play-mode logic (player, drones, collision, waves, …) |
| `src/c64/render/` | Character playfield, bullets, HUD |
| `src/c64/sprite/` | Player/drone sprites, multiplexer |
| `src/c64/data/` | Tables, strings, embeds |
| `assets/<platform>/` | Art for one machine. C64 blobs are `assets/c64/` |
| `tools/<platform>/` | Host scripts for one machine. C64 is `tools/c64/` |
| `tst/c64/`, `tst/core/` | C64 mux demos, and the headless traces `make core` runs |
| `build/` | Generated PRG, `railgunner-core`, and `railgunner-sdl`. Not hand-edited |

Full rationale and vertical-slice file list: **`repo-layout.md`**.  
Build/run/debug: **`build-debug.md`**. Tool path notes: **`tools/c64/README.md`**.

## Project goal (how to work)

This repo is an experiment with **two purposes**:

1. **Can an agent build a C64 assembly game from prompts only?** The human should
   **not** need to read assembly.
2. **Dogfood c64m.** c64m itself was written by agents (human as producer); here
   agents are *developers using the tool they built*. So the day-to-day
   experience of building against c64m — assembler, control port, debugger — is
   under test as much as the game is.

Workflow:

1. Human describes features / files **bug reports** (what they saw vs expected).
2. Agent implements and, when needed, **debugs via the remote control API** while
   the human watches the window.
3. Human re-tests with the simple **play** path.

**Because of purpose 2, surface friction.** When using c64m feels awkward,
misleading, or forces a workaround (a repeated ritual, a confusing message, a
missing convenience), note it — do **not** patch c64m from here (see the repo
boundary rule). Log it in **`build-debug.md` → "c64m friction log"** so the
c64m team can make the tool more developer-friendly. That log is a first-class
deliverable of this project, not a side note.

**Dogfood wins already in the toolchain (use them):** flight recorder
(`history-*`), guarded breakpoints (`when=`), frame ring (`get-frame-at` /
coop `scrub`), **VIC ring** (`vic-ring-find` / coop `vic` — latched per-line
sprite X), `assemble basic-run=1`, assembler `locked` / `reclaim=` segments.
Prefer these over ad-hoc rituals; details live in `build-debug.md` and
`coop-debug.md`.

## Two launch paths

| Path | Who | What | Command |
|------|-----|------|---------|
| **Play (user)** | Human testing the game | Make rebuilds assets if needed, offline `c64masm` → `build/railgunner.prg` → windowed c64m `--prg --autorun`. No remote script stays attached. You just play. | **`make play`** (or `tools/c64/play.sh` / `tools/c64/run-emulator.sh`) |
| **Agent session** | Agent chasing a bug | Windowed c64m **with control port**, live `assemble basic-run=1` (assemble → fix BASIC pointers → paste `RUN`), then breakpoints / memory / CPU / frames. | `tools/c64/agent_session.py` |

```bash
# You (human): assets + PRG + start the game — no OPT+SHIFT+A, no typing RUN
make play
# (or: tools/c64/play.sh)

# Rebuild PRG only (still refreshes title bins if PNGs changed)
make

# Asset converters (screens / charset / sprites groups)
make assets
make screens

# Agent: instrumentable session (port 6510), window still visible
tools/c64/agent_session.py              # start + assemble basic-run=1 (one-command boot)
tools/c64/agent_session.py --attach     # emu already up; re-assemble + basic-run (reset default)
tools/c64/agent_session.py --verify     # smoke title screen, then exit
```

When the agent **re-assembles without restarting the emulator**, use **`assemble reset=1`**
(default in `agent_session.py`). Hot-patching with `reset=0` leaves old PC/IRQ/game
state running against the new image.

**Never use `--headless`.** The window is how the human experiences the game.
Do not pass `--headless` in scripts, agent recipes, or docs for this repo.

Default control port (agent path only): **6510**.

## Toolchain

| Piece | Where |
|-------|--------|
| Emulator | `tools/c64/c64m` → `../c64m/build/c64m` |
| **Play (user)** | `tools/c64/play.sh` |
| Build PRG only | `tools/c64/build-prg.sh` → `build/railgunner.prg` |
| **Agent session** | `tools/c64/agent_session.py` |
| CLI assembler | `tools/c64/c64masm` → `../c64m/build/am65` |
| Control client | `tools/c64/c64_control_client.py` |
| Coop watcher | `tools/c64/coop_debug_rg.py` / `make coop` (`scrub`/`frame`/`vic`, guarded arms) |
| Project INI | `c64m.ini` (ROMs, Assembler tab defaults; auto_run=no) |
| c64m manual (read-only) | `../c64m/manual/manual.md` |
| Control protocol (read-only) | `../c64m/agents/control-port.md` (**C64M/8**) |
| Frame/VIC ring plan (read-only) | `../c64m/agents/frame-ring-plan.md` (Ring A + Ring B shipped) |

## Repo boundary (hard rule)

**Only edit files inside this RailGunner repo** (and ephemeral paths like `/tmp` if
needed for scratch). **Do not change anything under `../c64m/`** — not source, not
docs, not tests, not configs, not build trees. Under **no circumstances**.

- Read `../c64m/` as a **reference** (manual, samples, control-port docs, tool
  behavior). Prefer project handoffs under `agents/` when they cover the same ground.
- If a c64m tool bug or missing feature is discovered, **report it**; do not patch
  c64m from a RailGunner session.
- Handoffs that agents may update: **`agents/*.md` in this repo only** (e.g.
  `agents/build-debug.md`, `agents/README.md`). Those are not
  `../c64m/agents/*`.

## Doc hygiene

- Prefer updating these docs in the same change that invalidates them.
- Stale handoffs are worse than missing ones.
- Keep design, roadmap, layout, assembler syntax, and build/debug handoffs
  separate; do not mix long design prose into the syntax doc.
