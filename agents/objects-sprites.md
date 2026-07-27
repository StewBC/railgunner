# Graphical objects and hardware-sprite system

**Status:** implementation design locked; source not yet implemented.
**Scope:** the common pool for objects drawn with VIC-II hardware sprites, the
frame snapshot, the general-purpose raster multiplexer, and collision-event
attribution. Character objects (rail and bullets), drone AI, wave composition,
and motion helpers are consumers of this system and remain separate.

Companions:

- [`railgunner.md`](railgunner.md) — gameplay rules and authoritative A/B/C
  convention.
- [`repo-layout.md`](repo-layout.md) — file ownership and include rules.
- [`assembler-syntax.md`](assembler-syntax.md) — required before writing source.
- [`build-debug.md`](build-debug.md) — c64m launch, raster, and collision
  inspection.

This document is deliberately implementation-oriented. A coder should not have
to choose a data representation, collision-ownership rule, frame handoff, or
failure policy while implementing it.

---

## 1. Locked decisions

1. **Object** means any gameplay entity.
2. **Graphical object** means an object represented by one VIC-II hardware
   sprite. The first implementation does not support one graphical object
   consuming multiple hardware sprites.
3. **Hardware sprite** means VIC-II sprite 0–7. Hardware slots are transient
   raster resources, not object identities.
4. The graphical-object pool contains **24 slots**, numbered 0–23.
5. Logical object slot **0 is permanently allocated to the player**. It may be
   render-disabled, but is never returned to the free pool.
6. All eight hardware sprites are multiplexable. No hardware sprite number is
   permanently reserved for the player.
7. The intended content ceiling is **at most seven graphical objects on any
   raster line**, leaving one hardware lane of safety. The system detects eight
   correctly and rejects nine; wave data should target seven.
8. Drone types are fixed:

   | Type | Size | Hits | Target | Visual order |
   |------|------|------|--------|--------------|
   | A | large | 3 | rail | behind B and C |
   | B | medium | 2 | rail | between A and C |
   | C | small | 1 | player | in front of A and B |

9. Lower VIC-II sprite numbers draw in front. For overlapping drone intervals,
   the scheduler therefore enforces `C hardware number < B hardware number <
   A hardware number`. Same-type order is immaterial.
10. Player and bonus relative sprite priority is immaterial. Player/bonus
    collection is a software overlap test.
11. Player graphics, shield, and repair animation should be composited into one
    sprite frame where art permits. Two writable 64-byte buffers allow an
    inactive frame to be changed and then selected atomically by pointer.
12. Positions are fractional:

    - X: unsigned 16.8 storage, three bytes.
    - Y: unsigned 8.8 storage, two bytes.

    Velocity uses matching two's-complement tables when the motion layer is
    added. The first implementation reserves the layout but does not add public
    motion/accessor routines.
13. PAL and NTSC are both targets. Gameplay runs at a normalized **50 logical
    ticks per real-world second** on both standards.
14. `$D01F` is a collision candidate latch, not an exclusive front-object
    selector. If several overlapping drones touch the same bullet pixels in one
    frame, all may be hit; the bullet is consumed once.
15. `$D01E` support is present but opt-in per graphical object. It reports
    participants, not collision pairs.
16. An unschedulable render set is never silently culled. A prospective spawn
    is deferred; an unexpected failure of an already-valid set is surfaced as
    a diagnostic.

---

## 2. Responsibility boundaries

### Object pool owns

- Stable logical slot identity for slots 0–23.
- Allocation, retirement, and safe deferred reuse.
- Position and sprite presentation fields.
- Per-object collision-interest flags.
- Sticky gameplay-event bytes.
- The future velocity-table locations.

### Mux builder owns

- Selecting renderable objects from the pool.
- Conservative vertical intervals.
- Hardware-lane assignment and drone priority.
- Raster programming-window validation.
- Building an immutable, timed command plan.
- The object-reference mask attached to that plan.

### Raster IRQ owns

- Selecting a published front plan at frame start.
- Programming VIC sprite registers from that plan.
- Tracking the current logical owner of each hardware sprite.
- Reading the global read-clear collision latches before ownership changes.
- Moving collision indications into an IRQ event buffer.
- Producing physical-frame and normalized-logic-tick signals.

### Gameplay collision code owns

- Interpreting a sprite/background event as bullet versus rail.
- Applying damage, score, explosions, and bullet consumption.
- Software player/bonus overlap.
- Any pair-specific sprite/sprite logic.

### AI/motion code owns

- Velocity selection and fractional integration.
- Drone paths and arrival decisions.
- Render-request state.
- Spawn retry after pool or schedule refusal.

The IRQ must never call AI, scan the object pool, sort objects, inspect screen
characters, or resolve gameplay damage.

---

## 3. Coordinate contract

The integer portions use **VIC sprite coordinate space** so the front plan can
copy them directly to `$D000–$D010`:

```text
X position = obj_x_hi : obj_x_lo . obj_x_frac
Y position =            obj_y_int . obj_y_frac
```

