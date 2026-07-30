; Bonus parcel delivery.
; Opposite-arm spawn, 2 drops/level at ~⅓ and ~⅔ of level_quota.
; Type priority: clear → repair → extra → filler (50% points / 25% power2x / 25% score2x).
; Sticky due bits in parcel_flags (not a deep queue).

.scope parcels

; ---------------------------------------------------------------------------
.proc init
    lda #$FF
    sta parcel_slot
    lda #0
    sta parcel_due
    sta parcel_flip
    sta parcel_drop_mask
    sta parcel_dir
    sta parcel_flags
    sta parcel_type
    rts
.endproc

; New level: reset drop marks only (in-flight parcels + due flags keep).
.proc level_reset
    lda #0
    sta parcel_due
    sta parcel_drop_mask
    rts
.endproc

; ---------------------------------------------------------------------------
; After a kill: 2 drops per level at ~⅓ and ~⅔ of level_quota (uses level_kills).
; ---------------------------------------------------------------------------
.proc on_kill
    lda level_quota
    cmp #3
    bcc ok_done
    lda level_kills
    sta mux_i
    lda level_quota
    sta mux_k

    lda mux_k
    clc
    adc #2
    bcc t1_div
    lda #255
t1_div:
    jsr div3
    sta mux_j
    lda parcel_drop_mask
    and #PARCEL_DROP_T1
    bne try_t2
    lda mux_i
    cmp mux_j
    bcc try_t2
    lda parcel_drop_mask
    ora #PARCEL_DROP_T1
    sta parcel_drop_mask
    jsr request_drop

try_t2:
    lda mux_k
    asl a
    bcc t2_sum
    lda #255
    jmp t2_div
t2_sum:
    clc
    adc #2
    bcc t2_div
    lda #255
t2_div:
    jsr div3
    sta mux_j
    lda parcel_drop_mask
    and #PARCEL_DROP_T2
    bne ok_done
    lda mux_i
    cmp mux_j
    bcc ok_done
    lda parcel_drop_mask
    ora #PARCEL_DROP_T2
    sta parcel_drop_mask
    ; Even levels: second parcel is repair (sticky if clear steals the slot)
    lda level
    and #1
    bne t2_req                      ; odd level → no repair arm
    lda parcel_flags
    ora #PARCEL_FLAG_REPAIR
    sta parcel_flags
t2_req:
    jsr request_drop
ok_done:
    rts
.endproc

; A = value / 3 (unsigned). Clobbers X.
.proc div3
    ldx #0
    cmp #0
    beq d3_done
d3_sub:
    cmp #3
    bcc d3_done
    sec
    sbc #3
    inx
    jmp d3_sub
d3_done:
    txa
    rts
.endproc

.proc request_drop
    lda parcel_slot
    cmp #$FF
    beq req_spawn
    lda #1
    sta parcel_due
    rts
req_spawn:
    jmp try_spawn
.endproc

; ---------------------------------------------------------------------------
.proc update
    ; If due and free, spawn
    lda parcel_slot
    cmp #$FF
    bne upd_live
    lda parcel_due
    beq upd_done
    lda #0
    sta parcel_due
    jsr try_spawn
    rts

upd_live:
    ldx parcel_slot
    lda objects::obj_flags, x
    and #OBJF_ALLOCATED
    bne upd_move
    ; slot lost somehow
    lda #$FF
    sta parcel_slot
    rts

upd_move:
    jsr integrate
    jsr check_offscreen
    bcs upd_collect                 ; still on field
    ; flew off — despawn, maybe due
    jsr despawn
    rts

upd_collect:
    jsr check_player_hit
    bcc upd_done
    jsr award_and_despawn
upd_done:
    rts
.endproc

