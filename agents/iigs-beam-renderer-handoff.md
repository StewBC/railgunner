# IIgs beam renderer handoff — 2026-10-18

## Current status

The beam-following repair is implemented. This is no longer the cleanup-only
handoff. Read [measured results and limitations](iigs-beam-renderer-results.md)
before treating any speed as accepted. There is no predictive whole-frame
admission, rejection, retry, or abandoned generation.

The tested accelerated builds prevent exposed intermediate erasures in the
retained ordinary-play runs. Stock-speed performance and fixed 30 Hz cadence
remain limitations; exact completed pixels and average FPS are not sufficient
acceptance. Audio remains deferred. Hardware acceptance remains the user's.

## Final frontend/build follow-up

The user reports good gameplay at 7.159 MHz and unplayable stock 2.8 MHz.
The practical target is an accelerated IIgs at 7.159 MHz or faster; do not imply
that the outstanding stock-speed or locked-30-Hz goals are complete.

- Shipping `highscore_color.asm` uses light grey plus a moving yellow row at the
  original ten-tick cadence. Only the previous and next rows change (80 cells).
  Initials retain their yellow/white cursor. `native_game_export.py` overrides
  two shipping presentation procedures; CORETEST retains original C64 semantics.
- Cadius formatting is supported by checked `asm_transform.py` edits. Preserve
  column-zero labels and quoted data. Missing/ambiguous anchors fail generation.
- `IIGS_GAME_SPEED` sets emulator configuration/manifest metadata, not machine code.
- The launch disk/config are `railgunner-iigs.2mg` / `railgunner-iigs.gs2`.
  Packaging also produces a transfer 2MG and non-bootable `railgunner-iigs-800K.po`.
- See the results document's follow-up section for exact test scope and hashes.

## Preserve what works

- Shipping GAME is native ORCA/M, adapted from selected C64 assembly by explicit
  manifests. Native M=X=8 gameplay, native16 renderer/lifecycle, explicit ABI
  wrappers. No ORCA/C objects or C runtime are linked into the game.
- Keep gameplay rules, software collision behavior, original art, HUD, frontends,
  high scores, input ownership, Ctrl-Q cleanup, and caller display/CPU restoration.
- `src/core` is shared by SDL/Archie and used as a **host-only oracle**. Do not
  remove or rewrite it. C64 gameplay remains the behavioral authority; the oracle
  has a documented C64 spawning override. Host C tests are not the retired IIgs C
  runtime. `native_render_assets.py` also reads shared C data definitions.
- Current compiled sprites really relocate S into bank01 framebuffer memory and
  use generated push/store code. This is not an unimplemented trick. Preserve
  stack, P, D, DBR, C068/C035 and IRQ safety; no calls/interrupts on a pixel stack.
  Existing fragments are <=8 rows; changing that needs a new blackout/ABI proof.
- Full-screen transitions now set both legacy text colours (C022) black before
  disabling SHR, restore C022 after re-enabling SHR, and restore on failure.
  Preserve that fix: S/I and title transitions must not flash the GS/OS blue screen.
- Only edit Railgunner. Time Pilot, Force, MrSprite, gssquared, c 64m and shared
  external tooling are read-only references. Never use a headless emulator.

## Scheduling and overlap proof

Read-only reference: `/Volumes/EXTERNAL/swessels/Develop/github/personal/Time-Pilot/TimePilot-IIgs`.
`game.asm` runs `gameProcessThings` behind old/new lower bounds, flushes remaining
work in `gsRasterDone`, and performs `gamePostFrame` afterwards. `things.asm`
first sorts by minY, identifies transitive Y overlap, sorts each overlap by layer,
and changes erase ordering so a later erasure cannot wipe an earlier new draw.
These details matter more than the sorting routine's name.

RailGunner uses disjoint eight-row regions rather than whole-object overlap
closure. Every changed glyph and every old/current object footprint marks its
intersecting regions. Within a region, ALL current background restores precede
ALL current sprite fragments, in the existing stable layer/slot order. A moving
overlapping pair and changing rail therefore share an ordered transaction in
each affected region. A later region cannot erase an earlier fragment: its
stores and clipped source-row bounds do not cross the region boundary.

- `beam_prepare_window` opens after physical row 199, conservatively including
  all rails, bullets/glyphs, mines and HUD. It remembers the next absolute
  crossing using the coherent 32-bit clock, so a crossing during late work
  already grants the next preparation. Empty scenes cannot accelerate logic;
  the existing ~59.92 Hz clock still controls ticks and records dropped ticks.
- `beam_wait_strip` measures `(physical_line - region_bottom) mod 262` and
  releases in the first 128 lines behind that bottom. The remaining 126 lines
  before the region's TOP provide redraw time. Lower-screen release windows
  extend through raster wrap; do not truncate them at 261.
