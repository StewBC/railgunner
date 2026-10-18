# IIgs beam-following renderer handoff — 2026-10-18

## Start here: the fix has NOT been implemented

The current native game (post-cleanup SHA256
`63083c158c8749269f5e210bc8ff6ea59fcc6bf6711a1a840ca232a0350e0e45`)
produces correct completed pixels but flashes badly during
play. It does not coordinate erase/draw with the beam. The user compared it with
Time Pilot IIgs, which runs much busier scenes without this flashing at 14 MHz.
This is a renderer scheduling defect, not evidence of the IIgs's performance limit.
The task for this session was cleanup and this handoff, **not** implementation of
the next renderer. Do not mistake the cleanup or the existing tests for that fix.

The user wants the feel of the C64/Archie game, ideally good at 2.8 MHz and great at
7 MHz; 14 MHz is an acceptable fallback. All their machines are NTSC ROM3 with
8 or 14 MB. ROM1 and 2/4 MB are secondary, not established supported minima.
Use physical NTSC refresh (~59.92 Hz). Treat the original 50 Hz gameplay as 60 Hz
for now; any later movement tuning must be explicit and play-tested. 60 completed
presentations/sec is ideal; a stable 30 is acceptable. Audio is deferred.

**A late frame must complete. No whole-frame cost prediction, admission veto,
rejection, or abandoned pending generation. This does not prohibit waiting for the
beam to pass a region.** Occasional tearing is acceptable; habitual visible
blanking/erased sprites is not. The previous agent incorrectly conflated these.

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
- Only edit Railgunner. Time Pilot, Force, MrSprite, gssquared, c64m and shared
  external tooling are read-only references. Never use a headless emulator.

## Current implementation and why it flashes

`tools/iigs/native_specialized_build.py` layers sprite generation and current
renderer substitutions over `native_game_build.py`. This template-based builder
is still somewhat awkward; cleanup retained required inputs rather than rewrite
working lifecycle code. `src/iigs/main.asm` is a lifecycle **template**, not
an independently buildable demo. Its slice hooks/COPY marker are replaced by the
builder. Generated assembly and frozen inputs live under `build/iigs/`.

Relevant source:

| File under `src/iigs/` | Responsibility |
|---|---|
| `continuous_clock.asm`, `platform.asm`, `render_service.asm` | NTSC tick accounting, game/input servicing; cached OS-tick fast path |
| `continuous_capture.asm`, `render_snapshot.asm` | Capture stamp; immutable candidate and published displayed snapshot |
| `direct_plan.asm` | Changed glyph/background work; old/current object cells; per-strip jobs in stable layer/slot order |
| `continuous_controller.asm` | Complete candidate, then publish; iterate strips 0..24 with no beam wait |
| `continuous_wave.asm` | Each strip: black erase, glyph restore, then sprite fragments; callbacks between batches/phases/jobs |
| `specialized_sprite.asm` | Compiled stack dispatch, inks, clipping fallback |
| `raster.asm` | Stable physical 0..261 raster sample; C02E/F access only |
| `specialized_lifecycle*.asm`, `input.asm`, `main.asm` | Caller bank01 backup, ownership, entry/exit |

`native_sprite_compile.py` generates original-art sprite code. Generic
`render_*.asm` components still supply frontends/backgrounds and template inputs;
they are not a second supported game. `render_commit.asm` has legacy checks that
the specialized builder adapts for IRQ-enabled ordinary copying. Inspect the
frozen generated source as well as templates when tracing the actual executable.

The current top-to-bottom eight-line strip order is **not** beam scheduling.
Stores to bank01 with shadowing enabled become visible in E1 during erasure.
Gameplay services can run before redraw. The beam can therefore see an erased or
partially reconstructed region. Exact final pixels and mean FPS do not detect this.
All visible current objects are currently redrawn; there is no overlap-closure
optimization. `rd_count` means dirty cells on the specialized route, spans on the
generic route. `rwp_max_blackout=0` is a compatibility placeholder, not a measurement.

## Reference implementation to study first

Local paths (on this machine `/Users/swessels/Develop` resolves onto EXTERNAL):

- `/Volumes/EXTERNAL/swessels/Develop/github/personal/Time-Pilot/TimePilot-IIgs`
  - `src/game.asm`: `gsRasterLoop`, `gsRasterDone`, `gameProcessThings`.
  - `thingsSortAndCollide` and its sorting implementation: follow the actual
    old/new Y ordering and layer/overlap dependencies, not just the call name.
  - `gameProcessThings` tests `activeOldMaxY` against `zScanLine` before erasing,
    and `activeMaxY` plus `AF_ERASED` before drawing. `gsRasterDone` flushes
    remaining work. Read its frame-processing/AI ordering too before adapting it.
