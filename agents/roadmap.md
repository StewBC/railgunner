# RailGunner — Development Roadmap

**Role:** Higher-level build and flow guide. Stages say *how mature* a slice of
the game should be; elements say *which runtime pieces* exist. Depth is uneven
on purpose — sketches and open questions are fine. Detailed specs live in later
docs; this file only keeps the map coherent.

**Companions:** [`level-rework.md`](level-rework.md) (**current loop / R1–R11**),
[`railgunner.md`](railgunner.md) (original brief — defer to level-rework on
conflict), [`repo-layout.md`](repo-layout.md), [`README.md`](README.md).
Optional reviews: [`reviews/`](reviews/) (not a work queue).

**Current phase:** **Level-centric baseline R1–R8 done.** See
[`level-rework.md`](level-rework.md) for the freeze, ledger, and code map.
**Next (ordered):** **R10** fun tune → **R9** fairness/sets (design first) →
bonus types / polish → **R11** victory/boss hooks. Ammo scarcity cancelled for
now (ammo removed). Post–step-7 hygiene:
[`reviews/2026-07-27-clade-post-step7.md`](reviews/2026-07-27-clade-post-step7.md).

---

## How to use this document

- **Stages** = maturity of the product (scaffold → ship). Pick the next stage
  that is still incomplete and work the elements that matter for it.
- **Elements** = game modes / flow nodes (init, title, play, game over, …).
  Each element lists sketch behaviour and which stage first makes it real.
- Prefer implementing **one vertical path through the flow** early (init →
  title → game init → stage init → thin play → death/game over stubs) rather
  than perfecting a single system in isolation — except where the design brief
  calls out hard unknowns (mux, collision disambiguation). The mux exception
  was taken: pool + mux exist; **use them**, do not rebuild them.
- **Next steps** (below) is the ordered work list. Prefer it over freestyle
  feature picks when unsure what to do next.
- When a sketch becomes load-bearing, spin out a detail doc and leave a
  one-line pointer here. Do not bloat this file into a full design rewrite.

---

## Where we are (reconciled with the tree)

Honest snapshot for agents. Update this when a Next-steps item lands.

| Area | Status | Notes |
|------|--------|--------|
| Cold init / IRQ / input | Done | `boot/init`, `sys/*`, main loop with logic ticks |
| Mode dispatcher | Done | Jump table; story/instructions extras |
| Frontend attract | Done | Hires title ↔ text menu; typewriter |
| Stage init | New game only | Full redraw + player start; **not** on level-up |
| Play | **Level-centric combat** | Full cross, A/B/C, parcels, cargo/mines; see [level-rework.md](level-rework.md) |
| Object pool + sprite mux | Done | Production path + `tst/c64/` demos |
| Player | Full cross | Mount/remap, both arms fire |
| Bullets | Both streams | V + H UDGs; cell ROF lock |
| Collision | Slice | `COLLISION_MODE=0` HW latch |
| HUD | **Rework done** | `000000 - LVL nn - bar - PILOTS:AAAA`; no health/ammo |
| Level / spawn | **R1–R8** | Level kill quota; stop spawn; quiescence → rank banner; no player waves |
| Rail damage A/B | In play | Multi-HP; core collapse → game over |
| C threat | Cargo/mines | Cargo → GHIJ stacks → arm → centre costs a life |
| Parcels | Score-only | 2/level @ ~⅓ & ~⅔ of level quota |
| High score / disk | Entry wired | Game over calls `hiscore_qualifies`. Disk load/save is not implemented (`hiscore_reset` is empty) |
| Fairness / sets | **Todo R9** | Deferred design |
| Bonus types (repair/shield/…) | Not started | After R10 |
| Audio | **In play** | Title music (3-voice Valkyries) + one-shot SFX. No in-game music bed, no fire-stream sound, no alarm |

**Intentional early work (keep):** mux foundation, title art, drone art (all
sizes/facings), mode skeleton, full-cross placeholder playfield.

---

## Next steps (do these in order)

### Stage 2 — Vertical slice (done)

Exit criteria met: one moving drone can be shot for score, can reach the rail
(and hurt the player), and death / session end reaches game-over → title.

