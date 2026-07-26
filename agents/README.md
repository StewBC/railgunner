# RailGunner agent handoff

This directory is the concise, implementation-oriented handoff for agents working
on **RailGunner** — a Commodore 64 game written in 6502 assembly and developed
against **c64m** (emulator, debugger, assembler, remote API) at `../c64m/`.

Game design and technical intent live here. The c64m **source and tests** remain
authoritative for the toolchain; if a handoff doc and the tool disagree, trust
the tool (and fix the handoff).

## Read in this order

1. **`railgunner.md`** — top-level design brief (what the game is, layout,
   mechanics, technical approach, suggested build order).
2. **`repo-layout.md`** — where source lives, component → folder map, expected
   file count, include rules. Create new files only under this plan.
3. **`assembler-syntax.md`** — **required before writing any `.asm`**. c64m
   assembler language only (not ACME / ca65 / KickAsm / 64tass unless listed
   there). Syntax, directives, macros, scopes, segments, pitfalls.
4. Component handoffs relevant to the task (added as they appear).
5. Source under `src/` (root unit: `src/main.asm`) and samples under
   `../c64m/samples/` when learning idioms.

Do not invent assembler syntax. If something is missing from
`assembler-syntax.md`, check `../c64m/manual/manual.md` (Assembler section), then
update the handoff so the next agent does not rediscover it.

## Document index

| Doc | Role |
|-----|------|
| [`railgunner.md`](railgunner.md) | Top-level design brief: screen, controls, combat, bonuses, wave data, HOW, build order |
| [`repo-layout.md`](repo-layout.md) | Repo tree, components, file-count rationale, vertical-slice file set |
| [`assembler-syntax.md`](assembler-syntax.md) | c64m 6502 assembler syntax for all game source |

## Source tree (summary)

| Path | Role |
|------|------|
| `src/main.asm` | Sole assemble root; includes everything else |
| `src/boot/` | Cold init / bring-up |
| `src/sys/` | ZP, constants, IRQ, input, memory map |
| `src/frontend/` | Title, high scores, score entry, game over, victory |
| `src/game/` | Play-mode logic (player, drones, collision, waves, …) |
| `src/render/` | Character playfield, bullets, HUD |
| `src/sprite/` | Player/drone sprites, multiplexer |
| `src/data/` | Tables, strings, embeds |
| `assets/` | Art / binary blobs for `.incbin` |
| `tools/` | Host generators |
| `build/` | Assembler outputs (not hand-edited) |

Full rationale and vertical-slice file list: **`repo-layout.md`**.

## Toolchain (pointer only)

| Piece | Where |
|-------|--------|
| Emulator + in-emulator assemble | `../c64m/` (`c64m`) |
| CLI assembler | `../c64m/` (`c64masm`) |
| Full user manual | `../c64m/manual/manual.md` |
| Sample `.asm` | `../c64m/samples/` |

Remote control and debugger workflow will get their own handoffs when needed.
Until then, syntax for assembly source is entirely in **`assembler-syntax.md`**.

## Doc hygiene

- Prefer updating these docs in the same change that invalidates them.
- Stale handoffs are worse than missing ones.
- Keep design (`railgunner.md`), layout (`repo-layout.md`), and assembler syntax
  (`assembler-syntax.md`) separate; do not mix long design prose into the syntax
  doc.
