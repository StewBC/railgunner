; Drone spawn + motion.
; Step 8.3–8.4: multi-direction C driven by wave table (quota/cadence/mask).
; C only; A/B later. spawn_c_approach is the main spawn API.

.scope drones

; ---------------------------------------------------------------------------
.proc init
    ; waves::load sets timer/seq/lane from the current wave row
    rts
.endproc

; ---------------------------------------------------------------------------
; Play tick: move active drones, then maybe spawn another C.
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

    jsr spawn_tick_c
    jsr spawn_tick_ab
    rts
.endproc

; ---------------------------------------------------------------------------
; C cadence from wave_cadence; stop when wave_spawned >= wave_quota.
; ---------------------------------------------------------------------------
.proc spawn_tick_c
    lda drone_spawn_timer
    beq stc_try
    dec drone_spawn_timer
    rts
stc_try:
    lda wave_cadence
    sta drone_spawn_timer
    lda wave_spawned
    cmp wave_quota
    bcs stc_done
    jsr count_active_c
    cmp wave_max_active
    bcs stc_done
    jsr pick_approach_from_mask
    jsr spawn_c_approach
    bcs stc_done
    inc wave_spawned
    inc drone_spawn_seq
    inc drone_spawn_lane
stc_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; A/B: slower cadence, max WAVE_AB_MAX live, top/bottom only (H-rail).
; Prefer finishing B quota before A (chaff hunt vs structure).
; ---------------------------------------------------------------------------
.proc spawn_tick_ab
    lda wave_ab_timer
    beq stab_try
    dec wave_ab_timer
    rts
stab_try:
    lda #WAVE_AB_CADENCE
    sta wave_ab_timer
    ; any A/B left to spawn?
    lda wave_b_spawned
    cmp wave_b_quota
    bcc stab_have
    lda wave_a_spawned
    cmp wave_a_quota
    bcs stab_done
stab_have:
    jsr count_active_ab
    cmp #WAVE_AB_MAX
    bcs stab_done
    ; kind: B until b_quota done, else A
    lda wave_b_spawned
    cmp wave_b_quota
    bcc stab_b
    lda #OBJ_DRONE_A
    jmp stab_spawn
stab_b:
    lda #OBJ_DRONE_B
stab_spawn:
    sta tmp0                        ; kind for spawn_ab
    sta tmp1                        ; keep for counters (tmp0 may clobber)
    ; approach: alternate top/bottom only
    lda drone_spawn_lane
    and #1
    beq stab_down
    lda #DRONE_APPROACH_UP
    jmp stab_go
stab_down:
    lda #DRONE_APPROACH_DOWN
stab_go:
    jsr spawn_ab_approach           ; A=approach, tmp0=kind
    bcs stab_done
    lda tmp1
    cmp #OBJ_DRONE_A
    beq stab_inc_a
    inc wave_b_spawned
    jmp stab_lane
stab_inc_a:
    inc wave_a_spawned
stab_lane:
    inc drone_spawn_lane
stab_done:
    rts
.endproc

; A = approach dir allowed by wave_approach_mask (fallback DOWN).
.proc pick_approach_from_mask
    lda drone_spawn_seq
    and #3
    sta tmp0                        ; start index
    lda #4
    sta tmp1                        ; tries
pam_loop:
    lda tmp0
    and #3
    tax
    lda approach_bit, x
    and wave_approach_mask
    bne pam_found
    inc tmp0
    dec tmp1
    bne pam_loop
    lda #DRONE_APPROACH_DOWN
    rts
pam_found:
    txa                             ; X = approach index 0..3
    rts
.endproc

approach_bit:
    .byte WAVE_EDGE_DOWN
    .byte WAVE_EDGE_UP
    .byte WAVE_EDGE_RIGHT
    .byte WAVE_EDGE_LEFT

; A = number of active C drones (not retiring).
.proc count_active_c
    ldx #1
    lda #0
    sta tmp0
cac_loop:
    lda objects::obj_flags, x
    and #(OBJF_ALLOCATED | OBJF_RETIRING)
    cmp #OBJF_ALLOCATED
    bne cac_n
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_C
    bne cac_n
    inc tmp0
cac_n:
    inx
    cpx #OBJECT_CAPACITY
    bne cac_loop
    lda tmp0
    rts
