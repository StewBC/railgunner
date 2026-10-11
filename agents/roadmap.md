# RailGunner — Development Roadmap

**Role:** Historical build map. The game is finished. There is no feature
backlog and no next stage.

**Shipped:** the level-centric loop in [`level-rework.md`](level-rework.md)
(R1–R8 and R8b): full cross, A/B/C, cargo and mines, parcels, rank banner,
title music, one-shot SFX, and RAM high-score entry. A **C core**
(`src/core/`) was written from the 6502 sources. **SDL** (`src/sdl/`) is the
first platform frontend on that core (`make sdl`). The Commodore 64 game
remains `src/c64/` (`make` / `make play`).

Sketches that never landed — fairness sets (R9), a further tune pass (R10),
victory and bosses (R11), a shield parcel, disk high scores, a fire-stream
sound, in-game music — are not remaining work.

**Companions:** [`level-rework.md`](level-rework.md) (shipped loop),
[`railgunner.md`](railgunner.md) (original brief; defer to level-rework on
conflict), [`repo-layout.md`](repo-layout.md), [`c64-to-sdl.md`](c64-to-sdl.md)
(finished port record), [`README.md`](README.md).
Optional reviews: [`reviews/`](reviews/) (historical, not a work queue).

---

## How to use this document

This file records how the game was built. It is not a work order.

- **Stages** and the build record below are that history. Do not pick an open
  row and implement it.
- **Elements** describe the flow as it was planned. Where they disagree with
  [`level-rework.md`](level-rework.md) or the source, trust those.
- **Where we are** is the shipped snapshot.
- The mux exception was taken during the build: pool + mux exist; **use them**,
  do not rebuild them.

---

## Where we are (reconciled with the tree)

Shipped snapshot. The lists further down are the build record, not a queue.

| Area | Status | Notes |
|------|--------|--------|
| Cold init / IRQ / input | Done | `boot/init`, `sys/*`, main loop with logic ticks |
| Mode dispatcher | Done | Jump table; story/instructions extras |
| Frontend attract | Done | Hires title ↔ text menu; typewriter |
| Stage init | New game only | Full redraw + player start; **not** on level-up |
| Play | **Shipped** | Full cross, A/B/C, parcels, cargo/mines; see [level-rework.md](level-rework.md) |
| Object pool + sprite mux | Done | Production path on the C64 + `tst/c64/` demos. SDL draws every `OBJF_RENDER` object and does not run the mux |
| Player | Full cross | Mount/remap, both arms fire |
| Bullets | Both streams | V + H UDGs; cell ROF lock |
| Collision | Production | `COLLISION_MODE=0`. Software tests are the authority. SDL has no VIC latch |
| HUD | **Shipped** | `000000   WAVE 01 ########    PILOTS AAAA`; no health/ammo |
| Level / spawn | **R1–R8** | Level kill quota; stop spawn; quiescence → rank banner |
| Rail damage A/B | In play | Multi-HP; core collapse → game over |
| C threat | Cargo/mines | Cargo → GHIJ stacks → arm → centre costs a life |
| Parcels | **Shipped** | 2/level. Clear, repair, extra life, points, power 2×, score 2×. No shield |
| High score | RAM entry | Game over calls `hiscore_qualifies`. Disk load/save was never written (`hiscore_reset` is empty) and is not remaining work |
| Audio | **Shipped as title + one-shots** | 3-voice Valkyries on the title. No in-game music bed, no fire-stream sound. Those are not remaining work |
| C core | **Done** | `src/core/`. Headless traces via `make core`. Rules only; no SDL |
| SDL | **Done** | `src/sdl/`. First platform frontend on the core. `make sdl` opens the 2× window |

The C64 build is `make` / `make play`. The portable builds are `make core` and
`make sdl`. Accepted differences for the port are in
[`c64-to-sdl.md`](c64-to-sdl.md).

---

## Build record

The steps below are how the game was built. Items that never landed are marked
**not shipped**. They are not a backlog.

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

**Step 8 complete.** The level rework (R1–R8, R8b) is the shipped game.
Later step numbers below are the record of what followed, including ideas that
were not built.

---

### Level rework R9–R11 (not shipped)

