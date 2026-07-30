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
; Junction: G/H/I/J (and elbow B on the H edges) have no damage glyphs
; (UDGs are a–f only). H-outer D/F never stamps cols 18–20; V damage never
; stamps rows 12–14 (those cells are the H-rail). E core still takes damage
; through the centre.
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
; G/H/I/J cargo stacks (0=G,1=H,2=I,3=J)
ghij_stack: .res 4
; Repair (7b): tiles marked during repair_timer; heal 1 step when timer ends
heal_mark_d:  .res SCREEN_W
heal_mark_e:  .res SCREEN_W
heal_mark_f:  .res SCREEN_W
heal_mark_va: .res SCREEN_H
heal_mark_vb: .res SCREEN_H
heal_mark_vc: .res SCREEN_H
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
    sta rail_data::heal_mark_d, x
    sta rail_data::heal_mark_e, x
    sta rail_data::heal_mark_f, x
    inx
    cpx #SCREEN_W
    bne clr_h
    ldx #0
    txa
clr_v:
    sta rail_data::dmg_va, x
    sta rail_data::dmg_vb, x
    sta rail_data::dmg_vc, x
    sta rail_data::heal_mark_va, x
    sta rail_data::heal_mark_vb, x
    sta rail_data::heal_mark_vc, x
    inx
    cpx #SCREEN_H
    bne clr_v
    rts
.endproc

; Zero heal marks only (no damage change). Used on death / new game.
.proc clear_heal_marks
    ldx #0
    txa
chm_h:
    sta rail_data::heal_mark_d, x
    sta rail_data::heal_mark_e, x
    sta rail_data::heal_mark_f, x
    inx
    cpx #SCREEN_W
    bne chm_h
    ldx #0
    txa
chm_v:
    sta rail_data::heal_mark_va, x
    sta rail_data::heal_mark_vb, x
    sta rail_data::heal_mark_vc, x
    inx
    cpx #SCREEN_H
    bne chm_v
    rts
.endproc

; Start mark window after repair parcel pickup.
.proc begin_repair
    jsr clear_heal_marks
    lda #REPAIR_MARK_FRAMES
    sta repair_timer
    rts
.endproc

; Per-frame while alive: mark player tiles; on timer expiry heal 1 step.
.proc repair_tick
    lda repair_timer
    beq rt_done
    jsr mark_player_tiles
    dec repair_timer
    bne rt_done
    jsr apply_heal_marks
rt_done:
    rts
.endproc

; Mark D/E/F at player col (H) or A/B/C at player row (V); paint lt-gray.
.proc mark_player_tiles
    lda player_rail
    cmp #PLAYER_RAIL_V
    beq mpt_v
    ; H-rail: column from player body centre
    ldx #0
    lda objects::obj_x_lo, x
    clc
    adc #12
    sta tmp0
    lda objects::obj_x_hi, x
    adc #0
    sta tmp1
    jsr player::px_to_col
    tax
    cpx #SCREEN_W
    bcs mpt_done
    lda #1
    sta rail_data::heal_mark_d, x
    sta rail_data::heal_mark_e, x
    sta rail_data::heal_mark_f, x
    stx draw_i
    jsr paint_mark_h
    rts
mpt_v:
    ldx #0
    lda objects::obj_y_int, x
    clc
    adc #10
    sec
    sbc #50
    lsr a
    lsr a
    lsr a
    tax
    cpx #SCREEN_H
    bcs mpt_done
    lda #1
    sta rail_data::heal_mark_va, x
    sta rail_data::heal_mark_vb, x
    sta rail_data::heal_mark_vc, x
    stx draw_i
    jsr paint_mark_v
mpt_done:
    rts
.endproc

.proc paint_mark_h
    ldx draw_i
    ldy #RAIL_ROW_TOP
    lda #COL_RAIL_HEAL_MARK
    jsr screen_color_xy
    ldx draw_i
    ldy #RAIL_ROW_MID
    lda #COL_RAIL_HEAL_MARK
    jsr screen_color_xy
    ldx draw_i
    ldy #RAIL_ROW_BOT
    lda #COL_RAIL_HEAL_MARK
    jmp screen_color_xy
.endproc

.proc paint_mark_v
    ldy draw_i
    ldx #RAIL_COL_LEFT
    lda #COL_RAIL_HEAL_MARK
    jsr screen_color_xy
    ldy draw_i
    ldx #RAIL_COL_MID
    lda #COL_RAIL_HEAL_MARK
    jsr screen_color_xy
    ldy draw_i
    ldx #RAIL_COL_RIGHT
    lda #COL_RAIL_HEAL_MARK
    jmp screen_color_xy
.endproc

