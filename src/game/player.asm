; Player — logical object slot 0.
; Step 8.1a: H + V rails, centre mount both ways, 90° barrel remap.
; Step 8.1b will add L/R mid-swing on V-arm (remap already leaves L/R facing).
;
; Fire: bullets::try_fire when barrel at rest and on an arm (not intersection).
; H-stream fire is Step 8.2 (L/R aim); V-stream still only for U/D rest.
;
; Controls (design brief):
;   H-rail: L/R move, U/D barrel (arm only).
;   V-rail: U/D move, L/R barrel (8.1b).
;   Remap: UP↔LEFT, DOWN↔RIGHT on every rail switch.
;   Intersection: no barrel flip.
;
; Rail-walk / centre decision (anti-ping-pong):
;   Travel dir is locked while crossing the gap (parallel stick may update
;   only before the centre decision). When the step *crosses* the mid point
;   (GAP_MID / Y_HRAIL), evaluate input once: prefer perpendicular non-coincident
;   dirs (mount other rail), else reverse-parallel, else keep travel. After that
;   decision, ignore stick until the player leaves the intersection.
;   Opposite-axis chords (up+down / left+right) can still oscillate arm↔mid;
;   joystick cannot do that — leave it; not worth special-casing.

.scope player

; ---------------------------------------------------------------------------
; stage enter: left H-arm rest, barrel up, on horizontal rail
; ---------------------------------------------------------------------------
.proc init
    lda #PLAYER_RAIL_H
    sta player_rail
    lda #SPR_DIR_UP
    sta player_rest_dir
    lda #0
    sta player_swing_t
    sta player_swing_to
    sta player_move_dir             ; PLAYER_DIR_NONE until first travel
    sta player_cross_decided

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
; Barrel: mid-swing advance, or arm-only opposite flip. Never at intersection.
; 8.1a: H-rail U/D flip only; V-rail flips deferred to 8.1b.
; ---------------------------------------------------------------------------
.proc update_barrel
    lda player_swing_t
    beq barrel_rest
    dec player_swing_t
    bne barrel_done
    lda player_swing_to
    sta player_rest_dir
    jsr install_frame_for_rest
    jsr objects::mark_dirty
    rts

barrel_rest:
    jsr at_intersection
    bcs barrel_done                 ; C set = in intersection → no flip

    lda player_rail
    cmp #PLAYER_RAIL_H
    bne barrel_done                 ; V-arm barrel = 8.1b

    ; H-rail: flip only on opposite of rest aim
    lda player_rest_dir
    cmp #SPR_DIR_UP
    bne rest_is_down
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
    cmp #SPR_DIR_DOWN
    bne barrel_done
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
; Move on current rail; centre mid-crossing decides mount/turn once per walk.
; ---------------------------------------------------------------------------
.proc update_move
    lda player_rail
    cmp #PLAYER_RAIL_V
    bne move_h
    jmp move_on_v
move_h:
    jmp move_on_h
.endproc

; --- Horizontal rail -------------------------------------------------------
.proc move_on_h
    jsr load_x_to_tmp
    jsr in_centre_gap_x
    bcs h_in_gap

    ; On an arm: clear centre decision; stick fully drives L/R
    lda #0
    sta player_cross_decided
    lda input_dirs
    and #JOY_RIGHT
    beq h_arm_left
    lda #PLAYER_DIR_RIGHT
    sta player_move_dir
    jmp step_h
h_arm_left:
    lda input_dirs
    and #JOY_LEFT
    beq h_idle
    lda #PLAYER_DIR_LEFT
    sta player_move_dir
    jmp step_h
h_idle:
    rts

h_in_gap:
    ; Before centre decision: parallel stick may update travel only
    lda player_cross_decided
    bne h_gap_step
    lda input_dirs
    and #JOY_RIGHT
    beq h_gap_left
    lda #PLAYER_DIR_RIGHT
    sta player_move_dir
    jmp h_gap_have_dir
h_gap_left:
    lda input_dirs
    and #JOY_LEFT
    beq h_gap_coast
    lda #PLAYER_DIR_LEFT
    sta player_move_dir
    jmp h_gap_have_dir
h_gap_coast:
    lda player_move_dir
    bne h_gap_have_dir
    ; No last dir: pick nearer exit
    jsr load_x_to_tmp
    lda tmp0
    cmp #PLAYER_GAP_MID
    bcc h_force_left
    lda #PLAYER_DIR_RIGHT
    sta player_move_dir
    jmp h_gap_have_dir
h_force_left:
    lda #PLAYER_DIR_LEFT
    sta player_move_dir

