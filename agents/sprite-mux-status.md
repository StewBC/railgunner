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
- C/B/A drone priority coloring, where C is front/small, B medium, A back/large.
- Neutral objects prefer `candidate ordinal & 7`, then fall back to the lowest
  legal lane. This compact round-robin bias avoids preventable rapid reuse of
  sprite 0 without changing drone priority rules.
- Collision-latch capture and old-owner attribution before lane reuse.
- PAL/NTSC detection with gameplay motion normalized to 50 logic ticks/second.
- Safe failure with the prior immutable plan retained when a layout cannot meet
  lane or raster-deadline constraints.

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

## Next stress tests

1. Force sprite/background collision immediately before every lane handoff and
   prove the event reaches the old logical owner exactly once.
2. Churn allocation and freeing in arbitrary order across all 24 slots.
3. Move overlapping C/B/A objects through one another and assert lane priority.
4. Exercise deliberate plan-busy, lane-capacity, and raster-deadline failures.
5. Cover multicolor, expansion, and behind-background attribute changes.

## Memory warning

The current production `CODE` segment ends exactly at `$1C00`, where the static
sprite segment begins. New production code cannot simply grow in place; free
bytes or revise the memory map before adding more routines. For intentional
runtime overlays of an emitted region (e.g. title image RAM reused as buffers),
use assembler **reclaim** segments (`.segdef "N", reclaim="HOST"`) — see
[`assembler-syntax.md`](assembler-syntax.md) §8; plain `noemit` overlaps are
rejected.
