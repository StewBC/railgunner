# Sprite multiplexer implementation status

This is the short implementation handoff for the graphical-object pool and
hardware-sprite multiplexer. The full design and ABI remain in
[`objects-sprites.md`](objects-sprites.md).

## Current verdict

The pool and multiplexer are ready for RailGunner gameplay integration. They
are a rendering/event facet for graphical game objects, not a complete entity
or AI system. Movement accessors, hitboxes, AI state, and gameplay lifecycle
remain higher-level work.

The most important unproven path is collision attribution immediately before a
hardware lane is reused. Test that before calling the entire graphical-object
layer battle-hardened.

## Implemented

- 24-slot structure-of-arrays object pool; player owns permanent slot 0.
- Fast allocation/free stack for slots 1–23.
- 16.8 X and 8.8 Y storage; VIC snapshots use 9-bit X and 8-bit Y.
- Double-buffered immutable raster command plans.
- Dynamic Y sorting and reassignment of the eight hardware sprites.
- Candidate sets of eight or fewer use distinct hardware lanes; low-count
  scenes never create needless lane-reuse deadlines.
- C/B/A drone priority coloring, where C is front/small, B medium, A back/large.
- Neutral objects prefer `candidate ordinal & 7`, then fall back to the lowest
  legal lane. This compact round-robin bias avoids preventable rapid reuse of
  sprite 0 without changing drone priority rules.
- Collision-latch capture and old-owner attribution before lane reuse.
- PAL/NTSC detection with gameplay motion normalized to 50 logic ticks/second.
- Safe failure with the prior immutable plan retained when a layout cannot meet
  lane or raster-deadline constraints.
- Prospective drone-spawn admission: the complete candidate render set is built
  before the spawn returns success. A deadline/lane/busy rejection clears the
  never-published object and restores its exact free-stack entry, so gameplay
  cannot keep advancing a drone that froze the prior sprite plan.
- Release-aware job scheduling fills idle time with ready work before jumping
  forward to a future lane-reuse release.

## Demonstrations

Both programs are standalone PRGs under `tst/` but include the production pool,
builder, IRQ executor, collision handoff, and video-standard code directly.
A red border means a build/publish error was latched.

```bash
# Stable two-ribbon reuse case
tst/play_sprite_mux_dance.sh

# Fourteen objects orbit clockwise, continually crossing in Y
tst/play_sprite_mux_circle.sh

# Either demo accepts an explicit standard
tst/play_sprite_mux_circle.sh --video PAL
tst/play_sprite_mux_circle.sh --video NTSC
```

The circle is the stronger mux test: every logical object moves through both
screen halves, so owner sort order and hardware-lane ownership change throughout
the orbit. Its ellipse covers X=54–290 and therefore crosses `$D010`.

## Verification completed

- Both demo PRGs and the production `railgunner.prg` assemble.
- Ribbon: 14 commands, blue border, no sticky error.
- Circle PAL: complete orbit, 14 commands, 16 sampled owner orders and 16
  sampled owner/lane maps, all plan coordinates matched the ellipse table.
- Circle NTSC: more than one normalized orbit, 14 commands, valid coordinates,
  no sticky error.
- Corrected a circle-table defect where X=228, 238, 247, and 255 incorrectly
  had the ninth X bit set. The mux `$D010` shadow/write path was not at fault.
- Coop snaps 017/019 isolated a production-only catch-up IRQ leak. An inline
  missed-raster command could latch a new `$D019` source without acknowledging
  it, causing either a stale command or a second frame-start in mid-display.
  Every command entry now acknowledges the source, and IRQ phase comes from
  command cursor/count rather than the current raster read.
- Coop snap-021 phase profiling proved the raster IRQ still held 50 Hz while a
  successful six-object tick exceeded the PAL CPU budget. The mux build averaged
  about 14,600 non-IRQ cycles: Y ordering 6,873 and emission 3,496. Gameplay
  added roughly 7,000 cycles, led by bullets (2,469) and drones (1,923).
  The fixed 256-row bucket pass is now a stable small-list insertion sort,
  per-object shadow masks are updated without five helper calls, and bullet
  screen/colour writes share one address calculation. Re-profile under the same
  load before declaring steady 50 Hz. Snap-022 then measured Y ordering at
  380 cycles and emission at 2,089, down from 6,873 and 3,496 respectively;
  five of six sampled ticks published a plan and the main loop spent about
  3,081 cycles waiting for the next frame.
- Snap-022 also resolved an apparent stray-bullet/ZP-corruption report: recorder
  writes identified the glyph as `SC_CARGO_DOT`, and cargo state advanced from
  a C-drone impact to the hub at the intended four-tick cadence. Cargo is now
  orange instead of bullet-yellow, and `paint_ghij` leaves unstacked hub letters
  gray rather than recoloring all four after one deposit.
- Coop snap-001 on 2026-07-29 captured a whole-plan replay from frames
  5388–about 5470. Slot 5 spawned a C at Y=`$68` into B/B/C geometry at
  Y=`$47/$54/$67`: serialized jobs at 28, 37, and 93 advanced the next start
  to 102, past the new C's deadline 95 despite three unused VIC-II lanes.
  The root planner fix gives all five candidates distinct lanes and fills
  release gaps before waiting. The visible standalone regression produced
  command lines `28,37,46,55,64`, lanes `2,3,0,1,4`, and
  `mux_last_error=0`. A separate visible 14-object circle run held command
  count 14 and error 0 after another 200 frames. Prospective spawn admission
  remains as a safety net.

## Next stress tests

1. Force sprite/background collision immediately before every lane handoff and
   prove the event reaches the old logical owner exactly once.
2. Churn allocation and freeing in arbitrary order across all 24 slots.
3. Move overlapping C/B/A objects through one another and assert lane priority.
4. Exercise deliberate plan-busy, lane-capacity, and raster-deadline failures,
   including rejected prospective spawns; prove free count, prior plan, and
   subsequent successful spawns remain correct.
5. Cover multicolor, expansion, and behind-background attribute changes.

## Memory layout

The production MUX layout is fixed and assembly-guarded: object pool `$C000`,
plans `$C300/$C500`, builder scratch `$C700`, and a currently reserved former
bucket page at `$C800`. Rail/cargo state follows at `$C900`; it must never be
included before the MUX allocations. Runtime sprite art remains fixed at
`$3000`, and the build script checks that `CODE` does not grow into it. For
intentional runtime overlays of emitted data, use assembler **reclaim**
segments — see [`assembler-syntax.md`](assembler-syntax.md) §8.
