; Shared standalone runtime for the sprite-mux visual demonstrations.
; The including root supplies demo_draw_labels and demo_update.

.segdef "ZEROPAGE", $02, noemit
.segdef "BASIC", $0801
.segdef "CODE", $080d
.segdef "SPRITES", $3000
.segdef "OBJECTS", $C000, noemit

.segment "BASIC"

    .word basic_next
    .word 10
    .byte $9e
    .byte "2061"
    .byte 0
basic_next:
    .word 0

.segment "ZEROPAGE"
.include "../src/sys/zeropage.asm"

.include "../src/sys/const.asm"
.include "../src/sys/memory.asm"

DEMO_OBJECT_COUNT = 14
DEMO_PHASE_MASK    = 31
DEMO_SPRITE_PTR    = $C0            ; $3000 / 64

.segment "CODE"

start:
    sei
    cld

    lda #VIC_CTRL1_TEXT
    sta VIC_CTRL1
    lda #VIC_CTRL2_HIRES
    sta VIC_CTRL2
    lda #VIC_MEM_TEXT
    sta VIC_MEM
    lda #COL_BLUE
    sta VIC_BORDER
    lda #COL_BLACK
    sta VIC_BG0

    jsr demo_clear_screen
    jsr objects::init
    jsr video::detect_standard
    jsr video::init_sprite_palette
    jsr sprite_mux_irq::init
    jsr demo_draw_labels
    jsr demo_create_objects
    bcs demo_fatal

    ; Publish the initial snapshot before enabling raster interrupts.
    jsr sprite_mux_build::build
    bcs demo_fatal
    jsr sprite_mux_build::publish
    bcs demo_fatal
    lda #0
    sta objects::mux_objects_dirty
    sta score0                       ; sticky demo error flag

    jsr irq_install
    cli

demo_loop:
    jsr wait_frame
    jsr objects::drain_irq_events
    lda objects::logic_ticks_pending
    beq demo_loop                    ; NTSC render-only physical frame
    dec objects::logic_ticks_pending
    lda objects::mux_plan_ready
    bne demo_loop                    ; wait until line 0 consumes prior publish

    jsr demo_update
    jsr objects::mark_dirty
    jsr sprite_mux_build::build
    bcs demo_plan_error
    jsr sprite_mux_build::publish
    bcs demo_plan_error

    lda #0
    sta objects::mux_objects_dirty
    lda score0
    bne demo_loop                    ; keep a prior error visibly latched
    lda #COL_BLUE
    sta VIC_BORDER
    jmp demo_loop

demo_plan_error:
    lda #1
    sta score0
    lda #COL_RED
    sta VIC_BORDER
    jmp demo_loop                    ; retain the previous immutable plan

demo_fatal:
    lda #1
    sta score0
    lda #COL_RED
    sta VIC_BORDER
:
    jmp :-

; ---------------------------------------------------------------------------
; Minimal text presentation
; ---------------------------------------------------------------------------

.proc demo_clear_screen
    lda #SC_SPACE
    ldx #0
clear_screen_pages:
    sta SCREEN_RAM + $000, x
    sta SCREEN_RAM + $100, x
    sta SCREEN_RAM + $200, x
    inx
    bne clear_screen_pages
    ldx #(SCREEN_SIZE - 768)
clear_screen_tail:
    sta SCREEN_RAM + $300 - 1, x
    dex
    bne clear_screen_tail

    lda #COL_LT_GRAY
    ldx #0
clear_color_pages:
    sta COLOR_RAM + $000, x
    sta COLOR_RAM + $100, x
    sta COLOR_RAM + $200, x
    inx
    bne clear_color_pages
    ldx #(SCREEN_SIZE - 768)
clear_color_tail:
    sta COLOR_RAM + $300 - 1, x
    dex
    bne clear_color_tail
    rts
.endproc

; ptr=zero-terminated ASCII source, print_ptr=screen destination.
.proc demo_print
    ldy #0
print_loop:
    lda (ptr_lo), y
    beq print_done
    cmp #'A'
    bcc store_character
    cmp #'Z' + 1
    bcs store_character
    sec
    sbc #('A' - 1)                  ; ASCII A -> screen code 1
store_character:
    sta (print_ptr_lo), y
    iny
    bne print_loop
print_done:
    rts
.endproc

; Print PAL/NTSC label at screen row 3, column 15.
.proc demo_draw_standard
    lda objects::video_standard
    beq draw_pal
    lda #<demo_ntsc
    sta ptr_lo
    lda #>demo_ntsc
    sta ptr_hi
    jmp draw_standard
