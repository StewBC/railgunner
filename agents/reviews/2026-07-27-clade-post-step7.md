# RailGunner code review — 2026-07-27

**Location:** `agents/reviews/` — historical / optional. **Not** part of the
agent handoff path (see `agents/README.md`). Reviewer is one voice; the
disposition table is the project decision.

Reviewer: Claude (Opus 4.8). Scope: **code quality, efficiency, accuracy** of the
6502 source under `src/` — *not* a review against the game design. c64m
assembler syntax per `agents/assembler-syntax.md`.

Baseline: the tree assembles clean with `tools/c64masm -i src/main.asm`
(exit 0, 28794 bytes) at the reviewed commit. Nothing below blocks the build.

**Actioned on master** in the post–step-7 cleanup stack ending at `473f152`
(IRQ writer, dead sync, plan-stride guard, keyboard coalesce + level paint).

---

## Disposition (updated 2026-07-27)

Statuses: **done** · **deferred** · **wontfix** · **keep** · **note**

| Item | Status | Notes |
|------|--------|--------|
| §1.1 Level digits never repainted | **done** | `hud::paint_level` on status dirty; not a Stage-2 combat bug, but cheap honesty |
| §1.2 Ammo tracked but never spent/shown | **deferred** | Roadmap Stage 5 Features; intentional placeholder, not a slice bug |
| §1.3 Typewriter column clamp | **deferred** | Safe while story/instructions are hand-wrapped; clamp/assert if generated copy lands |
| §1.4 `screen_print` ≤256-char limit | **deferred** | One-line comment if touching; fine for current labels |
| §2.1 IRQ lane writer → indexed stores | **done** | ~210 bytes CODE saved; critical path |
| §2.2 Keyboard row-1 re-strobe | **done** | W/A/S one strobe; matches Space/RUNSTOP idiom |
| §2.3 Dead `sync_char_approx` / `player_col`/`row` | **done** | Removed per-frame dead work + ZP |
| §2.4 Self-modifying `mode_run` jmp | **wontfix** | Fine 6502 pattern; reentrancy not a real constraint here |
| §3.1 Shared `px_to_col` | **deferred** | Consolidate when next touching player/collision/rail/bullets |
| §3.2 Parameterize health/ammo bar | **deferred** | Premature until ammo feature |
| §3.3 `draw_d` / `draw_e` collapse | **deferred** | When rail damage drawing grows |
| §3.4 `emit_current` plan0/plan1 dup | **deferred** | Cold path; only if that block keeps growing |
| §3.5 Shared `row_times_40` | **deferred** | Minor |
| §4 Dead procs / strings / reserved consts | **deferred** | Hygiene when nearby; not urgent |
| §5.1 Bullet `.res` in CODE segment | **deferred** | BSS hygiene when touching bullets layout |
| §5.2 Plan 2-page stride build guard | **done** | Assemble-time `.if` + undefined-symbol fail (c64m has no `.error`) |
| §5.3 COLLISION_MODE scaffolding | **note** | Dogfood; re-verify hybrid/soft if modes 1/2 ship |
| §5.4 Magic numbers vs constants | **deferred** | Prefer named origins when next editing pixel↔cell code |
| §6 What's good | **keep** | Mux plans/handshake, bucket sort, event attribution, deferred mode, score digits, retire/reap |

Legend (original): **[bug]** wrong/likely-wrong behavior · **[perf]** speed/size ·
**[dry]** duplication · **[dead]** unused · **[nit]** style/robustness ·
**[good]** worth keeping.

---

## 1. Correctness / accuracy

### 1.1 [bug] HUD "level" (and wave) digits are never repainted
- `str_hud` ships a hard-coded `L:01` ([data/strings.asm:109](../../src/data/strings.asm)).
- `level` is set in `game_init_enter` and `inc`'d in `next_level_enter`
  ([game/play.asm:65](../../src/game/play.asm)), but nothing ever writes the level
  value into the HUD cells `HUD_LEVEL_COL..+HUD_LEVEL_LEN`.
- Result: the on-screen level indicator is frozen at `01` regardless of
  progress. `score.asm` has a reusable digit-emit pattern; a small
  `paint_level_if_dirty` mirroring `score::paint_if_dirty` would close this.
  There is `HUD_LEVEL_COL`/`HUD_LEVEL_LEN` machinery already reserved for it.

### 1.2 [bug] `ammo` is tracked but never displayed or spent
- `ammo` is initialized in `game_init_enter` ([game/game_init.asm:14](../../src/game/game_init.asm))
  and never read again (confirmed by grep). The HUD paints a static
  `A:########` template with no bar routine, unlike health which has
  `hud::paint_health`.
- Either wire ammo into a bar paint (a near-clone of `paint_health` — see the
  DRY note 3.2) and decrement it on fire, or drop the field until the feature
  lands. Right now it's dead state that reads as "implemented".