; Walk every marked tile back one damage step (0 stays 0); clear marks.
; Always restore COL_RAIL colour — draw_* may skip GHIJ/junction geometry,
; so colour must not stay stuck on COL_RAIL_HEAL_MARK.
.proc apply_heal_marks
    ldx #0
ahm_h:
    stx draw_i
    lda rail_data::heal_mark_d, x
    beq ahm_he
    lda rail_data::dmg_d, x
    beq ahm_hd0
    dec rail_data::dmg_d, x
ahm_hd0:
    jsr draw_d
    ldx draw_i
    ldy #RAIL_ROW_TOP
    lda #COL_RAIL
    jsr screen_color_xy
    ldx draw_i
    lda #0
    sta rail_data::heal_mark_d, x
ahm_he:
    lda rail_data::heal_mark_e, x
    beq ahm_hf
    lda rail_data::dmg_e, x
    beq ahm_he0
    dec rail_data::dmg_e, x
ahm_he0:
    jsr draw_e
    ldx draw_i
    ldy #RAIL_ROW_MID
    lda #COL_RAIL
    jsr screen_color_xy
    ldx draw_i
    lda #0
    sta rail_data::heal_mark_e, x
ahm_hf:
    lda rail_data::heal_mark_f, x
    beq ahm_hn
    lda rail_data::dmg_f, x
    beq ahm_hf0
    dec rail_data::dmg_f, x
ahm_hf0:
    jsr draw_f
    ldx draw_i
    ldy #RAIL_ROW_BOT
    lda #COL_RAIL
    jsr screen_color_xy
    ldx draw_i
    lda #0
    sta rail_data::heal_mark_f, x
ahm_hn:
    inx
    cpx #SCREEN_W
    bne ahm_h

    ldx #0
ahm_v:
    stx draw_i
    lda rail_data::heal_mark_va, x
    beq ahm_vb
    lda rail_data::dmg_va, x
    beq ahm_va0
    dec rail_data::dmg_va, x
ahm_va0:
    jsr draw_va
    ldx #RAIL_COL_LEFT
    ldy draw_i
    lda #COL_RAIL
    jsr screen_color_xy
    ldx draw_i
    lda #0
    sta rail_data::heal_mark_va, x
ahm_vb:
    lda rail_data::heal_mark_vb, x
    beq ahm_vc
    lda rail_data::dmg_vb, x
    beq ahm_vb0
    dec rail_data::dmg_vb, x
ahm_vb0:
    jsr draw_vb
    ldx #RAIL_COL_MID
    ldy draw_i
    lda #COL_RAIL
    jsr screen_color_xy
    ldx draw_i
    lda #0
    sta rail_data::heal_mark_vb, x
ahm_vc:
    lda rail_data::heal_mark_vc, x
    beq ahm_vn
    lda rail_data::dmg_vc, x
    beq ahm_vc0
    dec rail_data::dmg_vc, x
ahm_vc0:
    jsr draw_vc
    ldx #RAIL_COL_RIGHT
    ldy draw_i
    lda #COL_RAIL
    jsr screen_color_xy
    ldx draw_i
    lda #0
    sta rail_data::heal_mark_vc, x
ahm_vn:
    inx
    cpx #SCREEN_H
    bne ahm_v
    ; Hubs may have been mark-tinted; redraw GHIJ so mine/hub glyphs keep COL_RAIL
    jsr cargo::paint_ghij
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
; Geometry gates (draw_i = col for H, row for V)
; C set = in restricted band
; ---------------------------------------------------------------------------
.proc col_is_junction
    lda draw_i
    cmp #RAIL_COL_LEFT
    bcc cij_no
    cmp #RAIL_COL_RIGHT + 1
    bcs cij_no
    sec                             ; cols 18..20
    rts
cij_no:
    clc
    rts
.endproc

.proc row_is_hrail
    lda draw_i
    cmp #RAIL_ROW_TOP
    bcc rih_no
    cmp #RAIL_ROW_BOT + 1
    bcs rih_no
    sec                             ; rows 12..14
    rts
rih_no:
    clc
    rts
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
    ; Junction top edge is G/B/H — no D decay; pass strike into E core
    jsr col_is_junction
    bcs dft_e_only
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
    ; Junction bottom edge is I/B/J — no F decay; pass strike into E core
    jsr col_is_junction
    bcs dfb_e_only
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
    ; Full core collapse → death sequence then game over (not instant mode_set)
    lda player_dead
    bne deh_rts
    jsr player::begin_death_fatal
deh_rts:
    rts
.endproc