Full freeze + ledger: **[`level-rework.md`](level-rework.md)**. R1–R8 and R8b
shipped. These three did not, and they are not remaining work.

| ID | Work | Notes |
|----|------|--------|
| **R9** | Sets + fairness gate | **Not shipped.** |
| **R10** | Fun tune | **Not shipped** as a separate pass. The numbers in the source are the game. |
| **R11** | Victory / boss hooks | **Not shipped.** |

### Step 9 — Features

| ID | Work | Notes |
|----|------|--------|
| ~~**9.1**~~ | ~~**Parcel mechanism + score**~~ **done** | See level-rework §2 parcels |
| ~~**9.2**~~ | ~~**Messages**~~ **done as rank banner** | HUD rank line on level clear |
| ~~**9.3**~~ | ~~**Ammo scarcity**~~ **cancelled** | Ammo removed in the rework. Not remaining work |
| ~~**9.4**~~ | ~~**Repair bonus**~~ **done** | Even-level second parcel. See level-rework |
| **9.5** | Shield bonus | **Not shipped.** |
| ~~**9.6**~~ | ~~**Damage multiplier**~~ **done** | Power 2× parcel |
| ~~**9.7**~~ | ~~**Score consolation parcel**~~ **done** | Points filler and score 2× |
| **9.8** | Balance pass | **Not shipped** as a separate pass. |
| ~~**9.9**~~ | ~~**Extra life**~~ **done** | Extra-life parcel on session kills |

---

### Step 10 — Gameplay polish (visual)

Not a remaining pass. Death already explodes and holds; drone death and rail
hits already have cues. Shield-ring and repair-orbit art were not built.

| ID | Work | Notes |
|----|------|--------|
| **10.1** | Explosions | Death sequence and `SFX_DRONE_DIE` / `SFX_PLAYER_DIE` shipped. No further pass. |
| **10.2** | More animations | **Not shipped** (repair orbit, shield ring). |
| **10.3** | Graphical refinements | The shipped font, HUD, and rail tiles are the game. |

---

### Step 11 — Game over / high scores

| ID | Work | Notes |
|----|------|--------|
| ~~**11.1**~~ | ~~High-score entry if qualified~~ **done** | 3 initials when `hiscore_qualifies` is set. |
| **11.2** | Load high-score table | **Not shipped.** RAM defaults. `hiscore_reset` is empty. |
| **11.3** | Save high-score table | **Not shipped.** |

Disk load/save is not remaining work. The table lives in RAM for the session.

---

### Step 12 — Bosses

**Not shipped.** The game shipped on the level loop alone. Not remaining work.

---

### Step 13 — Audio SFX (gameplay) — partial

One-shots live in `src/c64/sys/sound.asm` (`sfx::play` / `sfx::update`). Lower id wins a voice. No continuous fire.

| ID | Work | Notes |
|----|------|--------|
| **13.1** | ~~Explosions~~ **done** | `SFX_DRONE_DIE`, `SFX_PLAYER_DIE` |
| **13.2** | ~~Mines, parcels, heal, level whoop~~ **done** | `SFX_MINE`, `SFX_PARCEL`, `SFX_HEAL`, `SFX_WAVE` |
| **13.3** | Fire stream / alarms | **Not shipped.** Not remaining work |

---

### Step 14 — UI SFX — done

`SFX_UI_FIRE` on title, story, instructions, and game over. `SFX_HS_TICK` on high-score entry. `SFX_EXTRA` / `SFX_PING` on parcel collect.

---

### Step 15 — Music — title only

`src/c64/sys/music.asm` plays the 3-voice Valkyries loop from `src/c64/data/music_valkyrie.asm` on the title (`music::start_title`). Game init, story, and instructions call `music::stop`. SFX may steal a voice; the pattern keeps advancing. Stage, danger, game-over, and celebrate beds were not written. That is the shipped audio. The SDL port plays the same tables.

---

### Step 16 — Final polish

The game shipped. This step is not an open punch list.

---

**File ownership:** see [`repo-layout.md`](repo-layout.md). The C64 game is
assembled from `src/c64/main.asm`. Portable rules live in `src/core/`. The SDL
frontend is `src/sdl/`.

**Mapping to maturity stages (guide, not a second queue):**

