; Regression for coop snap-001: five objects fit in eight VIC-II sprites.
; The former low-lane packing + linear scheduler manufactured a deadline
; failure for this layout. Blue border means the plan remains valid.

.include "sprite_mux_demo_runtime.asm"

.segment "CODE"

DEADLINE_RENDER_COUNT = 5

.proc demo_draw_labels
    lda #<deadline_title
    sta ptr_lo
    lda #>deadline_title
    sta ptr_hi
    lda #<(SCREEN_RAM + 1 * SCREEN_W + 1)
    sta print_ptr_lo
    lda #>(SCREEN_RAM + 1 * SCREEN_W + 1)
    sta print_ptr_hi
    jsr demo_print

    lda #<deadline_subtitle
    sta ptr_lo
    lda #>deadline_subtitle
    sta ptr_hi
    lda #<(SCREEN_RAM + 2 * SCREEN_W + 1)
    sta print_ptr_lo
    lda #>(SCREEN_RAM + 2 * SCREEN_W + 1)
    sta print_ptr_hi
    jsr demo_print
    jsr demo_draw_standard
    jmp demo_draw_error_text
.endproc

; Captured Y order: B $47, B $54, C $67, C $68, player $92.
; Object-slot order is immaterial; these kinds/positions reproduce the planner
; windows that failed after the second C spawned.
.proc demo_update
    ldx #0
deadline_object_loop:
    lda deadline_kind, x
    sta objects::obj_kind, x
    lda deadline_y, x
    sta objects::obj_y_int, x
    lda deadline_x_lo, x
    sta objects::obj_x_lo, x
    lda deadline_x_hi, x
    sta objects::obj_x_hi, x
    lda #0
    sta objects::obj_sprite_attr, x
    lda #(OBJF_ALLOCATED | OBJF_RENDER)
    sta objects::obj_flags, x
    inx
    cpx #DEADLINE_RENDER_COUNT
    bne deadline_object_loop

; The shared runtime allocates 14 objects for its larger demos. Keep the other
; nine allocated but render-disabled so this fixture presents exactly five
; candidates to the production builder.
deadline_hide_loop:
    lda #OBJF_ALLOCATED
    sta objects::obj_flags, x
    inx
    cpx #DEMO_OBJECT_COUNT
    bne deadline_hide_loop
    rts
.endproc

deadline_title:
    .byte "MUX DEADLINE REGRESSION: 5 OF 8", 0
deadline_subtitle:
    .byte "BLUE = UNIQUE LANES / VALID PLAN", 0

deadline_kind:
    .byte OBJ_DRONE_B,OBJ_DRONE_B,OBJ_DRONE_C,OBJ_DRONE_C,OBJ_PLAYER
deadline_y:
    .byte $47,$54,$67,$68,$92
deadline_x_lo:
    .byte 60,110,160,210,4
deadline_x_hi:
    .byte 0,0,0,0,1