; ---------------------------------------------------------------------------
; V-rail row damage (draw_i = row, draw_j = approach LEFT/RIGHT)
; ---------------------------------------------------------------------------
.proc damage_row
    ; H-rail band is D/E/F + G/H/I/J elbows — not V A/B/C cells
    jsr row_is_hrail
    bcs dr_skip
    lda draw_j
    cmp #DRONE_APPROACH_LEFT
    beq dmg_from_right
    jmp dmg_from_left
dr_skip:
    rts
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
    lda player_dead
    bne dbv_rts
    jsr player::begin_death_fatal
dbv_rts:
    rts
.endproc

; ---------------------------------------------------------------------------
; Draw helpers — draw_i = col (H) or row (V)
; Never stamp over G/H/I/J (or H-band cells that are not V A/B/C).
; ---------------------------------------------------------------------------
; Glyph by damage only; colour always COL_RAIL (cracked art carries the look).
.proc draw_d
    jsr col_is_junction
    bcs dd_skip
    ldx draw_i
    lda rail_data::dmg_d, x
    tay
    lda d_glyph, y
    ldy #RAIL_ROW_TOP
    ldx draw_i
    jsr screen_put_xy
    ldx draw_i
    ldy #RAIL_ROW_TOP
    lda #COL_RAIL
    jmp screen_color_xy
dd_skip:
    rts
.endproc

.proc draw_e
    ; Centre cell is B∩E cross — never damaged, always SC_RAIL_X
    ldx draw_i
    cpx #RAIL_COL_MID
    beq de_cross
    lda rail_data::dmg_e, x
    tay
    lda e_glyph, y
    ldy #RAIL_ROW_MID
    ldx draw_i
    jsr screen_put_xy
    ldx draw_i
    ldy #RAIL_ROW_MID
    lda #COL_RAIL
    jmp screen_color_xy
de_cross:
    ldy #RAIL_ROW_MID
    lda #SC_RAIL_X
    jsr screen_put_xy
    ldx #RAIL_COL_MID
    ldy #RAIL_ROW_MID
    lda #COL_RAIL
    jmp screen_color_xy
.endproc

.proc draw_f
    jsr col_is_junction
    bcs df_skip
    ldx draw_i
    lda rail_data::dmg_f, x
    tay
    lda f_glyph, y
    ldy #RAIL_ROW_BOT
    ldx draw_i
    jsr screen_put_xy
    ldx draw_i
    ldy #RAIL_ROW_BOT
    lda #COL_RAIL
    jmp screen_color_xy
df_skip:
    rts
.endproc

.proc draw_va
    jsr row_is_hrail
    bcs dva_skip
    ldx draw_i
    lda rail_data::dmg_va, x
    tay
    lda a_glyph, y
    ldy draw_i
    ldx #RAIL_COL_LEFT
    jsr screen_put_xy
    ldx #RAIL_COL_LEFT
    ldy draw_i
    lda #COL_RAIL
    jmp screen_color_xy
dva_skip:
    rts
.endproc

.proc draw_vb
    jsr row_is_hrail
    bcs dvb_skip
    ldx draw_i
    lda rail_data::dmg_vb, x
    tay
    lda b_glyph, y
    ldy draw_i
    ldx #RAIL_COL_MID
    jsr screen_put_xy
    ldx #RAIL_COL_MID
    ldy draw_i
    lda #COL_RAIL
    jmp screen_color_xy
dvb_skip:
    rts
.endproc

.proc draw_vc
    jsr row_is_hrail
    bcs dvc_skip
    ldx draw_i
    lda rail_data::dmg_vc, x
    tay
    lda c_glyph, y
    ldy draw_i
    ldx #RAIL_COL_RIGHT
    jsr screen_put_xy
    ldx #RAIL_COL_RIGHT
    ldy draw_i
    lda #COL_RAIL
    jmp screen_color_xy
dvc_skip:
    rts
.endproc

; dmg level 0..3 → full / dmg / crit / destroyed (space)
d_glyph:
    .byte SC_RAIL_D, SC_RAIL_D_DMG, SC_RAIL_D_CRIT, SC_SPACE
e_glyph:
    .byte SC_RAIL_E, SC_RAIL_E_DMG, SC_RAIL_E_CRIT, SC_SPACE
f_glyph:
    .byte SC_RAIL_F, SC_RAIL_F_DMG, SC_RAIL_F_CRIT, SC_SPACE
a_glyph:
    .byte SC_RAIL_A, SC_RAIL_A_DMG, SC_RAIL_A_CRIT, SC_SPACE
b_glyph:
    .byte SC_RAIL_B, SC_RAIL_B_DMG, SC_RAIL_B_CRIT, SC_SPACE
c_glyph:
    .byte SC_RAIL_C, SC_RAIL_C_DMG, SC_RAIL_C_CRIT, SC_SPACE

.endscope
