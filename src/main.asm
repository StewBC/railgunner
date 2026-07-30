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
.segdef "CHARSET", $2800            ; 2K RAM font (futura 0..63 + UDG overlays at install)
.segdef "TITLE", $4000              ; hires source (bitmap + colours)
.segdef "DATA", $6328               ; strings/tables + sprite frame source
.segdef "CODE_HI", $7500            ; overflow game logic (after DATA + sprite frames)
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
    lda #PROFILE_MAIN_WAIT
    sta objects::profile_marker
    jsr wait_frame
    jsr sfx::update                 ; SID one-shots — every physical frame
    jsr music::update               ; title loop (skips voices held by SFX)
    lda #PROFILE_MAIN_DRAIN
    sta objects::profile_marker
    jsr objects::drain_irq_events
    lda objects::logic_ticks_pending
    beq main_loop                    ; NTSC: one physical frame in six is render-only
    ; Real-time policy: run exactly one logic tick, then drop any backlog.
    ; Under load the main loop can take >1 frame; IRQ keeps incrementing
    ; logic_ticks_pending. Draining only one per loop without clearing the
    ; rest caused permanent lag (pending grew to hundreds; motion looked like
    ; 25 Hz freezes). Prefer dropping missed ticks over slow-motion catch-up.
    lda #0
    sta objects::logic_ticks_pending
    lda #PROFILE_MAIN_REAP
    sta objects::profile_marker
    jsr objects::reap
    lda #PROFILE_MAIN_INPUT
    sta objects::profile_marker
    jsr input_poll
    lda #PROFILE_MAIN_MODE
    sta objects::profile_marker
    jsr mode_run
    lda #PROFILE_MAIN_BUILD_CHECK
    sta objects::profile_marker
    lda objects::mux_objects_dirty
    beq main_loop
    jsr sprite_mux_build::build
    bcs mux_build_failed             ; keep prior plan; retry while dirty
    lda #PROFILE_MAIN_PUBLISH
    sta objects::profile_marker
    jsr sprite_mux_build::publish
    bcs mux_build_failed
    lda #0
    sta objects::mux_objects_dirty
    jmp main_loop
mux_build_failed:
    ; PLAN_BUSY is normal while IRQ still holds ready plan — leave dirty set.
    ; Hard errors (deadline/lane) also leave dirty so we rebuild when geometry
    ; is legal again; never clear dirty on failure (that freezes sprites).
    lda #PROFILE_MAIN_BUILD_FAIL
    sta objects::profile_marker
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
.include "game/game_init.asm"
.include "game/score.asm"
.include "game/tallies.asm"
.include "game/hud.asm"
.include "game/objects.asm"
.include "sprite/mux_build.asm"
.include "sprite/mux_irq.asm"
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
; CODE_HI residents (each file sets .segment "CODE_HI")
.include "sys/sound.asm"
.include "sys/music.asm"
.include "frontend/hiscore.asm"

; ---------------------------------------------------------------------------
; Character set (VIC text font @ $2800 — load in place, no ROM copy)
; ---------------------------------------------------------------------------
.segment "CHARSET"
.include "data/charset_font.asm"

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
; charset_bullets / charset_bars retired — baked into CHARSET atlas
.include "data/waves.asm"
