# C64 → portable C → SDL

**Role:** Record of the finished port. The phases below are how it was built.
The game is feature-complete. This file is not a work queue, and neither is
[`roadmap.md`](roadmap.md).

**Status:** Finished. Phase 9 landed (2026-10-10). `src/core/` is the C
simulation of the 6502 rules (no SDL include). `src/sdl/` is the first
platform frontend on that core (blit, samples, key mapping). A later port
would be another frontend on `src/core/`, and would not need `src/sdl` or
`src/c64`. `src/c64/` stays the Commodore 64 game and the oracle. `make`,
`make core`, and `make sdl` are the three build entry points. `make play` and
`make coop` still launch the C64 emulator. The Phase 3 temporary spawn
comment is gone. No mux-shaped fields remain on `Object`.

Left out of the port, because the assembly does not have them or because the
frontend is not the C64: disk high scores (`hiscore_reset` is empty); no
fire-stream SFX and no in-game music bed; no NTSC "drop 1 tick in 6"; no
collision modes 1 and 2, no VIC latch, no border diagnostics; no sprite
multiplexer (SDL shows every `OBJF_RENDER` object); no gamepad. Those are not
remaining feature work. An SFX started during a tick is one frame shorter
than on the C64, because `sfx_update` then `music_update` run after
`mode_run`. `hitbox_id` is still on `Object` and nothing reads it.

**Rules live here.** Game behavior still comes from the assembly and from
[`level-rework.md`](level-rework.md). If this document and the assembly
disagree about a rule, trust the assembly, port that behavior, and fix this
document. The exceptions are listed under **Accepted differences** and are
intentional.

**Do not edit `../c64m/`.** Repo boundary in [`README.md`](README.md) still
applies.

---

## Decisions already made

Do not reopen these. They were accepted before this script was written.

| Decision | Meaning |
|----------|---------|
| No `src/6502-to-c` | Do not transliterate the machine into `uint8_t mem[65536]`. That tree will not be created. |
| One core, cleaned up as it goes | `src/core` is the surviving C. Literal translation and renaming happen in the same files, one module at a time. There is no second cleanup tree. |
| `src/c64` stays | It remains the oracle and must keep building with `make` and `make play`. Do not delete, rewrite, or "fix" it as part of the port. |
| `src/sdl` is a frontend | It links the core. It does not reimplement rules. |
| 50 Hz integer simulation | `LOGIC_HZ` is 50. Positions stay integers with the assembly's fractional bytes. No floats. No delta time. |
| The 40×25 cell buffer is real state | Glyph plus color. Rail hits, bullets, HUD, cargo letters, and the typewriter read and write it. A comment is not a substitute. |
| Software collision is the authority | `test_bullets` and `test_rail` run every logic tick. The VIC latch `$D01F` is not required. See **Accepted differences**. |
| PAL is the design rate | Music durations and attract timers are in PAL frames. The NTSC "drop 1 tick in 6" path is not ported. |
| Art already exists | Title bitmap, charset, and sprites under `assets/c64/`. SDL blits those. Nobody redraws them for the port. |
| High scores stay in RAM | Disk load/save was never implemented (`hiscore_reset` is empty). Do not invent disk I/O. |

---

## What "finished" looks like

| Path | Survives | Role |
|------|----------|------|
| `src/c64/` | yes | Original game. Unchanged by the port. |
| `src/core/` | yes | Rules, cell buffer, object list, music and SFX **tables**. No SDL, no VIC, no SID registers. |
| `src/sdl/` | yes | Window, blit, audio callback. The only thing that includes SDL. |
| `src/6502-to-c/` | no | Do not create it. |

A later non-SDL port reads the cell buffer and the sprite list and blits its
own way. It should not need `src/sdl` or `src/c64`.

---

## Hard rules for every phase

The phases are done. These rules still apply if the core or the SDL frontend
is touched.

1. **One module at a time.** Read the `.asm`, write the C, compile the headless
   driver, then the next module. Do not translate several large files in one
   untested batch.
2. **Keep 8-bit wrap** where the assembly wraps: `uint8_t` counters, table
   indexes, score digits, HP, phase numbers. Widen a value only when the
   assembly already uses a 16-bit pair (`attract_lo/hi`, sprite X hi/lo,
   score).
