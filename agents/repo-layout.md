# Repo layout — decision

**Status:** chosen. `src/c64/` is the Commodore 64 game: level-centric combat
(R1–R8), pool/mux, frontend, title music, and one-shot SFX. `src/core/` and
`src/sdl/` are the portable port in [`c64-to-sdl.md`](c64-to-sdl.md). The core
owns those rules. SDL blits the frame and synthesizes samples. This file is
the directory rules. C64 feature work still follows [`roadmap.md`](roadmap.md).  
**Companion docs:** [`railgunner.md`](railgunner.md) (design), [`roadmap.md`](roadmap.md) (stages/flow), [`build-debug.md`](build-debug.md) (run/debug), [`assembler-syntax.md`](assembler-syntax.md) (syntax), [`c64-to-sdl.md`](c64-to-sdl.md) (port).

## Decision summary

| Choice | Value |
|--------|--------|
| Platform trees | `src/<platform>/`, `assets/<platform>/`, `tools/<platform>/`, `tst/<platform>/`. This game is `c64`. Siblings stay out of `c64/` |
| Depth | Two levels under the platform root: `src/c64/<area>/<file>.asm` |
| Entry file | `src/c64/main.asm` — only file that sets origin / BASIC stub and `.include`s the rest |
| Binary / generated assets | `assets/c64/` (inputs for `.incbin` or generators) |
| Host tools | `tools/c64/` (c64m symlinks, launch script, generators) |
| Assemble output | `build/` (not source; may be gitignored later) |
| Agent docs | `agents/` (already present) |

**Why not a flat root or a single `game.asm`?**  
The design is not a demo loop. Frontend states, rail/bullet character pipelines, sprite mux, collision disambiguation, wave tables, and bonuses are independent enough to want separate files, and there will be enough of them that a flat dump becomes unsearchable.

**Why not deep nesting** (`src/c64/game/enemies/types/...`)?  
c64m `.include` paths are relative to the including file; deep trees make include lines brittle and encourage over-splitting. One area folder + clear filenames is enough. The platform directory is the one extra level: other versions of the game are siblings of `c64/`, not more folders inside it.

**Why `c64/` under `src/`, `assets/`, `tools/`, and `tst/`?**  
Each machine gets its own source, art, host scripts, and standalone tests. C64 is the only machine. `src/core/` and `src/sdl/` are the portable port, not another platform directory. `agents/` and `build/` stay at the repo root: handoffs are shared, and `build/` is generated output. `.include` lines inside `src/c64/` are unchanged (relative to the including file). `.incbin` from `src/c64/data/` is `../../../assets/c64/...`. Demos in `tst/c64/` include production code with `../../src/c64/...`. Do not put platform files directly in `src/`, `assets/`, `tools/`, or `tst/`.

---

## Component breakdown (from design brief)

### A. Bootstrap & system (~4–6 files)

Machine bring-up shared by every mode (title and play).

| Piece | Responsibility |
|-------|----------------|
| Entry / BASIC stub | `$0801` SYS stub, jump to init |
| Memory map & ZP | Segment layout, zero-page allocations, hardware constants |
| Init | VIC bank, charset pointer, screen clear, IRQ install |
| IRQ / frame | Raster frame clock, PAL/NTSC cadence, sprite-mux command owner |
| Input | Joystick + keyboard (WASD/space) → normalized dir/fire |

### B. Frontend / meta-game (~6–8 files)

Not specified in the first brief beyond “there will be screens”; we assume a real outer shell.

| Piece | Responsibility |
|-------|----------------|
| Mode / state machine | Title ↔ scores ↔ play ↔ game over ↔ victory ↔ score entry |
| Title | Title image/text, “press fire”, optional joy vs keyboard choice |
| Attract / high scores | Timed flip between title and score table |
| High score table | Display top scores; storage (RAM now, disk later if needed) |
| Score entry | Initials after a qualifying score |
| Game over | Loss presentation → back to scores/title |
| Victory | Optional clear-state presentation |
| Radio message | In-fiction ammo unlock (can live here or under game HUD text) |

### C. Playfield rendering (~5–7 files)

Background characters, not sprite logic.

| Piece | Responsibility |
|-------|----------------|
| Screen / layout | 40×25 cross rail layout, center gap, static structure draw |
| Rail damage draw | Damage levels as redefined chars / per-segment state → screen |
| Bullets draw | 8-char animation state machines per rail direction; cell occupancy |
| HUD | Score digits, health bar, ammo bar (incl. inactive gray), level, lives icons |
| Charset load | Copy/point to custom character definitions |

