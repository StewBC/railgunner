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
.segdef "CODE", $080d               ; low code — keep below CHARSET $2800
.segdef "TITLE", $4000              ; hires source (bitmap + colours)
.segdef "DATA", $6328               ; strings/tables + sprite frame source
.segdef "CODE_HI", $7000            ; overflow game logic (rail, future bulk)
.segdef "OBJECTS", $C000, noemit

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
    jsr wait_frame
    jsr objects::drain_irq_events
    lda objects::logic_ticks_pending
    beq main_loop                    ; NTSC: one physical frame in six is render-only
    dec objects::logic_ticks_pending
    jsr objects::reap
    jsr input_poll
    jsr mode_run
    lda objects::mux_objects_dirty
    beq main_loop
    jsr sprite_mux_build::build
    bcs mux_build_failed             ; keep prior plan; retry while dirty
    jsr sprite_mux_build::publish
    bcs mux_build_failed
    lda #0
    sta objects::mux_objects_dirty
    jmp main_loop
mux_build_failed:
    ; PLAN_BUSY is normal while IRQ still holds ready plan — leave dirty set.
    ; Hard errors (deadline/lane) also leave dirty so we rebuild when geometry
    ; is legal again; never clear dirty on failure (that freezes sprites).
    jmp main_loop

.include "boot/init.asm"
.include "sys/video.asm"
.include "sys/sprite_install.asm"   ; game-only (spr_frames_src); not for tst/
.include "sys/irq.asm"
.include "sys/input.asm"
.include "render/screen.asm"
.include "render/charset.asm"
.include "render/bullets.asm"
.include "frontend/mode.asm"
.include "frontend/title.asm"
.include "frontend/typewriter.asm"
.include "frontend/story.asm"
.include "frontend/instructions.asm"
.include "frontend/gameover.asm"
.include "frontend/hiscore.asm"
.include "game/game_init.asm"
.include "game/score.asm"
.include "game/hud.asm"
.include "game/rail.asm"
.include "game/player.asm"
.include "game/drones.asm"
.include "game/parcels.asm"
.include "game/cargo.asm"
.include "game/waves.asm"
.include "game/collision.asm"
.include "game/stage.asm"
.include "game/message.asm"
.include "game/play.asm"
.include "game/life.asm"
.include "game/objects.asm"
.include "sprite/mux_build.asm"
.include "sprite/mux_irq.asm"

; ---------------------------------------------------------------------------
; Title graphics (source arrays; copied to $2000 / $0400 at runtime)
; ---------------------------------------------------------------------------
.segment "TITLE"
.include "data/title_gfx.asm"

; ---------------------------------------------------------------------------
; Data (strings + sprite frame SOURCE — installed into $3000 for VIC)
; ---------------------------------------------------------------------------
.segment "DATA"
.include "data/strings.asm"
.include "data/sprites.asm"
.include "data/charset_bullets.asm"
.include "data/charset_bars.asm"
.include "data/waves.asm"