.endproc

; A = active A+B count.
.proc count_active_ab
    ldx #1
    lda #0
    sta tmp0
cab_loop:
    lda objects::obj_flags, x
    and #(OBJF_ALLOCATED | OBJF_RETIRING)
    cmp #OBJF_ALLOCATED
    bne cab_n
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_A
    beq cab_yes
    cmp #OBJ_DRONE_B
    bne cab_n
cab_yes:
    inc tmp0
cab_n:
    inx
    cpx #OBJECT_CAPACITY
    bne cab_loop
    lda tmp0
    rts
.endproc

; A = any active A/B/C (for wave clear).
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

; ---------------------------------------------------------------------------
; Spawn one C. A = DRONE_APPROACH_*. C set on alloc fail.
; ---------------------------------------------------------------------------
.proc spawn_c_approach
    sta tmp2                        ; approach
    jsr objects::alloc
    bcc sca_ok
    rts                             ; C set
sca_ok:
    lda #OBJ_DRONE_C
    sta objects::obj_kind, x
    lda #SPR_COLOR_DRONE_C
    sta objects::obj_sprite_color, x
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

    lda tmp2
    sta objects::obj_user, x
    cmp #DRONE_APPROACH_DOWN
    beq sca_down
    cmp #DRONE_APPROACH_UP
    beq sca_up
    cmp #DRONE_APPROACH_RIGHT
    beq sca_right
    jmp sca_left

sca_down:
    lda #SPR_PTR_DRONE_C_DOWN
    sta objects::obj_sprite_ptr, x
    jsr pick_vert_lane_x
    lda #DRONE_SPAWN_Y_FROM_TOP     ; off-screen above (mux floor)
    sta objects::obj_y_int, x
    lda #DRONE_C_SPEED
    sta objects::obj_vy_int, x
    jmp sca_flags

sca_up:
    lda #SPR_PTR_DRONE_C_UP
    sta objects::obj_sprite_ptr, x
    jsr pick_vert_lane_x
    lda #DRONE_SPAWN_Y_FROM_BOT     ; off-screen below (mux-safe max)
    sta objects::obj_y_int, x
    lda #$FF                        ; -1
    sta objects::obj_vy_int, x
    jmp sca_flags

sca_right:
    ; from left edge → V-rail
    lda #SPR_PTR_DRONE_C_RIGHT
    sta objects::obj_sprite_ptr, x
    lda #DRONE_SPAWN_X_EDGE_L_LO
    sta objects::obj_x_lo, x
    lda #DRONE_SPAWN_X_EDGE_L_HI
    sta objects::obj_x_hi, x
    jsr pick_horiz_lane_y
    lda #DRONE_C_SPEED
    sta objects::obj_vx_lo, x
    lda #0
    sta objects::obj_vx_hi, x
    jmp sca_flags

sca_left:
    lda #SPR_PTR_DRONE_C_LEFT
    sta objects::obj_sprite_ptr, x
    lda #DRONE_SPAWN_X_EDGE_R_LO
    sta objects::obj_x_lo, x
    lda #DRONE_SPAWN_X_EDGE_R_HI
    sta objects::obj_x_hi, x
    jsr pick_horiz_lane_y
    lda #$FF
    sta objects::obj_vx_lo, x
    sta objects::obj_vx_hi, x

sca_flags:
    lda #DRONE_HP_C
    sta objects::obj_reserved, x    ; hits remaining
    lda #(OBJF_ALLOCATED | OBJF_RENDER | OBJF_BG_INTEREST)
    sta objects::obj_flags, x
    jsr objects::mark_dirty
    clc
    rts
.endproc

; ---------------------------------------------------------------------------
; Spawn A or B. A = approach (DOWN/UP only), tmp0 = OBJ_DRONE_A/B.
; C set on alloc fail. Preserves kind in tmp0.
; ---------------------------------------------------------------------------
.proc spawn_ab_approach
    sta tmp2                        ; approach
    jsr objects::alloc
    bcc sab_ok
    rts