1. ~~**Player as graphical object (slot 0)**~~ **done**
2. ~~**Player movement on rails (H-arm)**~~ **done**
3. ~~**Character bullets (H-rail vertical)**~~ **done**
4. ~~**One moving drone (C, top → H-rail)**~~ **done**
5. ~~**Collision consumer**~~ **slice working** (re-test under mux load in Step 8)
6. ~~**Score + thin HUD**~~ **done (thin)**
7. ~~**Death / session end into existing modes**~~ **done (slice)**

---

### Step 8 — Full player + session / spawn (“make it a game”)

**Intent:** Expand the slice into a real session without features (bonuses,
ammo scarcity, HS disk, audio). End state: player can use the **full cross**,
drones come from a **spawn engine** driven by **level/wave data**, and a short
playtest pass says “this is fun enough to build on.”

**Exit criteria:**

- Full player locomotion + fire on both arms (8.1a–8.2), including **correct
  mount/remap** (not “move works most of the time”).
- Multi-direction **C** pressure proven under load (8.3), then A/B + rail in the
  mix (8.5), under a real spawn policy (8.4–8.6).
- A **short** level/wave shape exists and has been **playtested for fun** (8.7).
- Bonuses, ammo rationing, and disk high scores stayed out of this step. Title music and one-shot SFX came later (steps 13–15).

**Notes / decisions while doing Step 8:**

- **8.0 first** — the auto rail-attack C is great for the slice and terrible for
  free player testing. Kill auto-spawn (or gate it behind a debug flag) before
  investing in V-arm work.
- **V-arm is two pieces (8.1a / 8.1b).** Mount/remap is not polish for 8.7 — it
  is **done criteria** for 8.1a. Free V-arm travel (8.1b) sits on top of that.
  Design brief ([`railgunner.md`](railgunner.md)): mount at centre intersection;
  90° barrel remap on rail change; no barrel flip in the dead centre; diagonal
  = parallel axis move / perpendicular mount or aim.
- **Fire follows facing** — 8.2 is the horizontal bullet stream (UDGs already
  reserved `$F8–$FF`) with the same cell-occupancy ROF rule as the vertical
  stream. Prefer one shared launch path parameterized by direction.
- **Multi-C before full A/B polish.** Fun teaches more from **several C’s from
  multiple edges** than from multi-HP A/B first. Sequence intent:
  **8.3** (directions + light multi-C under a *dumb* spawner) → **8.5** (A/B +
  rail as content) → **8.4 / 8.6** (real tables + spawn engine). 8.5 is required
  before the **8.7 fun exit**, not before any multi-spawn. Numbers stay 8.3 →
  8.4 → 8.5 → 8.6 for IDs; **do not block 8.3 on finished wave tables or A/B.**
- **Collision under load** — Step 5 was never locked under multi-drone mux
  pressure. Smoke latch attribution when multi-drone first appears (8.3); dig
  only if it fails — not a separate epic.
- **Wave vs continuous spawn** — design brief is wave-based; the “spawn engine”
  (8.6) is the *runtime* that *consumes* wave/level data (8.4). Do not invent a
  second competing system. 8.4 = data shape + counters; 8.6 = who/when/where/speed.
  First tables: **3–5 waves per level**, one short “level 1” — grow content in
  8.7, do not invent twenty empty waves.
- **8.7 is a first-class step**, not optional polish. Be willing to change
  speeds, spawn density, C blast feel, or ROF if the game is not fun. Document
  knobs in code constants or a tiny table, not only in chat.
- **Player start position** — after V-arm works, prefer **centre intersection**
  (or a fixed legal rest on H-arm). Left-of-V is a slice artifact; decide in
  8.1b and stick to it.

