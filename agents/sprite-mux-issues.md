# Sprite mux code review

**Date:** 2026-07-26  
**Scope:** Production mux/pool (`src/sprite/mux_*.asm`, `src/game/objects.asm`, IRQ/main wiring), PLAY art harness, and `tst/` demos.  
**Policy:** Review only — **no source changes**.  
**Method:** Design handoffs (`objects-sprites.md`, `sprite-mux-status.md`), full read of builder/IRQ/pool, offline assemble, live c64m remote tests in PLAY mode (correct `set-memory` binary protocol).

## Verdict

The multiplexer is **structurally sound and matches the locked design** for the paths that matter to RailGunner: double-buffered immutable plans, Y-interval lane coloring with **C < B < A**, serialized raster job windows, collision latch capture on lane handoff, and fail-closed plan retention.

Live checks confirmed the PLAY lower-left stack, exact reuse deadlines, priority coloring, and capacity/deadline rejection. Remaining issues are mostly **integration hazards**, **unproven collision attribution**, **test-harness regression**, and a few **policy/edge** behaviors wave data must respect.

This is ready for gameplay integration with eyes open — not yet “battle-hardened” for collision.

---

## What works (verified)

### PLAY lower-left stack (lane reuse)

Default harness layout (LL: C@140, B@172, A@204, X=92):

| Cmd | Raster | Lane | Owner | Kind | Y |
|----:|-------:|-----:|------:|-----:|--:|
| 0 | 28 | 0 | 1 | C | 80 (UL) |
| 1 | 37 | 1 | 2 | B | 80 (UR) |
| 2 | 102 | 0 | 4 | C | 140 (LL) |
| 3 | 162 | 0 | 5 | B | 172 (LL) |
| 4 | 171 | 1 | 3 | A | 188 (LR) |
| 5 | 194 | 0 | 6 | A | 204 (LL) |

- All three LL objects share **lane 0** (non-overlapping Y → legal reuse).
- Release math matches design: after C bottom 160, B job at 162 (= 160 + `MUX_POST_GUARD` + 1); after B bottom 192, A job at 194.
- **`mux_last_error = 0`**, plan count 6.

Stacking **works** for the current staggered LL layout.

### C / B / A hardware priority

With only slots 4/5/6 renderable at the **same Y=160**:

| Owner | Kind | Lane |
|------:|------|-----:|
| 4 | C | 0 |
| 5 | B | 1 |
| 6 | A | 2 |

**PASS** (`C` lane `<` `B` `<` `A`).

Also **PASS** when A is higher on screen than C (Y 155/160/165) — coloring is by class + interval overlap, not by Y order. Matches design §9.3.

### Raster deadline boundary (exact)

With UL/UR/LR render-disabled so LL alone share lane 0:

| B Y | Expected | Observed |
|----:|----------|----------|
| 170 | fail (`MUX_ERR_RASTER_DEADLINE` = 4) | err=4, dirty stuck, prior plan retained |
| 171 | succeed | err=0, 3 cmds, reuse lines 28 / 162 / 193 |

Builder math matches `release = prev_bottom + 2`, `deadline = top - 9`.

### Capacity and density

| Case | Expected | Observed |
|------|----------|----------|
| 9 objects same Y | `MUX_ERR_LANE_CAPACITY` (2) | err=2, dirty stuck |
| 8 neutrals @ Y=80 | deadline fail (serialized jobs) | err=4 |
| 8 neutrals @ Y=120 | success | err=0, 8 cmds at lines 28,37,…,91 |

### Assembler / layout

- Production `src/main.asm` assembles: **CODE `[$080D–$1C69)`**, OBJECTS `[$C000–$C900)`.
- Plan buffers sit at `$C300` / `$C500` as designed; IRQ page-delta patching (+2) is correct.
- 24-byte SoA tables stay page-aligned.

---

## Issues

Severity key: **P0** ship-blocker for gameplay · **P1** real bug / silent fail risk · **P2** design gap / integration trap · **P3** polish / docs / debt.

### P1 — Collision attribution is implemented but unproven

`mux_irq` captures `$D01E`/`$D01F` into software lane masks, attributes to `hw_owner` before reuse, and double-buffers IRQ event banks. PLAY drones and demos **never set** `OBJF_BG_INTEREST` / `OBJF_SS_INTEREST`, and no automated test forces a BG collision immediately before a lane handoff.

Status doc already flags this; it remains the **most important unproven path**. A wrong owner map or clear order would look fine in demos and fail only when bullets hit drones under mux pressure.

