; Drone spawn + motion.
; Stage 2: one C (UL, player threat) + one B (UR, rail threat); vertical only.
; Later: waves of 3 per quadrant.

.scope drones

; ---------------------------------------------------------------------------
.proc init
    jsr ensure_slice_mover
    jsr ensure_rail_attacker
    rts
.endproc

; ---------------------------------------------------------------------------
; Keep exactly one active C in play (UL).
; ---------------------------------------------------------------------------
.proc ensure_slice_mover
    ldx #1
    lda #0
    sta tmp0
count_c:
    lda objects::obj_flags, x
    and #(OBJF_ALLOCATED | OBJF_RETIRING)
    cmp #OBJF_ALLOCATED
    bne count_c_n
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_C
    bne count_c_n
    inc tmp0
count_c_n:
    inx
    cpx #OBJECT_CAPACITY
    bne count_c
    lda tmp0
    bne ensure_c_done
    jsr spawn_slice_mover
ensure_c_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; Keep exactly one active B in play (UR) — damages rail on arrival.
; ---------------------------------------------------------------------------
.proc ensure_rail_attacker
    ldx #1
    lda #0
    sta tmp0
count_b:
    lda objects::obj_flags, x
    and #(OBJF_ALLOCATED | OBJF_RETIRING)
    cmp #OBJF_ALLOCATED
    bne count_b_n
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_B
    bne count_b_n
    inc tmp0
count_b_n:
    inx
    cpx #OBJECT_CAPACITY
    bne count_b
    lda tmp0
    bne ensure_b_done
    jsr spawn_rail_attacker
ensure_b_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; One C in upper-left, nose down → H-rail (player blast on arrival).
; ---------------------------------------------------------------------------
.proc spawn_slice_mover
    jsr objects::alloc
    bcs spawn_c_fail

    lda #OBJ_DRONE_C
    sta objects::obj_kind, x
    lda #SPR_COLOR_DRONE_C
    sta objects::obj_sprite_color, x
    lda #OBJA_MULTICOLOR
    sta objects::obj_sprite_attr, x
    lda #SPR_PTR_DRONE_C_DOWN
    sta objects::obj_sprite_ptr, x

    lda #DRONE_SPAWN_X_LO
    sta objects::obj_x_lo, x
    lda #DRONE_SPAWN_X_HI
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
    lda #DRONE_C_SPEED_Y
    sta objects::obj_vy_int, x

    lda #QUAD_UL
    sta objects::obj_user, x

    lda #(OBJF_ALLOCATED | OBJF_RENDER | OBJF_BG_INTEREST)
    sta objects::obj_flags, x
    jsr objects::mark_dirty
spawn_c_fail:
    rts
.endproc

; ---------------------------------------------------------------------------
; One B in upper-right, nose down → H-rail (rail damage on arrival).
; ---------------------------------------------------------------------------
.proc spawn_rail_attacker
    jsr objects::alloc
    bcs spawn_b_fail

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

    lda #QUAD_UR
    sta objects::obj_user, x

    lda #(OBJF_ALLOCATED | OBJF_RENDER | OBJF_BG_INTEREST)
    sta objects::obj_flags, x
    jsr objects::mark_dirty
spawn_b_fail:
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
    jsr clamp_to_quadrant
    jsr check_rail_arrival
upd_next:
    inx
    cpx #OBJECT_CAPACITY
    bne upd_loop
    jsr ensure_slice_mover
    jsr ensure_rail_attacker
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
.proc clamp_to_quadrant
    lda objects::obj_user, x
    cmp #QUAD_UR
    beq clamp_right
    cmp #QUAD_LR
    beq clamp_right
    lda objects::obj_x_hi, x
    bne left_hi
    lda objects::obj_x_lo, x
    cmp #DRONE_X_LEFT_MIN
    bcs left_max
    lda #DRONE_X_LEFT_MIN
    sta objects::obj_x_lo, x
    lda #0
    sta objects::obj_x_hi, x
    rts
left_max:
    cmp #DRONE_X_LEFT_MAX
    bcc clamp_done
    beq clamp_done
left_hi:
    lda #DRONE_X_LEFT_MAX
    sta objects::obj_x_lo, x
    lda #0
    sta objects::obj_x_hi, x
    rts

clamp_right:
    lda objects::obj_x_hi, x
    bne right_ge_256
    lda objects::obj_x_lo, x
    cmp #DRONE_X_RIGHT_MIN
    bcs clamp_done
    lda #DRONE_X_RIGHT_MIN
    sta objects::obj_x_lo, x
    lda #0
    sta objects::obj_x_hi, x
    rts
right_ge_256:
    lda objects::obj_x_lo, x
    cmp #$41
    bcc clamp_done
    lda #$40
    sta objects::obj_x_lo, x
    lda #1
    sta objects::obj_x_hi, x
clamp_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; Rail arrival: C → player blast; A/B → rail damage (2 cells); then retire.
; ---------------------------------------------------------------------------
.proc check_rail_arrival
    lda objects::obj_y_int, x
    cmp #DRONE_RAIL_ARRIVE_Y
    bcc arrive_done
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_C
    beq arrive_c
    cmp #OBJ_DRONE_A
    beq arrive_ab
    cmp #OBJ_DRONE_B
    beq arrive_ab
    jmp arrive_retire
arrive_c:
    txa
    pha
    jsr player::apply_c_blast_full
    pla
    tax
    jmp arrive_retire
arrive_ab:
    txa
    pha
    jsr rail::apply_ab_hit
    pla
    tax
arrive_retire:
    jsr objects::retire_and_try_free
arrive_done:
    rts
.endproc

.endscope
