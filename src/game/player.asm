; Player — logical object slot 0.
; Stage 2 slice: horizontal rail only, 4px steps, barrel up/down with mid swing.
;
; Fire: bullets::try_fire only when barrel at rest and not in the V-rail
; centre gap (see in_centre_gap — arms only).
;
; Barrel change (H-rail): only if not swinging, and stick presses the opposite
; of rest aim: UP rest + DOWN → U→R→D; DOWN rest + UP → D→L→U.

.scope player

; ---------------------------------------------------------------------------
; stage enter: place left of V-rail, barrel up, enable render on slot 0
; ---------------------------------------------------------------------------
.proc init
    lda #SPR_DIR_UP
    sta player_rest_dir
    lda #0
    sta player_swing_t
    sta player_swing_to
    sta player_move_dir             ; PLAYER_DIR_NONE until first L/R

    ; Slot 0 is permanent; fill presentation + position
    ldx #0
    lda #OBJ_PLAYER
    sta objects::obj_kind, x
    lda #SPR_COLOR_PLAYER
    sta objects::obj_sprite_color, x
    lda #OBJA_MULTICOLOR
    sta objects::obj_sprite_attr, x
    lda #SPR_PTR_PLAYER_0
    sta objects::obj_sprite_ptr, x

    lda #PLAYER_X_START
    sta objects::obj_x_lo, x
    lda #0
    sta objects::obj_x_hi, x
    sta objects::obj_x_frac, x
    sta objects::obj_y_frac, x
    lda #PLAYER_Y_HRAIL
    sta objects::obj_y_int, x

    lda #(OBJF_ALLOCATED | OBJF_RENDER)
    sta objects::obj_flags, x

    jsr install_frame_for_rest
    jsr sync_char_approx
    jsr objects::mark_dirty
    rts
.endproc

; ---------------------------------------------------------------------------
; Per logic tick while MODE_PLAY
; ---------------------------------------------------------------------------
.proc update
    jsr update_barrel
    jsr update_move
    rts
.endproc

; ---------------------------------------------------------------------------
; Barrel: advance mid-swing, or start opposite-direction flip
; ---------------------------------------------------------------------------
.proc update_barrel
    lda player_swing_t
    beq barrel_rest
    dec player_swing_t
    bne barrel_done
    ; Mid frame expired → settle on target rest facing
    lda player_swing_to
    sta player_rest_dir
    jsr install_frame_for_rest
    jsr objects::mark_dirty
    rts

barrel_rest:
    ; Only flip when pressing opposite of current rest aim
    lda player_rest_dir
    cmp #SPR_DIR_UP
    bne rest_is_down
    ; Facing up: need DOWN to start U→R→D
    lda input_dirs
    and #JOY_DOWN
    beq barrel_done
    lda #SPR_DIR_RIGHT
    jsr install_frame_a
    lda #PLAYER_SWING_MID_FRAMES
    sta player_swing_t
    lda #SPR_DIR_DOWN
    sta player_swing_to
    jsr objects::mark_dirty
    rts

rest_is_down:
    ; Facing down: need UP to start D→L→U
    lda input_dirs
    and #JOY_UP
    beq barrel_done
    lda #SPR_DIR_LEFT
    jsr install_frame_a
    lda #PLAYER_SWING_MID_FRAMES
    sta player_swing_t
    lda #SPR_DIR_UP
    sta player_swing_to
    jsr objects::mark_dirty
barrel_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; Horizontal move, 4px steps. Centre (V-rail cross) is walk-through only:
;   - stick sets / can reverse last travel dir
;   - release stick while in the gap → keep stepping last dir until clear
;   - never hop; X takes every 4px cell through the gap
; tmp0/tmp1 = candidate 16-bit X (lo/hi)
; ---------------------------------------------------------------------------
.proc update_move
    ; --- resolve this tick's travel dir ---
    lda input_dirs
    and #JOY_RIGHT
    beq check_left
    lda #PLAYER_DIR_RIGHT
    sta player_move_dir
    jmp apply_step
check_left:
    lda input_dirs
    and #JOY_LEFT
    beq no_stick
    lda #PLAYER_DIR_LEFT
    sta player_move_dir
    jmp apply_step

