# RailGunner — Development Roadmap

**Role:** Higher-level build and flow guide. Stages say *how mature* a slice of
the game should be; elements say *which runtime pieces* exist. Depth is uneven
on purpose — sketches and open questions are fine. Detailed specs live in later
docs; this file only keeps the map coherent.

**Companions:** [`railgunner.md`](railgunner.md) (mechanics / design truth),
[`repo-layout.md`](repo-layout.md) (where code lives), [`README.md`](README.md)
(index).

**Current phase:** Stage 1 (Scaffold) **done**. Object-pool / sprite-mux
foundation **done** early (Stage 4 tech). Frontend shell richer than scaffold
expected. **Stage 2 (Vertical slice) is the active work** — steps **1–2 done**
(player sprite + H-rail move / barrel); see **Next steps**. Do not expand
Features (bonuses, ammo unlock, disk HS, music) until the slice can kill a
drone and die cleanly.

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
| Mode dispatcher | Done | Jump table; modes include story/instructions extras |
| Frontend attract | Ahead of plan | Hires title ↔ text menu; typewriter; S/I stubs |
| Game / stage init | Minimal | Session vars reset; playfield draw; player on H-rail |
| Play | **Player + bullets + mover** | H-rail; bullets; one C drone top→rail; RUN/STOP → game over |
| Object pool + sprite mux | **Done early** | Production path + `tst/` demos; see [`sprite-mux-status.md`](sprite-mux-status.md) |
| Player sprite / move | **Done (H-arm)** | Slot 0 sprite; 4px steps; U/D barrel via mid frame; V-rail later |
| Bullets / charset UDGs | **Done (V stream)** | RAM font + 8 UDGs; H-rail fire up/down with 4-phase cells |
| Collision consumer | Not started | Mux latches events; play does not interpret them |
| Waves / lives / rail damage | Stubs only | Mode hooks exist; nothing drives them from play |
| High score entry / disk | Stub | Always skip hiscore from game over |

**Intentional early work (keep):** mux foundation, title art, drone art (all
sizes/facings), mode skeleton, full-cross placeholder playfield.

---

## Next steps (do these in order)

Active checklist for **Stage 2 — Vertical slice**. Exit criteria: one moving
drone can be shot for score, can reach the rail (or kill the player path), and
a death or “session end” reaches existing game-over → title. Full four arms,
wave tables, and bonuses are **out of scope** here.

Prefer **one rail arm** and **one drone type** for combat logic even though all
three drone arts and the full cross are already drawn. Extra art can stay
installed; do not require multi-type AI for the slice.

1. ~~**Player as graphical object (slot 0)**~~ **done**  
   - Frames in `assets/sprites/player_{up,right,down,left}.*`; copied to `$3E00`.  
   - `*` stand-in removed; demo drone harness removed.  
   - Starts left of V-rail, barrel up (not parked in centre).

2. ~~**Player movement on rails (H-arm)**~~ **done**  
   - Horizontal arm, **4px** steps; centre gap crossed to far legal rest.  
   - Barrel rest up/down only; opposite stick → mid swing (R or L, ~5 frames).  
   - RUN/STOP → game over (FIRE reserved for shooting).  
   - Vertical rail mount / full intersection rules still later.

3. ~~**Character bullets**~~ **done (H-rail vertical)**  
   - RAM charset + 8 bullet UDGs; `render/bullets.asm` stream.  
   - 4 sub-cell phases × `BULLET_HOLD`; launch cell occupancy = ROF cap.  
   - Auto-fire while FIRE held and barrel at rest; L/R aim later with H UDGs.

4. ~~**One moving drone**~~ **done (slice mover)**  
   - `game/drones.asm`: one **C** (small), nose-down, top → H-rail; vy via pool.  
   - Rail arrival currently **retires** the slot (stub until collision consumer).  
   - Spawn API ready to grow to 3-per-quadrant waves later.

5. **Collision consumer (the remaining hard unknown)**  
   - Drain `objects::` IRQ events after mux attribution.  
   - Char-peek under drone hitbox: bullet → damage/score/consume bullet; rail chars
     → arrival (rail damage stub or instant “hit rail” for slice).  
   - Prove path with live c64m tests; see [`sprite-mux-issues.md`](sprite-mux-issues.md)
     stress item on latch-before-reuse.

6. **Score + thin HUD**  
   - Tick score on kill; show digits (placeholder string → live values).  
   - Health/lives can stay constants until step 7.

7. **Death / session end into existing modes**  
   - Health 0 or “rail destroyed” stub → `MODE_NEXT_LIFE` or `MODE_GAME_OVER`
     (stubs already exist).  
   - Prefer: one life / no lives → game over → title, matching current FIRE-to-quit
     demo path but driven by combat.

