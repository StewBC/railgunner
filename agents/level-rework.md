# Level-centric rework (design freeze + status)

**Role:** Authoritative model for the **post–R1–R8** game loop. Prefer this over
older wave/health/ammo text in [`railgunner.md`](railgunner.md) when they
conflict. Work queue and maturity still live in [`roadmap.md`](roadmap.md).

**Landed:** commit baseline **R1–R8** (`0c391c7` and successors).  
**Not in this freeze:** spawn fairness / sets (R9), deep fun tune (R10),
victory/bosses (R11).

---

## 1. Principles

| Principle | Meaning |
|-----------|---------|
| **Level is the only external unit** | HUD, parcels, rank banner, kill quota, spawn stop. |
| **No player-facing waves** | No “wave clear,” no wave counter. Internal spawn may still change mix/density by **level progress**. |
| **Spawner is level-aware; world mostly is not** | Player, rail scars, score, parcels-in-flight do not soft-reset on level-up. |
| **Don’t pull every lever at once** | Fairness scheduling and deep C cargo polish are later steps. |

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

- Explicit per-level total in `level_kill_quota_tbl` (`src/data/strings.asm` data
  area / tables next to rank strings — see `level_kill_quota_tbl`).
- **1 destroy = 1 kill** (A, B, or C each count once; multi-HP still one kill at death).
- Band **16–32** (L1–15 curve: 16,16,20,20,24,24,24,28,28,28,32×5).

### Progress bar

- HUD segment `########` (8 cells, bar UDGs): **full at level start**, **empty**
  when quota met. Kills past quota do not change the bar.
- Mapping uses fine steps (~32) so non-multiples of 8 still work.

### Rank banner

- Full top line replaced for `LEVEL_BANNER_FRAMES` (~50 @ 50Hz ≈ 1s).
- Copy: praise + shortened rank (`str_rank_01`…`15`). Ladder: Private → … →
  Lt Col → Colonel → Brigadier → Maj Gen → General.
- **LVL digit advances after banner**, not at start.
- No FIRE skip.

### Parcels (unchanged intent from 9.1)

- At most **two** per level, at ~⅓ and ~⅔ of **level_quota**.
- Opposite arm, global end flip-flop, score-only payload (`5 × level` table).
- In-flight parcels **keep running** across level boundary (no auto-award on clear).

---

## 3. HUD layout (40 columns)

```
000000 - LVL 01 - ######## - PILOTS:AAAA
```

| Field | Role |
|-------|------|
| `000000` | Score |
| `LVL nn` | Level (post-banner) |
| `########` | Level progress (full → empty) |
| `PILOTS:AAAA` | Lives (up to 4 `A` icons) |

**Removed:** health bar, ammo bar, health/ammo mechanics.

---

## 4. Combat & death

| Threat | Effect |
|--------|--------|
| **A / B** | Multi-HP; on rail arrival → **rail damage** (core destroy → **game over**). |
| **C** | No player HP. On rail arrival → **cargo** toward hub. |
| **Cargo** | Char dot along arm → centre; stacks on **G,H,I,J** round-robin. |
| **Mines** | When each of G,H,I,J has stacks ≥ **K** (`MINE_STACK_K`, default **1** → 4 cargo to arm), tiles show mine glyphs; **player in centre** → lose a life, stacks clear. |
| **Lives 0** | Game over. |
| **Health / ammo** | **Gone** (not deferred UI — removed from session model). |

Shield / ammo parcel types from the original brief remain **future content**;
repair still makes sense with rail damage.

---

## 5. Velocity (still valid from 8.7)

- Precomputed **tiers** equalize first-sight → rail time on all four approaches.
- Class max tier: C = level, B = level−1, A = level−2 (floor 1).
- Per-spawn geometric step-down from class max (near-max common).

---

## 6. Implementation map (code)

| Area | Location |
|------|----------|
| Level quota / clear / banner tick / advance | `src/game/waves.asm` (name historical; **level** controller) |
| HUD progress / level / lives | `src/game/hud.asm` |
| Rank banner | `src/game/message.asm` |
| C cargo + mines | `src/game/cargo.asm`; stacks in `rail_data::ghij_stack` |
| Parcels | `src/game/parcels.asm` |
| Quota + rank tables | `src/data/strings.asm` (`level_kill_quota_tbl`, `str_rank_*`) |
| HUD template | `str_hud` |
| Constants | `src/sys/const.asm` (`LEVEL_*`, `MINE_STACK_K`, …) |
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
| **R9** | Sets + fairness gate (A/B close-shave scheduling) | **todo** — design postponed |
| **R10** | Fun tune (quotas, banner time, density, `MINE_STACK_K`) | **todo** |
| **R11** | Victory / boss hooks (e.g. after 5 / 10 / 15) | **todo** |

### Suggested next order

1. **R10** playtest + number tweaks (and cargo/mine feel).  
2. **R9** fairness (own mini-design first).  
3. Bonus types / repair / etc. when the loop is fun.  
4. **R11** victory/bosses.

**Explicitly deferred / cancelled for now:** ammo scarcity (old 9.3), wave-clear UI,
C blast HP, stage reset on level clear.

---

## 8. Fairness (R9 — deferred notes only)

Intent (not implemented):

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
