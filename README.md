# Rail Gunner

A Commodore 64 rail shooter written in 6502 assembly, built against **c64m** — emulator, debugger, and assembler.

A **C core** (`src/core/`) was written from those 6502 sources. Both the **SDL** build (`src/sdl/`) and the native **Acorn Archimedes** port (`src/archie/`) use that core. The Archimedes port targets A3010 / ARM250, 2 MB RAM and RISC OS 3.11, with native graphics, keyboard input and sound.

This project was made by AI. **Grok** wrote essentially all of the game code. The **sprite multiplexer** was written by **Codex**. **Claude** reviewed the work and made the improvements to **c64m** that came out of building and debugging this game.

**Codex** made the **Archimedes port**.

YouTube Video: https://youtu.be/UlGNZt61dxk

---

## Why this exists

Two experiments in one:

1. **Can agents ship a real C64 assembly game from prompts?** The human produces direction and playtests; the agents write and fix the code.
2. **Dogfood c64m.** The same class of agents that built the emulator and assembler now *use* them — assemble offline, run the window, attach the remote debugger, hunt bugs under pressure. Friction in the toolchain is a first-class finding, not a side note.

Rail Gunner is the game that falls out of that loop: something you can actually play, and something that stresses the tools hard enough to improve them.

---

## The game

You are a gunner locked to a cross of rails. Drones come in from the edges. Some chew the rail; red ones dump **cargo** that arms **mines** at the hub. Four mines and a centre pass ends you. The rail collapsing under damage ends you too.

It is a game about **quick decisions under pressure**:

- **Defend the rail or yourself** — every shot and every second of movement is a trade.
- **Manage parcels** — power-ups arrive mid-wave: points, 2× score, 2× damage, repair, extra life, and **clear**.
- **Think ahead on clears** — pick up a clear when cargo is stacking, not when the hub is empty. Clear *arms* on pickup and wipes stacks/mines on the **next centre pass**, so timing matters as much as collecting it.
- **Survive the quota** — clear the kill bar, take the rank banner, and the next wave hits harder.

**Controls (C64):** joystick, or **WASD** + **Space**. Move along the rail you are on; push perpendicular to switch barrel (or mount the other rail at the cross). Hold fire for continuous shot.

**Controls (SDL):** arrows or **WASD**, **Space** to fire, **S** for the story, **I** for instructions, **Escape** for RUN/STOP. This port is keyboard only.

**Controls (Archimedes):** the same keyboard controls as SDL; **Ctrl-Q** quits and returns to RISC OS.

In-game story and instructions screens have the full fiction and enemy table; you do not need them to start playing.

---

## What you need

| Tool | Role |
|------|------|
| **make** | Build orchestration for C64, core, SDL and Archimedes targets |
| **Python 3** | Asset conversion, Archimedes packaging and helper scripts; PNG converters require Pillow |
| **c64masm** | Offline assembler (from c64m) |
| **c64m** | Emulator window to run the PRG |
| **C compiler** | `make core` and `make sdl` (C11) |
| **SDL2** | `make sdl` (`sdl2-config` on `PATH`). The C64 build does not need it |
| **ArchieSDK** | `make archie` and `make archie-package`; set `ARCHIESDK` to its installation root |
| **Arculator** | Optional emulator for `make archie-run`; set `ARCU_HOME` to its installation root |

Install the tools for the target you want to build. The Commodore 64 build needs
**c64m** as a sibling checkout. Core, SDL and Archimedes builds use the shared
C sources and `assets/c64/` without needing c64m. Archimedes uses ArchieSDK
instead of the host compiler and does not require SDL2.

**c64m must sit next to this repo** (sibling checkout), not inside it:

```text
parent/
  c64m/          ← build the emulator & assembler here first
  railgunner/    ← this project
```

Build c64m so these exist:

- `../c64m/build/c64m`
- `../c64m/build/am65` (offline assembler; the old `c64masm` name is gone)

### Symlinks in `tools/c64/`

`tools/c64/c64m`, `tools/c64/c64masm`, and a couple of shared Python helpers are **soft links** into that sibling tree:

```text
tools/c64/c64m      → ../../../c64m/build/c64m
tools/c64/c64masm   → ../../../c64m/build/am65
```

**Do they survive a round-trip through GitHub?** Yes on Unix and macOS. Git stores symlinks as mode `120000` with the *target path string* as content; clone restores real symlinks. They are not followed or inlined on push.

Caveats:

- The links are **relative**. They only resolve if `c64m` is still the sibling of `railgunner` after clone.
- The **targets must exist** — cloning both repos is not enough; build c64m first.
- On Windows, clones without symlink support often turn the links into plain text files holding the path. Recreate the links or point `PATH` at your c64m build.

---

## Build and play

From the `railgunner` root. `make`, `make play`, and `make coop` need c64m
built as a sibling. Core, SDL and Archimedes targets are independent of c64m:

