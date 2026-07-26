# Repo layout — decision

**Status:** chosen. Folders exist; source is not implemented yet.  
**Companion docs:** [`railgunner.md`](railgunner.md) (design), [`assembler-syntax.md`](assembler-syntax.md) (syntax).

## Decision summary

| Choice | Value |
|--------|--------|
| Source root | `src/` (not repo root) |
| Depth | Two levels under `src/` max: `src/<area>/<file>.asm` |
| Entry file | `src/main.asm` — only file that sets origin / BASIC stub and `.include`s the rest |
| Binary / generated assets | `assets/` (inputs for `.incbin` or generators) |
| Host tools | `tools/` (Python, etc.) |
| Assemble output | `build/` (not source; may be gitignored later) |
| Agent docs | `agents/` (already present) |

**Why not a flat root or a single `game.asm`?**  
The design is not a demo loop. Frontend states, rail/bullet character pipelines, sprite mux, collision disambiguation, wave tables, and bonuses are independent enough to want separate files, and there will be enough of them that a flat dump becomes unsearchable.

**Why not deep nesting** (`src/game/enemies/types/...`)?  
c64m `.include` paths are relative to the including file; deep trees make include lines brittle and encourage over-splitting. One area folder + clear filenames is enough.

---

## Component breakdown (from design brief)

### A. Bootstrap & system (~4–6 files)

Machine bring-up shared by every mode (title and play).

| Piece | Responsibility |
|-------|----------------|
| Entry / BASIC stub | `$0801` SYS stub, jump to init |
| Memory map & ZP | Segment layout, zero-page allocations, hardware constants |
| Init | VIC bank, charset pointer, screen clear, IRQ install |
| IRQ / frame | Raster IRQ shell; eventually hosts sprite mux |
| Input | Joystick + keyboard (WASD/space) → normalized dir/fire |

### B. Frontend / meta-game (~6–8 files)

Not specified in the first brief beyond “there will be screens”; we assume a real outer shell.

| Piece | Responsibility |
|-------|----------------|
| Mode / state machine | Title ↔ scores ↔ play ↔ game over ↔ victory ↔ score entry |
| Title | Title image/text, “press fire”, optional joy vs keyboard choice |
| Attract / high scores | Timed flip between title and score table |
| High score table | Display top scores; storage (RAM now, disk later if needed) |
| Score entry | Initials after a qualifying score |
| Game over | Loss presentation → back to scores/title |
| Victory | Optional clear-state presentation |
| Radio message | In-fiction ammo unlock (can live here or under game HUD text) |

### C. Playfield rendering (~5–7 files)

Background characters, not sprite logic.

| Piece | Responsibility |
|-------|----------------|
| Screen / layout | 40×25 cross rail layout, center gap, static structure draw |
| Rail damage draw | Damage levels as redefined chars / per-segment state → screen |
| Bullets draw | 8-char animation state machines per rail direction; cell occupancy |
| HUD | Score digits, health bar, ammo bar (incl. inactive gray), level, lives icons |
| Charset load | Copy/point to custom character definitions |

### D. Sprites & multiplexing (~4–6 files)

| Piece | Responsibility |
|-------|----------------|
| Player sprite | Position on rail centerline, 2 barrel frames + 90° remap, shield/repair overlays |
| Drone sprites | A/B/C appearance, size → sprite number priority band |
| Sprite mux | Raster-driven reuse of 6 drone HW slots; ≤8 sprites/line guarantee |
| Sprite data | Pointer tables / `.incbin` frames |

### E. Gameplay (~8–12 files)

Logic that mutates game state; may call into render/sprite modules.