- `obj_x_hi` is a full byte for efficient 16-bit whole-position arithmetic.
  A renderable VIC X uses only bit 0. Values with other high bits set are
  off-screen and omitted from the plan.
- `obj_y_int` is the byte written to the sprite Y register.
- Positions describe the hardware sprite's 24×21 canvas origin, not the
  visible artwork's center.
- Frame/hitbox metadata supplies offsets to an object's meaningful visual or
  collision bounds.
- Integer-to-character conversion belongs to collision/render helpers and
  subtracts the playfield's VIC origin before shifting by three.
- Fractional bytes never reach VIC registers.

Future integration is a normal low-to-high add using the same slot index:

```text
x_frac += vx_frac
x_lo   += vx_lo + carry
x_hi   += vx_hi + carry

y_frac += vy_frac
y_int  += vy_int + carry
```

This supports cardinal and diagonal motion. Initial drone content may use only
one nonzero velocity axis; the object representation must not impose that
restriction.

---

## 4. Structure-of-arrays memory layout

### 4.1 Rules

- Every per-object field is a separate 24-byte table.
- Tables used together take the same slot index in `X`.
- No 24-byte table may cross a page boundary. Its base low byte must be at most
  `$E8`.
- Frequently indexed fields stay byte-per-object. Do not pack hot flags merely
  to save a few bytes; shifts and read/modify/write cost more than the RAM.
- Zero page holds only pointers, counters, masks, and IRQ scalars. The 24-entry
  tables live in normal RAM and use absolute indexed addressing.
- Reserve `$C000–$C8FF` for the pool, plans, and builder scratch. Add a named
  `noemit` segment when implementation begins and clear runtime state explicitly
  during initialization.

### 4.2 Core page: `$C000`

The ten arrays fill 240 bytes and leave `$C0F0–$C0FF` for non-indexed scalars.

| Offset | Array | Meaning |
|-------:|-------|---------|
| `$00` | `obj_flags[24]` | lifecycle, render request, collision interest |
| `$18` | `obj_kind[24]` | player, drone A/B/C, bonus, effect |
| `$30` | `obj_x_frac[24]` | X fraction |
| `$48` | `obj_x_lo[24]` | X whole low byte |
| `$60` | `obj_x_hi[24]` | X whole high byte; VIC uses bit 0 |
| `$78` | `obj_y_frac[24]` | Y fraction |
| `$90` | `obj_y_int[24]` | Y whole byte |
| `$A8` | `obj_sprite_ptr[24]` | VIC sprite pointer value |
| `$C0` | `obj_sprite_color[24]` | low color nybble |
| `$D8` | `obj_sprite_attr[24]` | multicolor/expand/behind-background |

`obj_flags`:

| Bit | Name | Meaning |
|----:|------|---------|
| 0 | `OBJF_ALLOCATED` | slot contains a logical object |
| 1 | `OBJF_RENDER` | request inclusion when coordinates are renderable |
| 2 | `OBJF_RETIRING` | destroyed; excluded from new plans, not yet reusable |
| 3 | `OBJF_BG_INTEREST` | publish `$D01F` events for this object |
| 4 | `OBJF_SS_INTEREST` | publish `$D01E` participant events |
| 5–7 | reserved | write zero |

`obj_sprite_attr`:

| Bit | Name | VIC destination |
|----:|------|-----------------|
| 0 | `OBJA_MULTICOLOR` | `$D01C` |
| 1 | `OBJA_X_EXPAND` | `$D01D` |
| 2 | `OBJA_Y_EXPAND` | `$D017` |
| 3 | `OBJA_BEHIND_BG` | `$D01B` |
| 4–7 | reserved | write zero |

Object kinds start with:

```text
OBJ_PLAYER  = 0
OBJ_DRONE_A = 1
OBJ_DRONE_B = 2
OBJ_DRONE_C = 3
OBJ_BONUS   = 4
OBJ_EFFECT  = 5
```

Kind-to-priority and kind-to-default-interest are lookup tables, not branches
spread through the mux.

### 4.3 Auxiliary/future-motion page: `$C100`

| Offset | Array | Round-one use |
|-------:|-------|---------------|
| `$00` | `obj_vx_frac[24]` | reserved; cleared |
| `$18` | `obj_vx_lo[24]` | reserved; cleared |
| `$30` | `obj_vx_hi[24]` | reserved; cleared |
| `$48` | `obj_vy_frac[24]` | reserved; cleared |
| `$60` | `obj_vy_int[24]` | reserved; cleared |
| `$78` | `obj_hitbox_id[24]` | tight opaque-envelope metadata |
| `$90` | `obj_pending_events[24]` | sticky main-thread events |
| `$A8` | `obj_anim_state[24]` | reserved presentation state |
| `$C0` | `obj_user[24]` | owning gameplay system's compact index/state |
| `$D8` | reserved 24-byte field | must remain available |

The reserved velocity arrays prevent a later motion layer from forcing a data
layout migration. They do not imply motion accessors in the first code round.