h_gap_have_dir:
    jsr side_of_mid_h               ; A = 0 left / 1 right-of-mid
    sta tmp2
    jsr step_h
    lda player_cross_decided
    bne h_done
    jsr side_of_mid_h
    cmp tmp2
    beq h_done                      ; did not cross mid this step
    jsr eval_center_h               ; one-shot turn / mount
    lda #1
    sta player_cross_decided
h_done:
    rts

h_gap_step:
    ; Decision already made — coast locked travel until off intersection
    lda player_move_dir
    bne h_gap_step_go
    rts
h_gap_step_go:
    jmp step_h
.endproc

; One H-rail step from player_move_dir (LEFT/RIGHT). Also used after mount.
.proc step_h
    lda player_move_dir
    cmp #PLAYER_DIR_RIGHT
    beq h_do_right
    cmp #PLAYER_DIR_LEFT
    beq h_do_left
    rts

h_do_right:
    ldx #0
    lda objects::obj_x_lo, x
    clc
    adc #PLAYER_MOVE_STEP
    sta tmp0
    lda objects::obj_x_hi, x
    adc #0
    sta tmp1
    lda tmp1
    cmp #>PLAYER_X_MAX
    bcc h_store_x
    bne h_right_max
    lda tmp0
    cmp #<PLAYER_X_MAX
    bcc h_store_x
    beq h_store_x
h_right_max:
    lda #<PLAYER_X_MAX
    sta tmp0
    lda #>PLAYER_X_MAX
    sta tmp1
    jmp h_store_x

h_do_left:
    ldx #0
    lda objects::obj_x_lo, x
    sec
    sbc #PLAYER_MOVE_STEP
    sta tmp0
    lda objects::obj_x_hi, x
    sbc #0
    sta tmp1
    bcc h_left_min
    lda tmp1
    bne h_store_x
    lda tmp0
    cmp #PLAYER_X_MIN
    bcs h_store_x
h_left_min:
    lda #<PLAYER_X_MIN
    sta tmp0
    lda #>PLAYER_X_MIN
    sta tmp1

h_store_x:
    ldx #0
    lda tmp0
    sta objects::obj_x_lo, x
    lda tmp1
    sta objects::obj_x_hi, x
    lda #PLAYER_Y_HRAIL
    sta objects::obj_y_int, x
    jsr objects::mark_dirty
    rts
.endproc

; --- Vertical rail ---------------------------------------------------------
.proc move_on_v
    jsr load_y_to_a
    jsr in_centre_gap_y
    bcs v_in_gap

    lda #0
    sta player_cross_decided
    lda input_dirs
    and #JOY_UP
    beq v_arm_down
    lda #PLAYER_DIR_UP
    sta player_move_dir
    jmp step_v
v_arm_down:
    lda input_dirs
    and #JOY_DOWN
    beq v_idle
    lda #PLAYER_DIR_DOWN
    sta player_move_dir
    jmp step_v
v_idle:
    rts

v_in_gap:
    lda player_cross_decided
    bne v_gap_step
    lda input_dirs
    and #JOY_UP
    beq v_gap_down
    lda #PLAYER_DIR_UP
    sta player_move_dir
    jmp v_gap_have_dir
v_gap_down:
    lda input_dirs
    and #JOY_DOWN
    beq v_gap_coast
    lda #PLAYER_DIR_DOWN
    sta player_move_dir
    jmp v_gap_have_dir
v_gap_coast:
    lda player_move_dir
    bne v_gap_have_dir
    jsr load_y_to_a
    cmp #PLAYER_Y_HRAIL
    bcc v_force_up
    lda #PLAYER_DIR_DOWN
    sta player_move_dir
    jmp v_gap_have_dir
v_force_up:
    lda #PLAYER_DIR_UP
    sta player_move_dir

v_gap_have_dir:
    jsr side_of_mid_v               ; A = 0 above mid / 1 below-or-eq
    sta tmp2
    jsr step_v
    lda player_cross_decided
    bne v_done
    jsr side_of_mid_v
    cmp tmp2
    beq v_done
    jsr eval_center_v
    lda #1
    sta player_cross_decided
v_done:
    rts

v_gap_step:
    lda player_move_dir
    bne v_gap_step_go
    rts
v_gap_step_go:
    jmp step_v
.endproc

; One V-rail step from player_move_dir (UP/DOWN). Also used after mount.
.proc step_v
    lda player_move_dir
    cmp #PLAYER_DIR_UP
    beq v_do_up
    cmp #PLAYER_DIR_DOWN
    beq v_do_down
    rts

v_do_up:
    ldx #0
    lda objects::obj_y_int, x
    sec
    sbc #PLAYER_MOVE_STEP
    bcc v_up_min
    cmp #PLAYER_Y_MIN
    bcs v_store_y