| ID | Work | Notes |
|----|------|--------|
| ~~**8.0**~~ | ~~**Stop auto-spawning**~~ **done** | `drones::init` empty; no ensure on update/collision. `spawn_*` / `ensure_*` kept for 8.3+. |
| ~~**8.1a**~~ | ~~**V-arm mount + barrel remap**~~ **done** | `player_rail`; centre mount H↔V; remap UP↔LEFT / DOWN↔RIGHT; no barrel flip in intersection; U/D step on V after mount. |
| ~~**8.1b**~~ | ~~**V-arm L/R barrel mid-swing**~~ **done** | Clockwise L→U→R / R→D→L; same mid-frame timing as H. |
| ~~**8.2**~~ | ~~**Shooting on the other arm**~~ **done** | HT/HB stream; launch cols 17/21; Y half-lanes; collision AABB; same cell ROF. **Checkpoint:** full player experience. |
| ~~**8.3**~~ | ~~**Multi-direction C pressure**~~ **done** | Cadence spawner rotates DOWN/UP/RIGHT/LEFT; max 3 C; lane alternate; blast X or Y footprint by approach. |
| ~~**8.4**~~ | ~~**Levels / waves as data**~~ **done** | `data/waves.asm` level-1 ×4 rows (quota/cadence/max/mask); clear when quota done + field empty → NEXT_WAVE/LEVEL. |
| ~~**8.5**~~ | ~~**A/B + rail damage**~~ **done** | HP 3/2/1; rail hit on arrival; scars across levels. |
| ~~**8.6**~~ | ~~**Spawn engine v2**~~ **done** | Dice composer: kill debts, random cooldown, quad/approach/coord; piggyback C on A/B; teach waves MAIN_C. |
| ~~**8.7**~~ | ~~**Tune basic spawn / gameplay; evaluate fun**~~ **passed** | Knobs in (velocity tiers, class tier pick, quotas/cd/max, composition, hard-tail growth). Human: “better than it ever was / enough that we know we have a game.” **Parked:** C threat / health relevance redesign (revisit mid–late Step 9). Side armour / force V-rail still deferred. |

**Step 8 complete.** Features (bonuses, ammo, messages), disk HS, music, bosses,
explosion polish remain later steps (9+).

---

### Level rework R9–R11 (active queue after R1–R8)

Full freeze + ledger: **[`level-rework.md`](level-rework.md)**.

| ID | Work | Notes |
|----|------|--------|
| **R9** | **Sets + fairness gate** | A/B launch separation; close-shave curve; design first |
| **R10** | **Fun tune** | Quotas, banner time, density, `MINE_STACK_K`, cargo feel |
| **R11** | **Victory / boss hooks** | Empty hooks; possible set-pieces after 5/10/15 |

### Step 9 — Features (parcels done; rest after R10)

| ID | Work | Notes |
|----|------|--------|
| ~~**9.1**~~ | ~~**Parcel mechanism + score**~~ **done** | See level-rework §2 parcels |
| ~~**9.2**~~ | ~~**Messages**~~ **done as rank banner** | HUD rank line on level clear (not wave clear) |
| ~~**9.3**~~ | ~~**Ammo scarcity**~~ **cancelled** | Ammo removed in rework; revisit only if design returns ammo |
| **9.4** | **Repair bonus** | After R10; rail damage still live |
| **9.5** | **Shield bonus** | Needs new damage model (mines / future hits) |
| **9.6** | **Damage multiplier** | 2× on score/hits |
| **9.7** | **Score consolation parcel** | When other types held |
| **9.8** | **Balance pass** | With R10 |
| **9.9** | **Extra life** | Score thresholds |

---

### Step 10 — Gameplay polish (visual)

| ID | Work | Notes |
|----|------|--------|
| **10.1** | Explosions | Player, drone, rail-arrival feedback. |
| **10.2** | More animations | As needed (repair orbit, shield ring, barrel polish). |
| **10.3** | Graphical refinements | Font / UDG pass, HUD icons, rail damage readability. |

---

### Step 11 — Game over / high scores

| ID | Work | Notes |
|----|------|--------|
| **11.1** | High-score entry if qualified | 3 initials. Game over already enters hiscore when `hiscore_qualifies` is set. |
| **11.2** | Load high-score table | Cold init / frontend; RAM defaults if no disk. |
| **11.3** | Save high-score table | After entry confirm/timeout. |

Disk format = detail doc when 11.2 starts. Failure path: keep playing with RAM table.

---

### Step 12 — Bosses (optional exploration)

