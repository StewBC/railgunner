; Character bullets — UDG stream with sub-cell phases.
;
; Vertical (H-rail aim): 4 phases SC_BULLET_V0..V3
;   DOWN: phase 0→1→2→3 then next row down
;   UP:   phase 3→2→1→0 then next row up
; Hold BULLET_HOLD ticks per phase. Launch cell must be free (structural ROF).
; Fire only when player barrel is at rest and FIRE held.

.scope bullets

bullet_active:  .res BULLET_MAX
bullet_col:     .res BULLET_MAX
bullet_row:     .res BULLET_MAX
bullet_dir:     .res BULLET_MAX     ; SPR_DIR_UP or SPR_DIR_DOWN
bullet_phase:   .res BULLET_MAX     ; 0..3
bullet_hold:    .res BULLET_MAX

; ---------------------------------------------------------------------------
.proc init
    ldx #0
    lda #0
clear:
    sta bullet_active, x
    inx
    cpx #BULLET_MAX
    bne clear
    rts
.endproc

; ---------------------------------------------------------------------------
.proc update
    jsr advance_all
    jsr try_fire
    rts
.endproc

; ---------------------------------------------------------------------------
.proc advance_all
    ldx #0
adv_loop:
    lda bullet_active, x
    beq adv_next
    dec bullet_hold, x
    bne adv_draw
    lda #BULLET_HOLD
    sta bullet_hold, x
    lda bullet_dir, x
    cmp #SPR_DIR_UP
    beq adv_up

    ; DOWN: 0→1→2→3 then row++
    lda bullet_phase, x
    cmp #3
    bcs down_next_cell
    inc bullet_phase, x
    jmp adv_draw
down_next_cell:
    jsr erase_slot
    inc bullet_row, x
    lda bullet_row, x
    cmp #SCREEN_H
    bcs adv_kill
    lda #0
    sta bullet_phase, x
    jmp adv_draw

adv_up:
    ; UP: 3→2→1→0 then row--
    lda bullet_phase, x
    beq up_next_cell
    dec bullet_phase, x
    jmp adv_draw
up_next_cell:
    jsr erase_slot
    lda bullet_row, x
    beq adv_kill
    dec bullet_row, x
    lda #3
    sta bullet_phase, x
    jmp adv_draw

adv_kill:
    lda #0
    sta bullet_active, x
    jmp adv_next

adv_draw:
    jsr draw_slot
adv_next:
    inx
    cpx #BULLET_MAX
    bne adv_loop
    rts
.endproc

; ---------------------------------------------------------------------------
; Erase glyph at slot X. Preserves X.
; ---------------------------------------------------------------------------
.proc erase_slot
    txa
    pha
    lda bullet_col, x
    pha
    ldy bullet_row, x
    pla
    tax
    lda #SC_SPACE
    jsr screen_put_xy
    pla
    tax
    rts
.endproc

; ---------------------------------------------------------------------------
; Draw glyph + colour for slot X. Preserves X.
; ---------------------------------------------------------------------------
.proc draw_slot
    txa
    pha
    lda bullet_phase, x
    clc
    adc #SC_BULLET_V0
    sta tmp0
    lda bullet_col, x
    pha
    ldy bullet_row, x
    pla
    tax
    lda tmp0
    jsr screen_put_xy
    pla
    tax
    txa
    pha
    lda bullet_col, x
    pha
    ldy bullet_row, x
    pla
    tax
    lda #BULLET_COLOR
    jsr screen_color_xy
    pla
    tax
    rts
.endproc

; ---------------------------------------------------------------------------
.proc try_fire
    lda player_swing_t
    bne fire_done
    lda input_fire
    beq fire_done

    lda player_rest_dir
    cmp #SPR_DIR_UP
    beq aim_up
    cmp #SPR_DIR_DOWN
    beq aim_down
    rts

aim_up:
    jsr player_launch_col
    sta draw_i                      ; col
    lda #BULLET_LAUNCH_ROW_UP
    sta draw_j                      ; row
    lda #SPR_DIR_UP
    sta tmp1                        ; dir
    lda #3                          ; start phase (bottom)
    sta tmp2
    jmp fire_common

aim_down:
    jsr player_launch_col
    sta draw_i
    lda #BULLET_LAUNCH_ROW_DOWN
    sta draw_j
    lda #SPR_DIR_DOWN
    sta tmp1
    lda #0                          ; start phase (top)
    sta tmp2

fire_common:
    ; Occupancy: launch cell free?
    ldx #0
occ_loop:
    lda bullet_active, x
    beq occ_next
    lda bullet_col, x
    cmp draw_i
    bne occ_next
    lda bullet_row, x
    cmp draw_j
    beq fire_done
occ_next:
    inx
    cpx #BULLET_MAX
    bne occ_loop

    ldx #0
slot_loop:
    lda bullet_active, x
    beq slot_found
    inx
    cpx #BULLET_MAX
    bne slot_loop
    rts

slot_found:
    lda #1
    sta bullet_active, x
    lda draw_i
    sta bullet_col, x
    lda draw_j
    sta bullet_row, x
    lda tmp1
    sta bullet_dir, x
    lda tmp2
    sta bullet_phase, x
    lda #BULLET_HOLD
    sta bullet_hold, x
    jsr draw_slot
fire_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; A ← column of player sprite centre (0..39)
; ---------------------------------------------------------------------------
.proc player_launch_col
    ldx #0
    lda objects::obj_x_lo, x
    clc
    adc #12
    sta tmp0
    lda objects::obj_x_hi, x
    adc #0
    sta tmp1
    ; x_center - 24
    lda tmp0
    sec
    sbc #24
    sta tmp0
    lda tmp1
    sbc #0
    ; / 8
    lsr a
    ror tmp0
    lsr a
    ror tmp0
    lsr a
    ror tmp0
    lda tmp0
    cmp #40
    bcc col_ok
    lda #39
col_ok:
    rts
.endproc

.endscope
