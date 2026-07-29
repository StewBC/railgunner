# c64m Assembler Syntax — Agent Handoff

**Purpose:** Use this document when writing 6502/6510 assembly for RailGunner. The game is built with the **c64m** assembler (same engine as the in-emulator Assembler tab and the `c64masm` CLI). Do not invent ACME, ca65, KickAsm, or 64tass directives unless they also appear here.

**Source of truth:** `../c64m/manual/manual.md` (section **Assembler**). This file is a rewrite for agents: syntax-first, game-dev oriented, with pitfalls called out. If this doc and the manual disagree, trust the manual and fix this doc.

**Assembler identity:** Two-pass 6502 assembler. C64 code targets the **6510**, which is instruction-compatible with the 6502. Default opcode set is 6502; `.65c02` enables 65C02 opcodes if needed (usually not for stock C64).

---

## 1. File shape (minimal program)

```asm
; comment
* = $C000                 ; or: .org $C000

BORDER  = $D020           ; constant / variable
start:
    lda #0
    sta BORDER
    jmp *
```

Common origins for this project (choose one strategy and stay consistent):

| Origin   | Use |
|----------|-----|
| `$0801`  | BASIC program area; often with a `SYS` stub so the user can `RUN` |
| `$C000`  | Upper free RAM; typical for demos / games loaded with assemble-into-RAM |
| Segments | Named regions via `.segdef` / `.segment` (see §8) |

---

## 2. Lexical rules

### Comments

- `;` starts a comment; rest of the line is ignored.

### Labels

- Start with a letter or `_`.
- May contain letters, digits, and `_`.
- End with `:` on the definition line.
- Example: `main:`, `_loop:`, `player_x:`.

### Variables / constants

- Assignment: `ident = expr`
- Same identifier rules as labels (no trailing `:`).
- Used for ZP addresses, hardware registers, magic numbers, counters in `.for` / `.repeat`.

### Postfix on variables

- `++` and `--` are **prefix-style postfix** on the identifier: they modify the variable and the expression uses the value **after** the change.
- Example: `lda #i++` loads the incremented value of `i`.

### Current address (`*`)

- `*` is the address of the **current** instruction or data line (standard convention).
- `jmp *` is a self-loop.
- Arithmetic works: `jmp *+5`, `.word *`, `lda *`.
- Setting origin: `* = $nnnn` (equivalent to `.org $nnnn`).

### Numbers

| Prefix / form | Base        | Example   |
|---------------|-------------|-----------|
| `$`           | Hex         | `$C000`, `$ff` |
| `%`           | Binary      | `%01000000` |
| leading `0`   | Octal       | `010` (= 8 decimal) |
| `1`–`9` start | Decimal     | `40`, `2061` |

### Character literals

- Single-quoted characters participate in expressions: `'A'`, `'0'`.
- Useful with `.strcode` and PETSCII/screen-code math.

---

## 3. Expressions

Full C-style precedence. Use **dot-operators** for relational comparisons (not bare `<` / `>` as binary comparisons — those are unary low/high byte).

### Operators (high → low precedence)

| Level | Operators | Meaning |
|-------|-----------|---------|
| Atoms | `*`, `:`, numbers, variables, `(...)` | Program counter, ternary colon, values |
| Unary | `+` `-` `<` `>` `~` | Plus, minus, **low byte**, **high byte**, bitwise NOT |
| Exp   | `**` | Exponentiation |
| Mul   | `*` `/` `%` | Multiply, divide, modulo |
| Add   | `+` `-` | Add, subtract |
| Shift | `<<` `>>` | Shift left / right |
| Rel   | `.lt` `.le` `.gt` `.ge` | `<` `<=` `>` `>=` |
| Eq    | `.eq` `.ne` | `==` `!=` |
| Bit AND | `&` | Bitwise AND |
| Bit XOR | `^` | Bitwise XOR |
| Bit OR  | `\|` | Bitwise OR |
| Logic | `&&` `\|\|` | Logical AND / OR |
| Ternary | `?` `:` | `cond ? then : else` |

### Critical: low / high byte

```asm
lda #<BITMAP          ; low byte of address
lda #>BITMAP          ; high byte of address
.word start           ; little-endian 16-bit address
```

Do **not** write comparisons as `a < b`. Use `a .lt b`.

### Conditional / define tests

Inside `.if`:

- Relational/equality: `.lt` `.le` `.gt` `.ge` `.eq` `.ne`
- Existence: `.defined name`
- Bare symbol: `.if FLAG` is true when `FLAG` is nonzero (works for `C64MASM`)

**CRITICAL — do not use `=` inside `.if`:**

```asm
MODE = 0
.if MODE = 0        ; WRONG: this is ASSIGNMENT, not equality
    lda #$11        ; skipped when MODE was already 0 (assign 0 → false)
.endif
.if MODE = 1        ; assigns MODE := 1, condition true → ASSEMBLED
    lda #$22
.endif
.if MODE = 2        ; assigns MODE := 2, condition true → ASSEMBLED
    lda #$33
.endif
; MODE is now 2 (side effect). Both $22 and $33 were emitted.
```

Verified with `tools/c64masm` (2026-07): `.if X = n` **assigns** `X := n` and treats
the assigned value as the condition (0 = false, nonzero = true). So a mode switch
written that way can assemble **multiple** branches and **mutate** the constant for
later code. RailGunner hit this: `COLLISION_MODE = 0` still built hybrid + soft
paths (green/blue border dogfood in “HW-only” play).

```asm
; Correct:
.if MODE .eq 0
    jsr mode_hw_only
.endif
.if MODE .eq 1
    jsr mode_hybrid
.endif

; C-style == is a hard error ("Unexpected primary token"):
; .if MODE == 0
```

When changing a compile-time mode flag, **disassemble or check symbols** for the
expected single `JSR` target — do not trust that only one `.if` body assembled.

### Predefined define: `C64MASM`

| Host | `C64MASM` value |
|------|-----------------|
| Command-line `c64masm` | `1` |
| In-emulator Assembler tab / remote `assemble` | `0` |

```asm
.if C64MASM
    * = $0801           ; file build
.else
    * = $C000           ; live poke into spare RAM
.endif
```

Extra defines: `c64masm -D NAME[=value]` (value defaults to `1`).

---

## 4. Instructions and addressing modes

Standard 6502 mnemonics and addressing modes. Write them in the usual form:

```asm
    lda #$00            ; immediate
    lda $02             ; zero page
    lda $0400           ; absolute
    lda $0400,x         ; absolute,X
    lda $0400,y         ; absolute,Y
    lda ($fb),y         ; (indirect),Y
    lda ($fb,x)         ; (indirect,X)
    sta BORDER          ; symbol as address
    jmp ($0318)         ; indirect jump
    bne loop            ; relative branch to label
    lsr $4d             ; RMW on ZP — must emit opcode + operand (fixed in c64m)
    ldx $10,y           ; zeropage,Y (LDX/STX only) — not promoted to abs,Y
```

**Macro pitfall:** arguments that contain a comma must be double-quoted, or the comma splits parameters:

```asm
    copy "($50),y", $0400
```

**Silent encoding (fixed upstream, do not re-work around):**

| Form | Was wrong | Now |
|------|-----------|-----|
| `lsr $nn` / `lsr zp` | opcode only (`$46`), dropped address byte | full `46 nn` (width fixed like `asl`/`rol`/`ror`) |
| `ldx $nn,y` | always absolute,Y (`$BE`) | zeropage,Y (`$B6`) when in range |
| `stx $nn,y` | hard error (no abs,Y form) | zeropage,Y when the opcode exists |

If you still see lone-opcode `lsr` or forced abs,Y, rebuild `tools/c64masm`
from c64m (need ≥ 638d3c9). Prefer `c64masm -v` on a one-liner to verify.

---

## 5. Directives (complete table)