### 4.4 Runtime page: `$C200`

This page holds:

- Two 24-byte IRQ event banks.
- The 23-byte free-slot stack and count.
- `hw_owner[8]`, `$FF` meaning no logical owner.
- `hw_interest[8]`.
- Software collision masks accumulated from `$D01E/$D01F`.
- Front/back plan IDs and ready/acknowledgement flags.
- Three-byte front-plan object-reference mask.
- Physical frame sequence, main acknowledgement, logic accumulator, and
  pending logical-tick count.
- Diagnostic counters and the last mux error.

Exact scalar order may be chosen when source is laid out, but it must remain
inside this page and be documented in `src/sys/memory.asm`.

### 4.5 Command plans and scratch

```text
$C300–$C4FF  plan 0
$C500–$C6FF  plan 1
$C700–$C8FF  builder scratch
```

Both plan buffers have identical field offsets so the IRQ can switch buffers by
patching only the high bytes of its absolute-indexed loads at frame start.

Exact plan layout, relative to `$C300` for plan 0 and `$C500` for plan 1:

| Relative address | Field |
|-----------------:|-------|
| page 0 + `$00` | `cmd_line[24]` |
| page 0 + `$18` | `cmd_lane[24]` |
| page 0 + `$30` | `cmd_owner[24]` |
| page 0 + `$48` | `cmd_interest[24]` |
| page 0 + `$60` | `cmd_x_lo[24]` |
| page 0 + `$78` | `cmd_y[24]` |
| page 0 + `$90` | `cmd_ptr[24]` |
| page 0 + `$A8` | `cmd_color[24]` |
| page 0 + `$C0` | `cmd_enable_mask[24]` |
| page 0 + `$D8` | `cmd_x_msb_mask[24]` |
| page 1 + `$00` | `cmd_x_expand_mask[24]` |
| page 1 + `$18` | `cmd_y_expand_mask[24]` |
| page 1 + `$30` | `cmd_multicolor_mask[24]` |
| page 1 + `$48` | `cmd_bg_priority_mask[24]` |
| page 1 + `$60` | command count |
| page 1 + `$61` | validity byte |
| page 1 + `$62..$64` | logical-object reference mask |
| page 1 + `$65` | build sequence |
| page 1 + `$66..$FF` | reserved; write zero in debug initialization |

Builder scratch at `$C700–$C8FF` is not part of an IRQ or gameplay ABI. Its
array labels may be arranged to suit the chosen implementation, but the same
24-byte/no-page-crossing rule applies and the final arrangement must be listed
in `src/sys/memory.asm`.

---

## 5. Object lifecycle

### 5.1 Initialization

`objects::init` must:

1. Clear both object pages, both event banks, owner maps, and diagnostics.
2. Mark slot 0 allocated as `OBJ_PLAYER`; leave render disabled.
3. Fill the free stack so allocations return slots 1, 2, 3, … when no frees
   have yet occurred.
4. Set every hardware owner to `$FF`.
5. Set both collision-accumulator masks to zero.

### 5.2 Allocation ABI

`objects::alloc`:

- Input: none.
- Success: carry clear, `X = allocated slot` in 1–23.
- Failure: carry set, `A = OBJ_ERR_POOL_FULL`; no table or stack changes.
- It pops one free-stack entry, clears every field for that slot, applies
  neutral defaults, then sets `OBJF_ALLOCATED`.
- Allocation clears both IRQ-bank event bytes and
  `obj_pending_events[slot]` before the slot becomes visible to callers.

Callers initialize kind, position, pointer, color, attributes, hitbox, and
interest flags directly through the indexed arrays. There is no `set_x`,
`set_color`, or similar subroutine.

### 5.3 Retirement, not immediate free

`objects::retire`:

- Input: `X = slot`.
- Slot 0 is ignored and reports `OBJ_ERR_PLAYER_FIXED` in debug builds.
- The operation is idempotent.
- Clear `OBJF_RENDER`; set `OBJF_RETIRING`.
- Do **not** push the slot onto the free stack yet.

A retiring slot may still be referenced by the immutable front plan for the
rest of the physical frame. Immediate reuse could cause a late collision bit to
be delivered to a new object with the same logical slot.

### 5.4 Reaping

Each plan carries a 24-bit mask of logical slots it references.
`objects::reap` runs in the main loop only after IRQ events have been drained:

1. Scan slots 1–23 with `OBJF_RETIRING`.
2. If the slot is absent from the current front-plan reference mask and absent
   from the pending published plan, clear all fields and push it onto the free
   stack.
3. Otherwise leave it retiring.

This also handles a missed plan swap: a slot is not reused while an old front
plan is being replayed.

---

## 6. Frame ownership and synchronization

There are three distinct state domains:

```text
main-owned object arrays
        ↓ mux builder
main-owned unpublished back plan
        ↓ atomic publish
IRQ-owned immutable front plan
        ↓ collision owner map
IRQ event bank → main pending-event table
```