3. **Keep procedure names searchable.** `player_update`, `test_bullets`,
   `note_kill`. Do not rename into a new vocabulary during the port.
4. **Keep call order.** `play_update` in `src/c64/game/play.asm` is the order.
   Do not sort "for clarity."
5. **Coordinates stay VIC pixels.** Bullet math is `x = 24 + col*8 + …` and
   `y = 50 + row*8 + …`. Sprite positions use that same origin. SDL converts
   to the 320×200 bitmap by subtracting 24 from X and 50 from Y. Do not store
   a second coordinate system in the core.
6. **Core has no SDL, no `c64m`, no hardware addresses.** `$D000`, `$0400`,
   CIA, and raster IRQs do not appear in `src/core`.
7. **Do not port the multiplexer.** `src/c64/sprite/mux_build.asm`,
   `src/c64/sprite/mux_irq.asm`, IRQ event banks, HW lane owners, and plan
   publish exist because the C64 has 8 sprites. SDL draws every object with
   `OBJF_RENDER` set.
8. **Do not port machine bring-up.** `boot/init.asm`, `sys/irq.asm`,
   `sys/video.asm`, `sys/memory.asm`, `sys/zeropage.asm`,
   `sys/sprite_install.asm`. Copy the **game constants** out of `const.asm`.
   Leave the VIC/CIA/SID address equates behind.
9. **`make` and `make play` must keep working** after every phase. The C64
   Makefile globs `src/**/*.asm` as rebuild inputs. Do not put `.asm` files
   under `src/core` or `src/sdl`. New targets (`make core`, `make sdl`) must
   not become dependencies of `prg` or `play`.
10. **No gameplay improvements.** The assembly is the rule set. Disk high
    scores, a fire-stream sound, and in-game music are not in it. Do not add
    them here.
11. **Phases 0 through 9 already ran.** The checklist at the end is complete.
    Do not start the port over.
12. **A broken blit is a bug in `src/sdl`,** and a wrong rule is a bug in
    `src/core`. Fix the tree that owns it. Do not add gameplay.

---

## Accepted differences

These are the only places the port is allowed to disagree with a running C64.

### Collision has no latch

`COLLISION_MODE` in `src/c64/sys/const.asm` is 0. On the C64,
`collision::update` ignores a drone unless the multiplexer latched
sprite-background overlap (`OBJE_BG` from `$D01F`). The software tests then
decide bullet versus rail.

The port runs `test_bullets` and then `test_rail` for every allocated,
non-retiring, non-exploding drone of kind A/B/C, every logic tick. There is
no latch gate. Hits can differ from the C64: the latch both rejected noise
and accepted some contacts before the drone's own Y-arrival check. That is
accepted. Do not simulate VIC overlap to get the latch back.

`mode_hybrid`, `mode_hw_only`, and the border-color diagnostics
(`diag_fp_border`, `diag_fn_border`) are not ported.

Drone Y-arrival in `drones.asm` still retires at the rail on its own. Keep
that path. It is separate from `collision::update`.

### Timing

One logic tick is 1/50 second, always. The host may repaint at any refresh
rate. Extra host frames draw the same simulation state.

If the host falls behind, run **one** tick and drop the backlog. Do not catch
up by running several ticks in one frame. That matches the comment in
`src/c64/main.asm`: missed ticks are dropped, not replayed in slow motion.

On the C64, `sfx::update` and `music::update` run on every physical frame,
and logic sometimes does not (NTSC). The port advances audio on the same 50 Hz
tick as logic. Do not drive the sequencer from the display refresh, or a
144 Hz monitor speeds the tune up.

### Presentation hooks that are not state

Border-color flashes, display-enable blanking, and VIC bank switches are not
simulated. Where the assembly changes the border to signal a mode
(`play_enter` sets green), the core may ignore it. Do not add a fake VIC.

---

## Layout to create