```bash
make          # assets if needed → build/railgunner.prg
make play     # build, then open c64m with the PRG (autorun)
make coop     # build, then windowed emu + control port + live-debug watcher
make core     # headless C simulation, then tst/core traces
make sdl      # SDL2 window (needs SDL2). Not part of make or make play
make sdl-build       # build SDL without opening a window
make archie          # ARM2 executable, ELF and linker map (needs ArchieSDK)
make archie-run      # build and launch private A3010 Arculator deployment
make archie-package  # build !RailGunner and both release ZIPs
```

Useful variants:

```bash
make assets   # regenerate title / charset / sprite bins from PNGs
make clean    # remove C64/core/SDL outputs; retains Archimedes outputs
make archie-test        # host renderer comparisons (ASan/UBSan)
make archie-audio-test  # host sound comparisons (ASan/UBSan)
```

`make play` is the simple human path: rebuild if needed, launch a windowed emulator, and play. No control-port session, no typing `RUN`.

### Where it really shines: `make coop`

`make coop` is the human + agent debugging loop. You play; the agent has a live
hook into the paused machine (flight recorder, frame ring screenshots, memory,
breakpoints). That is how most of the hard bugs in this game got fixed — and
how c64m got better.

**How I use it:**

1. Run **`make coop`** and play.
2. See a bug → **pause** the emulator and leave it paused.
3. Ask an agent for **screenshots of the last few seconds** (the frame ring —
   a short history of what was on screen).
4. Point at **where in that screenshot chain** the glitch appears, and describe
   what is wrong.
5. The agent digs in while the machine stays frozen: scrub frames, dump state,
   arm watches, figure out the cause, **fix the code**, rebuild and re-test.

If something gets in the way — state not available at the right moment, a
query that takes too long, a missing command, an awkward ritual — that friction
is noted so **c64m can be improved**. That dogfood step is intentional: the game
is the load test for the tools the agents themselves depend on.

---

## Archimedes port

The native A3010 / 2 MB / RISC OS 3.11 frontend builds with `make archie`.
Use `make archie-run` for the private Arculator deployment and `make archie-package`
for `!RailGunner` and HostFS/native ZIPs under `build/archie/release`.
`ARCHIESDK` defaults to `$HOME/Develop/gitlab/archiesdk`; `ARCU_HOME` defaults to
`$HOME/Applications/arculator`. Override either on the make command line if needed.
The emulator keeps its configuration and HostFS inside `build/archie/arculator`;
open HostFS and `!RGDiag` to play. Extract `RailGunner-HostFS.zip` into HostFS,
preserving comma file-type suffixes, to use the packaged `!RailGunner` application.
On RISC OS, extract `RailGunner-RISCOS.zip` with an Acorn-aware unzip tool.

Cursors/WASD move, Space fires/starts/selects, S opens story, I opens instructions
and Ctrl-Q quits. The playable emulator release and packaged launch/exit checks
are complete. Occasional missed VSyncs are documented and accepted; actual
hardware validation remains pending. See [Archimedes instructions](src/archie/README.md)
and [release record](agents/archie-port.md).

## Layout (brief)

| Path | What |
|------|------|
| `src/c64/` | Commodore 64 6502 sources (`main.asm` is the assemble root) |
| `src/core/` | Portable C11 simulation of those rules. No SDL. Headless driver is `src/core/main.c` |
| `src/sdl/` | SDL2 window: 2× blit, three-voice samples, keyboard mapping. No gameplay rules |
| `src/archie/` | Native ARM2 frontend: banked Mode 9 graphics, three-voice synthesis, keyboard input and OS restoration |
| `assets/c64/` | Original art and converted blobs, shared by all frontends |
| `tools/c64/` | C64 build/play scripts and c64m symlinks |
| `tools/archie/` | Isolated SDK build, asset embedding, private emulator deployment and release packaging |
| `tst/c64/` | C64 sprite-mux demos, not the game PRG |
| `tst/core/` | Headless traces run by `make core` |
| `tst/archie/` | Renderer and sound comparisons against SDL references |
| `build/` | Generated PRG, `railgunner-core`, and `railgunner-sdl` |
| `build/archie/` | Native executable, ELF/map, generated assets, emulator files and test outputs; `release/` holds the app and ZIPs |
| `agents/` | Agent handoffs — design, roadmap, assembler notes (for AI sessions, not required to play) |

---

Title screen, font and sprites by Grok.  Cleanup and tile graphics by Stefan.  
Code by Grok & Codex.  Support from Claude.  
Archimedes port by Codex, completed 11 October 2026.\
Music and Sound Effects by Grok.  
No human read, changed or edited the code in the making of this game.  
Original C64 game written over 5 days with 1st commit on 26 July 2026.\
Produced by Stefan Wessels, 2026.