### 6.1 Rules

- Main code never edits the front plan.
- IRQ code never reads live object position or presentation arrays.
- A complete back plan is published with a short `PHP / SEI / ... / PLP`
  critical section.
- The IRQ accepts a published plan only at raster line 0.
- If no new plan is ready, it replays the existing front plan and increments
  `mux_plan_miss`; it does not display a half-built plan.
- Plan IDs and all cursors are bytes; only 0 and 1 are valid plan IDs.

### 6.2 Physical-frame start

At raster line 0, in this order:

1. Acknowledge the VIC raster IRQ.
2. Read `$D01F` and `$D01E`; OR them into the software hardware-lane masks.
3. Attribute all remaining accumulated bits through the **old**
   `hw_owner[]/hw_interest[]` maps.
4. Disable all hardware sprites and set every owner to `$FF`.
5. Finish the current IRQ event bank. If the main loop acknowledged the prior
   read bank, swap event-bank roles and clear the new write bank. If not, keep
   accumulating and set an event-overrun diagnostic; never overwrite unread
   events.
6. Accept the published plan if ready; otherwise retain the current plan.
7. Patch the command-reader operand high bytes for the chosen front plan.
8. Publish that plan's reference mask for retirement checks.
9. Reset the command cursor and all VIC sprite shadow masks.
10. Advance physical-frame and 50 Hz logical-tick accounting.
11. Signal the main loop that a physical frame began.
12. Program the next command raster, or raster 0 of the next frame if the plan
    is empty.

The frame-start handler owns raster lines 0–7. No sprite-load command may be
scheduled earlier than line 8.

### 6.3 Main-loop order

Once per physical frame:

1. Wait for a new physical-frame sequence.
2. Drain the completed IRQ event bank by ORing it into
   `obj_pending_events[]`; acknowledge the bank.
3. Run `objects::reap`.
4. If a normalized logical tick is due:
   1. resolve pending collisions;
   2. update AI and timers;
   3. integrate motion when that layer exists;
   4. perform spawn attempts.
5. Build a new mux plan from the resulting object state.
6. Publish only a complete successful plan.
7. Mark the physical frame consumed.

Collision is handled before motion so an event is interpreted at the position
that produced it, rather than after the object has advanced again.

---

## 7. PAL/NTSC normalization

### 7.1 Detection

Detect the video standard once during cold initialization, before raster IRQs:

1. Wait for `$D011` raster bit 8 to become set.
2. While it remains set, watch `$D012`.
3. PAL reaches a low raster value of at least `$20` in the 256–311 region.
4. NTSC wraps after line 262 and therefore never reaches `$20` while bit 8 is
   set.

Store `VIDEO_PAL` or `VIDEO_NTSC` and set `display_hz` to 50 or 60.

### 7.2 Logical ticks

Use a byte accumulator at physical-frame start:

```text
logic_accum += 50
if logic_accum >= display_hz:
    logic_accum -= display_hz
    logic_ticks_pending += 1
```

- PAL produces one logical tick every physical frame.
- NTSC produces five logical ticks every six physical frames.
- AI speed, fractional velocities, wave timing, and gameplay animation therefore
  have the same real-world pace.
- Rendering may repeat the prior position on the skipped NTSC frame.
- Input may be sampled every physical frame, but gameplay consumes it on logical
  ticks. Edge bits must be held until consumed.

All mux command rasters are in 0–255, common to PAL and NTSC. Raster compare bit
8 remains clear. After a late visible command, the next compare at line 0 occurs
only after the standard's natural frame wrap.

---

## 8. Sprite dimensions and frame metadata

An unexpanded VIC sprite always consumes a hardware lane for its full 21-line
DMA/display interval even if only an 8×8 portion contains opaque pixels.

Recommended art envelopes:

| Drone | Suggested opaque area | Expansion |
|-------|-----------------------|-----------|
| C small | about 8×8 | none |
| B medium | 12×16 or 16×12 | none |
| A large | up to 24×12 horizontal or 12×21 vertical | none |

- Directionally elongated A/B drones use separate horizontal and vertical
  frames.
- Transparent padding is allowed and does not itself cause VIC collision.
- Tight per-frame or per-shape hitbox metadata prevents padding from confusing
  software collision classification.
- X expansion is supported as an attribute but should be exceptional.
- Y expansion is supported and makes the conservative vertical interval 42
  lines. Wave planning must account for the doubled pressure.
- Multicolor is an object attribute. Remember that it provides 12 double-width
  logical pixels, not 24 independently colored horizontal pixels.
- `$D025/$D026` are shared by every multicolor sprite. They are stage/global
  palette values, set outside the mux and never rewritten per object. Each
  command changes only the lane's individual `$D027–$D02E` color. Sprite art
  must be authored against the common pair.
- Software hitbox dimensions and offsets must apply X/Y expansion when an
  expanded object opts into collision interpretation.

### Dynamic player frames

