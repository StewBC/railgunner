# Level-centric rework (design freeze + status)

**Role:** Authoritative model for the **shipped** play loop. Prefer this over
older wave/health/ammo text in [`railgunner.md`](railgunner.md) and over the
historical sketches in [`roadmap.md`](roadmap.md).

**Landed:** **R1–R8** and **R8b** (`0c391c7` and successors). The same rules
are in `src/c64/` and in the C core (`src/core/`). SDL presents them; it does
not own them.

**Not in the game:** spawn fairness / sets (R9), a further tune pass (R10),
victory/bosses (R11). Those are not a work queue. The game is feature-complete.

---

## 1. Principles

| Principle | Meaning |
|-----------|---------|
| **Level is the only external unit** | HUD, parcels, rank banner, kill quota, spawn stop. |
| **No player-facing waves** | No “wave clear,” no wave counter. Internal spawn may still change mix/density by **level progress**. |
| **Spawner is level-aware; world mostly is not** | Player, rail scars, score, parcels-in-flight do not soft-reset on level-up. |
| **Don’t pull every lever at once** | Fairness scheduling and further cargo polish were not built. |

---

## 2. Player-facing loop

```
play (move + fire always, except game over)
  spawner runs while level_kills < level_quota  (and not in banner)
  kill any A/B/C → level_kills++, progress bar drains
  when level_kills >= level_quota → stop new launches
  when also active drones == 0 → rank banner (~1s) on HUD top line
       player still moves and fires; spawner paused; no skip; no stage redraw
  banner ends → level++, LVL on HUD updates, progress full again, spawn resumes
```

### Level kill quota (B2)

- Explicit per-level total in `level_kill_quota_tbl` (`src/c64/data/strings.asm` data
  area / tables next to rank strings — see `level_kill_quota_tbl`).
- **1 destroy = 1 kill** (A, B, or C each count once; multi-HP still one kill at death).
- Band **16–32** (L1–15 curve: 16,16,20,20,24,24,24,28,28,28,32×5).

### Progress bar

- HUD segment `########` (8 cells, bar UDGs): **full at level start**, **empty**
  when quota met. Kills past quota do not change the bar.
- Mapping uses fine steps (~32) so non-multiples of 8 still work.

### Rank banner

- Centred overlay on the HUD top line (score / pilots stay); leading+trailing
  pad spaces when room. Duration `LEVEL_BANNER_FRAMES` (75 ≈ 1.5s, 50% longer
  than the original 50). Colour-cycles **once** through the high-score palette
  (`score_color_table`, 10 colours × `BANNER_COLOR_HOLD` frames each).
- Copy: **nicety** + **rank title** (`str_nicety_*` / `str_rank_title_*`,
  composed for the banner; game over uses title only). Ladder: Private → … →
  Lt Col → Colonel → Brigadier → Maj Gen → General.
- **LVL digit advances after banner**, not at start.
- No FIRE skip.

### Lives (reserve model)

- `lives` ZP = **reserve** ships on the HUD (max **4**). The ship on the board is not an icon.
- New game: show **3** icons, no player → **deploy peel** (one icon leaves, player appears) → **2** reserve.
- Death with reserve **> 0** → explode/hold → restart current level spawn → **deploy peel** (reserve−1).
- Death with reserve **0** → game over. Rail core collapse → game over (no reserve spend).
- Extra-life parcel: +1 reserve if below cap.

### Parcels (types + due bits)

- At most **two** per level, at ~⅓ and ~⅔ of **level_quota**. Opposite arm, flip-flop.
- In-flight parcels **keep running** across level boundary (no auto-award on clear).
- **Priority** when spawning: **clear → repair → extra → filler**.
- **Clear:** if ≥3 GHIJ tiles have cargo, force clear; if 2, 50%. After a clear is *sent*, next parcel cannot be clear. Pickup **arms** wipe; **next centre pass** clears all stacks/mines (even if 4 mines armed).
- **Repair:** even levels, **second** parcel arms `repair_due` (sticky if clear steals). Pickup → mark window (~3s, light-gray tiles walked); timer end → each marked tile heals **1** damage step.
- **Extra:** every **100** session kills sets `extra_due`. If reserve already 4 at spawn time, drop flag → filler.
- **Filler:** 50% points (`5×level`), 25% **power 2×** (cyan `add_2x`, 2 HP/hit), 25% **score 2×** (black `add_2x`, 2 pts/hit). Both 2× last until **level end** (and clear on death).
- Colours: points purple, score2× black, power2× cyan, clear brown, extra green, repair light gray. Rails **dark gray**.

### A/B HP colour

- Remaining HP paints unique sprite colour: **3 blue / 2 green / 1 cyan**. C stays red.

---

## 3. HUD layout (40 columns)

```
000000 - WAVE 01 - ######## -PILOTS:AAAA
```