### D. Sprites & multiplexing (~4–6 files)

| Piece | Responsibility |
|-------|----------------|
| Graphical-object pool | 24 common slots; player fixed at logical slot 0; SoA state |
| Player sprite | Position on rail centerline, 2 barrel frames + 90° remap, composited shield/repair animation |
| Drone sprites | A=large, B=medium, C=small; `C < B < A` sprite-number priority |
| Sprite mux | Raster-driven reuse of all 8 HW slots; content targets ≤7 sprites/line |
| Sprite data | Pointer tables / `.incbin` frames |

Detailed layout, APIs, scheduling, collision attribution, and PAL/NTSC contract:
[`objects-sprites.md`](objects-sprites.md).

### E. Gameplay (~8–12 files)

Logic that mutates game state; may call into render/sprite modules.

| Piece | Responsibility |
|-------|----------------|
| Player move | Rail lock, barrel switch, center intersection mount rules |
| Shooting / ammo | Fire stream, cell throttle, ammo consume when unlocked |
| Drones / motion | Straight-line to rail, speed, spawn from edges/quadrants |
| Collision | `$D01F` sprite-BG; map HW lane to object; disambiguate bullet vs rail |
| Rail damage logic | A/B impact → segment damage; full rail destruction → game over |
| Health / lives | C blast radii (full/half), shield pool, respawn, lives |
| Bonuses | Parcel spawn on opposite arm, types, no same-type stack |
| Waves / levels | Table-driven waves: quadrants, speed, mix, overlap, bonus timing |
| Score | Points, multipliers |
| Play loop | Per-frame order while `mode == play` |

### F. Data / content (~6–12 files, grows with levels)

| Piece | Responsibility |
|-------|----------------|
| Wave tables | Per-wave / per-level binary-friendly tables |
| Char definitions | Rail, bullets, HUD bars, lives icon, damage frames |
| Sprite frames | Player, drones A/B/C, shield ring, repair orb, bonus parcel |
| Strings / PETSCII | Title, game over, victory, radio message, score entry UI |
| High score seed | Default table |

### G. Tools & host assets (optional growth)

| Piece | Responsibility |
|-------|----------------|
| Table generators | Wave sheets, sine/offset tables if any |
| Char/sprite export | From PNG or other source → bytes for `.incbin` |

---

## Expected file count

| Phase | Approx. `.asm` / `.inc` under `src/c64/` | Notes |
|-------|--------------------------------------|--------|
| Vertical slice (1 arm, 1 drone, no bonuses) | **8–12** | boot, zp, irq stub, rail, player, one drone, bullets, collision, main |
| Playable single level + HUD | **18–25** | + HUD, health, damage, waves |
| Full game + frontend shell | **30–45** | + title/scores/entry/game over, bonuses, mux, ammo |
| Content-heavy (many levels, polish) | **40–55+** | mostly `data/` growth |

**Conclusion:** too large for repo-root clutter or one monolith; small enough that **area folders under `src/c64/`** (not a deep package tree) is the right grain. Rough steady state: **~35 files of logic + data includes**, plus `assets/c64/` binaries and a few `tools/c64/`.

---

## Directory tree

```
railgunner/
├── agents/                 # Handoffs (design, syntax, this layout)
├── src/
│   ├── c64/                # Commodore 64 — authoritative machine game
│   │   ├── main.asm        # Entry: stub, segments, include graph
│   │   ├── boot/           # BASIC stub helpers, cold init
│   │   ├── sys/            # ZP, constants, IRQ, input, memory map
│   │   ├── frontend/       # Title, scores, game over, victory, entry
│   │   ├── game/           # Play-mode logic
│   │   ├── render/         # Screen, rail/bullet/HUD character presentation
│   │   ├── sprite/         # Player/drone sprites, multiplexer
│   │   └── data/           # Tables, strings, embeds (or includes of assets)
│   ├── core/               # Portable C11 simulation. No SDL, no .asm
│   └── sdl/                # SDL2 frontend: window, blit, samples
├── assets/                 # One directory per platform
│   └── c64/                # Commodore 64 art and .incbin blobs
│       ├── charset/
│       ├── sprites/
│       └── screens/        # Title / attract PNG + converted .bin
├── tools/                  # One directory per platform
│   └── c64/                # c64m symlinks, play.sh, generators
├── tst/
│   ├── c64/                # Mux demos (not the game PRG)
│   └── core/               # Headless traces (make core)
├── Makefile                # make, make core, make sdl
└── build/                  # PRG, railgunner-core, railgunner-sdl; not hand-edited
```

