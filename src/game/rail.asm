; Rail damage (A/B). Approach-aware:
;
;   H-rail (DOWN/UP):
;     From top:    D (outer) → E (core)   per column
;     From bottom: F (outer) → E (core)   per column
;   V-rail (RIGHT/LEFT — drone flies sideways into the shaft):
;     From left:   A (outer) → B (core)   per row
;     From right:  C (outer) → B (core)   per row
;
; Core destroyed (E column or B row) → game over.
; Strike footprint: 2 columns (H) or 2 rows (V) under the drone body.
;
; screen_put_xy clobbers tmp0–tmp2 — keep approach in draw_j for the strike.

.segment "OBJECTS"
.scope rail_data
; H-rail: index = column 0..39
dmg_d:  .res SCREEN_W              ; top edge D
dmg_e:  .res SCREEN_W              ; mid solid E (core)
dmg_f:  .res SCREEN_W              ; bottom edge F
; V-rail: index = row 0..24
dmg_va: .res SCREEN_H              ; left outer A  (col RAIL_COL_LEFT)
dmg_vb: .res SCREEN_H              ; mid core B   (col RAIL_COL_MID)
dmg_vc: .res SCREEN_H              ; right outer C (col RAIL_COL_RIGHT)
.endscope

.segment "CODE_HI"
.scope rail

.proc reset
    ldx #0
    txa
clr_h:
    sta rail_data::dmg_d, x
    sta rail_data::dmg_e, x
    sta rail_data::dmg_f, x
    inx
    cpx #SCREEN_W
    bne clr_h
    ldx #0
    txa
clr_v:
    sta rail_data::dmg_va, x
    sta rail_data::dmg_vb, x
    sta rail_data::dmg_vc, x
    inx
    cpx #SCREEN_H
    bne clr_v
    rts
.endproc

; Re-stamp damage after playfield redraw (next level).
.proc redraw_from_state
    ldx #0
rfs_h:
    stx draw_i
    lda rail_data::dmg_d, x
    beq rfs_he
    jsr draw_d
    ldx draw_i
rfs_he:
    lda rail_data::dmg_e, x
    beq rfs_hf
    jsr draw_e
    ldx draw_i
rfs_hf:
    lda rail_data::dmg_f, x
    beq rfs_hn
    jsr draw_f
    ldx draw_i
rfs_hn:
    inx
    cpx #SCREEN_W
    bne rfs_h

    ldx #0
rfs_v:
    stx draw_i                      ; row
    lda rail_data::dmg_va, x
    beq rfs_vb
    jsr draw_va
    ldx draw_i
rfs_vb:
    lda rail_data::dmg_vb, x
    beq rfs_vc
    jsr draw_vb
    ldx draw_i
rfs_vc:
    lda rail_data::dmg_vc, x
    beq rfs_vn
    jsr draw_vc
    ldx draw_i
rfs_vn:
    inx
    cpx #SCREEN_H
    bne rfs_v
    rts
.endproc

; X = drone slot
.proc apply_ab_hit
    lda objects::obj_user, x
    sta draw_j                      ; approach
    cmp #DRONE_APPROACH_RIGHT
    beq apply_v
    cmp #DRONE_APPROACH_LEFT
    beq apply_v
    jmp apply_h

; ----- V-rail: 2 rows under body, outer col then core B -----
apply_v:
    lda objects::obj_y_int, x
    clc
    adc #DRONE_IMPACT_Y_OFF
    sec
    sbc #50
    bcc av0
    lsr a
    lsr a
    lsr a
    jmp av_row
av0:
    lda #0
av_row:
    cmp #SCREEN_H
    bcc av_ok
    lda #SCREEN_H - 1
av_ok:
    sta draw_i                      ; row0
    jsr damage_row
    lda draw_i
    clc
    adc #1
    cmp #SCREEN_H
    bcs av_done
    sta draw_i
    jsr damage_row
av_done:
    rts

; ----- H-rail: 2 cols under body, outer row then core E -----
apply_h:
    lda objects::obj_x_lo, x
    clc
    adc #DRONE_IMPACT_X_OFF
    sta tmp0
    lda objects::obj_x_hi, x
    adc #0
    sta tmp1
    lda tmp0
    sec
    sbc #24
    sta tmp0
    lda tmp1
    sbc #0
    bcc ah0
    lsr a
    ror tmp0
    lsr a
    ror tmp0
    lsr a
    ror tmp0
    lda tmp0
    cmp #40
    bcc ah_ok
    lda #39