- `/Volumes/EXTERNAL/swessels/Develop/github/personal/force`: GS/OS ownership,
  relocated-stack wrappers, native adaptation reference.
- `/Volumes/EXTERNAL/swessels/Develop/github/external/MrSprite_v1.0a/Src/README-macOS.md`
  and executable `Src/MrSprite`: user's macOS sprite compiler. Compare actual
  generated code/cost with the existing compiler before deciding to replace it.
  Time Pilot is the successful real integration example.

Time Pilot's behavior is the reference, not a claim that its code can be copied
unchanged. Different object bounds, glyph bullets, HUD and background restoration
must be accounted for.

## Desired scheduling: user's suggestion and engineering constraints

The user suggests running logic as soon as the beam is past the lowest sprite,
then rendering immediately behind the beam, as in Time Pilot. This is a sensible
starting point. Here “VBL passes” means the moving raster/scan beam; vertical blank
is the interval outside the visible display, not a cursor moving through sprites.

1. Keep the currently displayed image intact while doing logic and preparation.
   Once the beam has passed the lowest relevant displayed region, use the remaining
   lower screen/blanking time for the next tick and plan. The relevant region is
   not necessarily just sprites: account for bullets/glyphs, rails, mines and HUD.
   Do not run simulation faster simply because a scene is empty or its lowest
   sprite moves up. Preserve the ~60 Hz tick contract and count any missed ticks.
2. Capture an immutable candidate and its relationship to the last **completed**
   displayed state. If preparation spans a refresh, keep working; do not discard
   it. Do not use partial stores as the basis for a new old-state snapshot.
3. Release bounded erase/restore/redraw work behind the beam. Sorting old erasures
   by their lower Y bound and new draws by their lower Y bound, with dependencies,
   is Time Pilot's model. A region is available after its last affected row has
   been scanned, leaving nearly a refresh before that region is scanned again.
   Use correct raster coordinates, wrap/epoch handling, and actual affected bounds.
4. Preserve layer priority and overlap dependencies. Sorting by Y alone is not
   sufficient: a later old-sprite erase must not wipe an already drawn new sprite;
   a background glyph restore must not wipe a stationary overlapping sprite.
   Group dependent regions, or use a correctly ordered erase/draw frontier. For a
   conservative group, release after the bottom of its **old and new** affected
   union, erase/restore the group, then redraw its objects in layer/slot order.
   Evaluate the cost of grouping; do not reintroduce a general per-pixel planner
   or an expensive full-screen dependency closure without evidence it is needed.
5. Keep the visible erase-to-redraw interval short. Avoid arbitrary gameplay or
   Toolbox work between erasure and its dependent redraw. Poll/service while
   waiting or at safe boundaries; do not fix flicker by masking interrupts for an
   entire frame. Tool9 callbacks and clock services still need bounded latency.
6. If a refresh is missed, finish the pending generation and record the miss.
   Do not abandon it, restart it each tick, or freeze presentation behind a budget
   gate. Avoid an extra full-refresh wait when the relevant beam crossing has
   already happened. Test wrap during both waiting and drawing. Late completion
   may tear occasionally; it must not make erase exposure the normal schedule.
7. Publish only after all candidate work is complete. A stable 30 Hz presentation
   can prepare on one refresh and draw on the next, with simulation maintained
   near60 Hz if affordable. Simulation ticks and completed presentations must be
   measured separately. Do not silently halve bullet speed or change gameplay.

Recommend proving a small Time Pilot-style object/region scheduler before broad
integration. Existing eight-row fragments may remain useful primitives; they are
not a requirement to retain the current expensive plan. Show the scheduling and
layer-dependency reasoning with a moving overlapping pair and a changing rail
under it. Prefer the simplest design that demonstrably avoids exposed erasures.
No new implementation was attempted in this cleanup session.

## Build and run from the cleaned tree

Dependencies: Python3, host C compiler (oracle only), `iix` ORCA/M toolchain,
`cadius`, GSSquared, and user's GS/OS template at the path below. No ORCA/C game
build is supported. Existing C64 assets are read; do not modify other frontends.

```sh
make iigs-game
make iigs-game-play IIGS_GAME_SPEED=14.3mhz
make iigs-game-package IIGS_GAME_SPEED=14.3mhz
```

Default speed is7.159 MHz and ROM3. Override `IIGS_ROM`, `IIGS_TEMPLATE` and
`IIGS_VOLUME` as needed. Default template is `../force/assets/iigs/disc/templat.2mg`,
volume `FORCE`; launch/package use private copies, never edit that template.
Build now explicitly generates the host schema before native GAME. Outputs:
`build/iigs/native-game-play/{RAILGUNNER,manifest.json,main.asm}` and
`build/iigs/native-game-package/{railgunner-boot.2mg,railgunner-transfer.2mg}`.