Reserve two sprite blocks in VIC bank 0, preferably `$3E00` and `$3E40`
(pointers `$F8/$F9`):

1. The currently displayed block is read-only for the frame.
2. Main code composes the next player/shield/repair image into the inactive
   block.
3. After composition, change `obj_sprite_ptr[0]` to the inactive pointer.
4. The next back plan captures that pointer.

Static sprite frames may occupy `$3000–$3DFF`. Keep all sprite blocks aligned to
64 bytes and document the final region in `src/sys/memory.asm`.

---

## 9. Lane assignment

### 9.1 Conservative interval

For lane conflicts, treat an object as occupying:

```text
top    = obj_y_int
height = 21, or 42 with Y expansion
bottom = top + height - 1
```

This is deliberately conservative around the VIC's fetch/display pipeline.
Transparent top or bottom rows do not shorten the interval.

The first implementation does not render a sprite DMA interval across the
NTSC frame wrap. Use the common PAL/NTSC safe condition:

```text
top + height <= 262
```

Thus the greatest renderable top is 241 unexpanded or 220 Y-expanded. Objects
farther below the screen remain logically active but are omitted as off-screen
until they enter the safe range. This prevents a sprite that is still DMA-active
after NTSC wraps to line 0 from outliving its hardware-owner map. Wave and
player coordinate constants must keep visible gameplay inside this common
range.

### 9.2 Candidate order

Build a temporary list of allocated, render-requested, coordinate-renderable
objects. Process drone priority classes in this order:

1. C (front)
2. B
3. A (back)
4. neutral kinds (player, bonus, non-priority effects)

Within each class, insertion-sort by `(top, logical slot)`. Twenty-four entries
is small, positions change gradually, and insertion sort behaves well on nearly
sorted frame-to-frame data.

### 9.3 Greedy constrained coloring

For each candidate:

1. Scan already assigned candidates whose conservative Y intervals overlap.
2. OR their hardware-lane bits into a forbidden mask.
3. For a drone, set `minimum_lane` to one greater than every overlapping
   higher-priority drone lane.
4. Select the lowest numbered non-forbidden lane at or above
   `minimum_lane`.
5. Neutral objects select the lowest non-forbidden lane; their relative visual
   order is unspecified.
6. If no lane 0–7 is legal, return `MUX_ERR_LANE_CAPACITY`.

Processing higher-priority classes first and assigning them the lowest
available lanes preserves every overlapping C/B/A ordering while minimizing
the constraint placed on later classes. Same-class overlaps receive distinct
lanes but no special order.

Lane assignment is rebuilt each physical frame. A logical object is not
promised the same hardware sprite number on consecutive frames.

---

## 10. Raster programming jobs

Lane assignment proves that at most eight sprite intervals overlap. It does not
prove that the CPU has time to reprogram a lane between two occupants.

### 10.1 Fixed timing constants

The first implementation uses:

```text
MUX_FRAME_IRQ_LINES = 8   ; frame-start work owns lines 0–7
MUX_FIRST_JOB_LINE  = 8
MUX_JOB_LINES       = 4   ; reserved start-to-start cost per load command
MUX_POST_GUARD      = 1   ; line after prior interval before reprogramming
MUX_MAX_COMMANDS    = 24
```

Four PAL raster lines provide 252 nominal cycles. Even with one bad line and
sprite DMA steals from seven active lanes, the command handler must be kept
within this reserved window. The implementation must cycle-audit the worst
path on both standards. If it exceeds the budget, increase the single
`MUX_JOB_LINES` constant and let the builder reject denser schedules; do not
silently rely on typical rather than worst-case collisions.

### 10.2 Job windows

Each rendered object creates one lane-load job.

For the first object in a lane:

```text
release_start = MUX_FIRST_JOB_LINE
latest_start  = object_top - MUX_JOB_LINES
```

For a reused lane:

```text
release_start = previous_bottom + MUX_POST_GUARD + 1
latest_start  = object_top - MUX_JOB_LINES
```

If arithmetic wraps or `release_start > latest_start`, the plan is
unschedulable.

Sort jobs by `(latest_start, object_top, hardware_lane)`. Starting with a cursor
at `MUX_FIRST_JOB_LINE`:

```text
job_start = max(cursor, release_start)
if job_start > latest_start: fail MUX_ERR_RASTER_DEADLINE
cursor = job_start + MUX_JOB_LINES
```

This intentionally serializes lane-load handlers. It may reject a theoretically
possible cycle-perfect schedule, but it is deterministic, testable, and safe
for wave data to target.

### 10.3 Why spawn layout matters

Small artwork still occupies a 21-line lane interval. Two vertical groups can
each be within the eight-sprites-per-line rule yet leave too little time to
rewrite several lanes at the boundary. Wave launch offsets must satisfy both:

- maximum overlapping intervals, and
- the job-window deadline check.

The wave system should initialize a prospective slot with `OBJF_RENDER` set,
run the normal builder without publishing, and publish only on success. On
failure it clears render request or retires that candidate and retries later.
Because the builder writes only the inactive plan, validation cannot disturb
the displayed frame.