| ID | Work | Notes |
|----|------|--------|
| **12.1** | **Decide if bosses belong** | Scripted pattern enemies; e.g. every N levels. Only build if Step 8–9 fun still has a “set-piece” gap. If no, skip without guilt — the game can ship on wave pressure alone. |

If yes, spin a short boss design note (HP, patterns, telegraph, reward) before
coding.

---

### Step 13 — Audio SFX (gameplay) — partial

One-shots live in `src/c64/sys/sound.asm` (`sfx::play` / `sfx::update`). Lower id wins a voice. No continuous fire.

| ID | Work | Notes |
|----|------|--------|
| **13.1** | ~~Explosions~~ **done** | `SFX_DRONE_DIE`, `SFX_PLAYER_DIE` |
| **13.2** | ~~Mines, parcels, heal, level whoop~~ **done** | `SFX_MINE`, `SFX_PARCEL`, `SFX_HEAL`, `SFX_WAVE` |
| **13.3** | Fire stream / alarms | Not built. Alarm (critical rail, pre-boss) still open |

---

### Step 14 — UI SFX — done

`SFX_UI_FIRE` on title, story, instructions, and game over. `SFX_HS_TICK` on high-score entry. `SFX_EXTRA` / `SFX_PING` on parcel collect.

---

### Step 15 — Music — title only

`src/c64/sys/music.asm` plays the 3-voice Valkyries loop from `src/c64/data/music_valkyrie.asm` on the title (`music::start_title`). Game init, story, and instructions call `music::stop`. SFX may steal a voice; the pattern keeps advancing. Stage, danger, game-over, and celebrate beds are not started. Do not block R9–R11 on them.

---

### Step 16 — Final polish

Loose ends: stuck transitions, message timing, edge-case mounts, last balance,
smoke full path title → play → death → HS → title. Ship checklist lives here.

---

**File ownership (new work):** see vertical-slice / game lists in
[`repo-layout.md`](repo-layout.md). Wire every new `.asm` through `src/c64/main.asm`.

**Mapping to maturity stages (guide, not a second queue):**

| Steps | Stage label |
|-------|-------------|
| 1–7 | **2. Vertical slice** (done) |
| 8.0–8.7 | **3. Core loop** + **4. Systems** (full arms, multi-C, A/B/rail, spawn) |
| 9, 11 | **5. Features** |
| 10, 16 | **6. Polish** |
| 12 | Optional systems/features |
| 13–15 | Audio — title music + one-shots landed; beds / fire stream / alarm still open |
| Ship smoke | **7. Ship** |

---

## Game flow (control map)

Cold start and mode transitions. Solid lines are the main path; dashed are
optional or later content.

```
                    ┌─────────────┐
                    │  Cold Init  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
           ┌───────►│  Frontend   │◄──────────────────────────┐
           │        │ (title / HS │                           │
           │        │  table show)│                           │
           │        └──────┬──────┘                           │
           │               │ FIRE                             │
           │        ┌──────▼──────┐                           │
           │        │  Game Init  │                           │
           │        └──────┬──────┘                           │
           │               │                                  │
           │        ┌──────▼──────┐                           │
           │   ┌───►│ Stage Init  │◄──────────┐               │
           │   │    │  (re-init)  │           │               │
           │   │    └──────┬──────┘           │               │
           │   │           │                  │               │
           │   │    ┌──────▼──────┐           │               │
           │   │    │    Play     │           │               │
           │   │    │   (loop)    │           │               │
           │   │    └──┬─────┬────┘           │               │
           │   │       │     │                │               │
           │   │       │     │ wave cleared   │               │
           │   │       │     ├─► Next Wave ───┘  (same stage) │
           │   │       │     │     (+ optional message)       │
           │   │       │     │                                │
           │   │       │     │ all waves done                 │
           │   │       │     └─► Next Level ──► Stage Init    │
           │   │       │           (+ message system)         │
           │   │       │                                      │
           │   │       │ player dies                          │
           │   │       ▼                                      │
           │   │  ┌──────────┐   lives remain                 │
           │   └──┤ Next Life├────────────────┘               │
           │      └────┬─────┘                                │
           │           │ no lives (or rail fully destroyed)   │
           │    ┌──────▼──────┐                               │
           │    │  Game Over  │                               │
           │    └──────┬──────┘                               │
           │           │                                      │
           │           ├─ top-10 score? ──► High Score Entry ─┤
           │           │                         (save disk)  │
           │           └──────────────────────────────────────┘
           │                    (timeout / done → Frontend)
           └──────────────────────────────────────────────────
```