For a diagnostic VM, use `native_probe.py --binary ... --manifest ... --source ...
--rom 3 --speed ... --template ... --volume FORCE`. All three prebuilt paths are
from the matching build. It prints a private `session.json`; pass that file to
checks below. Diagnostic launch starts paused, window visible. Own and quit only
the VM you launched. Normal `make iigs-game-play` has no attached harness.

## Evidence, limitations, and next acceptance checks

Old retained level9 held-fire measurements, active PLAY portions of60-second runs:

| MHz | Complete FPS | Logic ticks/sec | Dropped PLAY ticks | Active PLAY seconds |
|---|---:|---:|---:|---:|
|14.3|33.869|59.924|0|32.892|
|7.159|16.193|59.928|0|33.841|
|2.8|4.595|59.641|8|30.902|

These are **known-flashing baseline results**, not performance or presentation
acceptance. Workloads were not full-duration busy PLAY; do not include frontend
idle time in a gameplay average. Reports and hashes are in
`build/iigs/railgunner-iigs-evidence/batched{14,7,2}`. Reports' `pass` fields use the old
throughput-only gate; they do not certify visible stability. The user initially
liked14 MHz, then explicitly reported severe flashing. That later report overrides
any interpretation of the earlier praise as acceptance.

Useful retained checks:

- `native_core_adapter_test.py`, `native_core_data_test.py`, oracle tests and
  `native_*gameplay/full/frontend/entities*_test.py`: native semantics against
  normalized host state; C64 authority and declared collision exception matter.
- `native_continuous_clock_test.py`: native tick arithmetic, coherent sampling,
  fast-path races/wrap/faults. Existing55 fast-path assertions passed.
- `native_sprite_compile_test.py`: generated sprite instruction/pixel proof.
- `native_continuous_sprite_test.py --session ...`: real <=8-row compiled/clipped
  fragments, exact ABI/mapping and traced IRQ-off intervals. Prior824 calls passed;
  longest measured stock interval ~1.30ms. Not a universal worst-case bound.
- `native_continuous_scene_test.py --session ...`:23 final framebuffer and bank01
  fixtures, including overlaps, HUD, clipping,24 slots and disappearance. Passed.
- `native_continuous_smoke.py --session ...`: real keys, frontend/play pixels,
  transition blackness and Ctrl-Q cleanup. Passed, including the black fix.
- `native_specialized_lifecycle_test.py --session ... --base 0xa0000 --scenario quit
  --game --pattern-display --post-quit-check`: ROM3 caller CPU/display/bank01/input
  restoration. Verify actual relocated base for a different environment. Initial
  socket creation can race this older helper; wait for the owned socket first.
- `native_continuous_profile.py --session ... --seconds 60 --level 9 --mid-level`:
  physical-time throughput, counters, independent completed pixels. Requires an
  instrumented `native_specialized_build.py --profile --fixture-input --held-fire`
  build, not the real-input game. `--stress` is artificial10-object placement;
  do not label it a natural playthrough or assume all10 remain alive throughout.

**Missing proof to add:** scan-time observations of the displayed image during
ordinary play, not just framebuffer snapshots after completion. Trace beam
position at actual erase/restore/draw boundaries and/or retain scanned frames.
Show no routinely exposed erase intermediate at14 and7 MHz. Measure time from
first erase to its dependent redraw, per-stage preparation/drawing, wrap behavior,
worst completed-frame gap and actual visible object count. Current coarse sampled
gap and one later breakpoint diagnostic are not worst-case frame measurements.

Test ordinary busy8–10 real objects plus continuous fire, concentrated overlap,
clipping, changing glyphs/HUD, appearance/disappearance, death/respawn and frontend
transitions. Keep24-slot fixtures as correctness/overload tests, not a fabricated
normal gameplay requirement. Test2.8/7.159/14.3 MHz honestly. Inspect visible output
with the user; stable30FPS can look much better than flickering34FPS. Recheck
input and exit ownership if service placement/IRQ exclusion changes. Hardware
acceptance remains the user's; do not claim emulator results establish it.

## Cleanup performed before this handoff

See `iigs-cleanup.md`. Retired C runtime and obsolete demo/admission/retry paths
were removed. Shared platform sources are untouched. Old generated experiments
were moved out of the working tree; current evidence remains. No beam-renderer
fix is hidden in the cleanup. Do not revive the retired predictive rejection path.
