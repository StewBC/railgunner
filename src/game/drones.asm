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

    jsr spawn_tick
    rts
.endproc

; ---------------------------------------------------------------------------
; Cadence from wave_cadence; stop when wave_spawned >= wave_quota.
; Approach chosen from wave_approach_mask (seq walks 0..3).
; ---------------------------------------------------------------------------
.proc spawn_tick
    lda drone_spawn_timer
    beq spawn_try
    dec drone_spawn_timer
    rts
spawn_try:
    lda wave_cadence
    sta drone_spawn_timer
    lda wave_spawned
    cmp wave_quota
    bcs spawn_tick_done             ; quota full — wait for clear
    jsr count_active_c
    cmp wave_max_active
    bcs spawn_tick_done
    jsr pick_approach_from_mask     ; A = DRONE_APPROACH_*
    jsr spawn_c_approach
    bcs spawn_tick_done             ; alloc fail
    inc wave_spawned
    inc drone_spawn_seq
    inc drone_spawn_lane
spawn_tick_done:
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
    lda #DRONE_SPAWN_Y_TOP
    sta objects::obj_y_int, x
    lda #DRONE_C_SPEED
    sta objects::obj_vy_int, x
    jmp sca_flags

sca_up:
    lda #SPR_PTR_DRONE_C_UP
    sta objects::obj_sprite_ptr, x
    jsr pick_vert_lane_x
    lda #DRONE_SPAWN_Y_BOT
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
    lda #(OBJF_ALLOCATED | OBJF_RENDER | OBJF_BG_INTEREST)
    sta objects::obj_flags, x
    jsr objects::mark_dirty
    clc
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

.proc pick_horiz_lane_y
    lda drone_spawn_lane
    and #1
    bne phl_bot
    lda #DRONE_SPAWN_Y_TOP
    sta objects::obj_y_int, x
    rts
phl_bot:
    lda #DRONE_SPAWN_Y_BOT
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
    lda #DRONE_SPAWN_Y
    sta objects::obj_y_int, x
    lda #0
    sta objects::obj_vx_frac, x
    sta objects::obj_vx_lo, x
    sta objects::obj_vx_hi, x
    sta objects::obj_vy_frac, x
    lda #DRONE_B_SPEED_Y
    sta objects::obj_vy_int, x
    lda #DRONE_APPROACH_DOWN
    sta objects::obj_user, x
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
; Vertical approach: X fixed. Horizontal: keep Y in playfield.
; ---------------------------------------------------------------------------
.proc clamp_to_approach
    lda objects::obj_user, x
    cmp #DRONE_APPROACH_RIGHT
    bcc clamp_done                  ; DOWN/UP — no X drift
    lda objects::obj_y_int, x
    cmp #50
    bcs clamp_h_bot
    lda #50
    sta objects::obj_y_int, x
    rts
clamp_h_bot:
    cmp #230
    bcc clamp_done
    lda #230
    sta objects::obj_y_int, x
clamp_done:
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