**Loss conditions** (both → Game Over, no special distinction for the player):
player health reaches 0 with no reserve lives, or the rail is fully destroyed.
See [`railgunner.md`](railgunner.md).

---

## Stages

Names are maturity labels, not commit tags. Work can advance one element ahead
of another; the table is a *guide*. Prefer the **Next steps** IDs for day-to-day
order.

| Stage | Intent | Exit criteria (rough) |
|-------|--------|------------------------|
| **1. Scaffold** | Boot, mode stubs, transitions without real combat | Cold init → title → FIRE → empty playfield → stub game over → title; can assemble/run under c64m |
| **2. Vertical slice** | Prove hard tech on a minimal playable path | **Done.** One rail arm, one drone type, bullets, collision, score/HUD, death → game over |
| **3. Core loop** | Full session shape with real pressure | Full cross player (8.1a–8.2), multi-wave / next level, lives, spawn-driven play (8.3–8.7) |
| **4. Systems** | Mechanics from the design brief | A/B/C mix, rail damage, wave tables, spawn engine, mux load proven |
| **5. Features** | Content and meta systems | Bonuses, ammo unlock + rationing, messages, disk high scores |
| **6. Polish** | Feel, readability, edge cases | Explosions, art/UDG pass, balance, transitions, optional bosses decision |
| **7. Ship** | Release readiness | Audio as desired, final tables, disk layout, smoke of full path |

**Relation to design brief:** Stage 2 matched the “one arm, one drone, no
bonuses” bet in [`railgunner.md`](railgunner.md). Steps 8–9 expand to the full
design without reopening mux architecture.

---

## Elements

Sketch behaviour only. Numbers in parentheses are **first stage where this
should exist in non-stub form** (stubs may appear earlier).

### Cold Init (1)

Bring-up before any game mode.

- Clear screen (and any relevant colour RAM).
- Copy character ROM → RAM; install user-defined characters (rail, bullets,
  HUD bars, lives icons — assets grow over stages).
- Hardware / IRQ / input bring-up as required by the current stage.
- High-score table: start as zeros in RAM; later **load from disk** if present,
  else defaults. (Disk format and failure path = detail doc later.)
- Enter **Frontend**.

### Frontend (1 → 5)

Title and attract / table display.

- Show title screen (art and copy improve through polish).
- Optionally show high-score table (stub list early; real table at Features).
- Wait for **FIRE** to start.
- Transition → **Game Init**.

### Game Init (1 → 3)

Per-session reset (new game from title).

- Player score → 0.
- Lives → starting count (design: reserve lives shown as icons, max 4 displayed;
  exact starting number tunable — treat **3** as the working default until set).
- Health → full (bar-driven; design ties pool to bar granularity — not a magic
  “8” forever).
- Ammo → full *or* inactive/grayed until ammo mechanic unlocks (Features / 9.3).
- Level counter → 1 (or 0-based internal — pick one and stick to it in code).
- Draw game screen: HUD top line, rails, player at default pose.
- Start stage/session music when audio exists (Step 15).
- Transition → **Stage Init**.

### Stage Init / re-init (2 → 3)

Per-stage or post-death re-entry into play.

- Enemy wave counter → 0 (or “next wave to spawn = 1”).
- Player position — prefer **centre intersection** once V-arm works (decide in
  8.1b and stick to it); left-of-V is a slice artifact.
- Clear transient play state: active bullets, drones, messages; later also
  active bonuses, shield, repair orbiters as those systems exist.
- Rail damage: policy TBD in detail docs — full repair on stage re-init vs
  carry damage across lives. Default assumption for early core loop: **reset
  rail and health to full on next life** unless design later says otherwise.
- Transition → **Play**.

### Play (2 → 6)

Main loop until an exit condition.

