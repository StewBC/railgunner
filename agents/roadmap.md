# RailGunner — Development Roadmap

**Role:** Higher-level build and flow guide. Stages say *how mature* a slice of
the game should be; elements say *which runtime pieces* exist. Depth is uneven
on purpose — sketches and open questions are fine. Detailed specs live in later
docs; this file only keeps the map coherent.

**Companions:** [`railgunner.md`](railgunner.md) (mechanics / design truth),
[`repo-layout.md`](repo-layout.md) (where code lives), [`README.md`](README.md)
(index).

---

## How to use this document

- **Stages** = maturity of the product (scaffold → ship). Pick the next stage
  that is still incomplete and work the elements that matter for it.
- **Elements** = game modes / flow nodes (init, title, play, game over, …).
  Each element lists sketch behaviour and which stage first makes it real.
- Prefer implementing **one vertical path through the flow** early (init →
  title → game init → stage init → thin play → death/game over stubs) rather
  than perfecting a single system in isolation — except where the design brief
  calls out hard unknowns (mux, collision disambiguation).
- When a sketch becomes load-bearing, spin out a detail doc and leave a
  one-line pointer here. Do not bloat this file into a full design rewrite.

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
their own detail docs; this element only owns the loop and its exits.

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
| Cold Init | ● | ● | ● | ● | ● | ○ | ○ |
| Frontend | ● | ○ | ○ | ○ | ● | ● | ○ |
| Game Init | ◐ | ● | ● | ○ | ○ | ○ | ○ |
| Stage Init | ◐ | ● | ● | ○ | ○ | ○ | ○ |
| Play | ◐ empty | ● thin | ● multi-wave | ● full mech | ● bonuses/ammo | ● feel | ○ |
| Next Wave | — | — | ● | ○ | ○ | ● | ○ |
| Next Level | — | — | ● | ○ | ● tables | ● | ○ |
| Next Life | — | — | ● | ○ | ○ | ● FX | ○ |
| Game Over | ◐ stub | ○ | ● | ○ | ○ | ● | ○ |
| High Score | — | — | — | — | ● | ● | ○ |

● = primary work for that stage · ◐ = stub / minimal · ○ = improve as needed · — = not yet

---

## Suggested build sequence (narrative)

1. **Scaffold** — `boot` + `sys` enough to draw something; mode labels or blank
   screens that advance on FIRE; prove assemble → load → run via
   [`build-debug.md`](build-debug.md).
2. **Vertical slice** — one rail arm, player sprite, one drone type, bullets as
   UDG state machine, collision path (bullet hit vs rail reach), score tick.
   Matches design brief risk reduction.
3. **Core loop** — wrap the slice in real session flow: waves, lives, re-init,
   game over back to title. Placeholder wave count (20). Second/third rail arms
   can start appearing here if the slice is solid.
4. **Systems** — A/B/C, health bar and rail damage levels, draw/hit priority,
   wave tables, sprite multiplexer when concurrent drones demand it.
5. **Features** — bonuses, ammo unlock fiction + bar, disk high scores, music
   hooks, fuller title/HS presentation.
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
| Mode implementation | Jump table / state byte | Detail when code lands |

---

## Future detail docs (spawn as needed)

When an area outgrows a sketch, add a focused handoff and link it from
[`README.md`](README.md) and the relevant element above. Candidates:

- Play loop & frame timing (IRQ vs main, update order)
- Collision disambiguation (sprite–bg + char peek)
- Wave / level data format
- Sprite multiplexer constraints
- Bonus spawn and parcel motion
- High-score file format and disk I/O
- Audio / music triggers per mode
- HUD character set (health/ammo bars, lives icons)

---

## Doc hygiene

- Update this roadmap when a stage’s exit criteria or the control map changes.
- Keep mechanics rules in [`railgunner.md`](railgunner.md); keep file placement
  in [`repo-layout.md`](repo-layout.md).
- Prefer a short matrix/flow edit over long prose when the only change is
  “this element moved earlier/later.”