| Field | Role |
|-------|------|
| `000000` | Score |
| `WAVE nn` | Attack wave (player-facing; code may still say `level`) |
| `########` | Wave progress (full → empty) |
| `PILOTS:AAAA` | **Reserve** lives (up to 4 `A` icons) |

**Removed:** health bar, ammo bar, health/ammo mechanics.

---

## 4. Combat & death

| Threat | Effect |
|--------|--------|
| **A / B** | Multi-HP (colour ladder); on rail arrival → **rail damage** (core destroy → **game over**). |
| **C** | No player HP. On rail arrival → **cargo** toward hub. |
| **Cargo** | Orange parcel **sprite** flies to the next **G→H→I→J** hub tile; on arrival sprite vanishes and that tile stacks. |
| **Level-clear cargo peel** | On level clear (rank banner start): remove **one** stack from the **most recently** deposited GHIJ tile (survive bonus). |
| **Mines / detonate** | When each of G,H,I,J has stacks ≥ **K** (`MINE_STACK_K`, default **1** → **4 landings**), tiles show mine glyphs (**armed**). Player dies only on the next **centre enter** while armed (stacks clear). Clear parcel on that pass disarms first. Reserve left → respawn peel; else game over. |
| **Death sequence** | Ignore input; explode then hold. Then: reserve left → restart **current level** spawn + deploy peel; no reserve or rail collapse → game over. |
| **Reserve 0 + death** | Game over (after death sequence). |
| **Health / ammo** | **Gone** (not deferred UI — removed from session model). |

---

## 5. Velocity (still valid from 8.7)

- Precomputed **tiers** equalize first-sight → rail time on all four approaches.
- Class max tier: C = level, B = level−1, A = level−2 (floor 1).
- Per-spawn geometric step-down from class max (near-max common).

---

## 6. Implementation map (code)

| Area | Location |
|------|----------|
| Level quota / clear / banner tick / advance | `src/c64/game/waves.asm` (name historical; **level** controller) |
| HUD progress / level / lives | `src/c64/game/hud.asm` |
| Rank banner | `src/c64/game/message.asm` |
| C cargo + mines | `src/c64/game/cargo.asm`; stacks in `rail_data::ghij_stack` |
| Parcels | `src/c64/game/parcels.asm` |
| Quota + rank tables | `src/c64/data/strings.asm` (`level_kill_quota_tbl`, nicety + rank title) |
| HUD template | `str_hud` (`WAVE`) |
| Constants | `src/c64/sys/const.asm` (`LEVEL_*`, `MINE_STACK_K`, …) |
| ZP | `level_kills`, `level_quota`, `level_banner_t`, cargo/mine fields |

**Stage init** is for **new game** (and rare full re-init), **not** every level-up.

---

## 7. Rework step ledger

| ID | Scope | Status |
|----|--------|--------|
| **R0** | Design freeze (this doc) | **done** |
| **R1** | HUD rewrite | **done** |
| **R2** | Remove health & ammo | **done** |
| **R3** | Level quotas + progress bar + stop spawn at quota | **done** |
| **R4** | Rank banner + live play; no stage snap on level-up | **done** |
| **R5** | No player-facing waves; level-driven spawn params | **done** (light) |
| **R6** | Rail core collapse → game over | **done** |
| **R7** | Parcels on level_quota | **done** |
| **R8** | C cargo → GHIJ stacks → mines → lives | **done** (basic) |
| **R8b** | Reserve lives + deploy peel; A/B HP colour; full parcel types | **done** |
| **R9** | Sets + fairness gate (A/B close-shave scheduling) | **not shipped** |
| **R10** | Fun tune (quotas, banner time, density, `MINE_STACK_K`, repair window) | **not shipped** as a separate pass. The numbers in the source are the game |
| **R11** | Victory / boss hooks (e.g. after 5 / 10 / 15) | **not shipped** |

The shipped loop ends at **R8b**. Ammo scarcity (old 9.3), a wave-clear screen,
C blast HP, and a stage reset on level clear are not in the game.

---

## 8. Fairness (R9 — not built)

Notes kept so the idea is not rediscovered as a task. Not remaining work.

- Player cover rate ~4 px/frame; A needs ~3 hits + human slack (~30 frames on-station).
- Do not launch A/B so that concurrent rail attackers are impossible to clear.
- Early level = loose gaps; late level / deep progress = more close shaves.
- “Sets” = internal launch batches for fairness/cadence, **not** a player term.

---

## 9. Stale docs

| Doc | Note |
|-----|------|
| [`railgunner.md`](railgunner.md) | Original brief; health/ammo/C-blast/wave sections **superseded** by this file for the live loop. |
| Older Step 8–9 rows in roadmap | Historical; **Where we are** + this file win. |
| [`coop-debug.md`](coop-debug.md) | Prefer `level_kills` / `level_quota` / cargo symbols over old `wave_*` kill fields. |