8. **Only after 1–7:** expand to multi-wave (`MODE_NEXT_WAVE`), multi-arm, A/B/C
   AI, rail damage levels, real HUD bars — **Stage 3 / 4**. Do not start bonuses,
   ammo rationing, disk HS, or music before the slice exit criteria hold.

**File ownership (new work):** see vertical-slice list in
[`repo-layout.md`](repo-layout.md). Wire every new `.asm` through `src/main.asm`.

**Out of scope until Stage 2 exit:** richer story/instructions, more title polish,
mux rewrites, extra drone showcase layouts, high-score entry UX.

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
           │   │       │     │                                │
           │   │       │     │ all waves done                 │
           │   │       │     └─► Next Level ──► Stage Init    │
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
of another; the table is a *guide*.

| Stage | Intent | Exit criteria (rough) |
|-------|--------|------------------------|
| **1. Scaffold** | Boot, mode stubs, transitions without real combat | Cold init → title → FIRE → empty playfield → stub game over → title; can assemble/run under c64m |
| **2. Vertical slice** | Prove hard tech on a minimal playable path | One rail arm, one drone type, character bullets, collision disambiguation (bullet vs rail), basic score/HUD; death ends the run (lives optional) |
| **3. Core loop** | Full session shape with thin content | Multi-wave play, next wave / next level stubs, lives + next life + stage re-init, game over; ~N waves/level (placeholder **20**) |
| **4. Systems** | Mechanics from the design brief | All rail arms, A/B/C drones, health/rail damage, layering priority, wave table structure, sprite mux as needed |
| **5. Features** | Content and meta systems | Bonuses, ammo unlock + rationing, high-score table load/save, music hooks (stage / game over / celebrate), richer frontend |
| **6. Polish** | Feel, readability, edge cases | Wave/level clear messaging and timing, explosions, HS entry UX/timeout, balance knobs, no-stuck transitions |
| **7. Ship** | Release readiness | Final tables, disk layout, smoke of full path on target hardware/emulator |

**Relation to design brief:** Stage 2 is the same bet as the “suggested build
order” in [`railgunner.md`](railgunner.md) — one arm, one drone type, no
bonuses — so mux and collision are proven before the full game piles on.

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
- Ammo → full *or* inactive/grayed until ammo mechanic unlocks (Features).
- Level counter → 1 (or 0-based internal — pick one and stick to it in code).
- Draw game screen: HUD top line, rails, player at default pose.
- Start stage/session music when audio exists (Features/Polish).
- Transition → **Stage Init**.

### Stage Init / re-init (2 → 3)

Per-stage or post-death re-entry into play.

- Enemy wave counter → 0 (or “next wave to spawn = 1”).
- Player position → centre of the cross (intersection).
- Clear transient play state: active bullets, drones, messages; later also
  active bonuses, shield, repair orbiters as those systems exist.
- Rail damage: policy TBD in detail docs — full repair on stage re-init vs
  carry damage across lives. Default assumption for early core loop: **reset
  rail and health to full on next life** unless design later says otherwise.
- Transition → **Play**.

### Play (2 → 6)

Main loop until an exit condition.

**Today:** art harness only (static demo drones + facing cycle; FIRE ends
session). Not combat. Replace harness as Stage 2 items land (see **Next steps**).

Loop body (grows by stage):

- Spawn / advance waves from wave data (stub constants early; tables at Systems).
- Move drones; move player; advance bullets.
- Handle collisions (sprite–background register + char peek for bullet vs rail).
- Score, kill drones, apply rail/player damage as systems exist.
- HUD updates.

Exit conditions:

1. **Player dies** (health ≤ 0) → **Next Life**.
2. **Rail fully destroyed** → **Game Over** (same player-facing outcome as no lives).
3. **Waves for this level cleared** → **Next Wave** / **Next Level** as below.

**Placeholder content knobs** (replace with tables later):

- Waves per level: **20** (assumption until tuning).
- Wave speed, composition, quadrants: see wave data in design brief.

Lots of subsystems live under Play (mux, collision, bonuses, ammo). Those get
their own detail docs; this element only owns the loop and its exits. The
graphical-object pool, mux frame contract, and hardware collision attribution
are implemented ([`objects-sprites.md`](objects-sprites.md),
[`sprite-mux-status.md`](sprite-mux-status.md)). Motion/AI and the **gameplay
collision consumer** remain Stage 2+ work.

### Next Wave (3)

- Brief “wave cleared” (or similar) message + short pause / respite.
- Increment wave counter.
- If waves remain for this level → back into **Play** (or light stage touch-up
  without full Stage Init — exact boundary is implementation choice).
- If no waves remain → **Next Level**.

### Next Level (3 → 5)

- Level clear messaging + pause (richer in Polish).
- Increment level counter; reset wave counter.
- Difficulty levers (speed, multi-quadrant, composition) from tables when ready.
- → **Stage Init** (or a thinner “level init” if we split later).

### Next Life (3)

On player death:

- Player explosion (visual polish can lag the logic).
- Decrement lives (reserve count).
- If lives remain → **Stage Init** (re-init).
- If no lives left → **Game Over**.

### Game Over (1 stub → 3)

- Show Game Over on the playfield (or dedicated screen).
- Pause for readability; wait for fire or timeout (policy later).
- If score qualifies for top 10 → **High Score Entry**.
- Else → **Frontend** (title).

### High Score Achieved / Entry (5 → 6)

- Celebratory music when audio exists.
- Show top-10 table; highlight the new row (score already placed).
- Player enters **3 initials** on that row.
- On confirm or timeout: **save high-score table to disk**, then → **Frontend**.

---

## Stage × element matrix

| Element | Scaffold | Vertical slice | Core loop | Systems | Features | Polish | Ship |
|---------|:--------:|:--------------:|:---------:|:-------:|:--------:|:------:|:----:|
| Cold Init | ✓ | ● | ● | ● | ● | ○ | ○ |
| Frontend | ✓+ | ○ | ○ | ○ | ● | ● | ○ |
| Game Init | ✓◐ | ● | ● | ○ | ○ | ○ | ○ |
| Stage Init | ✓◐ harness | ● | ● | ○ | ○ | ○ | ○ |
| Play | ✓◐ art only | **← here** | ● multi-wave | ● full mech | ● bonuses/ammo | ● feel | ○ |
| Object/mux support | — | ○ use | ○ | ✓ early | ○ | ○ | ○ |
| Next Wave | — | — | ● | ○ | ○ | ● | ○ |
| Next Level | — | — | ● | ○ | ● tables | ● | ○ |
| Next Life | ✓ stub | ○ | ● | ○ | ○ | ● FX | ○ |
| Game Over | ✓ stub | ○ | ● | ○ | ○ | ● | ○ |
| High Score | — | — | — | — | ● | ● | ○ |

✓ = done (for that column’s intent) · ✓+ = done beyond scaffold scope · ✓◐ = stub/minimal done  
● = primary work for that stage · ◐ = stub / minimal · ○ = improve as needed · — = not yet  

**Object/mux support** is not a flow mode; it is listed so agents do not re-implement
the pool/mux during Stage 2 — **consume** it for player/drone sprites and events.

---

## Suggested build sequence (narrative)

1. **Scaffold** — **done.** Boot, modes, title attract, stub game over, assemble
   → play via [`build-debug.md`](build-debug.md). Mux foundation landed here early.
2. **Vertical slice** — **active** (see **Next steps**). Player sprite + move,
   bullets, one moving drone, collision consumer, score, death → game over.
   One arm / one combat type is enough; full cross art may stay on screen.
3. **Core loop** — wrap the slice in real session flow: waves, lives, re-init,
   game over back to title. Placeholder wave count (20). Second/third rail arms
   if the slice is solid.
4. **Systems** — remaining A/B/C behaviour, health bar and rail damage levels,
   wave tables; gameplay fully driven through the existing pool/mux.
5. **Features** — bonuses, ammo unlock fiction + bar, disk high scores, music
   hooks. Frontend is already partly here — do not deepen it until Stage 2 exits.
6. **Polish / Ship** — messages, timing, explosions, entry UX, balance, final
   disk and smoke path.

---

## Open questions (deliberately deferred)

Record decisions here when made; do not block early stages on them.

| Topic | Default for now | Later |
|-------|-----------------|--------|
| Waves per level | 20 | Wave/level tables |
| Starting lives | 3 | Tuning |
| Starting health | Full bar (design formula) | Tuning with C-blast costs |
| Rail/health on next life | Reset full | Confirm vs carry damage |
| High scores without disk | RAM zeros / no persist | Load/save file format |
| Wave-clear vs level-clear UI | Short pause + text | Art / SFX |
| Ammo inactive early | Grayed bar present | Radio-message unlock stage |
| Mode implementation | **Done:** jump table in `frontend/mode.asm` | — |
| Play content during Stage 2 | Replace art harness; full-cross draw OK | Multi-wave / multi-type AI |

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

Future candidates:

- Play loop & frame timing (IRQ vs main, update order) — main already drains
  events and builds plans; formalize when play grows
- Collision disambiguation (sprite–bg + char peek) — **Stage 2 step 5**
- Wave / level data format
- Bonus spawn and parcel motion
- High-score file format and disk I/O
- Audio / music triggers per mode
- HUD character set (health/ammo bars, lives icons)

---

## Doc hygiene

- Update this roadmap when a stage’s exit criteria or the control map changes.
- Tick or rewrite **Next steps** when an item ships; keep **Where we are** honest.
- Keep mechanics rules in [`railgunner.md`](railgunner.md); keep file placement
  in [`repo-layout.md`](repo-layout.md).
- Prefer a short matrix/flow edit over long prose when the only change is
  “this element moved earlier/later.”