; ---------------------------------------------------------------------------
.proc try_spawn
    lda parcel_slot
    cmp #$FF
    bne ts_fail
    jsr objects::alloc
    bcs ts_fail
    stx parcel_slot

    jsr choose_type                 ; → parcel_type + art/colour on slot
    ldx parcel_slot
    lda #OBJ_BONUS
    sta objects::obj_kind, x
    lda #OBJA_MULTICOLOR
    sta objects::obj_sprite_attr, x
    lda parcel_type
    sta objects::obj_reserved, x

    lda #0
    sta objects::obj_x_frac, x
    sta objects::obj_y_frac, x
    sta objects::obj_vx_frac, x
    sta objects::obj_vx_lo, x
    sta objects::obj_vx_hi, x
    sta objects::obj_vy_frac, x
    sta objects::obj_vy_int, x

    jsr pick_arm_and_place

    ldx parcel_slot
    lda #(OBJF_ALLOCATED | OBJF_RENDER)
    sta objects::obj_flags, x
    jsr objects::mark_dirty
    clc
    rts
ts_fail:
    lda #1
    sta parcel_due
    sec
    rts
.endproc

; Priority: clear → repair → extra → filler (50% points, 25% power, 25% score2x).
.proc choose_type
    ; --- clear (unless blocked after a prior clear) ---
    lda parcel_flags
    and #PARCEL_FLAG_BLOCK_CLEAR
    bne ct_repair
    jsr cargo_pressure              ; A = count of GHIJ with stack ≥ 1
    cmp #3
    bcs ct_force_clear
    cmp #2
    bcc ct_repair
    ; 2 hubs loaded → 50%
    jsr drones::rng8
    and #1
    beq ct_repair
ct_force_clear:
    lda #PARCEL_TYPE_CLEAR
    sta parcel_type
    lda parcel_flags
    and #($FF ^ PARCEL_FLAG_CLEAR)
    ora #PARCEL_FLAG_BLOCK_CLEAR     ; next parcel cannot be clear
    sta parcel_flags
    jmp ct_art

ct_repair:
    lda parcel_flags
    and #PARCEL_FLAG_REPAIR
    beq ct_extra
    lda #PARCEL_TYPE_REPAIR
    sta parcel_type
    lda parcel_flags
    and #($FF ^ (PARCEL_FLAG_REPAIR | PARCEL_FLAG_BLOCK_CLEAR))
    sta parcel_flags
    jmp ct_art

ct_extra:
    lda parcel_flags
    and #PARCEL_FLAG_EXTRA
    beq ct_filler
    ; Cap: 4 reserve — drop flag, fall through to filler
    lda lives
    cmp #MAX_RESERVE_LIVES
    bcc ct_extra_ok
    lda parcel_flags
    and #($FF ^ PARCEL_FLAG_EXTRA)
    sta parcel_flags
    jmp ct_filler
ct_extra_ok:
    lda #PARCEL_TYPE_EXTRA
    sta parcel_type
    lda parcel_flags
    and #($FF ^ (PARCEL_FLAG_EXTRA | PARCEL_FLAG_BLOCK_CLEAR))
    sta parcel_flags
    jmp ct_art

ct_filler:
    ; 50% points, 25% power 2x, 25% score 2x
    jsr drones::rng8
    cmp #128
    bcs ct_fill_2x
    lda #PARCEL_TYPE_POINTS
    sta parcel_type
    jmp ct_fill_done
ct_fill_2x:
    jsr drones::rng8
    and #1
    beq ct_fill_power
    lda #PARCEL_TYPE_SCORE2X
    sta parcel_type
    jmp ct_fill_done
ct_fill_power:
    lda #PARCEL_TYPE_POWER2X
    sta parcel_type
ct_fill_done:
    lda parcel_flags
    and #($FF ^ PARCEL_FLAG_BLOCK_CLEAR)
    sta parcel_flags
ct_art:
    ldx parcel_slot
    ldy parcel_type
    lda type_ptr_tbl, y
    sta objects::obj_sprite_ptr, x
    lda type_color_tbl, y
    sta objects::obj_sprite_color, x
    rts

