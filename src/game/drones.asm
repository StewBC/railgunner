; Drone motion + launcher v2 (dice / kill targets / piggyback C).
; waves::load fills wave_* params; note_kill on bullet kills only.

.scope drones

; ---------------------------------------------------------------------------
.proc init
    rts
.endproc

; ---------------------------------------------------------------------------
.proc update
    ldx #1
upd_loop:
    lda objects::obj_flags, x
    and #(OBJF_ALLOCATED | OBJF_RETIRING)
    cmp #OBJF_ALLOCATED
    bne upd_next
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_A
    bcc upd_next
    cmp #OBJ_BONUS
    bcs upd_next
    jsr integrate_slot
    jsr clamp_to_approach
    jsr check_rail_arrival
upd_next:
    inx
    cpx #OBJECT_CAPACITY
    bne upd_loop

    jsr spawn_tick_main
    jsr spawn_tick_piggy
    rts
.endproc

; ===========================================================================
; RNG + cooldown
; ===========================================================================
.proc rng8
    lda rng_state
    bne r8_go
    lda frame_count
    ora #1
    sta rng_state
r8_go:
    asl a
    bcc r8_store
    eor #$1d
r8_store:
    sta rng_state
    rts
.endproc

; A = exclusive max (1..255) → A = 0..max-1
.proc rng_mod
    sta tmp0
    beq rm_zero
    jsr rng8
rm_loop:
    cmp tmp0
    bcc rm_ok
    sec
    sbc tmp0
    jmp rm_loop
rm_ok:
    rts
rm_zero:
    lda #0
    rts
.endproc

; Set drone_spawn_timer = random in [wave_cd_min, wave_cd_max]
.proc roll_cooldown
    lda wave_cd_max
    sec
    sbc wave_cd_min
    clc
    adc #1                          ; span
    jsr rng_mod
    clc
    adc wave_cd_min
    sta drone_spawn_timer
    rts
.endproc

; ===========================================================================
; Main launch: dice type + quad + approach + coord until kill quotas met
; ===========================================================================
.proc spawn_tick_main
    lda drone_spawn_timer
    beq stm_try
    dec drone_spawn_timer
    rts
stm_try:
    jsr roll_cooldown
    jsr kills_remaining
    beq stm_done                    ; all kill debts paid
    jsr count_active_drones
    cmp wave_max_active
    bcs stm_done
    jsr roll_type                   ; A = OBJ_DRONE_* or 0 if none
    beq stm_done
    sta spawn_kind                  ; NOT tmp0 — rng_mod clobbers tmp0
    jsr roll_quad                   ; A = 0..3 quad index
    sta spawn_quad
    jsr roll_approach_for_quad      ; A = approach (uses spawn_quad)
    sta spawn_approach
    jsr spawn_drone
    bcs stm_done
    lda spawn_quad
    sta spawn_last_quad
    ; piggyback C after A/B
    lda spawn_kind
    cmp #OBJ_DRONE_C
    beq stm_done
    lda wave_flags
    and #WAVE_F_PIGGY_C
    beq stm_done
    jsr schedule_piggy
stm_done:
    rts
.endproc

; A = 0 if all kill debts 0, else nonzero
.proc kills_remaining
    lda wave_kills_c
    cmp wave_quota
    bcc kr_yes
    lda wave_kills_b
    cmp wave_b_quota
    bcc kr_yes
    lda wave_kills_a
    cmp wave_a_quota
    bcc kr_yes
    lda #0
    rts
kr_yes:
    lda #1
    rts
.endproc

; Weighted among types with remaining kill debt.
; C only if WAVE_F_MAIN_C or no A/B debt.
; A = kind or 0
.proc roll_type
    lda #0
    sta mux_i                       ; weight C
    sta mux_j                       ; weight B
    sta mux_k                       ; weight A

    lda wave_kills_c
    cmp wave_quota
    bcs rt_b
    lda wave_flags
    and #WAVE_F_MAIN_C
    bne rt_c_ok
    ; C only if no A/B debt left to prefer main A/B
    lda wave_kills_b
    cmp wave_b_quota
    bcc rt_b
    lda wave_kills_a
    cmp wave_a_quota
    bcc rt_b
rt_c_ok:
    lda #4
    sta mux_i
rt_b:
    lda wave_kills_b
    cmp wave_b_quota
    bcs rt_a
    lda #5
    sta mux_j
rt_a:
    lda wave_kills_a
    cmp wave_a_quota
    bcs rt_sum
    lda #3
    sta mux_k
