; H-rail damage (A/B). Per-cell cumulative, approach-aware:
;   From top (DOWN):  D (outer) → E (core)
;   From bottom (UP): F (outer) → E (core)
;   E destroyed → game over (rail destroyed)
; One strike damages two independent columns (ship wider than 8px).

.segment "OBJECTS"
.scope rail_data
dmg_d:  .res SCREEN_W              ; top edge D  0..3 (3 = space)
dmg_e:  .res SCREEN_W              ; mid solid E 0..3 (3 = space / rail dead)
dmg_f:  .res SCREEN_W              ; bottom edge F 0..3
.endscope

.segment "CODE_HI"
.scope rail

.proc reset
    ldx #0
    txa
clr:
    sta rail_data::dmg_d, x
    sta rail_data::dmg_e, x
    sta rail_data::dmg_f, x
    inx
    cpx #SCREEN_W
    bne clr
    rts
.endproc

; X = drone slot → two columns under body; outer edge from approach dir.
.proc apply_ab_hit
    lda objects::obj_user, x
    sta tmp2                        ; approach (DOWN vs UP)
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
    bcc ab0
    lsr a
    ror tmp0
    lsr a
    ror tmp0
    lsr a
    ror tmp0
    lda tmp0
    cmp #40
    bcc ab_ok
    lda #39
ab_ok:
    sta draw_i
    jsr damage_col
    lda draw_i
    clc
    adc #1
    cmp #40
    bcs ab_done
    sta draw_i
    jsr damage_col
ab_done:
    rts
ab0:
    lda #0
    sta draw_i
    jsr damage_col
    lda #1
    sta draw_i
    jmp damage_col
.endproc

; Outer edge from approach in tmp2, then E. draw_i = col.
.proc damage_col
    lda tmp2
    cmp #DRONE_APPROACH_UP
    beq dmg_from_bot
    jmp dmg_from_top
.endproc

; From top: D then E (original path).
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
    jmp damage_e
.endproc

; From bottom: F then E (hit lands on underside of H-rail).
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
    jmp damage_e
.endproc

.proc damage_e
    lda rail_data::dmg_e, x
    cmp #3
    bcs de_rts
    cmp #2
    beq de_destroy
    clc
    adc #1
    sta rail_data::dmg_e, x
    jsr draw_e
    rts
de_destroy:
    lda #3
    sta rail_data::dmg_e, x
    jsr draw_e
    lda #MODE_GAME_OVER
    sta pending_mode
de_rts:
    rts
.endproc

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

d_glyph:
    .byte SC_RAIL_D, SC_ZERO+1, SC_ZERO+2, SC_SPACE
e_glyph:
    .byte SC_RAIL_E, SC_ZERO+1, SC_ZERO+2, SC_SPACE
f_glyph:
    .byte SC_RAIL_F, SC_ZERO+1, SC_ZERO+2, SC_SPACE
dmg_color:
    .byte COL_GRAY, COL_ORANGE, COL_BROWN, COL_DK_GRAY

.endscope