type_ptr_tbl:
    .byte SPR_PTR_ADD_SCORE         ; POINTS
    .byte SPR_PTR_ADD_2X            ; SCORE2X
    .byte SPR_PTR_ADD_2X            ; POWER2X
    .byte SPR_PTR_ADD_CLEAR         ; CLEAR
    .byte SPR_PTR_ADD_EXTRA         ; EXTRA
    .byte SPR_PTR_ADD_REPAIR        ; REPAIR

type_color_tbl:
    .byte SPR_COLOR_PARCEL_SCORE
    .byte SPR_COLOR_PARCEL_SCORE2X
    .byte SPR_COLOR_PARCEL_POWER2X
    .byte SPR_COLOR_PARCEL_CLEAR
    .byte SPR_COLOR_PARCEL_EXTRA
    .byte SPR_COLOR_PARCEL_REPAIR
.endproc

; A = number of GHIJ tiles with stack ≥ 1 (0..4)
.proc cargo_pressure
    ldy #0
    ldx #0
cp_loop:
    lda rail_data::ghij_stack, x
    beq cp_next
    iny
cp_next:
    inx
    cpx #4
    bcc cp_loop
    tya
    rts
.endproc

; Choose perpendicular arm, apply global flip, set pos + velocity.
; X = parcel slot on entry. player::at_intersection / load_* clobber X →
; always reload from parcel_slot before any obj_*,x write.
.proc pick_arm_and_place
    ; Decide axis: 0 = H (W/E), 1 = V (N/S)
    jsr player::at_intersection
    bcs pap_centre
    lda player_rail
    cmp #PLAYER_RAIL_V
    beq pap_player_v
    ; player on H → parcel on V
    lda #1
    jmp pap_axis
pap_player_v:
    ; player on V → parcel on H
    lda #0
    jmp pap_axis
pap_centre:
    ; travel N/S → H arm; E/W → V arm
    lda player_move_dir
    cmp #PLAYER_DIR_UP
    beq pap_axis_h
    cmp #PLAYER_DIR_DOWN
    beq pap_axis_h
    cmp #PLAYER_DIR_LEFT
    beq pap_axis_v
    cmp #PLAYER_DIR_RIGHT
    beq pap_axis_v
    ; no travel: default opposite of rail
    lda player_rail
    cmp #PLAYER_RAIL_V
    beq pap_axis_h
pap_axis_v:
    lda #1
    jmp pap_axis
pap_axis_h:
    lda #0
pap_axis:
    sta mux_i                       ; 0=H 1=V

    ; Flip global end
    lda parcel_flip
    eor #1
    sta parcel_flip

    ldx parcel_slot                  ; restore after player helpers
    lda mux_i
    bne pap_place_v
    jmp pap_place_h

pap_place_h:
    ; Y = H-rail; start left or right from flip
    lda #PLAYER_Y_HRAIL
    sta objects::obj_y_int, x
    lda parcel_flip
    beq pap_h_from_left
    ; from right → go left
    lda #DRONE_SPAWN_X_EDGE_R_LO
    sta objects::obj_x_lo, x
    lda #DRONE_SPAWN_X_EDGE_R_HI
    sta objects::obj_x_hi, x
    lda #0
    sta objects::obj_vx_frac, x
    sec
    sbc #PARCEL_SPEED
    sta objects::obj_vx_lo, x
    lda #0
    sbc #0
    and #1
    sta objects::obj_vx_hi, x
    lda #SPR_DIR_LEFT
    sta parcel_dir
    sta objects::obj_user, x
    rts
pap_h_from_left:
    lda #DRONE_SPAWN_X_EDGE_L_LO
    sta objects::obj_x_lo, x
    lda #DRONE_SPAWN_X_EDGE_L_HI
    sta objects::obj_x_hi, x
    lda #0
    sta objects::obj_vx_frac, x
    sta objects::obj_vx_hi, x
    lda #PARCEL_SPEED
    sta objects::obj_vx_lo, x
    lda #SPR_DIR_RIGHT
    sta parcel_dir
    sta objects::obj_user, x
    rts