| Steps | Stage label |
|-------|-------------|
| 1–7 | **2. Vertical slice** (done) |
| 8.0–8.7 | **3. Core loop** + **4. Systems** (full arms, multi-C, A/B/rail, spawn) |
| 9, 11 | **5. Features** — parcels, banner, and RAM high-score entry shipped; shield and disk I/O did not |
| 10, 16 | **6. Polish** — no further pass |
| 12 | Bosses — not shipped |
| 13–15 | Audio — title music + one-shots shipped |
| C core + SDL | Port of the shipped rules. See [`c64-to-sdl.md`](c64-to-sdl.md) |
| Ship | **7. Ship** — this is where the project stopped |

---

## Game flow (control map)

Historical sketch from early in the build. The shipped loop is
[`level-rework.md`](level-rework.md): level quotas and a rank banner, reserve
lives, rail collapse and four mines, RAM high scores. There is no disk save.
The diagram below still shows the earlier wave and health wording.

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

Original maturity labels from the build. The project stopped at ship. Unmet
exit lines (disk high scores, bosses, in-game music) were dropped. They are
not a queue. The shipped snapshot is **Where we are** above.

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
bonuses” bet in [`railgunner.md`](railgunner.md). The shipped game is the
level-centric loop, plus the C core and the SDL frontend. The mux architecture
stays as built.

---

## Elements

Historical sketches. Numbers in parentheses are the stage where each piece was
first expected. Where a sketch still mentions health, ammo, disk save, or a
wave-clear screen, the shipped behaviour is
[`level-rework.md`](level-rework.md).

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

## What shipped

1. **Scaffold** — boot, modes, title attract, game over.
2. **Vertical slice** — H-arm, V bullets, one C, collision, score, death.
3. **Level-centric loop** — full cross, spawn, cargo, mines, parcels, rank
   banner ([`level-rework.md`](level-rework.md)).
4. **Around the game** — story, instructions, tallies, RAM high-score entry,
   title music, one-shot SFX.
5. **Ports** — `src/core/` from the 6502 sources, then `src/sdl/` as the first
   platform frontend ([`c64-to-sdl.md`](c64-to-sdl.md)).

Nothing follows. Shield, disk high scores, bosses, a fire-stream sound, and
in-game music were not built.

---

## Decisions the shipped game closed

| Topic | Shipped |
|-------|---------|
| Session shape | Level kill quotas and a rank banner. HUD text still says `WAVE`. |
| Lives | Reserve icons, max 4. New game shows 3, then the deploy peel leaves 2. |
| Health and ammo | Removed. |
| High scores | RAM table for the session. No disk load or save. |
| Bosses | Not in the game. |
| Player start | `PLAYER_X_START` / `PLAYER_Y_HRAIL` on the horizontal rail, at the left edge of the centre gap. |
| Spawn | The level spawner in `game/waves.asm` and `game/drones.asm`. |
| Modes | Jump table in `frontend/mode.asm`. The same mode ids exist in `src/core`. |

---

## Detail docs

When an area outgrows a sketch, add a focused handoff and link it from
[`README.md`](README.md) and the relevant element above.

Present:

- [`objects-sprites.md`](objects-sprites.md) — graphical-object pool, sprite
  mux, IRQ/collision attribution, PAL/NTSC cadence (design + ABI).
- [`sprite-mux-status.md`](sprite-mux-status.md) — mux implementation record
  and demos. Historical. Not a work queue.
- [`sprite-mux-issues.md`](sprite-mux-issues.md) — mux review findings.
  Historical. Not a work queue.
- [`reviews/`](reviews/) — optional post-stage code reviews + dispositions.

Not written, and not remaining work: disk high-score format, boss patterns,
in-game music beds. Shipped behaviour is in
[`level-rework.md`](level-rework.md), [`c64-to-sdl.md`](c64-to-sdl.md), and
the source.

---

## Doc hygiene

- This file is a record. Do not reopen it as a feature queue.
- Keep the shipped loop in [`level-rework.md`](level-rework.md) and file
  placement in [`repo-layout.md`](repo-layout.md).
- Keep the port record in [`c64-to-sdl.md`](c64-to-sdl.md).
- If a sentence here still reads like an assignment, fix the sentence. Do not
  implement it.
