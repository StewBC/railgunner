; Character bullets — 4px-aligned with player (half-cell lanes).
;
; Vertical aim (H-rail): VL*/VR* glyphs (left OO...... / right ....OO..)
;   DOWN: phase 0→1→2→3 then row++; UP: 3→2→1→0 then row--
; Horizontal aim (V-rail): HT*/HB* glyphs (top / bottom Y half)
;   RIGHT: phase 0→3 then col++; LEFT: 3→0 then col--
; Rate of fire: gun locked for BULLET_CELL_TICKS (= 4 phases × hold) after each
; shot so the previous bullet has fully left its first character cell.

.scope bullets

bullet_active:  .res BULLET_MAX
bullet_col:     .res BULLET_MAX
bullet_row:     .res BULLET_MAX
bullet_half:    .res BULLET_MAX     ; V: 0=left/1=right  H: 0=top/1=bot
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
    bne adv_active
    jmp adv_next
adv_active:
    dec bullet_hold, x
    beq adv_tick
    jmp adv_draw
adv_tick:
    lda #BULLET_HOLD
    sta bullet_hold, x
    lda bullet_dir, x
    cmp #SPR_DIR_UP
    bne adv_not_up
    jmp adv_up
adv_not_up:
    cmp #SPR_DIR_DOWN
    bne adv_not_down
    jmp adv_down
adv_not_down:
    cmp #SPR_DIR_LEFT
    bne adv_go_right
    jmp adv_left
adv_go_right:
    jmp adv_right

adv_down:
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
    lda bullet_row, x
    cmp #BULLET_ROW_MIN
    beq adv_kill
    bcc adv_kill
    dec bullet_row, x
    lda #3
    sta bullet_phase, x
    jmp adv_draw

adv_right:
    lda bullet_phase, x
    cmp #3
    bcs right_next_cell
    inc bullet_phase, x
    jmp adv_draw
right_next_cell:
    jsr erase_slot
    inc bullet_col, x
    lda bullet_col, x
    cmp #BULLET_COL_MAX + 1
    bcs adv_kill
    lda #0
    sta bullet_phase, x
    jmp adv_draw

adv_left:
    lda bullet_phase, x
    beq left_next_cell
    dec bullet_phase, x
    jmp adv_draw
left_next_cell:
    jsr erase_slot
    lda bullet_col, x
    cmp #BULLET_COL_MIN
    beq adv_kill
    bcc adv_kill
    dec bullet_col, x
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
    beq adv_done
    jmp adv_loop
adv_done:
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
; Vertical: SC_BULLET_VL0 + half*4 + phase
; Horizontal: SC_BULLET_HT0 + half*4 + phase
; ---------------------------------------------------------------------------
.proc draw_slot
    txa
    pha
    lda bullet_dir, x
    cmp #SPR_DIR_LEFT
    beq draw_h
    cmp #SPR_DIR_RIGHT
    beq draw_h
    lda #SC_BULLET_VL0
    jmp draw_base
draw_h:
    lda #SC_BULLET_HT0
draw_base:
    sta tmp1                        ; base glyph
    lda bullet_half, x
    asl a
    asl a                           ; *4
    clc
    adc bullet_phase, x
    clc
    adc tmp1
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
    rts
fire_unlocked:
    lda player_swing_t
    beq fire_swing_ok
    rts
fire_swing_ok:
    jsr player::at_intersection
    bcc fire_on_arm
    rts
fire_on_arm:
    lda input_fire
    bne fire_held
    rts
fire_held:
    lda player_rest_dir
    cmp #SPR_DIR_UP
    beq aim_up
    cmp #SPR_DIR_DOWN
    beq aim_down
    cmp #SPR_DIR_LEFT
    beq aim_left
    cmp #SPR_DIR_RIGHT
    beq aim_right
    rts

aim_up:
    jsr player_launch_lane          ; draw_i=col, tmp0=half X
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
    jmp fire_common

aim_left:
    jsr player_launch_row           ; draw_j=row, tmp0=half Y
    lda #BULLET_LAUNCH_COL_LEFT
    sta draw_i
    lda #SPR_DIR_LEFT
    sta tmp1
    lda #3
    sta tmp2
    jmp fire_common

aim_right:
    jsr player_launch_row
    lda #BULLET_LAUNCH_COL_RIGHT
    sta draw_i
    lda #SPR_DIR_RIGHT
    sta tmp1
    lda #0
    sta tmp2
    ; fall through

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
    lda tmp0
    sta bullet_half, x
    lda tmp1
    sta bullet_dir, x
    lda tmp2
    sta bullet_phase, x
    lda #BULLET_HOLD
    sta bullet_hold, x
    lda #BULLET_CELL_TICKS
    sta fire_lock
    jsr draw_slot
    rts
.endproc

; ---------------------------------------------------------------------------
; Aim point → char col + half-cell X lane (vertical stream).
;   draw_i = col (0..39)
;   tmp0   = BULLET_HALF_LEFT / RIGHT
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
    lda tmp0
    and #4
    beq half_left
    lda #BULLET_HALF_RIGHT
    bne half_store
half_left:
    lda #BULLET_HALF_LEFT
half_store:
    sta mode_state
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
    sta tmp0
    rts
.endproc

; ---------------------------------------------------------------------------
; Aim point → char row + half-cell Y lane (horizontal stream).
;   draw_j = row (0..24)
;   tmp0   = BULLET_HALF_TOP / BOT
; Gun pixel Y = sprite_y + PLAYER_GUN_Y_OFF; cell = (gunY - 50).
; ---------------------------------------------------------------------------
.proc player_launch_row
    ldx #0
    lda objects::obj_y_int, x
    clc
    adc #PLAYER_GUN_Y_OFF
    sec
    sbc #50
    sta tmp0                        ; pixel Y relative to char row 0
    and #4
    beq half_top
    lda #BULLET_HALF_BOT
    bne half_y_store
half_top:
    lda #BULLET_HALF_TOP
half_y_store:
    sta mode_state
    lda tmp0
    lsr a
    lsr a
    lsr a                           ; row
    cmp #SCREEN_H
    bcc row_ok
    lda #SCREEN_H - 1
row_ok:
    sta draw_j
    lda mode_state
    sta tmp0
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
    cmp #SC_BULLET_HT0
    bcs not_v
    cmp #SC_BULLET_VR0
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
