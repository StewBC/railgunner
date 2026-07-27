; RailGunner — root assembly unit
; Only this file is passed to c64masm / the c64m Assembler tab.
; Layout:  agents/repo-layout.md
; Roadmap: agents/roadmap.md
; Syntax:  agents/assembler-syntax.md

; ---------------------------------------------------------------------------
; Segments
; ---------------------------------------------------------------------------
.segdef "ZEROPAGE", $02, noemit
.segdef "BASIC", $0801
.segdef "CODE", $080d
.segdef "TITLE", $4000              ; hires source (bitmap + colours)
.segdef "DATA", $6328               ; strings/tables after TITLE ($4000+9000)

; ---------------------------------------------------------------------------
; BASIC stub: 10 SYS 2061  ($080d)
; User: tools/play.sh (offline PRG + --autorun). Agent: tools/agent_session.py
; (live assemble + paste RUN). Never assembler auto-run PC poke into start.
; ---------------------------------------------------------------------------
.segment "BASIC"

    .word basic_next
    .word 10
    .byte $9e
    .byte "2061"
    .byte 0
basic_next:
    .word 0

; ---------------------------------------------------------------------------
; Zero page
; ---------------------------------------------------------------------------
.segment "ZEROPAGE"
.include "sys/zeropage.asm"

; ---------------------------------------------------------------------------
; Constants / memory notes (no emit)
; ---------------------------------------------------------------------------
.include "sys/const.asm"
.include "sys/memory.asm"

; ---------------------------------------------------------------------------
; Code
; ---------------------------------------------------------------------------
.segment "CODE"

start:
    jsr cold_init
main_loop:
    jsr wait_frame                   ; ~1 tick per video frame (timers usable)
    jsr input_poll
    jsr mode_run
    jmp main_loop

.include "boot/init.asm"
.include "sys/irq.asm"
.include "sys/input.asm"
.include "render/screen.asm"
.include "frontend/mode.asm"
.include "frontend/title.asm"
.include "frontend/story.asm"
.include "frontend/instructions.asm"
.include "frontend/gameover.asm"
.include "frontend/hiscore.asm"
.include "game/game_init.asm"
.include "game/stage.asm"
.include "game/play.asm"
.include "game/life.asm"

; ---------------------------------------------------------------------------
; Title graphics (source arrays; copied to $2000 / $0400 at runtime)
; ---------------------------------------------------------------------------
.segment "TITLE"
.include "data/title_gfx.asm"

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
.segment "DATA"
.include "data/strings.asm"