---

## 11. Immutable command-plan format

Each plan contains up to 24 commands in structure-of-arrays form. The fields
are snapshots; the IRQ does no object-table lookup.

| Field | Meaning |
|-------|---------|
| `cmd_line` | raster line at which handler starts |
| `cmd_lane` | hardware sprite 0–7 |
| `cmd_owner` | logical object slot |
| `cmd_interest` | background/sprite collision-interest bits |
| `cmd_x_lo` | `$D000 + 2*lane` value |
| `cmd_y` | `$D001 + 2*lane` value |
| `cmd_ptr` | `$07F8 + lane` value |
| `cmd_color` | `$D027 + lane` value |
| `cmd_enable_mask` | complete `$D015` shadow after command |
| `cmd_x_msb_mask` | complete `$D010` shadow after command |
| `cmd_x_expand_mask` | complete `$D01D` shadow after command |
| `cmd_y_expand_mask` | complete `$D017` shadow after command |
| `cmd_multicolor_mask` | complete `$D01C` shadow after command |
| `cmd_bg_priority_mask` | complete `$D01B` shadow after command |

Plan metadata:

- command count;
- 24-bit logical-object reference mask;
- validity byte;
- optional build sequence for diagnostics.

The builder simulates commands in scheduled order and emits complete shared
register masks. The IRQ never performs a shared-register read/modify/write.

Plan 0 and plan 1 use the same offsets across two pages each. No command field
array crosses a page.

---

## 12. Raster command handler

Only the raster source is enabled in `$D01A`. Do not enable VIC collision IRQ
sources; the mux polls the collision latches at ownership boundaries.

For one command:

1. Acknowledge raster bit 0 in `$D019`.
2. Read `$D01F`; OR it into `irq_bg_lane_mask`.
3. Read `$D01E`; OR it into `irq_ss_lane_mask`.
4. For the lane being replaced, attribute its accumulated bits to the **old**
   owner, respecting `hw_interest[lane]`; clear that lane bit from the software
   masks.
5. Disable only that lane in `$D015`.
6. Set its owner to `$FF`.
7. Dispatch through one of eight unrolled lane writers so X, Y, pointer, and
   color stores use fixed absolute addresses.
8. Write the command's complete `$D010/$D01D/$D017/$D01C/$D01B` masks.
9. Set `hw_owner[lane]` and `hw_interest[lane]` to the new command values.
10. Write the final `$D015` enable mask.
11. Advance the command cursor.
12. Program `$D012` for the next command, or line 0 for the next frame. Keep
    raster compare bit 8 clear in the maintained `$D011` control shadow.
13. Exit through the IRQ restore path.

The old owner is changed only after its collision bits have been captured.
The new owner is installed before the lane is enabled.

### IRQ shell

The game uses the KERNAL IRQ vector at `$0314/$0315`, with CIA interrupt sources
disabled and acknowledged during install. The KERNAL entry has already saved
registers before it jumps through this vector; RailGunner's handler exits
through the KERNAL register-restore/`RTI` path, without running the full KERNAL
service on every mux interrupt.

The implementation constants and install sequence are fixed:

```text
IRQ_VECTOR_LO   = $0314
IRQ_VECTOR_HI   = $0315
CIA1_ICR        = $DC0D
CIA2_ICR        = $DD0D
VIC_IRQ_STATUS  = $D019
VIC_IRQ_ENABLE  = $D01A
VIC_RASTER      = $D012
KERNAL_IRQ_EXIT = $EA81
```

With interrupts disabled:

1. Write `$7F` to both CIA ICRs to disable their sources.
2. Read both CIA ICRs to clear pending indications.
3. Point `$0314/$0315` at the RailGunner IRQ entry.
4. Copy the maintained text/play `$D011` value with bit 7 clear to both the
   shadow and `$D011`.
5. Write raster compare 0 to `$D012`.
6. Write `$01` to `$D019` to acknowledge a pending raster source.
7. Write `$01` to `$D01A` so raster is the only enabled VIC source.
8. Return with interrupts still disabled; cold initialization performs the
   final `CLI` after all state is ready.

Every RailGunner IRQ path ends with `JMP KERNAL_IRQ_EXIT` (`$EA81`). Do not jump
to the full KERNAL service at `$EA31` from every mux command. The game owns its
frame clock and polls its own input, so stopping the KERNAL jiffy/keyboard IRQ
service during gameplay is intentional. Disk/frontend code that later requires
a different IRQ policy must explicitly suspend and restore this raster owner.

One frame-start hook is reserved for future music. Music must run at the
normalized cadence required by its driver and must be included in the
frame-start line budget, not added to mid-raster command handlers.

---

## 13. Collision attribution

### 13.1 Why software lane masks are required

`$D01E/$D01F`:

- are keyed by hardware sprite number;
- accumulate bits;
- clear globally when read (c64m models the hardware's deferred end-of-cycle
  clear);
