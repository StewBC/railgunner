; Rail damage (heavy/medium/light = 3/2/1 strike points from remaining HP).
;
;   H-rail (DOWN/UP):  D/F outer → E core per column
;   V-rail (LEFT/RIGHT): A/C outer → B core per row
;
; Per-cell values are damage *taken* (0 = healthy). Outer dies at RAIL_OUTER_HP,
; core at RAIL_CORE_HP (game over). Points spill outer → core in one apply.
; Glyphs mapped from damage (not 1:1 with points). Footprint: 2 cols/rows.
;
; screen_put_xy clobbers tmp0–tmp2 — keep approach in draw_j for the strike.

.segment "OBJECTS"
.scope rail_data
; H-rail: index = column 0..39 — damage taken 0..RAIL_*_HP
dmg_d:  .res SCREEN_W              ; top edge D (outer)
dmg_e:  .res SCREEN_W              ; mid solid E (core)
dmg_f:  .res SCREEN_W              ; bottom edge F (outer)
; V-rail: index = row 0..24
dmg_va: .res SCREEN_H              ; left outer A
dmg_vb: .res SCREEN_H              ; mid core B
dmg_vc: .res SCREEN_H              ; right outer C
; G/H/I/J cargo stacks (0=G,1=H,2=I,3=J)
ghij_stack: .res 4
; Repair (7b): tiles marked during repair_timer; heal 1 point when timer ends
heal_mark_d:  .res SCREEN_W
heal_mark_e:  .res SCREEN_W
heal_mark_f:  .res SCREEN_W
heal_mark_va: .res SCREEN_H
heal_mark_vb: .res SCREEN_H
heal_mark_vc: .res SCREEN_H
; Current impact
dmg_amt:  .res 1                   ; points for this strike (1..3)
hit_left: .res 1                   ; points left while applying one cell
hit_slot: .res 1                   ; slot that already applied rail dmg this tick ($FF=none)
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
    lda #SFX_HEAL
    jsr sfx::play
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

; Clear per-tick rail-hit dedupe (call once at start of play tick).
.proc strike_frame_reset
    lda #$FF
    sta rail_data::hit_slot
    rts
.endproc

; X = drone slot. rail_data::dmg_amt = strike points (1..3) set by caller.
; Applies points to ONE primary cell only (not ×2 footprint). Idempotent per
; slot per tick so geometry + collision cannot double-apply.
.proc apply_ab_hit
    cpx rail_data::hit_slot
    bne aah_go
    rts                             ; already struck this slot this tick
aah_go:
    stx rail_data::hit_slot
    lda objects::obj_user, x
    sta draw_j                      ; approach
    cmp #DRONE_APPROACH_RIGHT
    beq apply_v
    cmp #DRONE_APPROACH_LEFT
    beq apply_v
    jmp apply_h

; ----- V-rail: primary row under body only -----
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
    sta draw_i
    lda rail_data::dmg_amt
    sta rail_data::hit_left
    jmp damage_row

; ----- H-rail: primary column under body only -----
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
    lda rail_data::dmg_amt
    sta rail_data::hit_left
    jmp damage_col
ah0:
    lda #0
    sta draw_i
    lda rail_data::dmg_amt
    sta rail_data::hit_left
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
; Spend hit_left points on one column/row: outer first, spill to core.
; ---------------------------------------------------------------------------
.proc damage_col
    lda draw_j
    cmp #DRONE_APPROACH_UP
    beq dmg_from_bot
    jmp dmg_from_top
.endproc

.proc dmg_from_top
dft_loop:
    lda rail_data::hit_left
    beq dft_done
    dec rail_data::hit_left
    jsr col_is_junction
    bcs dft_core                    ; no D at G/B/H — all points to E
    ldx draw_i
    lda rail_data::dmg_d, x
    cmp #RAIL_OUTER_HP
    bcs dft_core                    ; outer already gone
    clc
    adc #1
    sta rail_data::dmg_d, x
    jsr draw_d
    jmp dft_loop
dft_core:
    ldx draw_i
    jsr damage_e_h_one
    jmp dft_loop
dft_done:
    rts
.endproc

