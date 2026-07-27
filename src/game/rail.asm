; H-rail damage (downward A/B). Per-cell cumulative:
;   D row (outer): 0 → 1 → 2 → space, then further hits go to E
;   E row (core):  0 → 1 → 2 → space + game over (rail destroyed)
; One strike damages two independent columns (ship wider than 8px).

.segment "OBJECTS"
.scope rail_data
dmg_d:  .res SCREEN_W              ; top edge D  0..3 (3 = space)
dmg_e:  .res SCREEN_W              ; mid solid E 0..3 (3 = space / rail dead)
.endscope

.segment "CODE_HI"
.scope rail

.proc reset
    ldx #0
    txa
clr:
    sta rail_data::dmg_d, x
    sta rail_data::dmg_e, x
    inx
    cpx #SCREEN_W
    bne clr
    rts
.endproc

; X = drone slot → two columns under the body (not geometric centre+1).
; Sprite left + 4px lines up with visible art; +12 was ~1 cell too far right.
.proc apply_ab_hit
    lda objects::obj_x_lo, x
    clc
    adc #4
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

; Advance one column stack: outer D first, then E. draw_i = col.
.proc damage_col
    ldx draw_i
    lda rail_data::dmg_d, x
    cmp #3
    bcs dmg_e_only                  ; D already gone → hit E
    cmp #2
    beq d_finish_outer              ; D at '2' → this hit spaces D and starts E
    ; D at 0 or 1 → step D only
    clc
    adc #1
    sta rail_data::dmg_d, x
    jsr draw_d
    rts

d_finish_outer:
    ; D was at 2: destroy D (space) and apply first step to E if E still 0
    lda #3
    sta rail_data::dmg_d, x
    jsr draw_d
    ldx draw_i
    lda rail_data::dmg_e, x
    bne dmg_e_step                  ; E already damaged — step it this hit too
    lda #1
    sta rail_data::dmg_e, x
    jsr draw_e
    rts

dmg_e_only:
    ldx draw_i
dmg_e_step:
    lda rail_data::dmg_e, x
    cmp #3
    bcs dmg_rts                     ; already dead column
    cmp #2
    beq e_destroy
    clc
    adc #1
    sta rail_data::dmg_e, x
    jsr draw_e
    rts

e_destroy:
    ; E at '2' → space + rail destroyed (defer mode_set to end of play tick)
    lda #3
    sta rail_data::dmg_e, x
    jsr draw_e
    lda #MODE_GAME_OVER
    sta pending_mode
    rts

dmg_rts:
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

; level 0..3
d_glyph:
    .byte SC_RAIL_D, SC_ZERO+1, SC_ZERO+2, SC_SPACE
e_glyph:
    .byte SC_RAIL_E, SC_ZERO+1, SC_ZERO+2, SC_SPACE
dmg_color:
    .byte COL_GRAY, COL_ORANGE, COL_BROWN, COL_DK_GRAY

.endscope
