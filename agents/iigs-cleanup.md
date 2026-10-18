# IIgs cleanup — 2026-10-18

Historical cleanup record. Subsequent beam scheduling, formatting-safe generators,
frontend animation and packaging changes are documented in the
[current handoff](iigs-beam-renderer-handoff.md).

Scope: remove abandoned IIgs implementation paths and misleading entry points;
preserve native gameplay, current renderer inputs, useful tests, shared platforms,
and matching evidence. The beam scheduler was NOT changed.

## What changed

- Removed the IIgs C platform/render runtime, compatibility headers, C build and
  profiling scripts, C lifecycle/demo probes, and their Make targets.
- Removed obsolete standalone renderer demos, whole-wave calibration/budget/
  scheduling/coalescing/retry implementations and superseded harnesses.
- Extracted live scene fixtures and PNG encoding from obsolete harness/model files
  into `native_scene_fixtures.py` and `native_png.py`. Removed the old closure model.
- Kept native gameplay adaptation, original assets, stack sprite generation,
  generic frontend components, input/lifecycle ownership, host oracle and tests.
- Simplified `native_probe.py` to prebuilt native binaries. Binary and source are
  required; the manifest defaults beside the executable. No hidden C compilation.
- Removed obsolete rejected-frame lifecycle test option. Kept real cleanup tests.
- Extracted the actual raster reader into `src/iigs/raster.asm`; removed
  obsolete demo drawing code. Kept the required lifecycle template, with explicit
  builder insertion marker, and the current NTSC clock.
- `make iigs-game` now builds the host schema explicitly. Public targets are
  `iigs-game`, `iigs-game-play`, `iigs-game-package`; old demo/C targets are retired.
- Replaced conflicting plans/handoffs with `iigs-beam-renderer-handoff.md`.
  The separate next-session prompt was deleted at the user's request before commit.
  Input and hardware notes remain relevant.

The native builder still has template substitutions. This cleanup did not redesign
that pipeline or alter gameplay. A fresh native build reproduces exactly the
pre-cleanup black-transition build:
`63083c158c8749269f5e210bc8ff6ea59fcc6bf6711a1a840ca232a0350e0e45`.

## Source layout follow-up

At the user's request, all files formerly in `src/iigs/native/` now live directly
in `src/iigs/`. Build scripts, tests and current documentation use the flat paths.
The removed-path inventory below records historical paths, not live dependencies.
The rebuilt executable is byte-for-byte identical to the pre-move build.

## Verification

- Native game rebuilt successfully; executable SHA256 identical to pre-cleanup.
- Native adapter and data-binding tests passed.
- Python syntax, local imports and literal source dependencies checked.
- All257 inventoried files under shared/game platform sources, assets and root
  Makefile retain their pre-cleanup hashes. No other frontend was modified.
- Current packaging regenerated with executable extraction/byte verification.
- Final ROM3 real-keyboard smoke passed, including black transitions and quit.
- All23 native framebuffer/bank01 scene fixtures passed with the extracted helpers.
  Matched reports are in `build/iigs/railgunner-iigs-evidence/cleanup-smoke` and
  `cleanup-scenes`. These are functional checks, not beam-stability acceptance.

## Recovery and evidence

These were largely untracked files; do not rely on Git to recover removed work.
A pre-cleanup source snapshot is at
`/tmp/railgunner-iigs-before-cleanup-20261018.tar.gz`.
Retired generated build items were moved (not destroyed) to
`/tmp/railgunner-iigs-retired-builds-20261018/`. These scratch locations are local
and not permanent storage. Do not put the retired sources back into active paths
merely to follow an old document.

After cleanup, the user deleted `build/` and rebuilt all four platforms. Old
measurement binaries and other generated experiments are no longer in that tree.
The user restored the reports under `build/iigs/railgunner-iigs-evidence/`; these
record their original binary hashes, not necessarily the current rebuilt image. Evidence includes old pass fields that do
NOT establish beam-safe presentation; see the current handoff.

Removed 71 obsolete source/document files and moved 97 generated build items.

### Removed paths

- `agents/iigs-continuous-renderer.md`
- `agents/iigs-native-plan.md`
- `agents/iigs-native-renderer.md`
- `agents/iigs-port-plan.md`
- `agents/iigs-specialized-renderer-design.md`
- `agents/iigs-specialized-renderer-handoff.md`
- `agents/iigs-specialized-renderer-implementation.md`
- `agents/iigs-specialized-renderer-overnight.md`
- `src/iigs/.DS_Store`
- `src/iigs/assets.h`
- `src/iigs/compat/compiler.h`
- `src/iigs/compat/stdint.h`
- `src/iigs/native/bands.asm`
- `src/iigs/native/clock.asm`
- `src/iigs/native/render.asm`
- `src/iigs/native/render_budget.asm`
- `src/iigs/native/render_calibrate.asm`
- `src/iigs/native/render_coalesce.asm`
- `src/iigs/native/render_schedule.asm`
- `src/iigs/native/render_wave.asm`
- `src/iigs/native/specialized_calibrate.asm`
- `src/iigs/native/specialized_calibrate_storage.asm`
- `src/iigs/native/specialized_damage.asm`
- `src/iigs/native/specialized_plan.asm`
- `src/iigs/native/specialized_retry.asm`
- `src/iigs/native/specialized_wave.asm`
- `src/iigs/platform.asm`
- `src/iigs/platform.c`
- `src/iigs/platform.h`
- `src/iigs/render.asm`
- `src/iigs/render.c`
- `src/iigs/render.h`
- `tools/iigs/assets.py`
- `tools/iigs/build.py`
- `tools/iigs/native_build.py`
- `tools/iigs/native_clock_test.py`
- `tools/iigs/native_edges.py`
- `tools/iigs/native_game_profile.py`
- `tools/iigs/native_game_smoke.py`
- `tools/iigs/native_geometry_test.py`
- `tools/iigs/native_matrix.py`
- `tools/iigs/native_render_budget_test.py`
- `tools/iigs/native_render_build.py`
- `tools/iigs/native_render_coalesce_analysis.py`
- `tools/iigs/native_render_coalesce_test.py`
- `tools/iigs/native_render_scene_test.py`
- `tools/iigs/native_render_schedule_test.py`
- `tools/iigs/native_render_stall_probe.py`
- `tools/iigs/native_render_test.py`
- `tools/iigs/native_render_verify.py`
- `tools/iigs/native_specialized_model.py`
- `tools/iigs/native_specialized_pixels_test.py`
- `tools/iigs/native_specialized_profile.py`
- `tools/iigs/native_specialized_retry_test.py`
- `tools/iigs/native_specialized_scene_test.py`
- `tools/iigs/native_specialized_sprite_test.py`
- `tools/iigs/native_specialized_trace.py`
- `tools/iigs/native_verify.py`
- `tools/iigs/native_verify_bands.py`
- `tools/iigs/probe.py`
- `tools/iigs/test.py`
- `tst/iigs/abi.asm`
- `tst/iigs/core_smoke.c`
- `tst/iigs/epoch.asm`
- `tst/iigs/native_abi.c`
- `tst/iigs/native_benchmark.c`
- `tst/iigs/native_clock.c`
- `tst/iigs/native_epoch.c`
- `tst/iigs/native_lifecycle.c`
- `tst/iigs/render_native_test.c`
- `tst/iigs/render_test.c`