- contain no logical object ID and no collision coordinate.

At every mux command, read both registers and OR them into software masks.
Reading globally is safe because bits for hardware lanes not currently being
reused remain in the software masks until those lanes are reused or the frame
ends.

This avoids an eight-owner scan on every mid-raster IRQ. A command attributes
only the lane it is about to replace. Frame start flushes all remaining lanes
while there is ample border time.

### 13.2 IRQ event banks

The IRQ writes event bits to one of two 24-byte banks:

```text
OBJE_BG = bit 0
OBJE_SS = bit 1
```

It uses `hw_owner[lane]` as the destination index and skips `$FF` owners or
events absent from `hw_interest[lane]`.

At frame start, the completed write bank becomes the main read bank only if the
previous read bank was acknowledged. Main merges it into
`obj_pending_events[]`, then acknowledges it. Thus collision events survive:

- hardware-lane reuse;
- an NTSC physical frame without a logical gameplay tick;
- a main-loop frame overrun;
- multiple hardware collision reports before gameplay consumes them.

### 13.3 Background collision resolution

`OBJE_BG` means only “one or more opaque sprite pixels touched foreground
graphics.” Gameplay resolves it in two phases.

**Detection phase**

1. Snapshot active bullet occupancy for this logical tick.
2. For every interested drone with `OBJE_BG`, scan the tight hitbox's covered
   character cells.
3. Record all matching bullet IDs and mark the drone for the appropriate hit.
4. If no bullet matches, test rail cells/arrival according to the drone path.
5. Do not remove bullets or retire drones during this scan.

**Commit phase**

1. Apply all recorded drone hits.
2. A bullet marked by several overlapping drones is consumed once.
3. Retire destroyed drones and start explosion state.
4. Apply rail/player consequences for surviving arrival events.
5. Clear the consumed pending-event bits.

Deferring bullet removal until after every collision candidate is scanned
implements the locked rule that several overlapping drones may all receive the
same bullet hit.

Tight hitboxes reduce ambiguity from transparent sprite padding. Exact
pixel-versus-character reconstruction is intentionally not part of the mux.

### 13.4 Sprite/sprite events

`OBJE_SS` tells an interested object that it participated in at least one
sprite/sprite collision. It does not identify the other object. A consumer that
needs a pair must run a software overlap check among its limited candidate
types.

Initial policy:

- drones: background interest on, sprite interest off;
- player: both off;
- bonus: both off; software player/bonus overlap;
- future effects: opt in only with a named consumer.

---

## 14. Build errors and runtime policy

| Code | Meaning |
|------|---------|
| `MUX_OK` | complete plan is publishable |
| `MUX_ERR_TOO_MANY_VISIBLE` | more than 24 render candidates |
| `MUX_ERR_LANE_CAPACITY` | no legal hardware lane / ninth interval overlap |
| `MUX_ERR_PRIORITY` | priority constraints cannot be colored |
| `MUX_ERR_RASTER_DEADLINE` | lane exists but cannot be reprogrammed safely |
| `MUX_ERR_COMMAND_CAPACITY` | more than 24 load commands |
| `MUX_ERR_PLAN_BUSY` | prior back plan has not been accepted |
| `MUX_ERR_BAD_COORDINATE` | unsupported wrap or invalid presentation value |

`mux::build` ABI:

- Input: live object arrays; inactive plan selected internally.
- Success: carry clear, `A = MUX_OK`; back plan complete but not yet published.
- Failure: carry set, `A = error`; front plan and publish state unchanged.

`mux::publish` publishes the most recently successful build. Calling it after a
failed build is a debug error.

Runtime behavior:

- **Prospective spawn failure:** keep the new object render-disabled or retire
  it; wave controller retries later.
- **Pool full:** wave controller retries; never steal an active object.
- **Unexpected failure after movement:** do not publish; replay the prior front
  plan, set a visible/debug diagnostic, suppress additional spawns, and fix the
  wave/motion constraints. Never silently omit only the offending sprite.
- Debug builds may stop on a breakpoint/BRK after recording the error. Human
  play builds should remain running long enough to expose the diagnostic.

---

## 15. Public routine set for the first implementation

| Routine | Context | Contract |
|---------|---------|----------|
| `video::detect_standard` | cold init | sets PAL/NTSC and tick threshold |
| `objects::init` | cold/stage init | initializes pool, slot 0, free stack |
| `objects::alloc` | main | carry clear + X slot; carry set + A error |
| `objects::retire` | main | marks deferred destruction |
| `objects::reap` | frame main | returns unreferenced retirees to free stack |
| `objects::drain_irq_events` | frame main | merges and acknowledges event bank |
| `mux::init` | cold/stage init | clears plans, hardware sprites, owner maps |
| `mux::build` | main | constructs and validates inactive plan |
| `mux::publish` | main | atomically offers complete plan |
| `irq::install` | cold init | installs raster-only IRQ shell |
| `irq::frame_start` | IRQ | line-0 swap/collision/tick work |
| `irq::mux_command` | IRQ | one timed hardware-lane load |