**Suggestion:** dedicated test (or PLAY poke) with solid BG pixels under a sprite, `OBJF_BG_INTEREST` set, force lane reuse, assert `obj_pending_events[old_owner]` gets `OBJE_BG` exactly once.

---

### P1 — Unschedulable layouts freeze the last good plan with no PLAY feedback

On build failure, main correctly keeps the prior immutable plan (`main.asm` `bcs main_loop`) and leaves `mux_objects_dirty` set so the next logic tick retries. Demos turn the border red; **PLAY does not**.

Live example: moving LL C/B/A to the same Y while UL/UR/LR stayed active produced `MUX_ERR_RASTER_DEADLINE` and left the old plan on screen. Positions in the object tables and the displayed plan diverged until the layout became schedulable again.

**Suggestion:** temporary diagnostic (border / HUD / sticky flag) when `mux_last_error != 0`, at least in debug builds. Wave spawn code must treat build failure as “don’t commit this spawn,” not only rely on silent retention.

---

### P1 — `tst/` demos currently fail to assemble — **FIXED**

```text
tst/build_sprite_mux_dance.sh  →  spr_frames_src not found (video.asm)
```

**Cause:** `video::install_sprite_frames` referenced game-only `spr_frames_src`
while demos included shared `video.asm`.

**Fix:** moved install to `src/sys/sprite_install.asm` (included only from
`main.asm`). Demos keep `video.asm` for detect/palette and their own
`SPRITES`/`dance_sprite` at `$3000`.

---

### P2 — Global job serialization is stricter than “8 sprites on a line”

`schedule_and_emit` advances one global `mux_cursor` by `MUX_JOB_LINES` (9) per command, even for first occupants of **different** lanes. Consequences measured live:

- 8 first loads need last job start `28 + 7×9 = 91` → `top >= 100`.
- Design verification text (“eight first occupants near the top of the playfield meet their deadlines”) is **optimistic** relative to these constants.
- Wave data that parks many drones on a shared early Y will fail the whole plan even when lane coloring succeeds.

This is intentional conservatism (design §10.2), but it is easy to violate. Document for wave authors: stagger Y by ≥ ~11 lines for same-lane reuse, and do not put 7–8 first loads above ~Y 100 without extra vertical spread.

---

### P2 — Any single unschedulable object fails the entire candidate set

Examples that return `MUX_ERR_RASTER_DEADLINE` for the **whole** plan:

- One object with `obj_y_int < MUX_JOB_LINES` (9).
- One reuse gap one line too tight (B@170 after C@140).
- Interaction between an otherwise fine stack and a distant drone (same-Y LL stack + LR A@188 failed via lane-0 predecessor release).

Design forbids silent culls (good for determinism). Integration must ensure motion/spawn never introduce a single bad coordinate, or the whole mux freezes on the previous frame’s snapshot.

---

### P2 — `objects::init` while the raster IRQ is live is racy

`game_init_enter` calls `objects::init` without `SEI` and without `sprite_mux_irq::init`. `objects::init` wipes **all nine pages** `$C000–$C8FF` (object tables, **both plans**, owner maps, frame counters).

Cold start is fine (`cold_init` sequences pool → mux IRQ init → `irq_install` → `CLI`). Mid-session re-init can:

- Zero the front plan under a running command handler.
- Clear `mux_front_command_count` mid-frame.
- Leave VIC sprites enabled until the next line-0 reset.

**Suggestion:** `SEI`, disable sprites / re-init mux IRQ state, then `CLI`; or document that `objects::init` is cold/stage-only with IRQ already stopped.

---

### P2 — Main loop does not wait for plan accept (demos do)

Demo runtime:

```asm
lda objects::mux_plan_ready
bne demo_loop    ; wait until line 0 consumes prior publish
```

Production `main_loop` does not. If `mux_objects_dirty` is set while `mux_plan_ready` is still 1, `build` returns `MUX_ERR_PLAN_BUSY`, clears `mux_build_valid_plan`, and retries next tick. Functionally OK, but:

- Wastes a full build attempt path every tick while busy.
- Couples “facing dirty every 15 frames” to plan-accept timing more than necessary.

Minor; prefer the demo’s wait-or-skip pattern when integrating heavy AI.

---

### P2 — Failed-build thrash leaves dirty set forever

When a layout is permanently illegal, every logic tick re-runs gather/sort/color/schedule. Fine for 24 objects today; still unnecessary work and a footgun if build cost grows. Consider latching “spawn suppressed” after N failures or only rebuilding when object state actually changes again.