sab_ok:
    lda tmp0
    sta objects::obj_kind, x
    cmp #OBJ_DRONE_A
    beq sab_a
    lda #SPR_COLOR_DRONE_B
    sta objects::obj_sprite_color, x
    lda #DRONE_HP_B
    sta objects::obj_reserved, x
    lda #DRONE_B_SPEED_Y_FRAC
    sta objects::obj_vy_frac, x
    lda #DRONE_B_SPEED_Y
    sta objects::obj_vy_int, x
    lda tmp2
    cmp #DRONE_APPROACH_UP
    beq sab_b_up
    lda #SPR_PTR_DRONE_B_DOWN
    jmp sab_ptr
sab_b_up:
    lda #SPR_PTR_DRONE_B_UP
    jmp sab_ptr
sab_a:
    lda #SPR_COLOR_DRONE_A
    sta objects::obj_sprite_color, x
    lda #DRONE_HP_A
    sta objects::obj_reserved, x
    lda #DRONE_A_SPEED_Y_FRAC
    sta objects::obj_vy_frac, x
    lda #DRONE_A_SPEED_Y
    sta objects::obj_vy_int, x
    lda tmp2
    cmp #DRONE_APPROACH_UP
    beq sab_a_up
    lda #SPR_PTR_DRONE_A_DOWN
    jmp sab_ptr
sab_a_up:
    lda #SPR_PTR_DRONE_A_UP
sab_ptr:
    sta objects::obj_sprite_ptr, x
    lda #OBJA_MULTICOLOR
    sta objects::obj_sprite_attr, x
    lda #0
    sta objects::obj_x_frac, x
    sta objects::obj_y_frac, x
    sta objects::obj_vx_frac, x
    sta objects::obj_vx_lo, x
    sta objects::obj_vx_hi, x

    lda tmp2
    sta objects::obj_user, x
    cmp #DRONE_APPROACH_UP
    beq sab_from_bot
    jsr pick_vert_lane_x
    lda #DRONE_SPAWN_Y_FROM_TOP
    sta objects::obj_y_int, x
    ; vy already set; for UP approach negate
    jmp sab_flags
sab_from_bot:
    jsr pick_vert_lane_x
    lda #DRONE_SPAWN_Y_FROM_BOT
    sta objects::obj_y_int, x
    ; negate fractional + int speed for upward travel
    lda #0
    sec
    sbc objects::obj_vy_frac, x
    sta objects::obj_vy_frac, x
    lda #0
    sbc objects::obj_vy_int, x
    sta objects::obj_vy_int, x
sab_flags:
    lda #(OBJF_ALLOCATED | OBJF_RENDER | OBJF_BG_INTEREST)
    sta objects::obj_flags, x
    jsr objects::mark_dirty
    clc
    rts
.endproc

; ---------------------------------------------------------------------------
; Bullet hit on drone mode_state: score 1, dec HP, retire at 0.
; X = drone slot (also mode_state). Clobbers A.
; ---------------------------------------------------------------------------
.proc apply_bullet_hit
    jsr score::add_hit
    ldx mode_state
    lda objects::obj_reserved, x
    beq abh_kill                    ; already 0 — kill
    sec
    sbc #1
    sta objects::obj_reserved, x
    beq abh_kill
    rts                             ; still alive
abh_kill:
    ldx mode_state
    jsr objects::retire_and_try_free
    rts
.endproc

; Set X from drone_spawn_lane (even=left band, odd=right). Preserves X slot.
.proc pick_vert_lane_x
    lda drone_spawn_lane
    and #1
    bne pvl_right
    lda #DRONE_SPAWN_X_LO
    sta objects::obj_x_lo, x
    lda #DRONE_SPAWN_X_HI
    sta objects::obj_x_hi, x
    rts
pvl_right:
    lda #DRONE_SPAWN_X_RIGHT_LO
    sta objects::obj_x_lo, x
    lda #DRONE_SPAWN_X_RIGHT_HI
    sta objects::obj_x_hi, x
    rts
.endproc

; On-screen Y for left/right approach (not off-screen — X is off-screen).
.proc pick_horiz_lane_y
    lda drone_spawn_lane
    and #1
    bne phl_bot
    lda #DRONE_LANE_Y_TOP
    sta objects::obj_y_int, x
    rts
phl_bot:
    lda #DRONE_LANE_Y_BOT
    sta objects::obj_y_int, x
    rts
.endproc