rt_sum:
    lda mux_i
    clc
    adc mux_j
    adc mux_k
    beq rt_none
    jsr rng_mod                     ; 0..sum-1
    cmp mux_i
    bcc rt_pick_c
    sbc mux_i
    cmp mux_j
    bcc rt_pick_b
    lda #OBJ_DRONE_A
    rts
rt_pick_c:
    lda #OBJ_DRONE_C
    rts
rt_pick_b:
    lda #OBJ_DRONE_B
    rts
rt_none:
    lda #0
    rts
.endproc

; A = quad index 0=Q1 .. 3=Q4 among wave_quad_mask; anti-streak vs spawn_last_quad
.proc roll_quad
    ; collect up to 4 candidates in stack via bit scan
    lda #0
    sta mux_i                       ; count
    ldx #0
rq_scan:
    lda quad_bit, x
    and wave_quad_mask
    beq rq_next
    ; skip if matches last and we have alternatives
    cpx spawn_last_quad
    bne rq_add
    lda mux_i
    beq rq_add                      ; only choice so far — allow
    ; if more bits exist after, skip this one for now
    stx mux_j
    jsr count_quad_bits
    cmp #2
    bcc rq_add_force
    jmp rq_next
rq_add_force:
    ldx mux_j
rq_add:
    txa
    ldy mux_i
    sta spawn_quad_list, y
    inc mux_i
rq_next:
    inx
    cpx #4
    bcc rq_scan
    lda mux_i
    bne rq_pick
    lda #3                          ; fallback Q4
    rts
rq_pick:
    jsr rng_mod
    tax
    lda spawn_quad_list, x
    rts
.endproc

quad_bit:
    .byte WAVE_Q1, WAVE_Q2, WAVE_Q3, WAVE_Q4

.proc count_quad_bits
    lda #0
    sta tmp0
    ldx #0
cqb:
    lda quad_bit, x
    and wave_quad_mask
    beq cqb_n
    inc tmp0
cqb_n:
    inx
    cpx #4
    bcc cqb
    lda tmp0
    rts
.endproc

; spawn_quad = 0..3 → A = approach (random among 2 legal)
.proc roll_approach_for_quad
    jsr rng8
    and #1
    sta mux_i                       ; 0 or 1 choice (avoid tmp0)
    lda spawn_quad
    asl a
    tax                             ; *2 into table
    lda approach_pair, x
    ldy mux_i
    beq raf_done
    lda approach_pair+1, x
raf_done:
    rts
.endproc

; Per quad: two legal approaches (DOWN/UP/RIGHT/LEFT)
approach_pair:
    .byte DRONE_APPROACH_DOWN, DRONE_APPROACH_LEFT   ; Q1 UR
    .byte DRONE_APPROACH_UP,   DRONE_APPROACH_LEFT   ; Q2 LR
    .byte DRONE_APPROACH_UP,   DRONE_APPROACH_RIGHT  ; Q3 LL
    .byte DRONE_APPROACH_DOWN, DRONE_APPROACH_RIGHT  ; Q4 UL

; ===========================================================================
; Piggyback C
; ===========================================================================
.proc schedule_piggy
    lda piggy_timer
    bne sp_done                     ; one pending only
    lda #WAVE_PIGGY_SPAN
    jsr rng_mod
    clc
    adc #WAVE_PIGGY_MIN
    sta piggy_timer
    lda spawn_quad
    sta piggy_quad
    lda spawn_approach
    sta piggy_approach
sp_done:
    rts
.endproc

.proc spawn_tick_piggy
    lda piggy_timer
    beq stp_done
    dec piggy_timer
    bne stp_done
    jsr count_active_drones
    cmp wave_max_active
    bcs stp_done
    lda #OBJ_DRONE_C
    sta spawn_kind
    lda piggy_quad
    sta spawn_quad
    jsr rng8
    and #1
    beq stp_same
    jsr roll_approach_for_quad
    jmp stp_go
stp_same:
    lda piggy_approach
stp_go:
    sta spawn_approach
    jsr spawn_drone
stp_done:
    rts
.endproc

; ===========================================================================
; spawn_drone: spawn_kind / spawn_quad / spawn_approach → C set fail
; ===========================================================================
.proc spawn_drone
    jsr objects::alloc
    bcc sd_ok
    rts
sd_ok:
    lda spawn_kind
    sta objects::obj_kind, x
    cmp #OBJ_DRONE_A
    beq sd_a
    cmp #OBJ_DRONE_B
    beq sd_b
    ; C
    lda #SPR_COLOR_DRONE_C
    sta objects::obj_sprite_color, x
    lda #DRONE_HP_C
    sta objects::obj_reserved, x
    jmp sd_common