### 1.3 [nit/robustness] Typewriter has no column clamp
- `typewriter_type_one` / `typewriter_skip_to_end`
  ([frontend/typewriter.asm:73](../../src/frontend/typewriter.asm),
  [:135](../../src/frontend/typewriter.asm)) `inc type_col` without bounding it to
  40. `screen_put_xy` → `screen_addr_xy` adds X to the row base with **no clamp**,
  so a source line longer than `40 - STORY_MARGIN_X` silently spills onto the
  next row (and off the bottom on the last row). Today it's safe only because
  `story_text` / `instructions_text` are hand-wrapped with `$0A`. A stray long
  line would corrupt the screen. Consider clamping `type_col` or asserting line
  length at build time.

### 1.4 [nit] `screen_print` / `typewriter` assume ≤256-char, single-row strings
- `screen_print` advances source and dest under a single `Y` (`iny / bne`),
  which is the nice linear trick ([render/screen.asm:217](../../src/render/screen.asm)),
  but it means a string ≥256 bytes wraps `Y` and overwrites from the row base.
  Fine for current HUD/menu labels; worth a one-line comment that this is a hard
  limit (the header says "short labels" but not why).

*No correctness defects were found in the hot paths* (mux build/IRQ handoff,
collision attribution, bullet/collision AABB math, score BCD-free digit
extraction, player rail clamps). Those were traced carefully; see §5.

---

## 2. Efficiency

### 2.1 [perf] IRQ sprite-register writer is ~110 lines that collapse to ~9
`command` in [sprite/mux_irq.asm:364](../../src/sprite/mux_irq.asm) dispatches on
`irq_lane` through a `cmp #0…#7` chain into eight near-identical `writer_N`
blocks. Every VIC target here is **lane-indexed**:
- X/Y coords: `$D000 + 2*lane` / `$D001 + 2*lane`
- pointer: `SPRITE_PTR_BASE + lane`
- colour: `VIC_SPR_COLOR0 + lane`

The whole `writer_check_*` chain + `writer_0..7` (lines 364–473) can become:

```asm
    ldx irq_lane
    lda irq_value_ptr
    sta SPRITE_PTR_BASE, x
    lda irq_value_color
    sta VIC_SPR_COLOR0, x
    txa
    asl a
    tax                     ; x = lane*2
    lda irq_value_x
    sta $D000, x
    lda irq_value_y
    sta $D001, x
```

Cost trade: four `STA abs,X` (5 cyc) vs `STA abs` (4 cyc) = **+4 cycles**, but it
deletes the compare ladder (up to ~30 cycles for lane 7) and ~100 bytes of code
in the most timing-sensitive routine in the game. Net win on both size and
worst-case time, and far less to get wrong when adding a 9th field. This is the
single highest-value change in the review.

### 2.2 [perf] `input_scan_keyboard` re-strobes the same matrix row 3×
W, A, S all live on select row 1 (`KEY_SEL_W == KEY_SEL_A == KEY_SEL_S ==
%11111101`, [sys/const.asm:93](../../src/sys/const.asm)). `input_scan_keyboard`
writes `CIA1_PRA` and re-reads `CIA1_PRB` separately for each
([sys/input.asm:110-140](../../src/sys/input.asm)). Strobe row 1 once, read `PRB`
once into a temp, and test `KEY_BIT_W / _A / _S` against that single read (the
Space+RUN/STOP pair already does exactly this — [:161](../../src/sys/input.asm)).
Saves two writes + two reads per frame; more importantly it's the established
idiom two labels down, so the inconsistency is the real smell.

### 2.3 [perf] `sync_char_approx` is dead work run every player step
`player::sync_char_approx` ([game/player.asm:273](../../src/game/player.asm))
computes `player_col` / `player_row` on every `init` and every `update_move`,
but **nothing reads those variables** (grep: only writes; the `apply_c_blast_full`
comment mentions "player_col" conceptually but the code recomputes via
`px_to_col` from raw X). Either delete `sync_char_approx` + its two call sites
and the `player_col/row` ZP, or start using them (e.g. as the source for
`apply_c_blast_full` and bullet launch, which would also remove a duplicate).
It's a full 16-bit shift + subtract per frame for nothing.

### 2.4 [perf] `mode_run` / `mode_set` use self-modifying `jmp`
[frontend/mode.asm:12](../../src/frontend/mode.asm) patches `mode_run_jmp+1/+2`
each frame. Works, but an indirect jump through a ZP vector
(`sta vec; sta vec+1; jmp (vec)`) is the same speed, is reentrant, and doesn't
mutate the code segment. Minor; flag only because it's on the per-frame path and
the pattern is repeated in two procs.

---

## 3. Duplication (DRY)