pap_place_v:
    lda #PLAYER_X_VRAIL
    sta objects::obj_x_lo, x
    lda #0
    sta objects::obj_x_hi, x
    lda parcel_flip
    beq pap_v_from_top
    ; from bottom → go up
    lda #DRONE_SPAWN_Y_FROM_BOT
    sta objects::obj_y_int, x
    lda #0
    sta objects::obj_vy_frac, x
    sec
    sbc #PARCEL_SPEED
    sta objects::obj_vy_int, x
    lda #SPR_DIR_UP
    sta parcel_dir
    sta objects::obj_user, x
    rts
pap_v_from_top:
    lda #DRONE_SPAWN_Y_FROM_TOP
    sta objects::obj_y_int, x
    lda #0
    sta objects::obj_vy_frac, x
    lda #PARCEL_SPEED
    sta objects::obj_vy_int, x
    lda #SPR_DIR_DOWN
    sta parcel_dir
    sta objects::obj_user, x
    rts
.endproc

.proc integrate
    lda objects::obj_x_frac, x
    clc
    adc objects::obj_vx_frac, x
    sta objects::obj_x_frac, x
    lda objects::obj_x_lo, x
    adc objects::obj_vx_lo, x
    sta objects::obj_x_lo, x
    lda objects::obj_x_hi, x
    adc objects::obj_vx_hi, x
    and #1
    sta objects::obj_x_hi, x

    lda objects::obj_y_frac, x
    clc
    adc objects::obj_vy_frac, x
    sta objects::obj_y_frac, x
    lda objects::obj_y_int, x
    adc objects::obj_vy_int, x
    sta objects::obj_y_int, x
    jsr objects::mark_dirty
    rts
.endproc

; C set = still on field; C clear = flew off
.proc check_offscreen
    lda parcel_dir
    cmp #SPR_DIR_RIGHT
    beq co_right
    cmp #SPR_DIR_LEFT
    beq co_left
    cmp #SPR_DIR_DOWN
    beq co_down
    ; UP
    lda objects::obj_y_int, x
    cmp #MUX_MIN_SPRITE_Y
    bcc co_off
    sec
    rts
co_down:
    lda objects::obj_y_int, x
    cmp #DRONE_SPAWN_Y_FROM_BOT
    bcs co_off
    sec
    rts
co_right:
    ; Off when X >= ~344 (hi set and lo >= edge lo)
    lda objects::obj_x_hi, x
    beq co_on
    lda objects::obj_x_lo, x
    cmp #DRONE_SPAWN_X_EDGE_R_LO
    bcs co_off
    sec
    rts
co_left:
    lda objects::obj_x_hi, x
    bne co_on                       ; still on right half
    lda objects::obj_x_lo, x
    cmp #4
    bcc co_off
co_on:
    sec
    rts
co_off:
    clc
    rts
.endproc

