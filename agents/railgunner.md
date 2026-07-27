# RailGunner — Design Brief

**Role:** Top-level design brief for agents. Read this first for *what* we are
building and *why* the technical choices exist. For *how* to write assembly that
assembles under c64m, read [`assembler-syntax.md`](assembler-syntax.md) before
emitting any source. Index: [`README.md`](README.md).

---

A Commodore 64 shooter. The player is a gun mounted on rails that form a cross across the screen. Enemy drones fly in from the edges and attack either the rail or the player; the player must decide, moment to moment, which to defend.

## The screen layout

40 columns × 25 rows (0-based in code). Implemented playfield matches
`str_hud` / `screen_draw_playfield` / `const.asm` rail geometry.

```
col: 0123456789012345678901234567890123456789
row +----------------------------------------+
  0 |000000  H:######## A:######## L:01  AAAA|  HUD (see below)
  1 |                  ABC                   |  V-rail only
  2 |                  ABC                   |
    |                  ...                   |  rows 1–11: ABC @ cols 18–20
 11 |                  ABC                   |
 12 |DDDDDDDDDDDDDDDDDDGBHDDDDDDDDDDDDDDDDDDD|  H-rail top edge
 13 |EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE|  H-rail mid (full width)
 14 |FFFFFFFFFFFFFFFFFFIBJFFFFFFFFFFFFFFFFFFF|  H-rail bottom edge
 15 |                  ABC                   |
    |                  ...                   |  rows 15–24: ABC @ cols 18–20
 24 |                  ABC                   |
    +----------------------------------------+
```

**Rail geometry (0-based cells)** — source of truth: `RAIL_*` in `src/sys/const.asm`:

| Band | Cells | Tiles (placeholder letters today) |
|------|--------|-----------------------------------|
| V-rail | cols **18–20** | A left edge, B solid mid, C right edge |
| H-rail | rows **12–14** | D top edge, E mid solid, F bottom edge |
| Junction | col 18–20 × row 12–14 | G elbow L→up, H elbow top→R, I L→down, J R→down, B solid cross |

- Left free play: cols 0–17 · Right free: cols 21–39.
- Stage-2 player rides the **H-rail** (Y on the E band). Crossing the V-band
  (between left/right arm rests) is walk-through only; **fire is locked out**
  there so bullets cannot chew the vertical rail.
- Final art replaces A–J with UDGs (same map, different screen codes — see
  **Character / UDG map** below). Letters are layout stand-ins, not the product look.

### Top line (HUD) — row 0

Exactly 40 columns; template in `src/data/strings.asm` (`str_hud`):

```
000000  H:######## A:######## L:01  AAAA
|     | ||      | ||      | ||  | ||  |
0     6 8 10    17 19 21   28 30 32 35 36  39
```

| Field | Cols | Len | Notes |
|-------|------|-----|--------|
| **Score** | 0–5 | 6 | Digits, leading zeros, no label. Colour wheel later. |
| *(pad)* | 6–7 | 2 | Spaces. |
| **H:** | 8–9 | 2 | Health label (ASCII until UDGs). |
| **Health bar** | 10–17 | 8 | `#` stand-in; blue. Final: UDG bar (finer steps later). |
| *(pad)* | 18 | 1 | Space. |
| **A:** | 19–20 | 2 | Ammo label. |
| **Ammo bar** | 21–28 | 8 | `#` stand-in; red / grayed when inactive. Same structure as health; shape/end-caps should differ for non-colour legibility. See **Ammo**. |
| *(pad)* | 29 | 1 | Space. |
| **L:** | 30–31 | 2 | Level label. |
| **Level** | 32–33 | 2 | Digits, leading zero. |
| *(pad)* | 34–35 | 2 | Spaces. |
| **Lives** | 36–39 | 4 | One icon per reserve life, max 4. Today: letter `A`; final: life UDG. |

Constants: `HUD_*` in `src/sys/const.asm` (must stay in sync with `str_hud`).

Live score/level/lives/bar fill is still partially placeholder (static template +
static colouring); wire-up is a later roadmap item.

### Character / UDG map

256-glyph RAM font at `CHARSET_RAM` ($2800). Cold init copies the ROM uppercase
set, then overlays UDGs. **Reserved game block** (39 glyphs; do not use for
plain text):

| Codes | Count | Use |
|-------|------:|-----|
| `$C0` | 1 | Life icon (HUD) |
| `$C1`–`$CA` | 10 | Rail normal a–j |
| `$CB`–`$D0` | 6 | Rail damage set 1 (a–f only) |
| `$D1`–`$D6` | 6 | Rail damage set 2 (a–f only) |
| `$F0`–`$F7` | 8 | Vertical bullets (4 phases × L/R half-cell) |
| `$F8`–`$FF` | 8 | Horizontal bullets (reserved; later) |

**What ships today**

- **Bullets** already use the final high codes (`$F0`–`$FF`) and install real
  UDG bitmaps at those slots — no conflict with the text font.
- **Rails / lives / bars** still draw **stock font placeholders** (A–J, `#`)
  via low screen codes so the cross and HUD stay readable before art exists.
  Planned production codes are the `$C0+` block above (`SC_UDG_*` in
  `const.asm`); playfield draw will switch `SC_RAIL_*` to those values when
  glyphs are installed.