```
src/core/                 C11. No SDL.
  sim.h / sim.c           tick, mode dispatch, the Game struct
  cells.h / cells.c       40×25 glyph + color
  objects.h / objects.c   24 slots, slot 0 is the player
  input.h / input.c       buttons in, edges computed here
  data/                   tables lifted from src/c64/data and const.asm
  <module>.c              one C file per assembly module that is ported
  main.c                  headless driver
src/sdl/                  C11 + SDL2. Links src/core.
  main.c                  window, clock, input mapping
  blit.c                  charset, sprites, hires title
  audio.c                 3 oscillators, created in Phase 8
tools/core/               optional host script only if make is a worse fit
```

`src/core` is a library plus a headless `main`. `src/sdl` is the only SDL
program. Both are siblings of `src/c64`, not directories inside it.

Suggested `Game` contents, grown as phases need them. Do not invent fields
the current phase does not read.

- `mode`, `mode_timer`, `mode_state`, `pending_mode`
- `cells[25][40]` of `{ uint8_t glyph; uint8_t color; }`
- `objects[24]` (see below)
- bullet slots (`BULLET_MAX` is 16)
- the input edges from the last tick
- a presentation flag: `PRESENT_HIRES_TITLE` or `PRESENT_TEXT`
- an SFX request queue (ids only, consumed by SDL in Phase 8)

Object fields the **game** reads. Copy these. Drop mux, IRQ, and plan fields
(`pending_events`, `irq_events_*`, `hw_owner`, `mux_*`, `profile_marker`).

| Assembly | Keep | Notes |
|----------|------|--------|
| `obj_flags`, `obj_kind` | yes | slot 0 is the player and is never freed |
| `obj_x_frac`, `obj_x_lo`, `obj_x_hi` | yes | 24-bit fixed point, same as the assembly |
| `obj_y_frac`, `obj_y_int` | yes | |
| `obj_vx_*`, `obj_vy_*` | yes | |
| `obj_sprite_ptr`, `obj_sprite_color`, `obj_sprite_attr` | yes | SDL uses them to pick a frame and a palette entry |
| `obj_anim_state`, `obj_user`, `obj_reserved` | yes | `obj_reserved` is drone HP |
| `obj_hitbox_id` | only if a ported caller reads it | |

An array of structs is the right C shape. The assembly's structure-of-arrays
at `$C000` is a 6502 layout, not a rule. Indexes must still match: player in
slot 0, allocations from the low free slots upward.

Build:

- C11 (`-std=c11`), warnings on.
- `make core` builds the headless driver to `build/railgunner-core`.
- `make sdl` builds `build/railgunner-sdl` and is allowed to fail with a
  clear "SDL2 not found" if the library is missing. Do not fail `make` or
  `make play` for that reason.
- Headless usage stays boring: `build/railgunner-core <trace>` reads a text
  trace and prints a dump. Trace lines are `tick`, `dir U|D|L|R|N`,
  `fire 0|1`, `key S|I|RUNSTOP 0|1`, `dump`. Held buttons persist until a
  later line changes them. `tick` runs one logic tick.

---

## How to port one module

Repeat this for every file in the phase lists.

1. Read the `.asm` and the constants it uses. Read [`level-rework.md`](level-rework.md)
   if the module is play-loop, HUD, mines, parcels, or level flow.
2. Write C with the same branches and the same wrap. `uint8_t` locals replace
   zero-page temps (`tmp0`, `ptr_lo`, `mode_state` when it is scratch).
3. Replace `screen_put_xy` / `screen_color_xy` / `screen_get_xy` with the cell
   buffer. Row and column stay 0..24 and 0..39.
4. Replace `sfx::play` with "enqueue this SFX id." Do not synthesize sound
   before Phase 8. The id list in `const.asm` (`SFX_UI_FIRE` … `SFX_COUNT`)
   is the API.
5. Replace `music::start_title`, `music::stop`, `music::update` with the core
   sequencer once Phase 8 starts. Before that, title mode may set a
   `music_active` flag and nothing else.
6. Replace `objects::mark_dirty` with nothing. Visibility is `OBJF_RENDER`.
7. Self-modified `jmp` tables (`mode_run`, `mode_set`) become arrays of
   function pointers. Same mode numbers (`MODE_TITLE_GFX` = 0 through
   `MODE_INSTRUCTIONS` = 11, `MODE_COUNT` = 12).
8. Compile `make core` and run the phase's trace. Then the next module.
9. After that module's trace passes, rename only temps that are unreadable.
   Do not restructure the rules in a follow-up pass "while you are here."