Host build is the root **`Makefile`**. Three entry points:

| Command | Product | Not a prerequisite of |
|---------|---------|------------------------|
| `make` / `make prg` | `build/railgunner.prg` from `src/c64` | `make core`, `make sdl` |
| `make core` | `build/railgunner-core`, then every `tst/core/*.trace` | the PRG |
| `make sdl` | `build/railgunner-sdl`, then the window | the PRG. Needs `sdl2-config` |

`make play` and `make coop` still launch the C64 emulator. They are not port entry points. The assemble glob is `.asm` / `.inc` only, so C under `src/core` and `src/sdl` does not rebuild the PRG. Toolchain paths and remote assemble/debug: **`build-debug.md`**, **`tools/c64/README.md`**.

### Naming conventions

| Kind | Convention | Example |
|------|------------|---------|
| Logic module | `src/c64/<area>/<topic>.asm` | `src/c64/game/collision.asm` |
| Shared definitions / tables only | `*.inc` ok when no code entry | `src/c64/data/waves.inc` |
| Labels | Prefer `.proc` / `.scope` per module; export with `module::label` only when needed | |
| Constants | `src/c64/sys/const.asm` (VIC, screen base, char codes) | |
| Zero page | `src/c64/sys/zeropage.asm` — single owner of ZP map | |

### Include graph (ownership)

```
main.asm
  ├── sys/const.asm, sys/zeropage.asm, sys/memory.asm
  ├── boot/init.asm
  ├── sys/irq.asm, sys/input.asm
  ├── frontend/*.asm          ; mode dispatcher last among frontend
  ├── render/*.asm
  ├── sprite/*.asm
  ├── game/*.asm
  └── data/*                  ; after code that references labels, or use two-pass freely
```

Exact include order is fixed in `src/c64/main.asm` when files appear. **Only `src/c64/main.asm` should be passed to `c64masm` / the Assembler tab** as the root file (unless a test harness says otherwise). From `src/c64/data/`, binary includes are `../../../assets/c64/...`.

### Assembler / load addresses (layout implication)

Use **named segments** (as in c64m `c64-life.asm` style), defined once in `src/c64/sys/memory.asm` or top of `main.asm`:

| Segment | Typical role |
|---------|----------------|
| `ZEROPAGE` | `noemit` variable map |
| `BASIC` | `$0801` stub |
| `CODE` | All executable modules |
| `DATA` | Tables, charset copies if resident |
| Optional later | `SPRITES`, `CHARSET` at fixed VIC-friendly addresses |

Live-in-emulator vs file build may differ via `AM65` (see assembler handoff); the **file tree stays the same**.

---

## Mapping: design systems → folders

| Design system | Primary folder | Secondary |
|---------------|----------------|-----------|
| Screen cross layout | `render/` | `data/` (char defs) |
| HUD | `render/` | `game/` (values) |
| Controls / barrel / rails move | `game/` + `sys/input` | `sprite/` (draw) |
| Shooting / bullet cells | `game/` + `render/` | `data/` (bullet chars) |
| Ammo | `game/` | `render/` (bar), `frontend/` (radio msg) |
| Drones A/B/C | `game/` + `sprite/` | `data/` |
| Graphical-object pool | `game/objects` | `sprite/` (immutable plans) |
| Collision `$D01F` | `game/collision` | — |
| Rail damage | `game/` + `render/` | `data/` |
| Health / shield / lives | `game/` | `render/` HUD, `sprite/` overlays |
| Bonuses | `game/` | `sprite/`, `render/` |
| Wave tables | `data/` | `game/waves` |
| Sprite mux | `sprite/` | `sys/irq` |
| Title / scores / game over / victory | `frontend/` | `assets/c64/screens`, `data/` |
| Score entry / hiscores | `frontend/` | `data/` |

---

## What does **not** go in `src/c64/`