**Why not already draw at `$C1` (e.g. “start at 129”)?**  
That is the right *end state*, and the map is reserved for it. Using A–J on
screen *now* is only so agents and playtests see a legible cross without a
second “seed A–J into UDG slots” step. It does **not** mean final art will
overwrite the letter forms in the text range: art installs into `$C0`–`$D6` /
`$F0`–`$FF`, and draw codes move with it. Prefer that path over a render-time
hack. Optional interim: copy ROM A–J bitmaps into `$C1`–`$CA` at init and draw
final codes immediately — same visual, one less constant flip later.

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

- **A (large)**: 3 hits to destroy.
- **B (medium)**: 2 hits to destroy.
- **C (small)**: 1 hit to destroy.

**Type convention is fixed:** A = large, B = medium, C = small. Preserve this
mapping in code, data, art names, and future documentation.

Speed is constant within a given wave; later waves within a level, and later levels overall, increase drone speed as a difficulty lever. All drones in a wave move at that wave's speed.

### What each type attacks

- **C (small) drones** attack the **player only**. On reaching the rail they explode with a radial blast: player within ~8px of the blast origin takes a **direct hit**, player within ~8-16px takes a **half hit** (exact radii tunable). The blast does not damage the rail and does not chain into other drones.
- **A (large) and B (medium) drones** attack the **rail only**. On reaching the rail they explode, causing rail damage. They do not harm the player directly.

Since a C drone's explosion origin is always at the rail edge, the player is in some degree of blast range any time they are occupying the rail arm a C reaches — this is the core risk/reward of choosing which arm to defend, not an oversight.

### Layering and hit resolution

Drones can overlap on screen (e.g. a small drone flying in front of a large one). Layering ranges from full overlap to partial (~50%) to no overlap at all — overlap frequency is a tunable difficulty knob, likely wired into the per-wave data (see Wave Data, below), with early levels staggered-only and full overlaps introduced later as a distinct skill.

**Draw priority uses VIC-II sprite number**: small (C) drones are always assigned the lowest available sprite numbers (highest display priority, drawn frontmost); large (A) drones get the highest sprite numbers (drawn behind). Medium (B) sits between. This is the same priority ordering the sprite multiplexer must preserve when cycling drones through hardware sprite slots.

VIC-II sprite/background collision is independent of sprite draw priority. If a
bullet overlaps opaque pixels from several drones in the same frame, every
reported drone receives the hit; the bullet is consumed once after all
collision candidates have been examined. This permissive result is intentional
and can read visually like one drone's destruction caught the overlapping
drones. Sprite number controls appearance, not exclusive bullet ownership.

**Collision detection** uses the VIC-II sprite-to-background collision register
($D01F) as a candidate latch. Since both bullets and rail structure are
background characters, the register alone cannot distinguish "hit a bullet"
from "reached the rail"; software checks the character cells under the drone's
tight hitbox and applies bullet damage or rail arrival. The mux must translate
the hardware collision bit to the logical object before reusing that hardware
sprite. See [`objects-sprites.md`](objects-sprites.md).

## Rail damage

The rail visibly accumulates damage from A/B impacts, represented via redefined characters (roughly 5 tunable damage levels per segment, same technique as static-frame character redefinition elsewhere in the project).

## Player health, shield, and damage resolution

The player has a health pool rather than a binary "hit = dead" state. A full (direct-range) **C** blast costs 2 points; a half (outer-range) blast costs 1 point. Starting health is tunable, likely `4 * health-bar-character-count` given a 2px-per-step bar, so that a full hit removes a clearly visible chunk of the bar. Health reaching 0 kills the player, at which point a reserve life (if any) is consumed and the player respawns; running out of lives, or the rail being fully destroyed, both end the game (there is no meaningful distinction between the two loss conditions — either way, it's Game Over).

**Shield** (see Bonuses) uses the same damage-point currency as health: while a shield is active, incoming **C-blast** damage is deducted from the shield pool instead of health, fully absorbing each hit regardless of size until the shield pool is exhausted, at which point damage resumes coming off health directly.

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
4. **Player sprite states**: barrel orientation (2 base frames, reused across both rail axes via the 90° remap), shield ring, and repair animation are composited into one dynamically updated sprite frame where the art permits. Use two writable 64-byte buffers and swap the sprite pointer after updating the inactive buffer.
5. **Graphical-object/mux system**: one common 24-slot pool contains player, drones, parcel, and later sprite effects; logical slot 0 is permanently the player. All eight hardware sprites are transient mux lanes. Wave launch timing targets at most 7 graphical objects per raster line and must also leave enough raster time for lane reuse. Preserve `C < B < A` hardware-sprite numbering for overlapping drones. Full implementation contract: [`objects-sprites.md`](objects-sprites.md).

## Suggested build order

Given the sprite multiplexer and the bullet/rail/collision-disambiguation pipeline are the parts with the most technical unknowns, a first vertical slice should target: one rail arm, one drone type, no bonuses — just enough to prove out sprite multiplexing, hardware-slot collision attribution, and bullet-vs-rail resolution before layering in damage tiers, bonuses, and the full wave table.

**Status:** the multiplexer and object pool are already implemented (see
[`sprite-mux-status.md`](sprite-mux-status.md)). The remaining slice work is
player, bullets, one mover, and a gameplay collision consumer.

**Full stage plan, ordered Next steps, and game-mode flow:** see
[`roadmap.md`](roadmap.md). This brief remains the source of truth for
mechanics; the roadmap owns maturity stages, control flow, and the default
work order.