.proc dmg_from_bot
dfb_loop:
    lda rail_data::hit_left
    beq dfb_done
    dec rail_data::hit_left
    jsr col_is_junction
    bcs dfb_core
    ldx draw_i
    lda rail_data::dmg_f, x
    cmp #RAIL_OUTER_HP
    bcs dfb_core
    clc
    adc #1
    sta rail_data::dmg_f, x
    jsr draw_f
    jmp dfb_loop
dfb_core:
    ldx draw_i
    jsr damage_e_h_one
    jmp dfb_loop
dfb_done:
    rts
.endproc

; +1 to E core at X; fatal if reaches RAIL_CORE_HP. Clobbers A.
.proc damage_e_h_one
    lda rail_data::dmg_e, x
    cmp #RAIL_CORE_HP
    bcs deh_rts
    clc
    adc #1
    sta rail_data::dmg_e, x
    jsr draw_e
    ldx draw_i
    lda rail_data::dmg_e, x
    cmp #RAIL_CORE_HP
    bcc deh_rts
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
    jsr row_is_hrail
    bcs dr_skip
    lda draw_j
    cmp #DRONE_APPROACH_LEFT
    beq dmg_from_right
    jmp dmg_from_left
dr_skip:
    rts
.endproc

.proc dmg_from_left
dfl_loop:
    lda rail_data::hit_left
    beq dfl_done
    dec rail_data::hit_left
    ldx draw_i
    lda rail_data::dmg_va, x
    cmp #RAIL_OUTER_HP
    bcs dfl_core
    clc
    adc #1
    sta rail_data::dmg_va, x
    jsr draw_va
    jmp dfl_loop
dfl_core:
    ldx draw_i
    jsr damage_b_v_one
    jmp dfl_loop
dfl_done:
    rts
.endproc

.proc dmg_from_right
dfr_loop:
    lda rail_data::hit_left
    beq dfr_done
    dec rail_data::hit_left
    ldx draw_i
    lda rail_data::dmg_vc, x
    cmp #RAIL_OUTER_HP
    bcs dfr_core
    clc
    adc #1
    sta rail_data::dmg_vc, x
    jsr draw_vc
    jmp dfr_loop
dfr_core:
    ldx draw_i
    jsr damage_b_v_one
    jmp dfr_loop
dfr_done:
    rts
.endproc

.proc damage_b_v_one
    lda rail_data::dmg_vb, x
    cmp #RAIL_CORE_HP
    bcs dbv_rts
    clc
    adc #1
    sta rail_data::dmg_vb, x
    jsr draw_vb
    ldx draw_i
    lda rail_data::dmg_vb, x
    cmp #RAIL_CORE_HP
    bcc dbv_rts
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
; Glyph by damage taken (mapped); colour always COL_RAIL.
.proc draw_d
    jsr col_is_junction
    bcs dd_skip
    ldx draw_i
    lda rail_data::dmg_d, x
    jsr outer_glyph_idx
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
    ldx draw_i
    cpx #RAIL_COL_MID
    beq de_cross
    lda rail_data::dmg_e, x
    jsr core_glyph_idx
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
    jsr outer_glyph_idx
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
    jsr outer_glyph_idx
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
    jsr core_glyph_idx
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
    jsr outer_glyph_idx
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

; A = outer damage taken (0..6+) → glyph index 0 full, 1 crack, 2 crit, 3 gone
; Thresholds for RAIL_OUTER_HP=6: 0 | 1–2 | 3–4 | 5+
.proc outer_glyph_idx
    cmp #0
    beq ogi0
    cmp #3
    bcc ogi1
    cmp #5
    bcc ogi2
    lda #3
    rts
ogi0:
    lda #0
    rts
ogi1:
    lda #1
    rts
ogi2:
    lda #2
    rts
.endproc

; A = core damage taken (0..5+) → 0 full, 1 crack, 2 crit, 3 gone
; Thresholds for RAIL_CORE_HP=5: 0 | 1–2 | 3–4 | 5+
.proc core_glyph_idx
    cmp #0
    beq cgi0
    cmp #3
    bcc cgi1
    cmp #5
    bcc cgi2
    lda #3
    rts
cgi0:
    lda #0
    rts
cgi1:
    lda #1
    rts
cgi2:
    lda #2
    rts
.endproc

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