sd_b:
    lda #SPR_COLOR_DRONE_B
    sta objects::obj_sprite_color, x
    lda #DRONE_HP_B
    sta objects::obj_reserved, x
    jmp sd_common
sd_a:
    lda #SPR_COLOR_DRONE_A
    sta objects::obj_sprite_color, x
    lda #DRONE_HP_A
    sta objects::obj_reserved, x
sd_common:
    lda #OBJA_MULTICOLOR
    sta objects::obj_sprite_attr, x
    lda #0
    sta objects::obj_x_frac, x
    sta objects::obj_y_frac, x
    sta objects::obj_vx_frac, x
    sta objects::obj_vy_frac, x
    sta objects::obj_vx_lo, x
    sta objects::obj_vx_hi, x
    sta objects::obj_vy_int, x
    lda spawn_approach
    sta objects::obj_user, x

    ; pointer + velocity + position by approach
    cmp #DRONE_APPROACH_DOWN
    beq sd_down
    cmp #DRONE_APPROACH_UP
    beq sd_up
    cmp #DRONE_APPROACH_RIGHT
    beq sd_right
    jmp sd_left

sd_down:
    jsr ptr_for_kind_down
    jsr place_x_for_quad_vert
    lda #DRONE_SPAWN_Y_FROM_TOP
    sta objects::obj_y_int, x
    jsr speed_down
    jmp sd_flags

sd_up:
    jsr ptr_for_kind_up
    jsr place_x_for_quad_vert
    lda #DRONE_SPAWN_Y_FROM_BOT
    sta objects::obj_y_int, x
    jsr speed_up
    jmp sd_flags

sd_right:
    jsr ptr_for_kind_right
    lda #DRONE_SPAWN_X_EDGE_L_LO
    sta objects::obj_x_lo, x
    lda #DRONE_SPAWN_X_EDGE_L_HI
    sta objects::obj_x_hi, x
    jsr place_y_for_quad_horiz
    jsr speed_right
    jmp sd_flags

sd_left:
    jsr ptr_for_kind_left
    lda #DRONE_SPAWN_X_EDGE_R_LO
    sta objects::obj_x_lo, x
    lda #DRONE_SPAWN_X_EDGE_R_HI
    sta objects::obj_x_hi, x
    jsr place_y_for_quad_horiz
    jsr speed_left

sd_flags:
    lda #(OBJF_ALLOCATED | OBJF_RENDER | OBJF_BG_INTEREST)
    sta objects::obj_flags, x
    jsr objects::mark_dirty
    clc
    rts
.endproc

; --- pointers (kind in spawn_kind) ---
.proc ptr_for_kind_down
    lda spawn_kind
    cmp #OBJ_DRONE_A
    beq pfd_a
    cmp #OBJ_DRONE_B
    beq pfd_b
    lda #SPR_PTR_DRONE_C_DOWN
    jmp pfd_st
pfd_b:
    lda #SPR_PTR_DRONE_B_DOWN
    jmp pfd_st
pfd_a:
    lda #SPR_PTR_DRONE_A_DOWN
pfd_st:
    sta objects::obj_sprite_ptr, x
    rts
.endproc

.proc ptr_for_kind_up
    lda spawn_kind
    cmp #OBJ_DRONE_A
    beq pfu_a
    cmp #OBJ_DRONE_B
    beq pfu_b
    lda #SPR_PTR_DRONE_C_UP
    jmp pfu_st
pfu_b:
    lda #SPR_PTR_DRONE_B_UP
    jmp pfu_st
pfu_a:
    lda #SPR_PTR_DRONE_A_UP
pfu_st:
    sta objects::obj_sprite_ptr, x
    rts
.endproc

.proc ptr_for_kind_right
    lda spawn_kind
    cmp #OBJ_DRONE_C
    beq pfr_c
    cmp #OBJ_DRONE_A
    beq pfr_a
    lda #SPR_PTR_DRONE_B_RIGHT
    jmp pfr_st
pfr_a:
    lda #SPR_PTR_DRONE_A_RIGHT
    jmp pfr_st
pfr_c:
    lda #SPR_PTR_DRONE_C_RIGHT
pfr_st:
    sta objects::obj_sprite_ptr, x
    rts
.endproc

.proc ptr_for_kind_left
    lda spawn_kind
    cmp #OBJ_DRONE_C
    beq pfl_c
    cmp #OBJ_DRONE_A
    beq pfl_a
    lda #SPR_PTR_DRONE_B_LEFT
    jmp pfl_st