Glyph ids: when you first copy a screen-code block from `const.asm`, add a
short comment that says what the C64 showed (rail tile, bullet half, HUD bar,
hub letter). One comment per constant. That is the drawing record the later
ports need. Do not write a parallel prose document of every poke.

---

## Phase 0 — Scaffold

**Goal:** the two trees exist, the headless driver ticks, and the C64 build
still works. No game rules yet.

**Create**

- `src/core` types: `Game`, empty `cells_clear`, `sim_tick` that only
  increments a frame counter.
- `src/core/main.c` trace reader (`tick`, `dump`).
- `make core`.
- A `src/sdl/` directory with a README of one paragraph pointing here, **or**
  no SDL sources yet. Do not link SDL in this phase.

**Do not**

- Do not copy assembly.
- Do not add SDL to the default `make` target.

**Exit**

- `make` and `make play` still build the PRG (play only if a display is
  available; if you cannot open the emulator, `make` passing is enough and
  say so).
- `echo tick | build/railgunner-core` prints a frame count of 1.
- Checklist below marked.

---

## Phase 1 — Constants and tables

**Goal:** the numbers the rules need live in C, next to comments for glyphs.

**Read**

- `src/c64/sys/const.asm` — copy game constants only. Skip every `= $Dxxx` /
  `$DCxx` / `$DDxx` equate and the memory-map segment addresses.
- `src/c64/data/strings.asm` — score text, rank strings, quota table.
- `src/c64/data/waves.asm` — spawn tables.
- `src/c64/data/music_valkyrie.asm` — three event lists, data only.
- `src/c64/sys/sound.asm` — the step tables at the bottom of the file (7-byte
  steps). Not the SID register writes.
- `src/c64/data/sprites.asm` — frame pointer ids, so SDL later indexes the
  same bins the assembly embeds.

**Keep these numbers exactly**

- Screen 40×25. Rail geometry: `RAIL_COL_LEFT..RIGHT` 18..20,
  `RAIL_ROW_TOP..BOT` 12..14.
- Modes `MODE_*` and `MODE_COUNT`.
- `OBJECT_CAPACITY` 24, kinds `OBJ_*`, flags `OBJF_*`.
- `LOGIC_HZ` 50, `ATTRACT_FRAMES` 750, `PLAYER_MOVE_STEP` 4, player rail
  limits and `PLAYER_X_START` / `PLAYER_Y_HRAIL`.
- `BULLET_MAX` 16, `BULLET_HOLD` 1, `BULLET_PHASES` 4, launch rows and columns.
- Hit box `HIT_X0..HIT_Y1` from `collision.asm` (0, 23, 3, 16).
- Rail HP `RAIL_OUTER_HP` 6, `RAIL_CORE_HP` 5.
- Screen codes from the UDG map (`SC_RAIL_A` through bullet and HUD glyphs).
- SFX ids 0..9 and `SFX_FREE`.

**Music table shape** (do not convert to MIDI)

Each event is `duration_frames, freq_lo, freq_hi`. `0,0` is a rest. `0xFF`
ends the list and loops. Comments in the assembly already name the notes.
Store the raw bytes. Hertz, later, is
`word * 985248 / 16777216` (PAL SID clock). Voice settings to store beside
the lists: wave pulse / pulse / triangle, AD/SR `$21/$A8`, `$21/$98`,
`$11/$C8`, pulse width `$0800`. No filter.

**Exit**

- A C file can name `MODE_PLAY`, `SC_RAIL_A`, and the first Valkyrie event
  without including any assembly.
- Headless driver still ticks.
- No behavior yet. Do not start the player in this phase.

---

## Phase 2 — Input and the mode shell

**Goal:** scripted buttons move the mode machine the way the title does.
The cell buffer gets real writes for the text title. The hires title is a
flag, not a decoded bitmap.

**Read**

- `src/c64/sys/input.asm` — the **result** struct, not the CIA matrix.
  Directions, fire, fire edge, S, I, RUN/STOP, and their edges.