---

### P3 — Error codes defined but unused

| Code | Status |
|------|--------|
| `MUX_ERR_TOO_MANY_VISIBLE` | Unreachable (`OBJECT_CAPACITY` == 24) |
| `MUX_ERR_PRIORITY` | Never returned (folded into lane capacity) |
| `MUX_ERR_COMMAND_CAPACITY` | Unreachable (one cmd per candidate) |
| `MUX_ERR_BAD_COORDINATE` | Bad X/Y are **skipped** in gather, not hard-failed |

Skipping off-screen / unsafe Y is convenient but differs from a hard `BAD_COORDINATE` diagnostic. Worth documenting so agents do not expect those codes in `mux_last_error`.

---

### P3 — Stale handoffs

| Doc claim | Reality |
|-----------|---------|
| `objects-sprites.md` “source not yet implemented” | Implemented |
| `sprite-mux-status.md` CODE ends at `$1C00` | CODE ends at **`$1C69`**; sprites live at `$3000`, so the old `$1C00` collision warning is outdated |
| Demo PRGs “assemble” | Fixed — install path no longer shared with demos |

---

### P3 — Event overrun observed under stress

During remote thrashing (pause/poke, forced illegal layouts, turbo/step-frame), `mux_event_overrun` reached **5** and `mux_plan_miss` was high. That is expected when main does not drain every physical frame, but it confirms the overrun path is exercised. Worth a clean PLAY-only run after integration to ensure steady-state overrun stays 0 when the main loop is healthy.

---

## Code paths reviewed (no defect found)

These were scrutinized and look correct relative to the design:

- Gather flags: allocated + render, not retiring; X hi ≥ 2 off-screen; Y+height ≤ 262 common safe range; Y-expand → height 42.
- Insertion sort by `(priority, Y, slot)` then greedy lane coloring with drone `min_lane`.
- Neutral lane preference `ordinal & 7` with fallback to lowest free.
- Bucket Y-order pass at `$C800` preserves priority within a scanline (verified by C/B/A tests).
- Interest packing: `OBJF_BG/SS` bits 3–4 → `OBJE_*` via three `LSR`.
- Publish critical section; IRQ accepts only at line 0; replay on miss.
- Command path: latch → attribute old owner → disable lane → program → set owner → enable; complete shared-register masks (no RMW on `$D010` etc.).
- Retirement: deferred free + front/ready ref masks; slot 0 fixed.
- PAL/NTSC logic tick accumulator (50 Hz normalized).

---

## Live test log (summary)

| Test | Result |
|------|--------|
| PLAY default 6-drone plan | 6 cmds, err=0, LL lane-0 reuse OK |
| LL only, C/B/A same Y=160 | lanes 0/1/2, **C&lt;B&lt;A PASS** |
| Inverted vertical order still overlapping | C still lowest lane, **PASS** |
| Reuse gap B@170 after C@140 | **deadline fail** (expected) |
| Reuse gap B@171 | **pass**, 3 cmds |
| 9 same Y | **lane capacity** |
| 8 @ Y=80 / Y=120 | fail / pass as predicted by 9-line serialization |
| Y=5 object | whole-plan deadline fail |
| Forced same-Y LL while full field active | deadline fail + frozen prior plan (integration hazard) |

**Note:** Initial poke attempts used an invalid `set-memory` text form; correct protocol is binary paste framing (`set-memory $addr len ram` + raw bytes). Worth a line in `build-debug.md` if not already obvious from the c64m control-port doc.

---

## Recommended next work (priority order)

1. **Collision handoff proof** — BG collision one line before every lane reuse; assert old logical owner once.
2. ~~**Fix `tst/` assemble**~~ done — dance/circle rebuild via `tst/build_*.sh`.
3. **PLAY/debug surface for `mux_last_error`** when integrating waves.
4. **Hardening `objects::init` / stage re-entry** under a live IRQ.
5. Keep wave tables inside the measured Y/reuse/serialization envelope (document constants next to spawn code).

---

## Bottom line

The mux feature is a solid, design-faithful implementation. The lower-left PLAY stack **does stack and reuses a hardware lane correctly**. C/B/A priority coloring is correct. Deadline and capacity failures fail closed.

Do **not** treat the layer as finished until collision attribution is proven under reuse, demos build again, and wave/motion code is constrained (or diagnostically noisy) when a layout cannot be scheduled.
