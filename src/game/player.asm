; Player — logical object slot 0.
; Step 8.1a: H + V rails, centre mount both ways, 90° barrel remap.
; Step 8.1b will add L/R mid-swing on V-arm (remap already leaves L/R facing).
;
; Fire: bullets::try_fire when barrel at rest and on an arm (not intersection).
; H-stream fire is Step 8.2 (L/R aim); V-stream still only for U/D rest.
;
; Controls (design brief):
;   H-rail: L/R move, U/D barrel (arm only); at centre U/D mounts V.
;   V-rail: U/D move, L/R barrel (8.1b); at centre L/R mounts H.
;   Remap: UP↔LEFT, DOWN↔RIGHT on every rail switch.
;   Intersection: no barrel flip; perpendicular input mounts immediately.

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
; Move on current rail; mount at centre on perpendicular input.
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
    ; Perpendicular at intersection → mount V (takes priority this tick)
    jsr at_intersection
    bcc h_no_mount
    lda input_dirs
    and #JOY_UP
    beq h_try_down
    jmp mount_v_up
h_try_down:
    lda input_dirs
    and #JOY_DOWN
    beq h_no_mount
    jmp mount_v_down

h_no_mount:
    ; Parallel: L/R move / coast through centre
    lda input_dirs
    and #JOY_RIGHT
    beq h_check_left
    lda #PLAYER_DIR_RIGHT
    sta player_move_dir
    jmp h_apply
h_check_left:
    lda input_dirs
    and #JOY_LEFT
    beq h_no_stick
    lda #PLAYER_DIR_LEFT
    sta player_move_dir
    jmp h_apply

h_no_stick:
    jsr load_x_to_tmp
    jsr in_centre_gap_x
    bcc h_idle
    lda player_move_dir
    bne h_apply
    lda tmp0
    cmp #PLAYER_GAP_MID
    bcc h_force_left
    lda #PLAYER_DIR_RIGHT
    sta player_move_dir
    jmp h_apply
h_force_left:
    lda #PLAYER_DIR_LEFT
    sta player_move_dir

h_apply:
    jmp step_h
h_idle:
    rts
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
    jsr at_intersection
    bcc v_no_mount
    lda input_dirs
    and #JOY_RIGHT
    beq v_try_left
    jmp mount_h_right
v_try_left:
    lda input_dirs
    and #JOY_LEFT
    beq v_no_mount
    jmp mount_h_left

v_no_mount:
    lda input_dirs
    and #JOY_UP
    beq v_check_down
    lda #PLAYER_DIR_UP
    sta player_move_dir
    jmp v_apply
v_check_down:
    lda input_dirs
    and #JOY_DOWN
    beq v_no_stick
    lda #PLAYER_DIR_DOWN
    sta player_move_dir
    jmp v_apply

v_no_stick:
    jsr load_y_to_a
    sta tmp0                        ; save Y for nearer-arm pick
    jsr in_centre_gap_y
    bcc v_idle
    lda player_move_dir
    bne v_apply
    lda tmp0
    cmp #PLAYER_Y_HRAIL
    bcc v_force_up
    lda #PLAYER_DIR_DOWN
    sta player_move_dir
    jmp v_apply
v_force_up:
    lda #PLAYER_DIR_UP
    sta player_move_dir

v_apply:
    jmp step_v
v_idle:
    rts
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
; Mount helpers — cancel swing, remap barrel, snap axis, set rail + move_dir,
; then take one step on the new rail (design: mount begins motion immediately).
; ---------------------------------------------------------------------------
.proc mount_v_up
    lda #PLAYER_DIR_UP
    sta player_move_dir
    jsr do_mount_v
    jmp step_v
.endproc

.proc mount_v_down
    lda #PLAYER_DIR_DOWN
    sta player_move_dir
    jsr do_mount_v
    jmp step_v
.endproc

.proc mount_h_left
    lda #PLAYER_DIR_LEFT
    sta player_move_dir
    jsr do_mount_h
    jmp step_h
.endproc

.proc mount_h_right
    lda #PLAYER_DIR_RIGHT
    sta player_move_dir
    jsr do_mount_h
    jmp step_h
.endproc

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