draw_pal:
    lda #<demo_pal
    sta ptr_lo
    lda #>demo_pal
    sta ptr_hi
draw_standard:
    lda #<(SCREEN_RAM + 3 * SCREEN_W + 15)
    sta print_ptr_lo
    lda #>(SCREEN_RAM + 3 * SCREEN_W + 15)
    sta print_ptr_hi
    jmp demo_print
.endproc

.proc demo_draw_error_text
    lda #<demo_error_text
    sta ptr_lo
    lda #>demo_error_text
    sta ptr_hi
    lda #<(SCREEN_RAM + 24 * SCREEN_W + 8)
    sta print_ptr_lo
    lda #>(SCREEN_RAM + 24 * SCREEN_W + 8)
    sta print_ptr_hi
    jmp demo_print
.endproc

; Allocate slots 1-13; slot 0 is the pool's permanent player slot but is used
; as an ordinary neutral demo object here.
.proc demo_create_objects
    ldx #0
create_loop:
    cpx #0
    beq have_slot
    jsr objects::alloc
    bcs create_fail
have_slot:
    lda #(OBJF_ALLOCATED | OBJF_RENDER)
    sta objects::obj_flags, x
    lda #OBJ_EFFECT                  ; neutral: no A/B/C ordering constraint
    sta objects::obj_kind, x
    lda #0
    sta objects::obj_x_frac, x
    sta objects::obj_y_frac, x
    sta objects::obj_sprite_attr, x ; hires, normal size, in front of chars
    lda #DEMO_SPRITE_PTR
    sta objects::obj_sprite_ptr, x
    lda demo_colors, x
    sta objects::obj_sprite_color, x
    lda demo_base_x_lo, x
    sta objects::obj_x_lo, x
    lda demo_base_x_hi, x
    sta objects::obj_x_hi, x
    inx
    cpx #DEMO_OBJECT_COUNT
    bne create_loop

    lda #0
    sta mode_timer                  ; shared animation phase
    jsr demo_update                 ; establish initial X/Y positions
    jsr objects::mark_dirty
    clc
    rts
create_fail:
    sec
    rts
.endproc

demo_pal:
    .byte "PAL / 50 HZ", 0
demo_ntsc:
    .byte "NTSC / 50 HZ", 0
demo_error_text:
    .byte "RED BORDER = PLAN ERROR", 0

; Seven evenly spaced X bases, repeated for the second group.
demo_base_x_lo:
    .byte 44,88,132,176,220,8,52
    .byte 44,88,132,176,220,8,52
demo_base_x_hi:
    .byte 0,0,0,0,0,1,1
    .byte 0,0,0,0,0,1,1

demo_colors:
    .byte COL_WHITE,COL_RED,COL_CYAN,COL_PURPLE,COL_GREEN,COL_BLUE,COL_YELLOW
    .byte COL_ORANGE,COL_BROWN,COL_LT_RED,COL_DK_GRAY,COL_GRAY,COL_LT_GREEN,COL_LT_BLUE

; ---------------------------------------------------------------------------
; Production support modules under test
; ---------------------------------------------------------------------------

.include "../src/sys/video.asm"
.include "../src/sys/irq.asm"
.include "../src/game/objects.asm"
.include "../src/sprite/mux_build.asm"
.include "../src/sprite/mux_irq.asm"

; ---------------------------------------------------------------------------
; One self-contained visible sprite frame
; ---------------------------------------------------------------------------

.segment "SPRITES"
.align 64
dance_sprite:
    .byte $00,$18,$00
    .byte $00,$3c,$00
    .byte $00,$7e,$00
    .byte $00,$ff,$00
    .byte $01,$ff,$80
    .byte $03,$e7,$c0
    .byte $07,$c3,$e0
    .byte $0f,$81,$f0
    .byte $1f,$00,$f8
    .byte $3e,$00,$7c
    .byte $7c,$00,$3e
    .byte $3e,$00,$7c
    .byte $1f,$00,$f8
    .byte $0f,$81,$f0
    .byte $07,$c3,$e0
    .byte $03,$e7,$c0
    .byte $01,$ff,$80
    .byte $00,$ff,$00
    .byte $00,$7e,$00
    .byte $00,$3c,$00
    .byte $00,$18,$00
    .byte $00                         ; VIC sprite pad byte