no_stick:
    ; Idle on an arm: stop. Idle in the centre gap: coast last dir.
    jsr load_x_to_tmp
    jsr in_centre_gap
    bcc move_idle                   ; not in gap → stay put
    lda player_move_dir
    bne apply_step                  ; coast
    ; No last dir (shouldn't happen mid-gap): exit toward nearer arm
    lda tmp0
    cmp #PLAYER_GAP_MID
    bcc force_left
    lda #PLAYER_DIR_RIGHT
    sta player_move_dir
    jmp apply_step
force_left:
    lda #PLAYER_DIR_LEFT
    sta player_move_dir
    ; fall through

apply_step:
    lda player_move_dir
    cmp #PLAYER_DIR_RIGHT
    beq do_right
    cmp #PLAYER_DIR_LEFT
    beq do_left
move_idle:
    rts

do_right:
    ldx #0
    lda objects::obj_x_lo, x
    clc
    adc #PLAYER_MOVE_STEP
    sta tmp0
    lda objects::obj_x_hi, x
    adc #0
    sta tmp1
    ; clamp max
    lda tmp1
    cmp #>PLAYER_X_MAX
    bcc store_x
    bne right_to_max
    lda tmp0
    cmp #<PLAYER_X_MAX
    bcc store_x
    beq store_x
right_to_max:
    lda #<PLAYER_X_MAX
    sta tmp0
    lda #>PLAYER_X_MAX
    sta tmp1
    jmp store_x

do_left:
    ldx #0
    lda objects::obj_x_lo, x
    sec
    sbc #PLAYER_MOVE_STEP
    sta tmp0
    lda objects::obj_x_hi, x
    sbc #0
    sta tmp1
    bcc left_to_min
    lda tmp1
    bne store_x
    lda tmp0
    cmp #PLAYER_X_MIN
    bcs store_x
left_to_min:
    lda #<PLAYER_X_MIN
    sta tmp0
    lda #>PLAYER_X_MIN
    sta tmp1

store_x:
    ldx #0
    lda tmp0
    sta objects::obj_x_lo, x
    lda tmp1
    sta objects::obj_x_hi, x
    jsr sync_char_approx
    jsr objects::mark_dirty
    rts
.endproc

; Load slot-0 X into tmp0/tmp1.
.proc load_x_to_tmp
    ldx #0
    lda objects::obj_x_lo, x
    sta tmp0
    lda objects::obj_x_hi, x
    sta tmp1
    rts
.endproc

; C set if tmp0/tmp1 is strictly inside (LEFT_MAX, RIGHT_MIN) — no rest zone.
.proc in_centre_gap
    lda tmp1
    bne gap_no                      ; x >= 256: not in centre band
    lda tmp0
    cmp #PLAYER_ARM_LEFT_MAX
    bcc gap_no                      ; x <= LEFT_MAX (legal left rest)
    beq gap_no
    cmp #PLAYER_ARM_RIGHT_MIN
    bcs gap_no                      ; x >= RIGHT_MIN (legal right rest)
    sec
    rts
gap_no:
    clc
    rts
.endproc

; ---------------------------------------------------------------------------
; Frames → PLAYER_BUF_0 ($3E00), ptr $F8
; ---------------------------------------------------------------------------
.proc install_frame_for_rest
    lda player_rest_dir
    jsr install_frame_a
    rts
.endproc

; A = SPR_DIR_* → copy that player frame source into $3E00
.proc install_frame_a
    asl a                           ; ×2 for word table
    tax
    lda player_frame_ptr, x
    sta ptr_lo
    lda player_frame_ptr+1, x
    sta ptr_hi
    ldy #0
copy_loop:
    lda (ptr_lo), y
    sta PLAYER_BUF_0, y
    iny
    cpy #64
    bne copy_loop
    rts
.endproc

; Rough char cell from sprite top-left (for future bullets / debug)
.proc sync_char_approx
    ldx #0
    ; col ≈ (x_lo + 256*x_hi - 24) / 8
    lda objects::obj_x_lo, x
    sec
    sbc #24
    sta tmp0
    lda objects::obj_x_hi, x
    sbc #0
    lsr a
    ror tmp0
    lsr a
    ror tmp0
    lsr a
    ror tmp0
    lda tmp0
    sta player_col
    ; row ≈ (y - 50) / 8
    lda objects::obj_y_int, x
    sec
    sbc #50
    lsr a
    lsr a
    lsr a
    sta player_row
    rts
.endproc

; ---------------------------------------------------------------------------
; C drone rail blast — full hit (slice: no range check). Health 0 → next life.
; Clobbers A. Preserves X,Y.
; ---------------------------------------------------------------------------
.proc apply_c_blast_full
    lda health
    beq blast_done                  ; already dead this life
    sec
    sbc #C_BLAST_FULL
    bcs blast_store
    lda #0
blast_store:
    sta health
    lda #1
    sta hud_status_dirty
    lda health
    bne blast_done
    lda #MODE_NEXT_LIFE
    jsr mode_set
blast_done:
    rts
.endproc

; Word table: index = SPR_DIR_* (left, right, up, down)
player_frame_ptr:
    .word spr_player_left
    .word spr_player_right
    .word spr_player_up
    .word spr_player_down

.endscope