Not in this round:

- per-field getter/setter routines;
- fractional motion integration;
- drone AI or wave tables;
- bullet rendering;
- bullet/rail collision consequences;
- dynamic player-frame compositor;
- final sprite art.

The first mux test may write object tables directly and use solid placeholder
sprite frames. That is a test harness, not a public accessor API.

---

## 16. Source ownership when implementation begins

| File | Responsibility |
|------|----------------|
| `src/sys/video.asm` | PAL/NTSC detection and normalized tick constants/state |
| `src/game/objects.asm` | pool layout API, free stack, retirement, events |
| `src/sprite/mux_build.asm` | gather, sort, lane coloring, job schedule, plan emit |
| `src/sprite/mux_irq.asm` | front-plan execution, owner maps, collision capture |
| `src/game/collision.asm` | later event interpretation, not mux attribution |
| `src/data/sprites.asm` | placeholder/final sprite frames and metadata |
| `src/sys/irq.asm` | vector install and dispatch shell |
| `src/sys/memory.asm` | `$C000–$C8FF`, `$3000–$3E7F`, pointer map |
| `src/sys/const.asm` | VIC sprite registers, flags, capacities, error IDs |
| `src/sys/zeropage.asm` | IRQ pointers/masks/cursors only |

Wire every source through `src/main.asm`; it remains the sole assembly root.

---

## 17. Verification matrix

### Pool

- Slot 0 exists after init and cannot be freed.
- Exactly 23 ordinary allocations succeed; the next returns pool-full.
- Destroy in arbitrary order, retain while referenced, then reuse safely.
- New allocation contains no position, event, flag, or presentation residue.
- Every 24-byte indexed table stays within one page.

### Lane assignment and priority

- 0, 1, 7, and 8 objects on one interval succeed.
- 9 objects on one interval return lane-capacity.
- Overlapping C/B/A objects receive ascending hardware numbers C→B→A.
- Six same-type drones plus player succeed.
- Six drones plus bonus succeed.
- A higher-priority drone beginning lower on screen still receives a lower
  hardware number than an already-listed lower-priority overlapping interval.
- Non-overlapping intervals reuse a lane.
- Y-expanded intervals occupy 42 lines.

### Raster deadlines

- Eight first occupants near the top of the playfield meet their deadlines.
- A 21-line reuse with insufficient programming gap is rejected.
- A valid 24-object, multi-band plan schedules every command at least four
  raster lines after the prior command.
- No command uses raster bit 8 or a line beyond 255.
- Worst command path fits its four-line window on PAL and NTSC, including one
  bad line, seven active sprite DMAs, and collision bits set.

### Collision ownership

- A background bit immediately before lane reuse reaches the old logical owner.
- A later bit on the reused lane reaches the new owner.
- Bits on other lanes survive a global latch read in the software masks.
- Final-band bits are delivered at next frame start.
- Several `$D01F` bits map to several overlapping drone objects.
- Player collision-interest off produces no player event even while over rail.
- `$D01E` opt-in produces participant events without claiming a pair.
- Retired slots are not reallocated until their front-plan references and late
  events are gone.

### PAL/NTSC

- Launch and verify with c64m `--video PAL` and `--video NTSC`.
- PAL generates 50 logical ticks in 50 physical frames.
- NTSC generates 50 logical ticks in 60 physical frames.
- A fixed velocity covers the same distance over equal real-world time.
- Raster command order, sprite image, and collisions agree on both standards.

### Visual/system smoke

- Use distinct solid colors for logical slots and show at least 12 objects
  across several vertical bands.
- Capture full frames with `step-frame`/`get-frame`; do not use turbo-3 pixels as
  visual evidence.
- Watch writes to `$D015`, `$D012`, and sprite coordinate registers.
- Inspect `hw_owner[]`, plan command arrays, event banks, and error counters
  through the c64m control port.
- Keep the emulator window visible for human observation.

---

## 18. Implementation sequence

1. Reserve/document memory and constants; add PAL/NTSC detection.
2. Implement and verify pool initialization/allocation/retirement without VIC
   rendering.
3. Install a line-0-only raster IRQ and normalized frame/tick handshake.
4. Add one immutable plan and render up to eight placeholder objects without
   reuse.
5. Add double-buffer publication and plan replay on missed publication.
6. Add priority-aware lane assignment.
7. Add raster job scheduling and hardware-lane reuse.
8. Add `$D01F/$D01E` software masks, owner mapping, and double-buffered events.
9. Stress 24 slots and deliberate arbitrary destruction/reallocation.
10. Verify PAL and NTSC deadlines and real-world motion cadence.
11. Only then layer in fractional motion helpers, drone AI, bullets, and
    gameplay collision consequences.

If implementation evidence invalidates a timing constant or VIC assumption,
update this handoff in the same change and log any c64m workflow friction in
[`build-debug.md`](build-debug.md). Never patch `../c64m/` from this repo.