pfl_a:
    lda #SPR_PTR_DRONE_A_LEFT
    jmp pfl_st
pfl_c:
    lda #SPR_PTR_DRONE_C_LEFT
pfl_st:
    sta objects::obj_sprite_ptr, x
    rts
.endproc

; ---------------------------------------------------------------------------
; Speed: pick velocity tier (class max + geometric step-down), then table lookup.
; build_speed_mag → tmp0=frac, tmp1=int (positive magnitude)
; ---------------------------------------------------------------------------
.proc speed_down
    lda #DRONE_APPROACH_DOWN
    jsr build_speed_mag
    lda tmp0
    sta objects::obj_vy_frac, x
    lda tmp1
    sta objects::obj_vy_int, x
    rts
.endproc

.proc speed_up
    lda #DRONE_APPROACH_UP
    jsr build_speed_mag
    lda #0
    sec
    sbc tmp0
    sta objects::obj_vy_frac, x
    lda #0
    sbc tmp1
    sta objects::obj_vy_int, x
    rts
.endproc

.proc speed_right
    lda #DRONE_APPROACH_RIGHT
    jsr build_speed_mag
    lda tmp0
    sta objects::obj_vx_frac, x
    lda tmp1
    sta objects::obj_vx_lo, x
    lda #0
    sta objects::obj_vx_hi, x
    rts
.endproc

.proc speed_left
    lda #DRONE_APPROACH_LEFT
    jsr build_speed_mag
    lda #0
    sec
    sbc tmp0
    sta objects::obj_vx_frac, x
    lda #0
    sbc tmp1
    sta objects::obj_vx_lo, x
    lda #0
    sbc #0
    and #1
    sta objects::obj_vx_hi, x
    rts
.endproc

; A = approach (0..3). Uses spawn_kind + drone_speed_cap.
; Out: tmp0=frac, tmp1=int. Clobbers mux_i, mux_j (X object slot preserved)
.proc build_speed_mag
    sta mux_j                       ; approach
    jsr pick_speed_tier             ; A = 0-based tier
    ; index = tier * 8 + approach * 2
    asl a
    asl a
    asl a                           ; *8
    sta mux_i
    lda mux_j
    asl a                           ; approach * 2
    clc
    adc mux_i
    tay
    lda drone_vel_tier, y
    sta tmp0
    lda drone_vel_tier + 1, y
    sta tmp1
    ; Never zero
    lda tmp0
    ora tmp1
    bne bsm_done
    lda #1
    sta tmp0
bsm_done:
    rts
.endproc

; Class max tier from drone_speed_cap, then geometric step-down toward 1.
; P(stop) = 50% each step → near-max common, far-slow rare.
; Out: A = 0-based tier index. Clobbers mux_i. Preserves X.
.proc pick_speed_tier
    lda drone_speed_cap
    bne pst_cap_ok
    lda #1
pst_cap_ok:
    cmp #MAX_LEVEL + 1
    bcc pst_cap_clamped
    lda #MAX_LEVEL
pst_cap_clamped:
    ; Class offsets: C=0, B=1, A=2 below cap (floor 1)
    sta mux_i
    lda spawn_kind
    cmp #OBJ_DRONE_A
    beq pst_a
    cmp #OBJ_DRONE_B
    beq pst_b
    ; C — full cap
    jmp pst_have_max
pst_b:
    lda mux_i
    sec
    sbc #DRONE_TIER_OFF_B
    bcs pst_b_ok
    lda #1
pst_b_ok:
    cmp #1
    bcs pst_b_store
    lda #1
pst_b_store:
    sta mux_i
    jmp pst_have_max
pst_a:
    lda mux_i
    sec
    sbc #DRONE_TIER_OFF_A
    bcs pst_a_ok
    lda #1
pst_a_ok:
    cmp #1
    bcs pst_a_store
    lda #1
pst_a_store:
    sta mux_i
pst_have_max:
    ; mux_i = 1-based max tier for this class
    lda mux_i
    cmp #1
    bcs pst_max_ge1
    lda #1
    sta mux_i
pst_max_ge1:
pst_step:
    lda mux_i
    cmp #2
    bcc pst_done                    ; already at tier 1
    jsr rng8
    and #1
    bne pst_done                    ; 50% keep current
    dec mux_i                       ; else step one tier slower
    jmp pst_step
pst_done:
    lda mux_i
    sec
    sbc #1                          ; 0-based table index
    rts
.endproc