**Today:** H-arm combat slice — player, vertical bullets, one C mover (until 8.0),
collision, score, death. Expand via **Step 8+**.

Loop body (grows by step):

- Spawn engine advances waves from level/wave data (8.4–8.6).
- Move drones; move player; advance bullets.
- Handle collisions (sprite–background register + char peek for bullet vs rail).
- Score, kill drones, apply rail/player damage as systems exist.
- Bonus parcels when Features land (9.x).
- HUD updates.

Exit conditions:

1. **Player dies** (health ≤ 0) → **Next Life**.
2. **Rail fully destroyed** → **Game Over** (same player-facing outcome as no lives).
3. **Waves for this level cleared** → **Next Wave** / **Next Level** as below.

**Placeholder content knobs** (replace with tables in 8.4+):

- Waves per level: **3–5** for first tables (grow in 8.7; do not start at 20).
- Wave speed, composition, quadrants: see wave data in design brief.

Lots of subsystems live under Play (mux, collision, bonuses, ammo). Those get
their own detail docs; this element only owns the loop and its exits. The
graphical-object pool, mux frame contract, and hardware collision attribution
are implemented ([`objects-sprites.md`](objects-sprites.md),
[`sprite-mux-status.md`](sprite-mux-status.md)).

### Next Wave (3)

- Brief “wave cleared” (or similar) message + short pause / respite.
- Increment wave counter.
- If waves remain for this level → back into **Play** (or light stage touch-up
  without full Stage Init — exact boundary is implementation choice).
- If no waves remain → **Next Level**.

### Next Level (3 → 5)

- Level clear messaging + pause (message system in 9.2; richer in Polish).
- Increment level counter; reset wave counter.
- Difficulty levers (speed, multi-quadrant, composition) from tables when ready.
- → **Stage Init** (or a thinner “level init” if we split later).

### Next Life (3)

On player death:

- Player explosion (visual polish can lag the logic — 10.1).
- Decrement lives (reserve count).
- If lives remain → **Stage Init** (re-init).
- If no lives left → **Game Over**.

### Game Over (1 stub → 3 → 11)

- Show Game Over on the playfield (or dedicated screen).
- Pause for readability; wait for fire or timeout (policy later).
- If score qualifies for top 10 → **High Score Entry** (11.x).
- Else → **Frontend** (title).

### High Score Achieved / Entry (5 → 6 / Step 11)

- Celebratory music when audio exists.
- Show top-10 table; highlight the new row (score already placed).
- Player enters **3 initials** on that row.
- On confirm or timeout: **save high-score table to disk**, then → **Frontend**.

---

## Stage × element matrix

| Element | Scaffold | Vertical slice | Core loop | Systems | Features | Polish | Ship |
|---------|:--------:|:--------------:|:---------:|:-------:|:--------:|:------:|:----:|
| Cold Init | ✓ | ✓ | ● | ○ | ○ | ○ | ○ |
| Frontend | ✓+ | ✓ | ○ | ○ | ● | ● | ○ |
| Game Init | ✓◐ | ✓ | ● | ○ | ○ | ○ | ○ |
| Stage Init | ✓◐ | ✓ | ● | ○ | ○ | ○ | ○ |
| Play | ✓◐ | **✓ slice** | **← Step 8** | ● full mech | ● bonuses/ammo | ● feel | ○ |
| Object/mux support | — | ✓ use | ○ load | ○ | ○ | ○ | ○ |
| Next Wave | — | stub | ● | ○ | ○ | ● | ○ |
| Next Level | — | stub | ● | ○ | ● tables | ● msg | ○ |
| Next Life | ✓ stub | ✓ | ● | ○ | ○ | ● FX | ○ |
| Game Over | ✓ stub | ✓ | ● | ○ | ○ | ● | ○ |
| High Score | — | — | — | — | ● Step 11 | ● | ○ |

✓ = done (for that column’s intent) · ✓+ = done beyond scaffold scope · ✓◐ = stub/minimal done  
● = primary work for that stage · ◐ = stub / minimal · ○ = improve as needed · — = not yet

