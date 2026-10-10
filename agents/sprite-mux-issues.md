# Sprite mux code review

**Date:** 2026-07-26  
**Scope:** Production mux/pool (`src/c64/sprite/mux_*.asm`, `src/c64/game/objects.asm`, IRQ/main wiring), the play loop, and `tst/c64/` demos.  
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

- Production `src/c64/main.asm` assembles: **CODE `[$080D–$1C69)`**, OBJECTS `[$C000–$C900)`.
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

### P1 — `tst/c64/` demos currently fail to assemble — **FIXED**

```text
tst/c64/build_sprite_mux_dance.sh  →  spr_frames_src not found (video.asm)
```

**Cause:** `video::install_sprite_frames` referenced game-only `spr_frames_src`
while demos included shared `video.asm`.

**Fix:** moved install to `src/c64/sys/sprite_install.asm` (included only from
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

**Production confirmation (coop snap-022):** retained images show every
hardware sprite—not only the player—holding the exact same pixels from about
frame 6211 through 6269, then all jumping to current positions at frame 6270.
Character bullets continued from logical player coordinates during the freeze.
This is the signature of whole-plan replay, consistent with a hard build
rejection under the constraints above. The exact transient error was lost when
the paused machine was resumed before VIC/SoA history was collected; reproduce
and capture `mux_last_error` plus plan state before choosing the remediation.

**Planner root cause and drone-spawn safety fixed 2026-07-29:**
snap-001 preserved the exact transition. Slot 5 spawned a C at Y=`$68` while
slots 6/2/1 were B/B/C at Y=`$47/$54/$67`. Jobs at lines 28, 37, and 93 left
the global cursor at 102, beyond the new C's deadline 95; every build returned
`MUX_ERR_RASTER_DEADLINE` and replayed the old plan while character bullets
advanced. This was a false rejection, not VIC-II capacity: five objects were
being packed into reused low lanes while three hardware sprites sat unused.

The builder now assigns distinct lanes whenever candidate count is at most
eight. For true multiplexed sets, the scheduler fills a future-release idle gap
with ready work instead of blindly jumping past it. The visible
`sprite_mux_deadline` regression reproduced the captured five objects and
reported lines `28,37,46,55,64`, lanes `2,3,0,1,4`, and error 0.
`spawn_drone` also retains prospective build/rollback as a safety net for
genuinely illegal plans. General hard failures from motion or non-drone
graphical spawners remain visible through the fail-closed policy.

---

### ~~P2 — `objects::init` while the raster IRQ is live is racy~~ **fixed 2026-07-28**

`game_init_enter` used to call `objects::init` without `SEI` / without
`sprite_mux_irq::init` / without re-detecting PAL-NTSC. The nine-page wipe
includes `display_hz` and mux IRQ scalars, so a new game left **`display_hz=0`**
and could race a live raster IRQ.

**Initial fix (`game_init.asm`):** under `SEI` — `objects::init` →
`video::detect_standard` → `video::init_sprite_palette` →
`sprite_mux_irq::init` → `CLI`.

**Follow-up fix (2026-07-28):** that sequence was incomplete. Video detection
can leave a raster IRQ pending while interrupts are masked; restoring interrupts
without resetting/acknowledging the compare lets the handler treat the current
nonzero raster as command 0 of an empty plan. The corrected order is
`objects::init` → `sprite_mux_irq::init` → `video::detect_standard` → palette →
`irq_install` → `CLI`. A guarded live breakpoint proved zero command entries
with `mux_front_command_count=0` through title→PLAY.

The same review restored the fixed MUX memory ABI after rail state had begun
occupying `OBJECTS` first: pool `$C000`, plans `$C300/$C500`, scratch through
`$C8FF`, with rail/cargo state following at `$C900`. Assembly guards now reject
future drift. Retirement reference checks also mask IRQs while sampling the
front and ready plans.

---

### ~~P1 — Catch-up command left a raster IRQ pending~~ **fixed 2026-07-28**

**First symptom (coop snap-017, frames 2347–2353):** an off-right purple
class-A drone appeared at X=43 while the player simultaneously wrapped 256
pixels left. Both retained their low X bytes but lost their `$D010` bits.

**Cause:** `schedule_run_now` can enter another command inline when its raster
target is already at/past the beam. Programming an on-beam compare can latch a
new raster source, but only the outer hardware IRQ entry acknowledged `$D019`.
After the inline chain completed, RTI immediately re-entered the IRQ with the
command cursor already at the plan count. The old shell inferred phase from
the *current* `$D012` raster read and dispatched stale command 4: owner 5, lane
1, X=$12B, Y=$DC, pointer `$C9`, color 4, X-MSB mask 0.

**First follow-up:** deriving IRQ phase from
`irq_command_index < mux_front_command_count` prevented the stale read, but the
pending source then caused a premature second `frame_start` in mid-display.
Coop snap-019 showed frame 1210's A drone cut off after two lines at raster 79,
followed by the same plan running again from raster 95; frames 1221, 1222, and
1228–1246 repeated the disappearance.

**Complete fix (`mux_irq.asm`):** every `command` entry now acknowledges
`$D019`, including inline catch-up entries. Cursor/count remains the robust
phase discriminator, and mux init explicitly zeros the cursor.

---

### P2 — Main loop does not wait for plan accept (demos do)

Demo runtime:

```asm
lda objects::mux_plan_ready
bne demo_loop    ; wait until line 0 consumes prior publish
```

Production `main_loop` does not. If `mux_objects_dirty` is set while
`mux_plan_ready` is still 1, `build` returns early with `MUX_ERR_PLAN_BUSY`
(does **not** clear a pending `mux_build_valid_plan` — that stomp was fixed
upstream of this review). Functionally OK; the early exit is cheap. Full rebuild
still runs every tick when dirty and not busy.

Minor; prefer the demo’s wait-or-skip pattern when integrating heavy AI.

---

### ~~P1 — Permanent main-loop lag under load (stall dogfood)~~ **fixed 2026-07-28**

**Symptom (coop + frame ring):** under multi-drone load, motion stuttered
(~2-frame freezes) while the host still painted at 50 Hz. Snap showed
`logic_ticks_pending ≈ 200`, `mux_last_error = PLAN_BUSY`, `dirty=1`, 6-command
plans.

**Cause:** `main_loop` did `dec logic_ticks_pending` once per loop while the IRQ
could `inc` every physical frame. When `mode_run` + mux build overran a frame,
pending grew without bound → permanent slow-motion rather than dropped ticks.

**Fix (`main.asm`):** real-time policy — if any tick is due, clear
`logic_ticks_pending` and run **exactly one** logic update. Missed ticks are
dropped; wall-clock pace is preserved. Prefer this over catch-up spirals.

---

### ~~P1 — One-frame player jump / ghost (missed mux raster)~~ **fixed 2026-07-28**

**Symptom (coop scrub + VIC ring, snap-009 f1019–1021):** player appears to
jump ~20px for one frame; dual green on H-rail + lower V-rail band. SoA
`obj_x_lo` walked smoothly (+4); display did not. VIC: one frame
`spr_en`/`spr_vis` selected a lane with player ptr at a stale X while another
lane held a green B-drone at Y=`$BB`.

**Cause:** if a mux command IRQ overruns past the **next** job’s compare line,
`$D012` will not match again that frame — the next command is **skipped**. The
rest of the frame keeps a partial enable mask / half-updated lanes → one-frame
jump or ghost. Stale X/Y from prior frames on unused lanes made ghosts worse.

**Fix (`mux_irq.asm`):**
1. After programming the next job line, if current raster ≥ target, **run the
   next command in the same IRQ** (missed-line catch-up). Job lines are
   non-decreasing within a frame.
2. Frame start: zero all eight sprite X/Y pairs after disable.
3. Before reprogramming a lane: park that sprite’s Y at 0 while disabled.

---

### ~~P1 — Purple Q1 pop on despawn (same-tick slot reuse)~~ **fixed 2026-07-28**

**Symptom (snap-011 f1661–62):** purple A in Q1 “pops forward then back.”
SoA Y stayed `$4A` then `clear_slot` → `$00` at `$177C`; VIC one frame showed
purple lane at **Y=`$CB` / ptr=`$CA`** (not the SoA pose). Red C composite
centroid jumped when purple left.

**Cause:** `retire_and_try_free` could **free the slot in the same logic tick**
if it was absent from front/ready refs. `mode_run` then `alloc` recycled that
slot for a new drone before the next line-0 plan swap; the next published plan
snapped the recycled slot to the new spawn (different Y/ptr). Design §5.3
forbids immediate reuse while a plan may still own the logical slot.

**Fix (`objects.asm`):** `retire_and_try_free` only **retires** (clear RENDER,
set RETIRING, dirty). Free always goes through **`reap`** at the start of the
next logic tick (before spawn). `reap` also sets dirty when it frees.

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
| `sprite-mux-status.md` old CODE-end warning | Updated after the reset/layout follow-up; sprites remain fixed at `$3000` |
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
- Stable small-list Y sort preserves the prior priority/slot order within a
  scanline; it replaced the fixed 256-bucket pass after profiling showed the
  latter consumed about 6,900 cycles for six candidates.
- Interest packing: `OBJF_BG/SS` bits 3–4 → `OBJE_*` via three `LSR`.
- Publish critical section; IRQ accepts only at line 0; replay on miss.
- IRQ phase is selected from command cursor/count, not the current raster read.
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
2. ~~**Fix `tst/c64/` assemble**~~ done — dance/circle rebuild via `tst/c64/build_*.sh`.
3. **PLAY/debug surface for `mux_last_error`** when integrating waves.
4. **Hardening `objects::init` / stage re-entry** under a live IRQ.
5. Keep wave tables inside the measured Y/reuse/serialization envelope (document constants next to spawn code).

---

## Bottom line

The mux feature is a solid, design-faithful implementation. The lower-left PLAY stack **does stack and reuses a hardware lane correctly**. C/B/A priority coloring is correct. Deadline and capacity failures fail closed.

Do **not** treat the layer as finished until collision attribution is proven under reuse, demos build again, and wave/motion code is constrained (or diagnostically noisy) when a layout cannot be scheduled.