| Directive | Meaning |
|-----------|---------|
| `.org n` or `* = n` | Set assembly origin |
| `.byte b[,b]*` | Emit bytes (numeric exprs **or** strings) |
| `.word w[,w]*` | 16-bit little-endian words |
| `.addr w[,w]*` | Synonym for `.word` |
| `.dword dw[,dw]*` | 32-bit little-endian |
| `.qword qw[,qw]*` | 64-bit little-endian |
| `.drow w[,w]*` | 16-bit **big-endian** words |
| `.drowd dw[,dw]*` | 32-bit big-endian |
| `.drowq qw[,qw]*` | 64-bit big-endian |
| `.res l[,b]` | Reserve `l` bytes filled with `b` (default `$00`) |
| `.align v` | Advance to next multiple of `v`, pad with zeros |
| `.string "s"` | Emit string bytes |
| `.asciiz "s"` | Emit string bytes + trailing `$00` |
| `.strcode e` | Per-character string map; `_` is current ASCII value |
| `.include "f"` | Include source (path relative to including file) |
| `.incbin "f"` | Include binary verbatim (same path rule) |
| `.define name text` | Text substitution on word boundaries (skips string literals) |
| `.if cond` / `.else` / `.endif` | Conditional assembly |
| `.for init, cond, iter` / `.endfor` | Assemble-time loop |
| `.repeat n[,v]` / `.endrepeat` or `.endrep` | Repeat block `n` times; optional counter `v` |
| `.macro name [args]` / `.endmacro` | Macro definition |
| `.local name` | Macro-local label (unique per expansion) — **only inside macros** |
| `.scope [name] [file="f"] [dest="d"]` / `.endscope` | Namespace; optional multi-file output (`c64masm` only) |
| `.proc name` / `.endproc` | Named procedure (named scope) |
| `.segdef "n",addr[,flags]` | Define named segment at `addr`. Flags are a comma-separated list of `emit`/`noemit` and `locked` |
| `.segdef "n",reclaim="host"` | Reclaim overlay on an emitted host (implicit `noemit`; see §8) |
| `.segment "n"` | Activate segment; `.segment ""` → native mode |
| `.6502` | Restrict to 6502 opcodes (**default**) |
| `.65c02` | Allow 65C02 opcodes |

### Notes on data directives

- `.byte` accepts strings; **`.strcode` does not apply** to string arguments of `.byte`.
- Use `.string` / `.asciiz` when you want `.strcode` remapping.
- String escapes (processed in strings, not passed through `.strcode`): `\n` `\r` `\t` `\0` `\\` `\xNN` `\0NN` (octal).

### Origin re-anchor rule (host default)

If the host supplies a default origin (`Assemble at`, or `address=` on the control port) and the source has **not yet emitted any bytes**, a later `* = $nnnn` / `.org $nnnn` re-anchors cleanly. **Going backwards after code has been emitted is an error.**

---

## 6. Macros

```asm
.macro name [arg [, arg]*]
    body
.endmacro
```

- Arguments are **text-substituted**.
- Comma inside an arg → wrap the whole arg in `"..."`.
- Use `.local labelname` for labels unique per call (required for branches inside reusable macros).
- **Illegal:** `.local` at top level; recursive macro calls; bare `.endmacro` without a matching `.macro`.

```asm
.macro load_store value dest
    lda #value
    sta dest
.endmacro

.macro branchy value
    .local done
    lda #value
    bne done
    lda #$ff
done:
    .byte value
.endmacro

    load_store $12, $d020
    branchy $01
```

Optional parameters can be tested with `.if .defined arg` inside the macro body.

---

## 7. Scopes and procs

`.scope` / `.proc` create namespaces so labels can be reused.

```asm
.proc loader
start:
    lda $D011
.endproc

.proc display
start:
    sta loader::start + 1    ; qualified reference into another scope
.endproc
```

Rules:

- Access other scopes with `scope::label`.
- `::name` at the start resolves from the **root** scope.
- Scope name: bare (`.scope game`) or quoted (`.scope "game"`) — equivalent.
- Quoted scope names must still be **legal identifiers** (no spaces). Used in `game::start`-style refs.
- Anonymous scopes (`.scope` … `.endscope` with no name) are ideal **inside loops** so iteration labels do not clash.

```asm
.for i=0, i .lt 8, i++
  .scope
    addr = $D800 + i
  start:
    lda addr
  .endscope
.endfor
```

`.proc name` is a named scope; close with `.endproc`.

### Multi-file output (CLI only)

```asm
* = $0801
        ; loader → default output file (-o)

.scope game file="game.bin"
    * = $C000
main:
    inc $D021
    jmp main
.endscope
```

- Honoured by **`c64masm` only**.
- In-emulator / remote assemble: `.scope` with `file=` / `dest=` is an **error** (no per-file targets; everything goes to live RAM).
- Labels stay visible across files via normal `::` rules (`game::main`).
- Optional `dest="..."` names a target for tooling without binding a file name.

---

## 8. Segments

Define regions once, then switch:

```asm
.segdef "ZEROPAGE", $02, noemit
.segdef "BASIC", $0801
.segdef "CODE", $080d
.segdef "DATA", $0D17

.segment "ZEROPAGE"
ptr:    .res 2

.segment "BASIC"
    .word $080B
    .word 10
    .byte $9E
    .byte "2061"
    .byte 0
    .word 0

.segment "CODE"
main:
    lda (ptr),y
    rts

.segment "DATA"
table:  .byte $01,$02,$03
```

- `noemit`: location counter advances, **no bytes written** — use for ZP variable maps.
- A plain **`noemit` segment may not overlap any other segment** (including
  another `noemit`). Intentional overlays use a **reclaim** segment (below).
- `.segment ""` returns to native (non-named) mode.
- Segment names are **quoted strings** in `.segdef` / `.segment`.

### Flags: `noemit` / `locked`

The trailing part of `.segdef` is a comma-separated flag list. Any of `emit` /
`noemit` (default `emit`) and `locked` may be combined:

```asm
.segdef "CODE",  $080d
.segdef "HIRES", $2000, emit, locked   ; VIC bitmap — pinned at $2000
```

- `locked` marks the segment as an **anchor**: when segment auto-adjust is
  enabled, its start address is never moved. Use it for regions the hardware
  reads from a fixed address (bitmap, sprite data, char sets).
- Auto-adjust still compacts lower segments **around** a locked anchor, but if
  they grow enough to overrun it, it does **not** try to reshuffle the layout —
  assembly fails with an error naming the locked segment, leaving the fix to
  you. Without auto-adjust, `locked` has no effect (an overlap is a plain
  overlap error, as before).

### Reclaim segments (intentional overlays)

`.segdef "NAME", reclaim="HOST"` is the sanctioned way to **reuse a host
segment’s address range at runtime** after the host’s load-time contents are
consumed (classic: title image at `$4000`, then buffers in the same RAM).

```asm
.segdef "TITLE", $4000                 ; image, emitted into the PRG
.segdef "REUSE", reclaim="TITLE"       ; labels resolve into TITLE's space

.segment "REUSE"
buffer: .res $100                      ; lives at $4000, emits nothing
```

Rules:

- Implicitly **`noemit`**; takes **no address of its own** (inherits host start).
- Host must be a **previously defined, emitted** segment.
- Size of the reclaim segment must be **≤ host** size.
- Follows the host if auto-adjust relocates it (start re-read on each re-parse).
- Assembler enforces address/size only — **you** must free/relocate the host
  before using the reclaim region at runtime.

RailGunner already has a large emitted `TITLE` at `$4000` and a tight `CODE`
region under the charset/sprite map. When you need buffers that reuse title
RAM after the title is discarded, prefer `reclaim="TITLE"` over fake
`noemit` overlaps (those now fail assembly).

---

## 9. Build-time loops

### `.for`

```asm
.for i=0, i .lt 4, i++
    .byte i
.endfor
```

Three clauses: init, condition, iteration. Condition uses `.lt` / `.eq` / etc.

### `.repeat`

```asm
.repeat 3, r
    .byte $10 + r
.endrep
; or .endrepeat
```

- Optional counter variable is the second argument.
- `.repeat 0` emits nothing (body skipped).

Nest freely; combine with anonymous `.scope` when emitting labels.

---

## 10. String mapping (`.strcode`)

Remap each character of subsequent `.string` / `.asciiz` data. `_` is the current character's ASCII value:

```asm
; Map A-Z and a-z to 0..25 (example)
.strcode _ .ge 'A' && _ .le 'Z' ? _ - 'A' : _ .ge 'a' && _ .le 'z' ? _ - 'a' : _
.string "Hello"

.strcode _                 ; restore identity map
```

For PETSCII/screen codes, write the appropriate expression once and keep strings readable.

---

## 11. Conditional assembly

```asm
.if VERSION .ge 2
    .byte $aa
.else
    .byte $bb
.endif

.if .defined DEBUG
    brk
.endif
```

Nesting is supported. False branches are not assembled (including nested content).

---

## 12. BASIC stub pattern (loadable with RUN)

Common pattern for a program that starts with a BASIC line `10 SYS nnnn`:

```asm
* = $0801
    .word next_line       ; pointer to next BASIC line
    .word 10              ; line number
    .byte $9E             ; SYS token
    .byte "2061"          ; address as ASCII decimal digits
    .byte 0               ; end of line
next_line:
    .word 0               ; end of program

* = $080d                 ; 2061 decimal — code starts here
start:
    ; ...
```