| Piece | Responsibility |
|-------|----------------|
| Player move | Rail lock, barrel switch, center intersection mount rules |
| Shooting / ammo | Fire stream, cell throttle, ammo consume when unlocked |
| Drones / motion | Straight-line to rail, speed, spawn from edges/quadrants |
| Collision | `$D01F` sprite-BG; disambiguate bullet vs rail char; hit priority |
| Rail damage logic | A/B impact → segment damage; full rail destruction → game over |
| Health / lives | C blast radii (full/half), shield pool, respawn, lives |
| Bonuses | Parcel spawn on opposite arm, types, no same-type stack |
| Waves / levels | Table-driven waves: quadrants, speed, mix, overlap, bonus timing |
| Score | Points, multipliers |
| Play loop | Per-frame order while `mode == play` |

### F. Data / content (~6–12 files, grows with levels)

| Piece | Responsibility |
|-------|----------------|
| Wave tables | Per-wave / per-level binary-friendly tables |
| Char definitions | Rail, bullets, HUD bars, lives icon, damage frames |
| Sprite frames | Player, drones A/B/C, shield ring, repair orb, bonus parcel |
| Strings / PETSCII | Title, game over, victory, radio message, score entry UI |
| High score seed | Default table |

### G. Tools & host assets (optional growth)

| Piece | Responsibility |
|-------|----------------|
| Table generators | Wave sheets, sine/offset tables if any |
| Char/sprite export | From PNG or other source → bytes for `.incbin` |

---

## Expected file count

| Phase | Approx. `.asm` / `.inc` under `src/` | Notes |
|-------|--------------------------------------|--------|
| Vertical slice (1 arm, 1 drone, no bonuses) | **8–12** | boot, zp, irq stub, rail, player, one drone, bullets, collision, main |
| Playable single level + HUD | **18–25** | + HUD, health, damage, waves |
| Full game + frontend shell | **30–45** | + title/scores/entry/game over, bonuses, mux, ammo |
| Content-heavy (many levels, polish) | **40–55+** | mostly `data/` growth |

**Conclusion:** too large for repo-root clutter or one monolith; small enough that **area folders under `src/`** (not a deep package tree) is the right grain. Rough steady state: **~35 files of logic + data includes**, plus `assets/` binaries and a few `tools/`.

---

## Directory tree

```
railgunner/
├── agents/                 # Handoffs (design, syntax, this layout)
├── src/                    # All assembly source
│   ├── main.asm            # Entry: stub, segments, include graph
│   ├── boot/               # BASIC stub helpers, cold init
│   ├── sys/                # ZP, constants, IRQ, input, memory map
│   ├── frontend/           # Title, scores, game over, victory, entry
│   ├── game/               # Play-mode logic
│   ├── render/             # Screen, rail/bullet/HUD character presentation
│   ├── sprite/             # Player/drone sprites, multiplexer
│   └── data/               # Tables, strings, embeds (or includes of assets)
├── assets/                 # Authoring inputs & binary blobs for .incbin
│   ├── charset/
│   ├── sprites/
│   └── screens/            # Title / attract screen art if not pure code
├── tools/                  # Generators and build helpers (host)
└── build/                  # c64masm outputs (PRG/bin); not hand-edited
```

### Naming conventions

| Kind | Convention | Example |
|------|------------|---------|
| Logic module | `src/<area>/<topic>.asm` | `src/game/collision.asm` |
| Shared definitions / tables only | `*.inc` ok when no code entry | `src/data/waves.inc` |
| Labels | Prefer `.proc` / `.scope` per module; export with `module::label` only when needed | |
| Constants | `src/sys/const.asm` (VIC, screen base, char codes) | |
| Zero page | `src/sys/zeropage.asm` — single owner of ZP map | |

### Include graph (ownership)

```
main.asm
  ├── sys/const.asm, sys/zeropage.asm, sys/memory.asm
  ├── boot/init.asm
  ├── sys/irq.asm, sys/input.asm
  ├── frontend/*.asm          ; mode dispatcher last among frontend
  ├── render/*.asm
  ├── sprite/*.asm
  ├── game/*.asm
  └── data/*                  ; after code that references labels, or use two-pass freely
```

Exact include order is fixed in `src/main.asm` when files appear. **Only `main.asm` should be passed to `c64masm` / the Assembler tab** as the root file (unless a test harness says otherwise).