ah_ok:
    sta draw_i
    jsr damage_col
    lda draw_i
    clc
    adc #1
    cmp #40
    bcs ah_done
    sta draw_i
    jsr damage_col
ah_done:
    rts
ah0:
    lda #0
    sta draw_i
    jsr damage_col
    lda #1
    sta draw_i
    jmp damage_col
.endproc

; ---------------------------------------------------------------------------
; H-rail column damage (draw_i = col, draw_j = approach UP/DOWN)
; ---------------------------------------------------------------------------
.proc damage_col
    lda draw_j
    cmp #DRONE_APPROACH_UP
    beq dmg_from_bot
    jmp dmg_from_top
.endproc

.proc dmg_from_top
    ldx draw_i
    lda rail_data::dmg_d, x
    cmp #3
    bcs dft_e_only
    cmp #2
    beq dft_d_finish
    clc
    adc #1
    sta rail_data::dmg_d, x
    jsr draw_d
    rts
dft_d_finish:
    lda #3
    sta rail_data::dmg_d, x
    jsr draw_d
    ldx draw_i
    lda rail_data::dmg_e, x
    bne dft_e_step
    lda #1
    sta rail_data::dmg_e, x
    jsr draw_e
    rts
dft_e_only:
    ldx draw_i
dft_e_step:
    jmp damage_e_h
.endproc

.proc dmg_from_bot
    ldx draw_i
    lda rail_data::dmg_f, x
    cmp #3
    bcs dfb_e_only
    cmp #2
    beq dfb_f_finish
    clc
    adc #1
    sta rail_data::dmg_f, x
    jsr draw_f
    rts
dfb_f_finish:
    lda #3
    sta rail_data::dmg_f, x
    jsr draw_f
    ldx draw_i
    lda rail_data::dmg_e, x
    bne dfb_e_step
    lda #1
    sta rail_data::dmg_e, x
    jsr draw_e
    rts
dfb_e_only:
    ldx draw_i
dfb_e_step:
    jmp damage_e_h
.endproc

.proc damage_e_h
    lda rail_data::dmg_e, x
    cmp #3
    bcs deh_rts
    cmp #2
    beq deh_destroy
    clc
    adc #1
    sta rail_data::dmg_e, x
    jsr draw_e
    rts
deh_destroy:
    lda #3
    sta rail_data::dmg_e, x
    jsr draw_e
    lda #MODE_GAME_OVER
    sta pending_mode
deh_rts:
    rts
.endproc

; ---------------------------------------------------------------------------
; V-rail row damage (draw_i = row, draw_j = approach LEFT/RIGHT)
; ---------------------------------------------------------------------------
.proc damage_row
    lda draw_j
    cmp #DRONE_APPROACH_LEFT
    beq dmg_from_right
    jmp dmg_from_left
.endproc

; From left (approach RIGHT): A outer → B core
.proc dmg_from_left
    ldx draw_i
    lda rail_data::dmg_va, x
    cmp #3
    bcs dfl_b_only
    cmp #2
    beq dfl_a_finish
    clc
    adc #1
    sta rail_data::dmg_va, x
    jsr draw_va
    rts
dfl_a_finish:
    lda #3
    sta rail_data::dmg_va, x
    jsr draw_va
    ldx draw_i
    lda rail_data::dmg_vb, x
    bne dfl_b_step
    lda #1
    sta rail_data::dmg_vb, x
    jsr draw_vb
    rts
dfl_b_only:
    ldx draw_i
dfl_b_step:
    jmp damage_b_v
.endproc

; From right (approach LEFT): C outer → B core
.proc dmg_from_right
    ldx draw_i
    lda rail_data::dmg_vc, x
    cmp #3
    bcs dfr_b_only
    cmp #2
    beq dfr_c_finish
    clc
    adc #1
    sta rail_data::dmg_vc, x
    jsr draw_vc
    rts
dfr_c_finish:
    lda #3
    sta rail_data::dmg_vc, x
    jsr draw_vc
    ldx draw_i
    lda rail_data::dmg_vb, x
    bne dfr_b_step
    lda #1
    sta rail_data::dmg_vb, x
    jsr draw_vb
    rts
dfr_b_only:
    ldx draw_i