- Each bounded transaction restores current background once and redraws all
  its sprites. There are no foreground gameplay/Toolbox callbacks between
  restoration and dependent redraw. IRQs remain enabled except in the existing
  <=8-row compiled stack fragments. Service hooks run during preparation and
  after completed nonempty regions; publication services every 256 words.
- `rc_candidate` remains immutable through all work and waits. Only complete
  candidates publish. A late region/candidate completes; diagnostics record
  its exposure/cadence instead of cancelling it.
- Dirty row/column extents avoid scanning untouched parts of the 1000-cell grid.
  Background classification no longer scans eight rows to choose black-fill
  versus copy: the prepared current glyph background is authoritative.

A fixed region window is not a universal worst-case guarantee for arbitrary
24-object overload. Retain exact pixel overload tests and measure scan exposure;
do not turn a late observation into whole-frame rejection.

## Files

| File | Role |
|---|---|
| `src/iigs/beam_schedule.asm` | Preparation crossing, modulo raster release, optional physical-time exposure and cadence trace |
| `src/iigs/continuous_controller.asm` | Release/execute/service regions; publish only after completion |
| `src/iigs/continuous_wave.asm` | One background restore pass, then ordered sprite fragments; no intervening foreground callbacks |
| `src/iigs/direct_plan.asm` | Dirty extents, immutable cell and sprite jobs, stable layer/slot order |
| `src/iigs/render_snapshot.asm` | Immutable capture/completed publication; bounded publication service |
| `tools/iigs/native_specialized_build.py` | Includes scheduler and replaces the lifecycle main-loop gateway |
| `tools/iigs/native_continuous_profile.py` | Physical logic/presentation rates, independent pixels, exposure counters and exact gap histogram |
| `tools/iigs/native_beam_schedule_test.py` | Native boundary, wrap, pending-generation and exposure-arithmetic tests |

`src/iigs/main.asm` remains a lifecycle template. The specialized builder freezes
all assembly inputs and generators under its output directory. Inspect that
frozen executable source when diagnosing behavior. `rw_admitted` is a legacy
copy-permission flag, not a cost gate. `rwp_max_blackout` remains an unused
compatibility placeholder; use real fragment instruction traces for blackout.

## Build and run from the cleaned tree

Dependencies: Python 3, host C compiler (oracle only), `iix` ORCA/M toolchain,
`cadius`, GSSquared, and user's GS/OS template at the path below. No ORCA/C game
build is supported. Existing C64 assets are read; do not modify other frontends.

```sh
make iigs-game
make iigs-game-play IIGS_GAME_SPEED=14.3mhz
make iigs-game-package IIGS_GAME_SPEED=14.3mhz
```

Default speed is 7.159 MHz and ROM3. Override `IIGS_ROM`, `IIGS_TEMPLATE` and
`IIGS_VOLUME` as needed. Default template is `../force/assets/iigs/disc/templat.2mg`,
volume `FORCE`; launch/package use private copies, never edit that template.
Build now explicitly generates the host schema before native GAME. Outputs:
`build/iigs/native-game-play/{RAILGUNNER,manifest.json,main.asm}` and
`build/iigs/native-game-package/{railgunner-iigs.2mg,railgunner-iigs-transfer.2mg,railgunner-iigs-800K.po}`.

For a diagnostic VM, use `native_probe.py --binary ... --manifest ... --source ...
--rom 3 --speed ... --template ... --volume FORCE`. All three prebuilt paths are
from the matching build. It prints a private `session.json`; pass that file to
checks below. Diagnostic launch starts paused, window visible. Own and quit only
the VM you launched. Normal `make iigs-game-play` has no attached harness.

## Verification and remaining work

See [results](iigs-beam-renderer-results.md) for exact reports, hashes, counters,
cadence and limits. Keep native gameplay, input ownership, Ctrl-Q restoration,
original art and black C022 transitions intact. C64/SDL/Archie/shared core and
sibling repositories remain outside the edit scope.

The profiler brackets every restore/redraw with coherent physical timestamps.
A region is safe only if completion precedes the next scan of its TOP. If the
sampler itself crosses wrap, use the upcoming top, not an extra 262-line deadline.
Scanned intermediate erasures are distinct from completed-pixel correctness.
The trace ring retains 128 region records; cumulative counters cover the entire
unpaused timing interval. Cadence histograms use ceiling(gap/262), with 16 as
an overflow bin. Unchanged images/full blank transitions reset the busy cadence
chain; report that scope explicitly.

Do not claim locked 30 Hz from mean 35 FPS. Ordinary busy play did not establish
8–10 simultaneous visible objects; synthetic 10-object placement is a separate
stress test, not a natural playthrough. Preserve that distinction. Remaining acceptance work includes stock-speed optimization and tighter cadence;
never revive admission/rejection or weaken the scan-time acceptance check.