; Random X in left or right band from spawn_quad
.proc place_x_for_quad_vert
    lda spawn_quad
    cmp #1
    beq px_right                    ; Q2
    cmp #0
    beq px_right                    ; Q1
    lda #DRONE_BAND_X_L1
    sec
    sbc #DRONE_BAND_X_L0
    clc
    adc #1
    jsr rng_mod
    clc
    adc #DRONE_BAND_X_L0
    sta objects::obj_x_lo, x
    lda #0
    sta objects::obj_x_hi, x
    rts
px_right:
    lda #DRONE_BAND_X_R1
    sec
    sbc #DRONE_BAND_X_R0
    clc
    adc #1
    jsr rng_mod
    clc
    adc #DRONE_BAND_X_R0
    sta objects::obj_x_lo, x
    lda #0
    sta objects::obj_x_hi, x
    rts
.endproc

.proc place_y_for_quad_horiz
    lda spawn_quad
    cmp #2
    beq py_bot                      ; Q3
    cmp #1
    beq py_bot                      ; Q2
    lda #DRONE_BAND_Y_T1
    sec
    sbc #DRONE_BAND_Y_T0
    clc
    adc #1
    jsr rng_mod
    clc
    adc #DRONE_BAND_Y_T0
    sta objects::obj_y_int, x
    rts
py_bot:
    lda #DRONE_BAND_Y_B1
    sec
    sbc #DRONE_BAND_Y_B0
    clc
    adc #1
    jsr rng_mod
    clc
    adc #DRONE_BAND_Y_B0
    sta objects::obj_y_int, x
    rts
.endproc

; ===========================================================================
; Counts / combat
; ===========================================================================
.proc count_active_drones
    ldx #1
    lda #0
    sta tmp0
cad_loop:
    lda objects::obj_flags, x
    and #(OBJF_ALLOCATED | OBJF_RETIRING)
    cmp #OBJF_ALLOCATED
    bne cad_n
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_A
    bcc cad_n
    cmp #OBJ_BONUS
    bcs cad_n
    inc tmp0
cad_n:
    inx
    cpx #OBJECT_CAPACITY
    bne cad_loop
    lda tmp0
    rts
.endproc

.proc apply_bullet_hit
    jsr score::add_hit
    ldx mode_state
    lda objects::obj_reserved, x
    beq abh_kill
    sec
    sbc #1
    sta objects::obj_reserved, x
    beq abh_kill
    rts
abh_kill:
    ldx mode_state
    jsr waves::note_kill
    ldx mode_state
    jsr objects::retire_and_try_free
    rts
.endproc

; ===========================================================================
; Motion / arrival (unchanged logic)
; ===========================================================================
.proc integrate_slot
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

.proc clamp_to_approach
    rts
.endproc

.proc check_rail_arrival
    lda objects::obj_user, x
    cmp #DRONE_APPROACH_DOWN
    beq arr_down
    cmp #DRONE_APPROACH_UP
    beq arr_up
    cmp #DRONE_APPROACH_RIGHT
    beq arr_right
    jmp arr_left

arr_down:
    lda objects::obj_y_int, x
    cmp #DRONE_RAIL_ARRIVE_Y
    bcc arr_done
    jmp arr_hit
arr_up:
    lda objects::obj_y_int, x
    cmp #DRONE_RAIL_ARRIVE_Y_UP
    beq arr_hit
    bcc arr_hit
    rts
arr_right:
    lda objects::obj_x_hi, x
    bne arr_hit
    lda objects::obj_x_lo, x
    cmp #DRONE_RAIL_ARRIVE_X_R
    bcc arr_done
    jmp arr_hit
arr_left:
    lda objects::obj_x_hi, x
    bne arr_done
    lda objects::obj_x_lo, x
    cmp #DRONE_RAIL_ARRIVE_X_L
    beq arr_hit
    bcc arr_hit
    rts

arr_hit:
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_C
    beq arr_c
    cmp #OBJ_DRONE_A
    beq arr_ab
    cmp #OBJ_DRONE_B
    beq arr_ab
    jmp arr_retire
arr_c:
    txa
    pha
    jsr player::apply_c_blast_full
    pla
    tax
    jmp arr_retire
arr_ab:
    txa
    pha
    jsr rail::apply_ab_hit
    pla
    tax
arr_retire:
    jsr objects::retire_and_try_free
arr_done:
    rts
.endproc

; Legacy test helpers
.proc spawn_c_approach
    sta spawn_approach
    lda #OBJ_DRONE_C
    sta spawn_kind
    lda #3
    sta spawn_quad
    jmp spawn_drone
.endproc

.proc spawn_slice_mover
    lda #DRONE_APPROACH_DOWN
    jmp spawn_c_approach
.endproc

.endscope