**Object/mux support** is not a flow mode; it is listed so agents do not re-implement
the pool/mux — **consume** it for player/drone sprites and events.

---

## Suggested build sequence (narrative)

1. **Scaffold** — **done.** Boot, modes, title attract, stub game over.
2. **Vertical slice** — **done** (steps 1–7). H-arm, V bullets, one C, collision,
   score, death.
3. **Full player + spawn (Step 8)** — **done** as the level-centric loop
   ([`level-rework.md`](level-rework.md)). Next ordered work is **R10**, then
   **R9**, then bonus types, then **R11**.
4. **Features (Step 9 + 11)** — repair, shield, and multiplier bonuses after
   R10; then high-score disk load/save. Parcel score and the rank banner are
   already in. Ammo scarcity is cancelled. Hiscore entry already runs when the
   score qualifies.
5. **Visual polish (Step 10)** — Explosions, animation, UDG/font pass.
6. **Optional bosses (Step 12)** — Only if set-pieces still missing after fun pass.
7. **Audio** — title music and one-shot SFX are in. Still open: fire-stream sound, alarms, in-game music beds.
8. **Ship polish (Step 16 + Stage 7)** — Loose ends, disk, full-path smoke.

---

## Open questions (deliberately deferred)

Record decisions here when made; do not block early stages on them.

| Topic | Default for now | Later |
|-------|-----------------|--------|
| Waves per level | **4** (level-1 table) | Grow in 8.7; never pad empty waves |
| Starting lives | 3 | Tuning / 9.8–9.9 |
| Starting health | 32 (8×4 bar steps) | Tuning with C-blast costs |
| Rail/health on next life | Reset full | Confirm vs carry damage |
| High scores without disk | RAM zeros / no persist | Load/save file format (11.x) |
| Wave-clear vs level-clear UI | Short pause + text | Message system 9.2; art / SFX |
| Ammo inactive early | Grayed bar present | Radio message unlock (9.2–9.3); mini fun pass after 9.3 |
| Mode implementation | **Done:** jump table in `frontend/mode.asm` | — |
| Bosses | Undecided — evaluate in 12.1; bias **no** until 8.7+9.8 need set pieces | Scripted patterns if yes |
| Player start position | Left of V-rail (slice) | **Centre** once V-arm works (8.1b) |
| Auto-spawn during dev | **Off (8.0 done)** | Re-enable via spawn engine / ensure_* when 8.3 starts |
| 8.1a mount/remap | Must be correct before 8.1b done | Not deferred to 8.7 polish |

---

## Detail docs

When an area outgrows a sketch, add a focused handoff and link it from
[`README.md`](README.md) and the relevant element above.

Present:

- [`objects-sprites.md`](objects-sprites.md) — graphical-object pool, sprite
  mux, IRQ/collision attribution, PAL/NTSC cadence (design + ABI).
- [`sprite-mux-status.md`](sprite-mux-status.md) — implementation status, demos,
  verification, remaining stress tests.
- [`sprite-mux-issues.md`](sprite-mux-issues.md) — review findings / integration
  hazards for the mux (read before relying on collision).
- [`reviews/`](reviews/) — optional post-stage code reviews + dispositions.

Future candidates:

- Play loop & frame timing (IRQ vs main, update order) — main already drains
  events and builds plans; formalize when play grows
- Wave / level data format + spawn engine contract (Step 8.4–8.6)
- Bonus spawn and parcel motion (Step 9.1)
- Message system (Step 9.2)
- High-score file format and disk I/O (Step 11)
- Audio / music triggers per mode (Steps 13–15)
- Boss patterns (only if 12.1 is yes)
- HUD character set (health/ammo bars, lives icons)

---

## Doc hygiene

- Update this roadmap when a stage’s exit criteria or the control map changes.
- Tick or rewrite **Next steps** when an item ships; keep **Where we are** honest.
- Keep mechanics rules in [`railgunner.md`](railgunner.md); keep file placement
  in [`repo-layout.md`](repo-layout.md).
- Prefer a short matrix/flow edit over long prose when the only change is
  “this element moved earlier/later.”
- Numbered steps (8.0, 9.3, …) are the day-to-day queue; stage names are the
  maturity summary only.