- `src/c64/frontend/mode.asm`
- `src/c64/frontend/title.asm` — attract timer, fire guard, gfx ↔ text.
- `src/c64/render/screen.asm` — `screen_clear`, `screen_put_xy`,
  `screen_color_xy`, `screen_print`, `ascii_to_screen`. Port those helpers
  onto the cell buffer. Skip `vic_select_bank*`, `screen_blank`,
  `screen_unblank`.

**Behavior to preserve**

- Edges are rising edges computed inside the core, from the held state the
  trace (or SDL) supplies. Gameplay must not depend on who sampled the keyboard.
- `MODE_TITLE_GFX` shows for `ATTRACT_FRAMES` or until fire edge, then
  `MODE_TITLE_TEXT`. Fire on the text page requests game start
  (`MODE_GAME_INIT`). S and I request story and instructions. Those modes
  may be empty stubs that return to the text title on fire, until Phase 7.
- Hires page sets `PRESENT_HIRES_TITLE` and does not paint 8000 bytes into
  the cell buffer. Text page sets `PRESENT_TEXT` and writes cells.
- `mode_set` clears `mode_timer` and `mode_state`, then calls enter.

**Trace**

`tick` × a few, `fire 1`, `tick`, `fire 0`, then enough `tick`s to leave the
fire guard, `fire 1`, `tick`, `dump`. Dump shows `MODE_TITLE_TEXT` after the
first accepted fire and `MODE_GAME_INIT` after the second.

**Exit**

- That trace passes.
- `game_init` may be an empty enter/update that sits in that mode. Do not
  port the playfield yet.

---

## Phase 3 — Playable slice, headless

**Goal:** a ship on the cross, bullets, drones, rail cells, software
collision, a score change, and a death that reaches game-over. Cargo,
parcels, rank banner, and high-score entry are **not** in this phase.

**Order. Finish and trace each step before the next.**

| Step | Assembly | Port | Leave behind |
|------|----------|------|----------------|
| 3a | `game/objects.asm` | init, alloc, free, slot 0 reserved | IRQ banks, dirty/mux flags |
| 3b | `game/game_init.asm`, `game/stage.asm`, `render/screen.asm` playfield draw | new game → stage → static cross in the cell buffer | VIC blanking |
| 3c | `game/player.asm` | rail walk, barrel, centre mount | sprite-mux interest bits |
| 3d | `render/bullets.asm` | the cell state machine **is** the bullet. Update writes glyphs. | |
| 3e | `game/drones.asm` | spawn, move, Y-arrival retire, HP, explode flag | |
| 3f | `game/rail.asm` | damage steps stored so `test_rail` can see rail glyphs in the cells | |
| 3g | `game/collision.asm` | `test_bullets`, `test_rail`, `cell_on_rail_cross`, `is_rail_tile`, `px_to_col`, `rail_arrival_retire` | latch modes, border diagnostics |
| 3h | `game/score.asm`, `game/life.asm`, `game/play.asm` | `add_hit`, death, `pending_mode` → `MODE_GAME_OVER` | `paint_*` can write cells; fancy HUD waits |
| 3i | `frontend/gameover.asm` | enter paints a plain game-over line and fire returns toward the title | tallies screen waits for Phase 7 |

`play_update` order, from the moment each callee exists:

1. RUN/STOP edge → `MODE_GAME_OVER`
2. `rail::strike_frame_reset`
3. `player::update`
4. `drones::update`
5. `cargo::update` — **skip the call until Phase 6.** Do not leave a dead
   stub that changes state.
6. `parcels::update` — same, skip until Phase 6.
7. `bullets::update`
8. `collision::update`
9. `waves::update_banner` / `check_clear` — **skip until Phase 6.** Until
   then a fixed spawn pace inside `drones::update` is enough if the wave
   tables are not ready. Document the temporary pace in a comment next to
   the call, and delete it in Phase 6.
10. score and HUD cell paints
11. `mode_set` if `pending_mode` is set

**Traces**

- Hold fire, `tick` until `dump` shows a bullet glyph in the cells above the
  ship, then the bullet gone off the top.
- A spawned drone whose X overlaps a bullet: later `dump` shows score
  increased **or** the drone retiring. Use the assembly's hit box, not a
  looser one.
