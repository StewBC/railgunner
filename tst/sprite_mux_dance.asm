; Two seven-sprite ribbons using the production object pool and sprite mux.

DANCE_TOP_BASE_Y    = 96
DANCE_BOTTOM_BASE_Y = 192

.include "sprite_mux_demo_runtime.asm"

.segment "CODE"

.proc demo_draw_labels
    lda #<demo_title
    sta ptr_lo
    lda #>demo_title
    sta ptr_hi
    lda #<(SCREEN_RAM + 1 * SCREEN_W + 1)
    sta print_ptr_lo
    lda #>(SCREEN_RAM + 1 * SCREEN_W + 1)
    sta print_ptr_hi
    jsr demo_print

    lda #<demo_subtitle
    sta ptr_lo
    lda #>demo_subtitle
    sta ptr_hi
    lda #<(SCREEN_RAM + 2 * SCREEN_W + 2)
    sta print_ptr_lo
    lda #>(SCREEN_RAM + 2 * SCREEN_W + 2)
    sta print_ptr_hi
    jsr demo_print
    jsr demo_draw_standard
    jmp demo_draw_error_text
.endproc

; Seven phase-shifted sprites form each ribbon. Individual X offsets follow a
; 32-step sine approximation. The two entire ribbons bob in opposite Y
; directions while remaining inside the mux's proven raster windows.
.proc demo_update
    lda mode_timer
    clc
    adc #1
    and #DEMO_PHASE_MASK
    sta mode_timer
    tay

    lda demo_y_wave, y
    sta tmp1
    clc
    adc #DANCE_TOP_BASE_Y
    sta tmp2                        ; current top-ribbon Y
    lda #DANCE_BOTTOM_BASE_Y
    sec
    sbc tmp1
    sta draw_i                      ; current bottom-ribbon Y

    ldx #0
update_loop:
    lda demo_phase_offset, x
    clc
    adc mode_timer
    and #DEMO_PHASE_MASK
    tay
    lda demo_x_wave, y
    sta tmp0

    ; Add signed X offset to the 9-bit base coordinate.
    clc
    adc demo_base_x_lo, x
    sta objects::obj_x_lo, x
    bit tmp0
    bpl positive_x_offset
    lda #$ff
    bne add_x_high
positive_x_offset:
    lda #0
add_x_high:
    adc demo_base_x_hi, x
    sta objects::obj_x_hi, x

    cpx #7
    bcc update_top_y
    lda draw_i
    bne store_y
update_top_y:
    lda tmp2
store_y:
    sta objects::obj_y_int, x

    inx
    cpx #DEMO_OBJECT_COUNT
    bne update_loop
    rts
.endproc

demo_title:
    .byte "SPRITE MUX: 14 OBJECTS / 8 VIC SPRITES", 0
demo_subtitle:
    .byte "TWO 7-SPRITE RIBBONS REUSE THE LANES", 0

demo_phase_offset:
    .byte 0,4,8,12,16,20,24
    .byte 16,20,24,28,0,4,8

; Signed two's-complement approximations of sin(phase), amplitudes 14 and 4.
demo_x_wave:
    .byte 0,3,5,8,10,12,13,14,14,14,13,12,10,8,5,3
    .byte 0,$fd,$fb,$f8,$f6,$f4,$f3,$f2,$f2,$f2,$f3,$f4,$f6,$f8,$fb,$fd
demo_y_wave:
    .byte 0,1,2,2,3,3,4,4,4,4,4,3,3,2,2,1
    .byte 0,$ff,$fe,$fe,$fd,$fd,$fc,$fc,$fc,$fc,$fc,$fd,$fd,$fe,$fe,$ff