; ---------------------------------------------------------------------------
; Legacy wrappers (API for tests / older call sites)
; ---------------------------------------------------------------------------
.proc spawn_slice_mover
    lda #DRONE_APPROACH_DOWN
    jmp spawn_c_approach
.endproc

.proc ensure_slice_mover
    jsr count_active_c
    cmp #1
    bcs esm_done
    lda #DRONE_APPROACH_DOWN
    jsr spawn_c_approach
esm_done:
    rts
.endproc

.proc ensure_rail_attacker
    ; B not used in 8.3 cadence; keep for 8.5
    ldx #1
    lda #0
    sta tmp0
era_count:
    lda objects::obj_flags, x
    and #(OBJF_ALLOCATED | OBJF_RETIRING)
    cmp #OBJF_ALLOCATED
    bne era_n
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_B
    bne era_n
    inc tmp0
era_n:
    inx
    cpx #OBJECT_CAPACITY
    bne era_count
    lda tmp0
    bne era_done
    jsr spawn_rail_attacker
era_done:
    rts
.endproc

.proc spawn_rail_attacker
    jsr objects::alloc
    bcs sra_fail
    lda #OBJ_DRONE_B
    sta objects::obj_kind, x
    lda #SPR_COLOR_DRONE_B
    sta objects::obj_sprite_color, x
    lda #OBJA_MULTICOLOR
    sta objects::obj_sprite_attr, x
    lda #SPR_PTR_DRONE_B_DOWN
    sta objects::obj_sprite_ptr, x
    lda #DRONE_B_SPAWN_X_LO
    sta objects::obj_x_lo, x
    lda #DRONE_B_SPAWN_X_HI
    sta objects::obj_x_hi, x
    lda #0
    sta objects::obj_x_frac, x
    sta objects::obj_y_frac, x
    lda #DRONE_SPAWN_Y_FROM_TOP
    sta objects::obj_y_int, x
    lda #0
    sta objects::obj_vx_frac, x
    sta objects::obj_vx_lo, x
    sta objects::obj_vx_hi, x
    sta objects::obj_vy_frac, x
    lda #DRONE_B_SPEED_Y_FRAC
    sta objects::obj_vy_frac, x
    lda #DRONE_B_SPEED_Y
    sta objects::obj_vy_int, x
    lda #DRONE_APPROACH_DOWN
    sta objects::obj_user, x
    lda #DRONE_HP_B
    sta objects::obj_reserved, x
    lda #(OBJF_ALLOCATED | OBJF_RENDER | OBJF_BG_INTEREST)
    sta objects::obj_flags, x
    jsr objects::mark_dirty
sra_fail:
    rts
.endproc

; ---------------------------------------------------------------------------
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

; ---------------------------------------------------------------------------
; No soft pull-on-screen: spawn points are intentionally off-screen (edges)
; or fixed on-screen lanes (side approach Y). Motion stays straight to rail.
; ---------------------------------------------------------------------------
.proc clamp_to_approach
    rts
.endproc

; ---------------------------------------------------------------------------
; Rail arrival by approach axis; C blast then retire.
; ---------------------------------------------------------------------------
.proc check_rail_arrival
    lda objects::obj_user, x
    cmp #DRONE_APPROACH_DOWN
    beq arr_down
    cmp #DRONE_APPROACH_UP
    beq arr_up
    cmp #DRONE_APPROACH_RIGHT
    beq arr_right
    ; LEFT
    jmp arr_left

arr_down:
    lda objects::obj_y_int, x
    cmp #DRONE_RAIL_ARRIVE_Y
    bcc arr_done
    jmp arr_hit

arr_up:
    ; from bottom: y decreasing; arrive when y <= threshold
    lda objects::obj_y_int, x
    cmp #DRONE_RAIL_ARRIVE_Y_UP
    beq arr_hit
    bcc arr_hit
    rts

arr_right:
    ; from left: x increasing; arrive when x >= ARRIVE_X_R
    lda objects::obj_x_hi, x
    bne arr_hit
    lda objects::obj_x_lo, x
    cmp #DRONE_RAIL_ARRIVE_X_R
    bcc arr_done
    jmp arr_hit

arr_left:
    ; from right: x decreasing; arrive when x <= ARRIVE_X_L
    lda objects::obj_x_hi, x
    bne arr_done                    ; still x >= 256
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

.endscope