v_up_min:
    lda #PLAYER_Y_MIN
    jmp v_store_y

v_do_down:
    ldx #0
    lda objects::obj_y_int, x
    clc
    adc #PLAYER_MOVE_STEP
    bcs v_down_max
    cmp #PLAYER_Y_MAX
    bcc v_store_y
    beq v_store_y
v_down_max:
    lda #PLAYER_Y_MAX

v_store_y:
    ldx #0
    sta objects::obj_y_int, x
    lda #<PLAYER_X_VRAIL
    sta objects::obj_x_lo, x
    lda #>PLAYER_X_VRAIL
    sta objects::obj_x_hi, x
    jsr objects::mark_dirty
    rts
.endproc

; ---------------------------------------------------------------------------
; Centre evaluation — one shot when a step crosses the mid line.
; Prefer perpendicular (mount), then reverse-parallel; order U,D,L,R in ties.
; ---------------------------------------------------------------------------
.proc eval_center_h
    ; Perpendicular first: UP then DOWN
    lda input_dirs
    and #JOY_UP
    beq ech_down
    lda #PLAYER_DIR_UP
    sta player_move_dir
    jsr do_mount_v
    jmp step_v
ech_down:
    lda input_dirs
    and #JOY_DOWN
    beq ech_rev
    lda #PLAYER_DIR_DOWN
    sta player_move_dir
    jsr do_mount_v
    jmp step_v
ech_rev:
    ; Reverse parallel if held and not current travel
    lda player_move_dir
    cmp #PLAYER_DIR_RIGHT
    bne ech_was_left
    lda input_dirs
    and #JOY_LEFT
    beq ech_keep
    lda #PLAYER_DIR_LEFT
    sta player_move_dir
ech_keep:
    rts
ech_was_left:
    lda input_dirs
    and #JOY_RIGHT
    beq ech_keep
    lda #PLAYER_DIR_RIGHT
    sta player_move_dir
    rts
.endproc

.proc eval_center_v
    ; Perpendicular first: LEFT then RIGHT (U,D,L,R priority → L before R)
    lda input_dirs
    and #JOY_LEFT
    beq ecv_right
    lda #PLAYER_DIR_LEFT
    sta player_move_dir
    jsr do_mount_h
    jmp step_h
ecv_right:
    lda input_dirs
    and #JOY_RIGHT
    beq ecv_rev
    lda #PLAYER_DIR_RIGHT
    sta player_move_dir
    jsr do_mount_h
    jmp step_h
ecv_rev:
    lda player_move_dir
    cmp #PLAYER_DIR_UP
    bne ecv_was_down
    lda input_dirs
    and #JOY_DOWN
    beq ecv_keep
    lda #PLAYER_DIR_DOWN
    sta player_move_dir
ecv_keep:
    rts
ecv_was_down:
    lda input_dirs
    and #JOY_UP
    beq ecv_keep
    lda #PLAYER_DIR_UP
    sta player_move_dir
    rts
.endproc

; ---------------------------------------------------------------------------
; Mount: cancel swing, remap barrel, snap to intersection, set rail.
; Caller sets player_move_dir and steps on the new rail.
; ---------------------------------------------------------------------------

.proc do_mount_v
    lda #0
    sta player_swing_t
    jsr remap_to_v
    lda #PLAYER_RAIL_V
    sta player_rail
    ldx #0
    lda #<PLAYER_X_VRAIL
    sta objects::obj_x_lo, x
    lda #>PLAYER_X_VRAIL
    sta objects::obj_x_hi, x
    lda #PLAYER_Y_HRAIL
    sta objects::obj_y_int, x
    jsr install_frame_for_rest
    jsr objects::mark_dirty
    rts
.endproc

.proc do_mount_h
    lda #0
    sta player_swing_t
    jsr remap_to_h
    lda #PLAYER_RAIL_H
    sta player_rail
    ldx #0
    lda #<PLAYER_X_VRAIL
    sta objects::obj_x_lo, x
    lda #>PLAYER_X_VRAIL
    sta objects::obj_x_hi, x
    lda #PLAYER_Y_HRAIL
    sta objects::obj_y_int, x
    jsr install_frame_for_rest
    jsr objects::mark_dirty
    rts
.endproc

; UP→LEFT, DOWN→RIGHT (and leave L/R unchanged if already)
.proc remap_to_v
    lda player_rest_dir
    cmp #SPR_DIR_UP
    bne r2v_down
    lda #SPR_DIR_LEFT
    sta player_rest_dir
    rts