### Assembler / load addresses (layout implication)

Use **named segments** (as in c64m `c64-life.asm` style), defined once in `src/sys/memory.asm` or top of `main.asm`:

| Segment | Typical role |
|---------|----------------|
| `ZEROPAGE` | `noemit` variable map |
| `BASIC` | `$0801` stub |
| `CODE` | All executable modules |
| `DATA` | Tables, charset copies if resident |
| Optional later | `SPRITES`, `CHARSET` at fixed VIC-friendly addresses |

Live-in-emulator vs file build may differ via `C64MASM` (see assembler handoff); the **file tree stays the same**.

---

## Mapping: design systems → folders

| Design system | Primary folder | Secondary |
|---------------|----------------|-----------|
| Screen cross layout | `render/` | `data/` (char defs) |
| HUD | `render/` | `game/` (values) |
| Controls / barrel / rails move | `game/` + `sys/input` | `sprite/` (draw) |
| Shooting / bullet cells | `game/` + `render/` | `data/` (bullet chars) |
| Ammo | `game/` | `render/` (bar), `frontend/` (radio msg) |
| Drones A/B/C | `game/` + `sprite/` | `data/` |
| Collision `$D01F` | `game/collision` | — |
| Rail damage | `game/` + `render/` | `data/` |
| Health / shield / lives | `game/` | `render/` HUD, `sprite/` overlays |
| Bonuses | `game/` | `sprite/`, `render/` |
| Wave tables | `data/` | `game/waves` |
| Sprite mux | `sprite/` | `sys/irq` |
| Title / scores / game over / victory | `frontend/` | `assets/screens`, `data/` |
| Score entry / hiscores | `frontend/` | `data/` |

---

## What does **not** go in `src/`

| Path | Why separate |
|------|----------------|
| `agents/` | Human/agent prose, not assembled |
| `assets/` | Large binaries and art sources; keep assemble unit small and `.incbin` explicit |
| `tools/` | Host Python/shell; never run on the 6510 |
| `build/` | Outputs only |

Repo root stays thin: optional top-level `README.md` / makefile later; **no game `.asm` at root**.

---

## Vertical-slice file set (first implementation target)

Aligned with the design brief’s suggested build order (one rail arm, one drone type, no bonuses):

```
src/main.asm
src/sys/const.asm
src/sys/zeropage.asm
src/sys/memory.asm
src/boot/init.asm
src/sys/irq.asm              ; stub IRQ first; mux later
src/sys/input.asm
src/render/screen.asm        ; draw one arm + structure
src/render/bullets.asm
src/sprite/player.asm
src/sprite/drones.asm        ; type A only at first
src/game/player.asm
src/game/shoot.asm
src/game/drones.asm
src/game/collision.asm
src/game/play.asm             ; frame loop
```

Frontend and bonuses land **after** mux + collision are proven.

---

## Rejected alternatives

| Alternative | Why rejected |
|-------------|--------------|
| All source in repo root | Clutters root; mixes with agents/tools; ~40 files unmanageable |
| Single `railgunner.asm` | Fine for a 200-line demo; not for mux + waves + frontend |
| `src/components/...` deep tree | Over-structured for asm; painful includes |
| Separate repo per frontend/game | No; one PRG, one product |
| `include/` vs `src/` split like C | Asm modules are both decls and code; one tree under `src/` |

---

## Maintenance rules for agents

1. New gameplay feature → prefer `src/game/<topic>.asm` (or extend an existing topic file if it is still small).
2. New pure presentation of existing state → `src/render/` or `src/sprite/`.
3. New outer-loop screen → `src/frontend/`.
4. New numbers/strings/frames → `src/data/` and/or `assets/`.
5. Always wire new files through `src/main.asm` includes.
6. Do not add assembler syntax variants; follow `assembler-syntax.md`.
7. If this layout document drifts from reality, update it in the same change.