### 3.1 [dry] "(VIC X − 24) >> 3, clamp 0..39" is reimplemented 4× (with a 5th variant)
The pixel-X → char-column conversion appears as:
- `player::px_to_col` ([game/player.asm:367](../../src/game/player.asm))
- `collision::px_to_col` ([game/collision.asm:457](../../src/game/collision.asm)) — byte-identical to the above
- inline in `rail::apply_ab_hit` ([game/rail.asm:37](../../src/game/rail.asm))
- inline in `bullets::player_launch_lane` ([render/bullets.asm:249](../../src/render/bullets.asm)) (also derives the half-lane)
- inline in `player::sync_char_approx` ([game/player.asm:273](../../src/game/player.asm))

Two copies are literally the same code in different scopes. A single shared
helper (in `render/screen.asm` next to `screen_addr_xy`, operating on
`tmp0/tmp1 → A`) would remove ~4 copies and guarantee the clamp/edge behavior
stays identical everywhere. Right now a fix to the rounding rule has to be made
in four places.

### 3.2 [dry] `hud::paint_health` and a future ammo bar
`paint_health` ([game/hud.asm:27](../../src/game/hud.asm)) walks 8 cells choosing
`BAR8/6/4/2/space` from an HP count. The ammo bar (§1.2) is the same algorithm
with a different source value, base column, and colour. Parameterize
(value in `A`, base col + length as args/ZP) before writing the second copy.

### 3.3 [dry] `rail::draw_d` and `rail::draw_e` are identical bar the row + damage array
[game/rail.asm:130](../../src/game/rail.asm) and [:149](../../src/game/rail.asm)
differ only in `dmg_d`↔`dmg_e` and `RAIL_ROW_TOP`↔`RAIL_ROW_MID`. Collapse to
one `draw_cell(row, dmg_array_ptr)` helper. ~18 lines saved and the glyph/colour
lookup logic lives in one place.

### 3.4 [dry] `emit_current` duplicates the entire per-field store block per plan
`emit_current` ([sprite/mux_build.asm:562](../../src/sprite/mux_build.asm)) has
`emit_plan_0` and the plan-1 branch as two ~18-line copies differing only in the
`plan0_cmd_*` vs `plan1_cmd_*` symbol. The IRQ side already solved this by
patching a single base-page delta (`select_front_plan`,
[sprite/mux_irq.asm:144](../../src/sprite/mux_irq.asm)). The builder could do the
same (write through a patched/indirect base) and keep one store block. Lower
priority than 3.1–3.3 because it's cold-ish (once per rebuild) — but it's also
the block most likely to drift out of sync between the two plans.

### 3.5 [dry] `screen_color_row` re-derives `Y*40`
[render/screen.asm:230](../../src/render/screen.asm) inlines the same `*8 + *32`
multiply that `screen_addr_xy` already computes ([:101](../../src/render/screen.asm)).
A shared `row_times_40 (Y → ptr)` primitive would deduplicate. Minor.

---

## 4. Dead / reserved code

- **[dead]** `bullets::find_at` ([render/bullets.asm:290](../../src/render/bullets.asm))
  and `bullets::half_from_glyph` ([:330](../../src/render/bullets.asm)) — defined,
  never called (grep-confirmed). Either they were superseded by the AABB path in
  `collision::test_bullets` or they're pending. Remove or mark `; TODO(consumer)`.
- **[dead]** Unused strings: `str_wave_clear`, `str_level_clear`
  ([data/strings.asm:113](../../src/data/strings.asm)), and the
  `str_hud_placeholder` alias ([:111](../../src/data/strings.asm)). The
  next-wave/next-level enters have the message as a `; TODO` comment but never
  print these.
- **[dead]** Unused constants: `C_BLAST_HALF`, `C_BLAST_COLS`
  ([sys/const.asm:166](../../src/sys/const.asm)) — the "reserved for outer ring"
  note is fair; just calling it out.
- These are all benign (labels/strings cost only their bytes; the two procs cost
  ~40 bytes of code). Listed for hygiene, not urgency.

---

## 5. Structure / maintainability notes

### 5.1 [nit] Mutable bullet state lives in the emitted CODE segment
`bullets` declares its RAM arrays (`bullet_active` … `fire_lock`, ~113 bytes)
with `.res` at [render/bullets.asm:10](../../src/render/bullets.asm), and the file
is `.include`d inside `.segment "CODE"` (main.asm:83). So they are emitted as
zero fill **inside the PRG code stream** and re-cleared at `init`. Compare
`rail_data` ([game/rail.asm:6](../../src/game/rail.asm)), which correctly lives in
the `OBJECTS` `noemit` segment. Not a bug (nothing executes through the fill),
but it (a) bloats the PRG by ~113 bytes of zeros and (b) is inconsistent with the
project's own BSS convention. Moving bullet state into `OBJECTS` (or a dedicated
noemit BSS segment) would match `rail_data` and the object SoA.