r2v_down:
    cmp #SPR_DIR_DOWN
    bne r2v_done
    lda #SPR_DIR_RIGHT
    sta player_rest_dir
r2v_done:
    rts
.endproc

; LEFT→UP, RIGHT→DOWN
.proc remap_to_h
    lda player_rest_dir
    cmp #SPR_DIR_LEFT
    bne r2h_right
    lda #SPR_DIR_UP
    sta player_rest_dir
    rts
r2h_right:
    cmp #SPR_DIR_RIGHT
    bne r2h_done
    lda #SPR_DIR_DOWN
    sta player_rest_dir
r2h_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; Geometry helpers
; ---------------------------------------------------------------------------

; C set if at centre intersection for current rail.
.proc at_intersection
    lda player_rail
    cmp #PLAYER_RAIL_V
    beq at_int_v
    jsr load_x_to_tmp
    jmp in_centre_gap_x
at_int_v:
    jsr load_y_to_a
    jmp in_centre_gap_y
.endproc

; A = 0 if X < GAP_MID, 1 if X >= GAP_MID (right arm / past mid).
.proc side_of_mid_h
    jsr load_x_to_tmp
    lda tmp1
    bne side_h_hi
    lda tmp0
    cmp #PLAYER_GAP_MID
    bcc side_h_lo
side_h_hi:
    lda #1
    rts
side_h_lo:
    lda #0
    rts
.endproc

; A = 0 if Y < Y_HRAIL (toward top), 1 if Y >= Y_HRAIL.
.proc side_of_mid_v
    jsr load_y_to_a
    cmp #PLAYER_Y_HRAIL
    bcc side_v_up
    lda #1
    rts
side_v_up:
    lda #0
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

; A = slot-0 Y (obj_y_int). Preserves X only via ldx #0.
.proc load_y_to_a
    ldx #0
    lda objects::obj_y_int, x
    rts
.endproc

; C set if tmp0/tmp1 is strictly inside (LEFT_MAX, RIGHT_MIN).
.proc in_centre_gap_x
    lda tmp1
    bne gap_x_no
    lda tmp0
    cmp #PLAYER_ARM_LEFT_MAX
    bcc gap_x_no
    beq gap_x_no
    cmp #PLAYER_ARM_RIGHT_MIN
    bcs gap_x_no
    sec
    rts
gap_x_no:
    clc
    rts
.endproc

; Alias for callers that still use the old name (bullets fire gate).
.proc in_centre_gap
    jmp in_centre_gap_x
.endproc

; C set if A is strictly inside (TOP_MAX, BOT_MIN). Clobbers nothing but flags/A compare.
.proc in_centre_gap_y
    cmp #PLAYER_ARM_TOP_MAX
    bcc gap_y_no
    beq gap_y_no
    cmp #PLAYER_ARM_BOT_MIN
    bcs gap_y_no
    sec
    rts
gap_y_no:
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
    asl a
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

; ---------------------------------------------------------------------------
; C drone rail blast — full hit only if player is in the 2-cell impact zone
; under the drone (same cols as rail::apply_ab_hit). X = C object slot.
; ---------------------------------------------------------------------------
.proc apply_c_blast_full
    lda objects::obj_x_lo, x
    clc
    adc #DRONE_IMPACT_X_OFF
    sta tmp0
    lda objects::obj_x_hi, x
    adc #0
    sta tmp1
    jsr px_to_col
    sta draw_i

    stx tmp2
    ldx #0
    lda objects::obj_x_lo, x
    clc
    adc #12
    sta tmp0
    lda objects::obj_x_hi, x
    adc #0
    sta tmp1
    jsr px_to_col
    ldx tmp2

    cmp draw_i
    beq blast_hit
    tax
    lda draw_i
    clc
    adc #1
    sta tmp0
    cpx tmp0
    beq blast_hit_restore_x
    ldx tmp2
    rts

blast_hit_restore_x:
    ldx tmp2
blast_hit:
    lda health
    beq blast_done
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
    sta pending_mode
blast_done:
    rts
.endproc

; tmp0/tmp1 = 16-bit VIC X → A = char col 0..39. Clobbers tmp0/tmp1.
.proc px_to_col
    lda tmp0
    sec
    sbc #24
    sta tmp0
    lda tmp1
    sbc #0
    bcc ptc0
    lsr a
    ror tmp0
    lsr a
    ror tmp0
    lsr a
    ror tmp0
    lda tmp0
    cmp #40
    bcc ptc_ok
    lda #39
ptc_ok:
    rts
ptc0:
    lda #0
    rts
.endproc

player_frame_ptr:
    .word spr_player_left
    .word spr_player_right
    .word spr_player_up
    .word spr_player_down

.endscope