; C set = hit player
.proc check_player_hit
    ; Parcel box in pixel space vs player box
    ; parcel left = x + PARCEL_HIT_X0
    ldx parcel_slot
    lda objects::obj_x_lo, x
    clc
    adc #PARCEL_HIT_X0
    sta tmp0
    lda objects::obj_x_hi, x
    adc #0
    sta tmp1                        ; parcel left 16-bit-ish (hi 0/1)

    lda objects::obj_x_lo, x
    clc
    adc #PARCEL_HIT_X1
    sta mux_i
    lda objects::obj_x_hi, x
    adc #0
    sta mux_j                       ; parcel right

    ; player left ≈ x+4, right ≈ x+20 (body)
    ldx #0
    lda objects::obj_x_lo, x
    clc
    adc #4
    sta mux_k
    lda objects::obj_x_hi, x
    adc #0
    sta draw_i                      ; player left

    lda objects::obj_x_lo, x
    clc
    adc #20
    sta draw_j
    lda objects::obj_x_hi, x
    adc #0                          ; player right hi in A — keep in...
    ; Use simplified 8-bit if both in low X
    ; Overlap X: parcel_left < player_right && player_left < parcel_right
    ; Compare lo only when hi matches — rough OK for playfield

    ldx parcel_slot
    lda objects::obj_y_int, x
    clc
    adc #PARCEL_HIT_Y0
    sta tmp0                        ; parcel top
    lda objects::obj_y_int, x
    clc
    adc #PARCEL_HIT_Y1
    sta tmp1                        ; parcel bot

    ldx #0
    lda objects::obj_y_int, x
    clc
    adc #3
    sta mux_i                       ; player top
    lda objects::obj_y_int, x
    clc
    adc #18
    sta mux_j                       ; player bot

    ; Y overlap: ptop < pbot_player && pl_top < pbot
    lda tmp0
    cmp mux_j
    bcs cph_no
    lda mux_i
    cmp tmp1
    bcs cph_no

    ; X overlap using lo bytes (MSB rare for both on rail)
    ldx parcel_slot
    lda objects::obj_x_lo, x
    clc
    adc #PARCEL_HIT_X0
    sta tmp0
    lda objects::obj_x_lo, x
    clc
    adc #PARCEL_HIT_X1
    sta tmp1
    ldx #0
    lda objects::obj_x_lo, x
    clc
    adc #4
    sta mux_i
    lda objects::obj_x_lo, x
    clc
    adc #20
    sta mux_j

    lda tmp0
    cmp mux_j
    bcs cph_no
    lda mux_i
    cmp tmp1
    bcs cph_no
    sec
    rts
cph_no:
    clc
    rts
.endproc

.proc award_if_active
    lda parcel_slot
    cmp #$FF
    beq aia_done
    jsr award_and_despawn
aia_done:
    rts
.endproc

.proc award_and_despawn
    jsr award_payload
    jmp despawn
.endproc

.proc award_payload
    lda parcel_type
    cmp #PARCEL_TYPE_SCORE2X
    beq ap_score2x
    cmp #PARCEL_TYPE_POWER2X
    beq ap_power2x
    cmp #PARCEL_TYPE_CLEAR
    beq ap_clear
    cmp #PARCEL_TYPE_EXTRA
    beq ap_extra
    cmp #PARCEL_TYPE_REPAIR
    beq ap_repair
    ; POINTS — +(5*level) from table
    jmp ap_points

ap_score2x:
    lda #1
    sta score_2x
    rts
ap_power2x:
    lda #1
    sta power_2x
    rts
ap_clear:
    lda #1
    sta clear_armed                 ; wipe on next centre pass
    rts
ap_extra:
    lda lives
    cmp #MAX_RESERVE_LIVES
    bcs ap_done
    inc lives
    lda #1
    sta hud_status_dirty
ap_done:
    rts
ap_repair:
    jmp rail::begin_repair

ap_points:
    lda level
    beq ap_l1
    cmp #MAX_LEVEL + 1
    bcc ap_idx
    lda #MAX_LEVEL
    jmp ap_idx
ap_l1:
    lda #1
ap_idx:
    tax
    dex                             ; 0-based
    lda score_parcel_points, x
    jsr score::add_n
    rts
.endproc

.proc despawn
    lda parcel_slot
    cmp #$FF
    beq dsp_due
    tax
    jsr objects::retire_and_try_free
    lda #$FF
    sta parcel_slot
dsp_due:
    lda parcel_due
    beq dsp_done
    lda #0
    sta parcel_due
    jsr try_spawn
dsp_done:
    rts
.endproc

; Score parcel points by level index 0..14 (level 1..15)
score_parcel_points:
    .byte 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75

.endscope
