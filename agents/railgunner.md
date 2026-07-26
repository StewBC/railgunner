# RailGunner — Design Brief

**Role:** Top-level design brief for agents. Read this first for *what* we are
building and *why* the technical choices exist. For *how* to write assembly that
assembles under c64m, read [`assembler-syntax.md`](assembler-syntax.md) before
emitting any source. Index: [`README.md`](README.md).

---

A Commodore 64 shooter. The player is a gun mounted on rails that form a cross across the screen. Enemy drones fly in from the edges and attack either the rail or the player; the player must decide, moment to moment, which to defend.

## The screen layout

40 columns by 25 rows.

```
  |1234567890123456789012345678901234567890|
  +----------------------------------------+
 1| 000000  HEALTH: XXXXXX  LEVEL: 00 AAAA |
 2|                  |  |                  |
 3|                  |  |                  |
 4|                  |  |                  |
 5|                  |  |                  |
 6|                  |  |                  |
 7|                  |  |                  |
 8|                  |  |                  |
 9|                  |  |                  |
10|                  |  |                  |
11|                  |  |                  |
12|                  |  |                  |
13|------------------+  +------------------|
14|------------------+  +------------------|
15|                  |  |                  |
16|                  |  |                  |
17|                  |  |                  |
18|                  |  |                  |
19|                  |  |                  |
20|                  |  |                  |
21|                  |  |                  |
22|                  |  |                  |
23|                  |  |                  |
24|                  |  |                  |
25|                  |  |                  |
  +----------------------------------------+
```

The center gap (rows 13-14, cols 20-21) is the intersection where the player switches between the vertical and horizontal rails.

### Top line (HUD)

- **Score**: 6 digits, leading zeros, no label.
- **Health bar**: replaces the old numeric "HEALTH:" readout. Rendered in blue as a graphical bar (user-defined characters, likely 4 characters wide, decrementing in 2px steps for 16 total steps of granularity).
- **Ammo bar**: same structure as the health bar, rendered in red. Inactive (grayed out, visibly present but non-functional) until the ammo mechanic is unlocked at a later stage — see **Ammo**, below. Health and ammo bars should be distinguishable by shape/end-cap, not color alone, for legibility.
- **Level**: 2 digits, leading zero.
- **Lives**: graphical rail-gun icon (user-defined character), one per reserve life, max 4 shown, left to right (`A` = 1 life in reserve, `AA` = 2, etc.).

## Controls

Joystick, or WASD + space on keyboard.

The player is always locked to the cross (rail centerline). Movement and barrel-switching are relative to which rail the player currently occupies:

- **On the vertical rail**: up/down = move; left/right = switch barrel between left and right.
- **On the horizontal rail**: left/right = move; up/down = switch barrel between up and down.
- **Barrel orientation carries across a rail switch on a fixed 90° remap**: a barrel pointing up becomes left after mounting the horizontal rail (and vice versa), down becomes right (and vice versa). This is consistent in both directions, so the player only has to learn the rule once. It also means only two distinct barrel-frame drawings are needed rather than four, reused across both rail orientations.
- **At the center intersection**: the player cannot change barrel orientation — pressing the axis perpendicular to the current rail instead mounts that rail and begins moving in the pressed direction immediately (no separate "confirm" step, and no second barrel-switch on the same input).
- **Diagonal input**: the axis parallel to the currently-occupied rail is treated as movement; the perpendicular axis is treated as the barrel-switch/mount input. In practice, players naturally bias toward holding the movement axis while tapping the perpendicular one to aim, so this is expected to resolve itself without a hard priority rule — to be confirmed in playtesting.

The rail itself is a true dead zone: neither drones nor player bullets can occupy or cross it. Drones travel in a straight line toward the rail and their journey ends on arrival (no drone-vs-drone avoidance logic needed). Bullets, being character-based, likewise never render or collide beyond the rail edge.

## Shooting

The player fires in the direction the barrel currently faces. Holding fire produces a constant auto-repeating stream, not one press per shot. Rate of fire is capped structurally: each rail direction has a fixed set of 8 user-defined characters used as a bullet-animation state machine, and firing is throttled so that no two bullets ever occupy the same character cell at once (a bullet must advance to the next row/column before a new one can be fired behind it).

## Ammo

Not present in early levels. Introduced at a later stage via an in-fiction "radio message" that ammo is now being rationed. Once active, firing consumes ammo (drawn down on the red ammo bar); running out disables firing until more is collected. Ammo bonuses drop periodically once this mechanic is live, and, once introduced, missing one becomes a real threat — encouraging the player to think about fire discipline rather than holding the button down constantly.

## Enemies

Drones fly in from the screen edges (sides for the horizontal rail, top/bottom for the vertical) in waves, typically confined to one quadrant early on and expanding to two, three, then all four quadrants as the level/difficulty progresses.

### Types

- **A (small)**: 1 hit to destroy.
- **B (medium)**: 2 hits to destroy.
- **C (large)**: 3 hits to destroy.

*(Note: type letters denote hit-count tier only — see Draw/Hit Priority below for how size maps to sprite assignment.)*

Speed is constant within a given wave; later waves within a level, and later levels overall, increase drone speed as a difficulty lever. All drones in a wave move at that wave's speed.

### What each type attacks

- **A and B drones** attack the **rail only**. On reaching the rail they explode, causing rail damage. They do not harm the player directly.
- **C drones** attack the **player only**. On reaching the rail they explode with a radial blast: player within ~8px of the blast origin takes a **direct hit**, player within ~8-16px takes a **half hit** (exact radii tunable). The blast does not damage the rail and does not chain into other drones.