| Path | Why separate |
|------|----------------|
| `src/<other-platform>/` | Another machine's source. Sibling of `c64/`, not a folder inside it |
| `src/core/`, `src/sdl/` | The portable port ([`c64-to-sdl.md`](c64-to-sdl.md)). Not C64 sources. No `.asm` (the PRG glob would assemble it). Core includes no SDL header. SDL does not own a gameplay rule |
| `agents/` | Human/agent prose, not assembled |
| `assets/<platform>/` | That machine's art. C64 blobs live in `assets/c64/` and are `.incbin`'d, not assembled as source |
| `tools/<platform>/` | That machine's host scripts. Never run on the 6510 |
| `build/` | Outputs only |

Repo root stays thin: **no game `.asm` at root**, and no platform files directly under `src/`, `assets/`, `tools/`, or `tst/`.

---

## Actual tree

### Present (do not reinvent)

```
src/c64/main.asm                 ; sole assemble root; main loop drains events + mux build
src/c64/boot/init.asm
src/c64/sys/{const,zeropage,memory,irq,input,video,sprite_install,sound,music}.asm
src/c64/render/{screen,charset,bullets}.asm
src/c64/game/{objects,game_init,stage,play,life,player,drones,collision,cargo,parcels,rail,score,hud,message,tallies,waves}.asm
src/c64/sprite/{mux_build,mux_irq}.asm
src/c64/frontend/{mode,title,typewriter,story,instructions,gameover,hiscore}.asm
src/c64/data/{strings,sprites,title_gfx,charset_font,waves,music_valkyrie}.asm
assets/c64/{charset,screens,sprites}
tst/c64/                         ; mux demos (not the game)
```

Play is the level-centric loop in [`level-rework.md`](level-rework.md): full
cross, A/B/C, parcels, cargo/mines, rank banner. There is no `shoot.asm` and
no `sprite/player.asm`. Fire and the player object live in `game/player.asm`
and `render/bullets.asm`. Frames live in `data/sprites.asm`.

Wire new files through `src/c64/main.asm`. Prefer extending `play.asm` /
`stage.asm` only for loop/enter glue; put real systems in the topic files.
Next C64 work is the roadmap queue (R10, R9, bonus types, R11), not a second slice.

### Portable port (present)

`src/c64/` stays the oracle. `src/core/` is the C11 simulation of those rules.
`src/sdl/` links the core except `src/core/main.c`.

```
src/core/sim.c main.c            ; 50 Hz tick; headless driver reads tst/core traces
src/core/{cells,objects,input,mode,music,sfx}.c
src/core/{title,typewriter,story,instructions,hiscore,gameover,tallies}.c
src/core/{game_init,stage,play,player,life,bullets,drones,collision}.c
src/core/{cargo,parcels,rail,score,hud,message,waves}.c
src/core/data/tables.c           ; wave, music, and SFX step bytes
src/core/const.h
src/sdl/{main,blit,audio}.c      ; clock, keys, 2× blit, three-voice samples
tst/core/*.trace                 ; run by tst/core/run.sh from make core
```

SDL's `main.c` maps the keyboard onto the core's held buttons, publishes one
tick per 20 ms, and drops a backlog. `blit.c` paints cells, sprites, and the
hires title. `audio.c` synthesizes pulse, triangle, saw, and noise from the
core's voice registers. Score, spawns, and collision stay in `src/core/`.

`Object` has no multiplexer fields (`pending_events`, `irq_events`,
`hw_owner`, `mux_*`, `profile_marker`). `hitbox_id` is the assembly field.
Nothing in the core reads it.

---

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| All source in repo root | Clutters root; mixes with agents/tools; ~40 files unmanageable |
| Single `railgunner.asm` | Fine for a 200-line demo; not for mux + waves + frontend |
| `src/c64/components/...` deep tree | Over-structured for asm; painful includes |
| Separate repo per frontend/game | No; one PRG, one product |
| `include/` vs `src/c64/` split like C | Asm modules are both decls and code; one tree under `src/c64/` |

---

## Maintenance rules for agents

1. New gameplay feature → prefer `src/c64/game/<topic>.asm` (or extend an existing topic file if it is still small).
2. New pure presentation of existing state → `src/c64/render/` or `src/c64/sprite/`.
3. New outer-loop screen → `src/c64/frontend/`.
4. New numbers/strings/frames → `src/c64/data/` and/or `assets/c64/`.
5. Always wire new files through `src/c64/main.asm` includes.
6. Do not add assembler syntax variants; follow `assembler-syntax.md`.
7. If this layout document drifts from reality, update it in the same change.