dfr_b_step:
    jmp damage_b_v
.endproc

.proc damage_b_v
    lda rail_data::dmg_vb, x
    cmp #3
    bcs dbv_rts
    cmp #2
    beq dbv_destroy
    clc
    adc #1
    sta rail_data::dmg_vb, x
    jsr draw_vb
    rts
dbv_destroy:
    lda #3
    sta rail_data::dmg_vb, x
    jsr draw_vb
    lda #MODE_GAME_OVER
    sta pending_mode
dbv_rts:
    rts
.endproc

; ---------------------------------------------------------------------------
; Draw helpers — draw_i = col (H) or row (V)
; ---------------------------------------------------------------------------
.proc draw_d
    ldx draw_i
    lda rail_data::dmg_d, x
    tay
    lda d_glyph, y
    sta tmp0
    ldy #RAIL_ROW_TOP
    ldx draw_i
    lda tmp0
    jsr screen_put_xy
    ldx draw_i
    lda rail_data::dmg_d, x
    tay
    lda dmg_color, y
    ldx draw_i
    ldy #RAIL_ROW_TOP
    jmp screen_color_xy
.endproc

.proc draw_e
    ldx draw_i
    lda rail_data::dmg_e, x
    tay
    lda e_glyph, y
    sta tmp0
    ldy #RAIL_ROW_MID
    ldx draw_i
    lda tmp0
    jsr screen_put_xy
    ldx draw_i
    lda rail_data::dmg_e, x
    tay
    lda dmg_color, y
    ldx draw_i
    ldy #RAIL_ROW_MID
    jmp screen_color_xy
.endproc

.proc draw_f
    ldx draw_i
    lda rail_data::dmg_f, x
    tay
    lda f_glyph, y
    sta tmp0
    ldy #RAIL_ROW_BOT
    ldx draw_i
    lda tmp0
    jsr screen_put_xy
    ldx draw_i
    lda rail_data::dmg_f, x
    tay
    lda dmg_color, y
    ldx draw_i
    ldy #RAIL_ROW_BOT
    jmp screen_color_xy
.endproc

.proc draw_va
    ldx draw_i
    lda rail_data::dmg_va, x
    tay
    lda a_glyph, y
    sta tmp0
    ldy draw_i                      ; row
    ldx #RAIL_COL_LEFT
    lda tmp0
    jsr screen_put_xy
    ldx draw_i
    lda rail_data::dmg_va, x
    tay
    lda dmg_color, y
    ldx #RAIL_COL_LEFT
    ldy draw_i
    jmp screen_color_xy
.endproc

.proc draw_vb
    ldx draw_i
    lda rail_data::dmg_vb, x
    tay
    lda b_glyph, y
    sta tmp0
    ldy draw_i
    ldx #RAIL_COL_MID
    lda tmp0
    jsr screen_put_xy
    ldx draw_i
    lda rail_data::dmg_vb, x
    tay
    lda dmg_color, y
    ldx #RAIL_COL_MID
    ldy draw_i
    jmp screen_color_xy
.endproc

.proc draw_vc
    ldx draw_i
    lda rail_data::dmg_vc, x
    tay
    lda c_glyph, y
    sta tmp0
    ldy draw_i
    ldx #RAIL_COL_RIGHT
    lda tmp0
    jsr screen_put_xy
    ldx draw_i
    lda rail_data::dmg_vc, x
    tay
    lda dmg_color, y
    ldx #RAIL_COL_RIGHT
    ldy draw_i
    jmp screen_color_xy
.endproc

d_glyph:
    .byte SC_RAIL_D, SC_ZERO+1, SC_ZERO+2, SC_SPACE
e_glyph:
    .byte SC_RAIL_E, SC_ZERO+1, SC_ZERO+2, SC_SPACE
f_glyph:
    .byte SC_RAIL_F, SC_ZERO+1, SC_ZERO+2, SC_SPACE
a_glyph:
    .byte SC_RAIL_A, SC_ZERO+1, SC_ZERO+2, SC_SPACE
b_glyph:
    .byte SC_RAIL_B, SC_ZERO+1, SC_ZERO+2, SC_SPACE
c_glyph:
    .byte SC_RAIL_C, SC_ZERO+1, SC_ZERO+2, SC_SPACE
dmg_color:
    .byte COL_GRAY, COL_ORANGE, COL_BROWN, COL_DK_GRAY

.endscope
