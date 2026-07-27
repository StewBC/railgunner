; Drone spawn + motion.
; Drones live only in the four quadrants — never over the cross rails
; (char cols 19–21, rows 12–13). Stage 2: one C in UL flying down to H-rail.
; Later: waves of 3 per quadrant.

.scope drones

; ---------------------------------------------------------------------------
.proc init
    jsr ensure_slice_mover
    rts
.endproc

; ---------------------------------------------------------------------------
; Keep exactly one active slice C in play (UL). Call after kills / arrivals.
; ---------------------------------------------------------------------------
.proc ensure_slice_mover
    ldx #1
    lda #0
    sta tmp0                        ; count
count_loop:
    lda objects::obj_flags, x
    and #(OBJF_ALLOCATED | OBJF_RETIRING)
    cmp #OBJF_ALLOCATED
    bne count_next
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_C
    bne count_next
    inc tmp0
count_next:
    inx
    cpx #OBJECT_CAPACITY
    bne count_loop
    lda tmp0
    bne ensure_done                 ; already have ≥1
    jsr spawn_slice_mover
ensure_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; One C in upper-left quadrant, nose down → H-rail.
; ---------------------------------------------------------------------------
.proc spawn_slice_mover
    jsr objects::alloc
    bcs spawn_fail

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
    sta objects::obj_user, x        ; quadrant for clamp / wave logic

    ; BG interest: $D01F candidate latch; gameplay peeks chars to disambiguate.
    lda #(OBJF_ALLOCATED | OBJF_RENDER | OBJF_BG_INTEREST)
    sta objects::obj_flags, x
    jsr objects::mark_dirty
spawn_fail:
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
    jsr ensure_slice_mover          ; top up if arrivals cleared the last one
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
; Keep 24px sprite fully in left (cols 0–18) or right (22–39) band.
; ---------------------------------------------------------------------------
.proc clamp_to_quadrant
    lda objects::obj_user, x
    cmp #QUAD_UR
    beq clamp_right
    cmp #QUAD_LR
    beq clamp_right
    ; UL / LL — left band
    lda objects::obj_x_hi, x
    bne left_hi                     ; X >= 256: force max left
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
    ; 16-bit X vs DRONE_X_RIGHT_MIN ($00C8) / MAX ($0140)
    lda objects::obj_x_hi, x
    bne right_ge_256
    ; X < 256: must be >= RIGHT_MIN (200); MAX is 320 so always <= if hi=0
    lda objects::obj_x_lo, x
    cmp #DRONE_X_RIGHT_MIN
    bcs clamp_done
    lda #DRONE_X_RIGHT_MIN
    sta objects::obj_x_lo, x
    lda #0
    sta objects::obj_x_hi, x
    rts
right_ge_256:
    ; X = $100 + lo; MAX = $140 → lo must be <= $40
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
; Reach H-rail edge (not over it): retire only. ensure_slice_mover respawns.
; ---------------------------------------------------------------------------
.proc check_rail_arrival
    lda objects::obj_y_int, x
    cmp #DRONE_RAIL_ARRIVE_Y
    bcc arrive_done
    jsr objects::retire_and_try_free
arrive_done:
    rts
.endproc

.endscope