Or use segments (`BASIC` + `CODE`) as in `../c64m/samples/c64-life.asm`.

---

## 13. How assembly is invoked (context only)

Agents writing source only need correct syntax; invocation details for later docs:

| Path | Notes |
|------|--------|
| In-emulator Assembler tab | Writes into C64 RAM; optional reset-to-BASIC, auto-run PC, host origin |
| Remote control `assemble` | Same engine; settings mirror the tab (`reset=`, `address=`, etc.) |
| `c64masm -i file.asm -o out.bin` | Offline binary; `C64MASM=1`; supports `file=` scopes |

Labels from a successful assembly are exported to the debugger symbol table (Disasm / Symbol Lookup).

**INI keys** (optional persistence of tab state):

```ini
[assembler]
file           = path/to/source.asm
address        = 8000
use_address    = yes
run_address    = 8000
auto_run       = no
reset          = yes
rearm_oneshots = no
```

---

## 14. Pitfalls checklist (read before shipping code)

1. **Comparisons:** use `.lt` `.le` `.gt` `.ge` `.eq` `.ne` — not C operators `<` `>` `==`.
1b. **`.if` equality:** always `X .eq n` / `X .ne n`. **`X = n` inside `.if` is
    assignment with side effects** (mutates `X`, truth = assigned value). See §3.
2. **Low/high byte:** unary `<` and `>` only: `#<label`, `#>label`.
3. **Macro commas:** quote addressing modes with commas: `"($fb),y"`.
4. **`.local` only inside macros** — for loops use anonymous `.scope` or unique names.
5. **No recursive macros.**
6. **`.scope file=`** only with `c64masm`; fails in live assemble.
7. **Do not emit then move `*` backwards.**
8. **Octal trap:** a token starting with `0` is octal (`010` ≠ ten). Prefer `$0A` or `10`.
9. **`.byte "text"`** ignores `.strcode`; use `.string` for mapped text.
10. **Segment names are quoted** (`"CODE"`); scope names usually bare (`game`).
11. **Paths** for `.include` / `.incbin` are relative to the **including** file's directory.
12. Stick to **6502** mnemonics unless you intentionally enable `.65c02`.
13. **Overlays:** plain `noemit` may not overlap anything. Use
    `.segdef "N", reclaim="HOST"` for intentional runtime reuse of host RAM.
14. **Fixed VIC addresses:** mark with `locked` so auto-adjust never moves them;
    if lower segments overrun a locked anchor, assembly fails by design.

---

## 15. Idioms used in c64m samples

Useful real-world patterns under `../c64m/samples/`:

| Pattern | Example |
|---------|---------|
| Simple origin + labels | `test1.asm`, `sinc.asm` |
| `* = $C000` game loop | `ripple.asm` |
| Segments + BASIC stub + `.proc` | `c64-life.asm` |
| Dual origin (stub then `$C000`) | `bball.asm` |
| `#<` / `#>` pointer setup | `ripple.asm`, `sinc.asm` |
| Binary flags with `%` | `c64-life.asm` |

---

## 16. Tiny reference card

```asm
; comment
NAME    = $expr           ; constant
label:                    ; label
* = $addr                 ; origin
.org $addr                ; same

lda #imm / zp / abs / (zp),y / (zp,x) / abs,x / abs,y
#<sym  #>sym              ; low / high byte
*  *+n                    ; PC and PC arithmetic

.byte / .word / .addr / .res / .align / .string / .asciiz / .incbin
.include "file"
.if .else .endif   .for .endfor   .repeat .endrepeat
.macro .endmacro   .local
.scope .endscope   .proc .endproc
.segdef "N",addr[,emit|noemit][,locked]   .segment "N"
.segdef "N",reclaim="HOST"                ; overlay host (implicit noemit)

scope::label              ; cross-scope
::rootlabel               ; from root
```

---

## Out of scope (for later agent docs)

Not covered here on purpose:

- Remote control protocol beyond “there is an `assemble` command”
- VIC-II / SID / CIA register semantics for RailGunner
- Debugger UI, breakpoints, flight recorder
- Build scripts, PRG headers beyond BASIC stub notes
- Game design (see `railgunner.md`)

When those docs are added, keep **this file** as the single syntax authority for assembly source.