### 5.2 [nit] Two-plan layout depends on an exact 2-page stride
`select_front_plan` patches every command-load's high byte with a single
`irq_plan_delta` of 2 pages ([sprite/mux_irq.asm:145](../../src/sprite/mux_irq.asm)).
This is correct **only because** each plan is forced to exactly 2 pages by the
`.align 256`s in `sprite_mux_data` and plan0/plan1 have byte-identical field
order. That invariant is load-bearing and implicit. Add a build-time guard, e.g.
`.if (plan1_cmd_line - plan0_cmd_line) .ne 512 …` (or a comment at both plan
definitions) so a future field insertion fails loudly instead of silently
reading the wrong plan at raster time.

### 5.3 [nit] `.if COLLISION_MODE .eq n` guards — good, but keep the whole-file discipline
`collision::update` correctly uses `.eq` ([game/collision.asm:36](../../src/game/collision.asm))
per the assembler pitfall in `assembler-syntax.md §3`. The live build is
`COLLISION_MODE = 0`, so `mode_hybrid` / `mode_soft_only` / the diag border
routines and `eval_soft`/`apply_soft_hit` are all assembled but unreachable.
That's fine as dogfood scaffolding — just be aware they're carrying
`mux_key`/`mux_forbidden`/`mux_key_prio` aliasing that will need re-verifying if
mode 1/2 ever ships (the overloaded ZP names make the hybrid path harder to read
than the hw-only path).

### 5.4 [nit] Magic numbers where a named constant exists
Scattered literal `#40` / `#25` / `#50` / `#24` appear next to their named
equivalents `SCREEN_W`, `SCREEN_H`, and the `50`/`24` screen-origin offsets
(e.g. [render/screen.asm:319](../../src/render/screen.asm),
[game/collision.asm:419](../../src/game/collision.asm),
[game/player.asm:281](../../src/game/player.asm)). `test_rail` even mixes
`cmp #SCREEN_H` and `cmp #40`/`cmp #SCREEN_H-1` within the same proc. Prefer the
constants for the char/pixel origins (`24`, `50`) too — define e.g.
`SPRITE_X_ORIGIN = 24`, `RASTER_Y_ORIGIN = 50` — since those two numbers recur
in every pixel↔cell conversion and any origin change today means a global grep.

---

## 6. What's good (keep)

- **[good]** Mux architecture: double-buffered *immutable* plans with a line-0
  atomic swap, `seq`/`ready` handshake between IRQ and main, and conservative
  Y-interval endpoints (`gather` inflating for Y-expand + PAL/NTSC safe-range
  rejection). The `assign_lanes` invariant (process C→B→A so a later class can
  always sit above overlapping earlier classes) is well reasoned and the comment
  explains it.
- **[good]** Replacing the O(n²) EDF selector with the linear
  `order_candidates_by_y` bucket pass + `schedule_and_emit`
  ([sprite/mux_build.asm:353](../../src/sprite/mux_build.asm)), with a comment
  proving equivalence. Stable bucket insertion (reverse-iterate + prepend) is
  subtle but correct.
- **[good]** Event attribution: per-lane BG/SS latch capture, interest masking,
  and the empty-read-bank rotation that lets the IRQ skip a 24-byte clear
  ([sprite/mux_irq.asm:209](../../src/sprite/mux_irq.asm),
  [game/objects.asm:305](../../src/game/objects.asm)). The `sei`-guarded ack in
  `drain_irq_events` is correctly scoped to just the flag write.
- **[good]** Deferred death/mode changes via `pending_mode` applied only at the
  end of `play_update` ([game/play.asm:27](../../src/game/play.asm)) — avoids
  mutating mode mid-combat/mid-mux. Documented intent matches the code.
- **[good]** Score digit extraction by repeated subtract-and-count against a
  place-value table ([game/score.asm:113](../../src/game/score.asm)) with a
  hard `#10` guard — no BCD, no divide, and the cap logic is correct across all
  three bytes.
- **[good]** `retire` / `retire_and_try_free` / `reap` + `slot_referenced`
  against front *and* pending plans — the "don't free a slot the IRQ still
  references" discipline is exactly right and is the thing that most easily goes
  wrong in a pooled mux.

---

## 7. Suggested priority order

1. §2.1 IRQ writer table-ify (biggest size win, on the critical path).
2. §1.1 / §1.2 HUD level + ammo (visible "looks broken" gaps).
3. §3.1 shared `px_to_col` (removes 4 copies; prevents divergence).
4. §2.3 delete or use `sync_char_approx` (per-frame dead work).
5. §5.2 add the 2-page plan-stride build guard (cheap insurance).
6. §3.2 / §3.3 / §3.4 remaining de-dup; §4 dead-code sweep.