Since a C drone's explosion origin is always at the rail edge, the player is in some degree of blast range any time they are occupying the rail arm a C reaches — this is the core risk/reward of choosing which arm to defend, not an oversight.

### Layering and hit resolution

Drones can overlap on screen (e.g. a small drone flying in front of a large one). Layering ranges from full overlap to partial (~50%) to no overlap at all — overlap frequency is a tunable difficulty knob, likely wired into the per-wave data (see Wave Data, below), with early levels staggered-only and full overlaps introduced later as a distinct skill.

**Draw and hit priority are unified via VIC-II sprite number**: small (A) drones are always assigned the lowest available sprite numbers (highest display priority, drawn frontmost); large (C) drones get the highest sprite numbers (drawn behind). Medium (B) sits between. This is the same priority ordering the sprite multiplexer must preserve when cycling drones through hardware sprite slots.

For a bullet reaching a stack of overlapping drones, the frontmost (lowest sprite number, smallest) drone absorbs the hit first, and once destroyed the next drone behind it becomes the frontmost target, and so on. In the case of a perfect overlap between two same-priority-band drones, both may register a simultaneous hit via hardware collision — this is an acceptable outcome and not specifically resolved further.

**Collision detection** uses the VIC-II sprite-to-background collision register ($D01F) rather than manual bounding-box math: a drone explodes the instant it registers a collision with any non-blank background pixel. Since both bullets and rail structure are background characters, the register alone can't distinguish "hit a bullet" from "reached the rail" — on collision, a quick software check of the character at the collision point (bullet-char vs. rail-structure-char) determines which outcome applies (score + bullet consumed, vs. rail damage).

## Rail damage

The rail visibly accumulates damage from A/B impacts, represented via redefined characters (roughly 5 tunable damage levels per segment, same technique as static-frame character redefinition elsewhere in the project).

## Player health, shield, and damage resolution

The player has a health pool rather than a binary "hit = dead" state. A full (direct-range) C blast costs 2 points; a half (outer-range) blast costs 1 point. Starting health is tunable, likely `4 * health-bar-character-count` given a 2px-per-step bar, so that a full hit removes a clearly visible chunk of the bar. Health reaching 0 kills the player, at which point a reserve life (if any) is consumed and the player respawns; running out of lives, or the rail being fully destroyed, both end the game (there is no meaningful distinction between the two loss conditions — either way, it's Game Over).

**Shield** (see Bonuses) uses the same damage-point currency as health: while a shield is active, incoming C-blast damage is deducted from the shield pool instead of health, fully absorbing each hit regardless of size until the shield pool is exhausted, at which point damage resumes coming off health directly.

## Bonuses

Periodically, a bonus "parcel" spawns at the end of a rail arm and travels its full length. It always starts on the rail arm the player is **not** currently occupying, forcing a deliberate choice to move and intercept it. A bonus type never spawns while that same type is already active on the player (no stacking within a type), but different bonus types can be held simultaneously.

- **Shield**: absorbs incoming C-blast damage before it touches health (see above). Comes in three strengths — 6, 4, or 2 damage-points' worth — shown as a colored ring around the player, color indicating strength. Drop rate is weighted so the strongest tier (6) is rare and the weakest (2) is common.
- **Damage multiplier**: player projectiles do 2x or 3x damage for a tunable duration. 3x is short-lived and degrades to 2x rather than expiring outright. Indicated by projectile color, using the same color coding as the shield tiers.
- **Repair**: shown as a small object orbiting the player. While active, standing stationary over a damaged rail segment repairs it.
- **Ammo** (once the ammo mechanic is live): replenishes the ammo bar. Missing one while ammo is scarce is a real threat.
- **Score multiplier**: a "consolation" bonus that spawns instead of a real bonus if the player already holds all other bonus types at once. Doesn't aid survival directly, but still rewards the player for successfully intercepting the parcel.

## Wave / level data (to be tabulated)

The following should be table-driven per wave, to be filled in during tuning:
- Quadrant(s)/direction(s) active
- Drone speed
- Enemy type composition (A/B/C mix)
- Overlap likelihood (none / partial / full)
- Bonus spawn timing and weighting

## The HOW (technical notes)

1. **Rail**: user-defined background characters; damage levels are just alternate character definitions.
2. **Player and drones**: hardware sprites.
3. **Bullets**: user-defined characters, animated via a fixed 8-frame state machine per rail direction; fire rate is naturally capped by the rule that no two bullets share a cell simultaneously.
4. **Player sprite states**: barrel orientation (2 base frames, reused across both rail axes via the 90° remap), a shield-ring overlay, and a rotating repair-drone overlay (likely a separate sprite given its animation frame count).
5. **Sprite budget**: the player occupies up to 2 hardware sprite slots, leaving 6 of the 8 available for drones — roughly 2-3 concurrent waves without multiplexing. A raster-IRQ-driven sprite multiplexer is planned to increase effective concurrent drone count, using table-driven, offset wave launch timing to guarantee no more than 8 sprites ever share a raster line, while preserving the small-drones-get-low-sprite-numbers priority assignment described above even as drones are cycled through slots.

## Suggested build order

Given the sprite multiplexer and the bullet/rail/collision-disambiguation pipeline are the parts with the most technical unknowns, a first vertical slice should target: one rail arm, one drone type, no bonuses — just enough to prove out sprite multiplexing and the collision-resolution logic (bullet vs. rail vs. drone-layer priority) before layering in damage tiers, bonuses, and the full wave table.
