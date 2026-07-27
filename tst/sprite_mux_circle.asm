; Fourteen logical sprites orbit one ellipse clockwise. Every object moves
; through both screen halves, so the mux must continuously re-sort the pool
; and change hardware-sprite ownership as their Y order changes.

CIRCLE_PHASE_MASK = 63

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

; Advance one sample at the normalized 50 Hz logic rate. Screen Y grows
; downward, so increasing phase from the rightmost point moves clockwise.
.proc demo_update
    lda mode_timer
    clc
    adc #1
    and #CIRCLE_PHASE_MASK
    sta mode_timer

    ldx #0
update_loop:
    lda demo_phase_offset, x
    clc
    adc mode_timer
    and #CIRCLE_PHASE_MASK
    tay

    lda demo_circle_x_lo, y
    sta objects::obj_x_lo, x
    lda demo_circle_x_hi, y
    sta objects::obj_x_hi, x
    lda demo_circle_y, y
    sta objects::obj_y_int, x

    inx
    cpx #DEMO_OBJECT_COUNT
    bne update_loop
    rts
.endproc

demo_title:
    .byte "SPRITE MUX: CLOCKWISE ORBIT", 0
demo_subtitle:
    .byte "14 OBJECTS CROSS AND RESORT EVERY FRAME", 0

; Fourteen approximately even starting positions around a 64-step orbit.
demo_phase_offset:
    .byte 0,5,9,14,18,23,27,32,37,41,46,50,55,59

; A precomputed ellipse centred at (172,145), with radii 118x66. Keeping the
; three 64-byte SoA tables together on one page makes every indexed load
; constant-time and exercises the full 9-bit VIC X range.
.align 256
demo_circle_x_lo:
    .byte 34,33,32,29,25,20,14,7,255,247,238,228,217,206,195,184
    .byte 172,160,149,138,127,116,106,97,89,81,74,68,63,59,56,55
    .byte 54,55,56,59,63,68,74,81,89,97,106,116,127,138,149,160
    .byte 172,184,195,206,217,228,238,247,255,7,14,20,25,29,32,33
demo_circle_x_hi:
    .byte 1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    .byte 0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1
demo_circle_y:
    .byte 145,151,158,164,170,176,182,187,192,196,200,203,206,208,210,211
    .byte 211,211,210,208,206,203,200,196,192,187,182,176,170,164,158,151
    .byte 145,139,132,126,120,114,108,103,98,94,90,87,84,82,80,79
    .byte 79,79,80,82,84,87,90,94,98,103,108,114,120,126,132,139
