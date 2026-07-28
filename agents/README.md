# RailGunner agent handoff

This directory is the concise, implementation-oriented handoff for agents working
on **RailGunner** — a Commodore 64 game written in 6502 assembly and developed
against **c64m** (emulator, debugger, assembler, remote API) at `../c64m/`.

Game design and technical intent live here. The c64m **source and tests** remain
authoritative for the toolchain; if a handoff doc and the tool disagree, trust
the tool (and fix the handoff).

## Read in this order

1. **`railgunner.md`** — top-level design brief (what the game is, layout,
   mechanics, technical approach).
2. **`roadmap.md`** — development stages, game flow (modes), **where we are**,
   and the ordered **Next steps** list (default work order — prefer this over
   freestyle features). Living guide; detail docs hang off it later.
3. **`repo-layout.md`** — where source lives, what already exists, Stage 2 files
   still to add, include rules. Create new files only under this plan.
4. **`assembler-syntax.md`** — **required before writing any `.asm`**. c64m
   assembler language only (not ACME / ca65 / KickAsm / 64tass unless listed
   there). Syntax, directives, macros, scopes, segments, pitfalls.
5. **`build-debug.md`** — **required before driving the emulator**. Play vs
   agent launch, remote API recipes, **pitfalls / hard-won lessons** (reset,
   BASIC pointers, ZP clobber, keyboard matrix). Read the pitfalls before
   debugging input or screen code.
6. Component handoffs relevant to the task. For graphical objects, hardware
   sprites, the mux, or collision attribution: **`objects-sprites.md`** (ABI)
   plus **`sprite-mux-status.md`** / **`sprite-mux-issues.md`** (live status).
7. Source under `src/` (root unit: `src/main.asm`) and samples under
   `../c64m/samples/` when learning idioms.

Do not invent assembler syntax. If something is missing from
`assembler-syntax.md`, check `../c64m/manual/manual.md` (Assembler section), then
update the handoff so the next agent does not rediscover it.

## Document index

| Doc | Role |
|-----|------|
| [`railgunner.md`](railgunner.md) | Top-level design brief: screen, controls, combat, bonuses, wave data, HOW |
| [`roadmap.md`](roadmap.md) | Stages, flow, **where we are**, ordered **Next steps**, matrix, open questions |
| [`repo-layout.md`](repo-layout.md) | Repo tree, what exists vs Stage 2 files to add, include rules |
| [`objects-sprites.md`](objects-sprites.md) | Pool/mux design + ABI (implemented; consumers still Stage 2+) |
| [`sprite-mux-status.md`](sprite-mux-status.md) | Implemented mux status, demos, verification, remaining stress tests |
| [`sprite-mux-issues.md`](sprite-mux-issues.md) | Mux review findings / integration hazards |
| [`assembler-syntax.md`](assembler-syntax.md) | c64m 6502 assembler syntax for all game source |
| [`build-debug.md`](build-debug.md) | Launch emulator, remote assemble, debug/control recipes for agents |
| [`coop-debug.md`](coop-debug.md) | **Cooperative live debug** — human pause + agent evidence packs (`coop_debug_rg`) |

**Optional / not in the handoff path:** [`reviews/`](reviews/) holds post-stage
code reviews (historical + disposition tables). Agents should **not** treat
them as required reading or as a work queue ahead of `roadmap.md`.

## Source tree (summary)

| Path | Role |
|------|------|
| `src/main.asm` | Sole assemble root; includes everything else |
| `src/boot/` | Cold init / bring-up |
| `src/sys/` | ZP, constants, IRQ, input, memory map |
| `src/frontend/` | Title, high scores, score entry, game over, victory |
| `src/game/` | Play-mode logic (player, drones, collision, waves, …) |
| `src/render/` | Character playfield, bullets, HUD |
| `src/sprite/` | Player/drone sprites, multiplexer |
| `src/data/` | Tables, strings, embeds |
| `assets/` | Art / binary blobs for `.incbin` |
| `tools/` | Symlinks to c64m binaries/client, `run-emulator.sh`, future generators |
| `build/` | Assembler outputs (not hand-edited) |

Full rationale and vertical-slice file list: **`repo-layout.md`**.  
Build/run/debug: **`build-debug.md`**. Tool path notes: **`tools/README.md`**.

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

## Two launch paths

| Path | Who | What | Command |
|------|-----|------|---------|
| **Play (user)** | Human testing the game | Make rebuilds assets if needed, offline `c64masm` → `build/railgunner.prg` → windowed c64m `--prg --autorun`. No remote script stays attached. You just play. | **`make play`** (or `tools/play.sh` / `tools/run-emulator.sh`) |
| **Agent session** | Agent chasing a bug | Windowed c64m **with control port**, live `assemble basic-run=1` (assemble → fix BASIC pointers → paste `RUN`), then breakpoints / memory / CPU / frames. | `tools/agent_session.py` |

```bash
# You (human): assets + PRG + start the game — no OPT+SHIFT+A, no typing RUN
make play
# (or: tools/play.sh)

# Rebuild PRG only (still refreshes title bins if PNGs changed)
make

# Asset converters (screens / charset / sprites groups)
make assets
make screens

# Agent: instrumentable session (port 6510), window still visible
tools/agent_session.py              # start + assemble basic-run=1 (one-command boot)
tools/agent_session.py --attach     # emu already up; re-assemble + basic-run (reset default)
tools/agent_session.py --verify     # smoke title screen, then exit
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
| Emulator | `tools/c64m` → `../c64m/build/c64m` |
| **Play (user)** | `tools/play.sh` |
| Build PRG only | `tools/build-prg.sh` → `build/railgunner.prg` |
| **Agent session** | `tools/agent_session.py` |
| CLI assembler | `tools/c64masm` |
| Control client | `tools/c64_control_client.py` |
| Project INI | `c64m.ini` (ROMs, Assembler tab defaults; auto_run=no) |
| c64m manual (read-only) | `../c64m/manual/manual.md` |
| Control protocol (read-only) | `../c64m/agents/control-port.md` |

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