- A drone that reaches the rail: the rail glyph changes **or** the drone
  retires via Y-arrival. Either path is already in the assembly. Do not add
  a third.
- Kill the player (the assembly's death condition that does not need cargo).
  `dump` shows `MODE_GAME_OVER`.

If the assembly's only fatal paths are "four mines" and "core collapse,"
port the smallest one that already works without cargo (core collapse if it
can be forced by repeated A/B arrivals). Do not invent a new death.

**Exit**

- The four traces above pass under `make core`.
- `src/c64` still assembles.
- Continue to Phase 4. SDL is Phase 5.

---

## Phase 4 — Slice traces are the regression suite

**Goal:** the Phase 3 traces live as files under `tst/core/` and `make core`
runs them. A failure exits non-zero.

**Do not**

- Do not add a framework. A shell loop over trace files is enough.
- Do not compare against c64m memory dumps. The human did not ask for
  byte-identical traces.
- Do not weaken a trace to make it pass. Fix the core.

**Exit**

- `make core` runs the suite.
- One new trace is cheap to add. That is the bar for every later phase.

---

## Phase 5 — SDL slice

**Goal:** a window that shows the hires title and the playfield of the
Phase 3 game. Later phases keep writing cells and sprites. This blit is
the one they all use, so it has to work before Phase 6.

**Read before writing blit code**

- `assets/c64/screens/title_hires.bin` (8000 bytes, 320×200 hires, 8 bytes
  per cell row-major in C64 bitmap order) and `title_hires_col.bin`
  (1000 bytes, one per cell: high nibble foreground, low nibble background).
- `assets/c64/charset/railgunner_charset.bin` (2048 bytes, 256 glyphs × 8).
  The playfield is monochrome glyphs tinted by the cell color.
- `assets/c64/sprites/*.bin` (64 bytes: 3 bytes × 21 rows, multicolor).
  Display width is 24 pixels. Bit pairs use the shared colors
  `SPR_MC0_COLOR` (dark gray) and `SPR_MC1_COLOR` (yellow) plus the object's
  own color. `OBJA_MULTICOLOR` selects that mode.
- Converters in `tools/c64/png_to_c64_*.py` document the byte layouts. Trust
  those scripts if this paragraph and a file disagree.

**Build**

- Logical image 320×200. Window is an integer scale (2× unless the human
  asked otherwise). Nearest-neighbor. No scanline filter.
- One C64 palette table, 16 colors, in one place. Use it for cells, sprites,
  and the title bitmap.
- Title: when `PRESENT_HIRES_TITLE`, blit the two title bins. Ignore the
  cell buffer for that frame.
- Text and play: blit the cell buffer with the charset. Then blit every
  object with `OBJF_RENDER`, in slot order, slot 0 last if the assembly
  draws the player on top. There is no 8-sprite cap.
- Map keyboard to the button struct: WASD or arrows, Space fire, S, I,
  Escape as RUN/STOP. A gamepad is optional and maps to the same struct.
- Clock: accumulate milliseconds, fire `sim_tick` every 20 ms, at most one
  tick per host frame, drop leftover backlog. Repaint every host frame.
- Audio: silence in this phase. Leave a call site where Phase 8 will run
  the sequencer after `sim_tick`.

**Exit**

- `make sdl` opens a window, shows the title art, accepts fire through to
  the playfield, moves the ship, and draws a bullet and a drone. Drive that
  path yourself. A screenshot of the title alone is not the exit.
- `make` / `make play` still build the C64 game.
- If that path fails, fix the blit or the slice before Phase 6. If it
  works, continue. Do not wait for the human to compare it with `make play`.

---

## Phase 6 — The rest of play

**Goal:** the running SDL game matches the level loop in
[`level-rework.md`](level-rework.md): quota, banner, cargo and mines, parcels,
full drone spawning.

**Order**

| Step | Assembly | Notes |
|------|----------|--------|
| 6a | `game/waves.asm`, `data/waves.asm` | Delete the Phase 3 temporary spawn pace in the same change that calls the real spawner. |
| 6b | `game/cargo.asm` | GHIJ glyphs in the cell buffer are the stacks. `paint_ghij` writes cells. |
| 6c | `game/parcels.asm` | Two per level, priority, awards. Sprites are objects of kind `OBJ_BONUS`. |
| 6d | `game/hud.asm`, `game/message.asm`, `game/score.asm` paints | HUD line and rank banner write cells. |
| 6e | `game/life.asm`, `game/player.asm` deploy | Reserve icons, peel, respawn. Core collapse and four mines both reach game over, as the assembly does. |
| 6f | `game/tallies.asm` | Session counts only, if game-over does not need them yet. Full paint can wait for Phase 7. |

Re-read level-rework before 6a. In particular: no player-facing wave counter,
kills do not soft-reset the rail, parcels in flight survive the level
boundary, clear arms on pickup and wipes on the **next** centre pass.

**Tests**

Add one trace per step that locks a single rule: a kill increments the quota
counter; a C arrival writes a hub glyph; a parcel award changes the documented
flag (extra life, 2×, repair). Do not try to script an entire level.

**Exit**

- New traces pass.
- SDL shows cargo letters, a parcel sprite, the HUD line, and a level banner
  without further renderer work. If a feature is invisible, the core forgot
  to write a cell or set `OBJF_RENDER`. Fix the core.
- C64 `make` still works.

---

## Phase 7 — Frontend tail

**Goal:** text around the game matches the assembly. Still no new rules.

**Order**

| Step | Assembly |
|------|----------|
| 7a | `frontend/typewriter.asm`, `frontend/story.asm`, `frontend/instructions.asm` |
| 7b | `frontend/gameover.asm` plus `game/tallies.asm` paint |
| 7c | `frontend/hiscore.asm` — qualify, insert, initial entry, paint. RAM table only. |
| 7d | `frontend/title.asm` score-color rotation, now that the table exists |

High-score entry is about a thousand lines. Port it in the same style as the
rest (cell writes, edges from the core input). Do not redesign the UI.

**Exit**

- From the SDL window: title, story, instructions, a death, initials if the
  score qualifies, and back to the title.
- A trace covers "score below the table does not enter `MODE_HISCORE`" and
  "a qualifying score does."

---

## Phase 8 — Audio

**Goal:** the title loop and the ten one-shots play from the Phase 1 tables.
No SID emulator library. No filter. Wagner's theme is public domain, and
this arrangement is original to this repo. Keeping the tables is the port.

**Read**

- `src/c64/sys/music.asm` — `start_title`, `stop`, `update`, `load_next_note`,
  mute while an SFX owns the voice.
- `src/c64/sys/sound.asm` — `play` (priority, steal the lowest priority),
  `update`, `start_step`, `slide_if_needed` (`+$40` frequency per tick on
  parcel, wave, and heal).

**Core**

- Advance both sequencers at the end of `sim_tick`, after gameplay, matching
  "audio runs even when a logic tick is the whole frame" on PAL.
- Three logical voices. Each voice is either following its music event or
  leased to an SFX step. On lease, music keeps consuming its duration in
  silence (`music.asm` already does this).
- Output of the core, each tick, per voice: waveform, frequency word, gate,
  AD, SR, pulse width. A rest clears the control byte (gate off; frequency,
  AD, and SR stay). A leased voice reports that SFX step, gate on while the
  step says so. The core does not produce samples.

**SDL**

- Audio callback synthesizes pulse, triangle, saw, and noise from those
  three voice states, with the ADSR nibbles from the tables.
- Frequency word → Hz is `word * 985248 / 16777216`.
- Callback follows the audio device clock. It consumes the latest voice
  state. It does not advance the score. The 50 Hz tick does that.
- Volume is the assembly's `$0F` with no filter bits.

**Exit**

- Title mode plays the loop. A fire on the menu plays `SFX_UI_FIRE` and
  takes a voice for the length of that step, then the loop is audible again.
- Continue to Phase 9.

---

## Phase 9 — Leave the tree honest

**Goal:** a stranger can see what is authoritative. No new features.

- Delete the Phase 3 temporary spawn comment if it is still there. It should
  already be gone.
- Delete unused mux-shaped fields if any survived in `objects`.
- Confirm `src/core` has no SDL include and `src/sdl` has no rule that is
  not a blit or a sample.
- Confirm `make`, `make core`, and `make sdl` are the three entry points.
- Update [`repo-layout.md`](repo-layout.md) so the tree matches reality.
- Set this document's status line to the phase that actually landed, and
  list anything skipped.

---

## Checklist

Every phase below is done. The notes are the exit that was actually run.

| Phase | Exit | State |
|-------|------|--------|
| 0 Scaffold | headless `tick` prints 1; C64 `make` still works | done 2026-10-10 (`echo tick` → `frame 1`; `make` wrote the PRG; emulator window not opened) |
| 1 Tables | constants and music bytes visible to C | done 2026-10-10 (`MODE_PLAY`, `SC_RAIL_A`, `music_track0` starts 12, 0xDA, 0x20; `echo tick` still prints `frame 1`) |
| 2 Mode shell | scripted fire walks gfx → text → game init | done 2026-10-10 (guard rejects a held fire; accepted fire reaches `MODE_TITLE_TEXT` with title cells; the next accepted fire reaches `MODE_GAME_INIT`; 750 ticks of attract also open the text page) |
| 3 Slice | bullet, hit or retire, rail, game over | done 2026-10-10 (up bullet glyph 102 at row 11 col 17 then gone; shot from x=189 scores 1 and drops that A from 3 HP to 2; column 22 D becomes crit; four A strikes reach `MODE_GAME_OVER`, and fire after the guard returns to the text title) |
| 4 Suite | `make core` runs `tst/core` traces | done 2026-10-10 (`tst/core/{bullet,hit,rail,gameover}.trace`; `make core` runs them) |
| 5 SDL slice | window shows title and play; fix a broken blit before Phase 6 | done 2026-10-10 (640×400 window, readback matches the 320×200 image at 2×; hires title; Space reaches play; Right moves the ship to x=189; yellow up-bullet and the blue drone are on the playfield) |
| 6 Play loop | quota, cargo, parcels, HUD, both deaths | done 2026-10-10 (traces `quota`, `cargo`, `parcel`, `hud`, `mine`, `gameover`, `tally`; SDL window shows the HUD line, armed G hub, clear parcel, and `NICE WORK, PRIVATE`; `make` left `build/railgunner.prg` current. Tally page paint waits for Phase 7) |
| 7 Frontend | story, instructions, tallies, RAM high score | done 2026-10-10 (`story.trace` locks the first glyph gray; `hiscore.trace` locks score 1 → `MODE_HISCORE` and a later score of 0 → text title; `gameover.trace` / `mine.trace` show the red results banner, and the rail-collapse farm enters initials; SDL window shows hires title, text title, story, instructions, death results, initials, and the title again. Disk high scores stay missing. The score wheel was already ported; hiscore calls it) |
| 8 Audio | title loop and one SFX steal a voice | done 2026-10-10 (`audio.trace` locks the boot B4, menu fire leasing voice 0 to freq 3584 gate on while voice 1 stays on the harmony note, then voice 0 back on the B4; the callback render measured ~494 Hz and ~210 Hz, plus saw, triangle, noise, and a silent gate-off; the audio device opened. No in-game music bed) |
| 9 Honest tree | layout doc matches the tree | done 2026-10-10 (`agents/repo-layout.md` lists `src/c64`, `src/core`, `src/sdl`, `tst/core`, and the three entry points. No SDL include under `src/core`. `src/sdl` is window, blit, and samples. Mux fields already absent. Phase 3 spawn comment already gone. `make -q` on the three binaries is current) |

---

## Where the assembly should not be "improved"

| Assembly fact | Port behavior |
|---------------|----------------|
| `MODE_NEXT_WAVE` / `MODE_NEXT_LEVEL` are legacy jumps back to play | Keep the ids so saves of the mode byte still mean the same thing. Enter may jump straight to play, as the assembly does. |
| `hiscore_reset` does not load disk | RAM table seeded the way the assembly seeds it. |
| No fire-stream SFX, no in-game music bed | Do not add them. |
| Collision mode 0 is what the PRG builds | Port the software tests only, as **Accepted differences**. Do not port modes 1 and 2. |
| Sprite multiplexer drops sprites on illegal layouts | SDL shows every `OBJF_RENDER` object. A drone the C64 failed to multiplex can be visible here. That is accepted. Do not port the scheduler to hide it. |
