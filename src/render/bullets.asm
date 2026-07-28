; Character bullets — 4px-aligned with player (half-cell X lanes).
;
; Vertical aim (H-rail): VL*/VR* glyphs (left OO...... / right ....OO..)
;   DOWN: phase 0→1→2→3 then row++; UP: 3→2→1→0 then row--
; Rate of fire: gun locked for BULLET_CELL_TICKS (= 4 phases × hold) after each
; shot so the previous bullet has fully left its first character cell.

.scope bullets

bullet_active:  .res BULLET_MAX
bullet_col:     .res BULLET_MAX
bullet_row:     .res BULLET_MAX
bullet_half:    .res BULLET_MAX     ; 0=left OO......  1=right ....OO..
bullet_dir:     .res BULLET_MAX
bullet_phase:   .res BULLET_MAX
bullet_hold:    .res BULLET_MAX
fire_lock:      .res 1              ; ticks until gun may fire again

; ---------------------------------------------------------------------------
.proc init
    ldx #0
    lda #0
    sta fire_lock
clear:
    sta bullet_active, x
    inx
    cpx #BULLET_MAX
    bne clear
    rts
.endproc

; ---------------------------------------------------------------------------
.proc update
    lda fire_lock
    beq lock_zero
    dec fire_lock
lock_zero:
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
    lda bullet_phase, x
    beq up_next_cell
    dec bullet_phase, x
    jmp adv_draw
up_next_cell:
    jsr erase_slot
    ; Finished a cell: leave if already on min row (score is row 0 above)
    lda bullet_row, x
    cmp #BULLET_ROW_MIN
    beq adv_kill
    bcc adv_kill
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
; Glyph = SC_BULLET_VL0 + half*4 + phase
; ---------------------------------------------------------------------------
.proc draw_slot
    txa
    pha
    lda bullet_half, x
    asl a
    asl a                           ; *4
    clc
    adc bullet_phase, x
    clc
    adc #SC_BULLET_VL0
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
    lda fire_lock
    beq fire_unlocked
    rts                             ; prior shot still finishing first cell
fire_unlocked:
    lda player_swing_t
    beq fire_swing_ok
    rts                             ; mid barrel swing
fire_swing_ok:
    ; No fire in the centre intersection (either rail)
    jsr player::at_intersection
    bcc fire_on_arm
    rts
fire_on_arm:
    lda input_fire
    bne fire_held
    rts
fire_held:
    ; 8.1a: vertical stream only (U/D rest). L/R stream = Step 8.2.
    lda player_rest_dir
    cmp #SPR_DIR_UP
    beq aim_up
    cmp #SPR_DIR_DOWN
    beq aim_down
    rts

aim_up:
    jsr player_launch_lane          ; draw_i=col, tmp0=half
    lda #BULLET_LAUNCH_ROW_UP
    sta draw_j
    lda #SPR_DIR_UP
    sta tmp1
    lda #3
    sta tmp2
    jmp fire_common

aim_down:
    jsr player_launch_lane
    lda #BULLET_LAUNCH_ROW_DOWN
    sta draw_j
    lda #SPR_DIR_DOWN
    sta tmp1
    lda #0
    sta tmp2

fire_common:
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
    lda tmp0                        ; half from player_launch_lane
    sta bullet_half, x
    lda tmp1
    sta bullet_dir, x
    lda tmp2
    sta bullet_phase, x
    lda #BULLET_HOLD
    sta bullet_hold, x
    ; Lock gun for one full cell lifetime (4 phases × hold)
    lda #BULLET_CELL_TICKS
    sta fire_lock
    jsr draw_slot
    rts
.endproc

; ---------------------------------------------------------------------------
; Aim point → char col + half-cell lane.
;   draw_i = col (0..39)
;   tmp0   = BULLET_HALF_LEFT (0) or RIGHT (1)
; Gun pixel X = sprite_x + PLAYER_GUN_X_OFF; cell = (gunX - 24).
; ---------------------------------------------------------------------------
.proc player_launch_lane
    ldx #0
    lda objects::obj_x_lo, x
    clc
    adc #PLAYER_GUN_X_OFF
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
    sta tmp1
    ; tmp0/tmp1 = gun pixel X relative to left of char col 0
    ; col = pixel / 8, half = 0 if (pixel & 4) == 0 else 1
    lda tmp0
    and #4
    beq half_left
    lda #BULLET_HALF_RIGHT
    bne half_store
half_left:
    lda #BULLET_HALF_LEFT
half_store:
    sta mode_state                  ; temp half
    ; col = pixel >> 3 (16-bit)
    lda tmp1
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
    sta draw_i
    lda mode_state
    sta tmp0                        ; half out
    rts
.endproc

; ---------------------------------------------------------------------------
; Find active bullet at col=draw_i, row=draw_j, half=tmp0.
; C clear + X=slot if found; C set if none.
; ---------------------------------------------------------------------------
.proc find_at
    ldx #0
find_loop:
    lda bullet_active, x
    beq find_next
    lda bullet_col, x
    cmp draw_i
    bne find_next
    lda bullet_row, x
    cmp draw_j
    bne find_next
    lda bullet_half, x
    cmp tmp0
    bne find_next
    clc
    rts
find_next:
    inx
    cpx #BULLET_MAX
    bne find_loop
    sec
    rts
.endproc

; ---------------------------------------------------------------------------
; Destroy bullet slot X: erase glyph, free slot. Preserves Y; clobbers A.
; ---------------------------------------------------------------------------
.proc destroy
    lda bullet_active, x
    beq destroy_done
    jsr erase_slot
    lda #0
    sta bullet_active, x
destroy_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; Half from vertical bullet glyph A → tmp0 (0 left / 1 right). C set if not V.
; ---------------------------------------------------------------------------
.proc half_from_glyph
    cmp #SC_BULLET_VL0
    bcc not_v
    cmp #SC_BULLET_HT0              ; $F8 — first horizontal glyph
    bcs not_v
    cmp #SC_BULLET_VR0              ; $F4
    bcc half_l
    lda #BULLET_HALF_RIGHT
    sta tmp0
    clc
    rts
half_l:
    lda #BULLET_HALF_LEFT
    sta tmp0
    clc
    rts
not_v:
    sec
    rts
.endproc

.endscope
