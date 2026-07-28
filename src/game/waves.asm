; Wave load + kill clear (launcher v2 params).

.scope waves

.proc load
    lda wave
    cmp #WAVES_PER_LEVEL
    bcc load_idx
    lda #WAVES_PER_LEVEL - 1
load_idx:
    ; *8 = asl 3
    asl a
    asl a
    asl a
    clc
    adc #<level1_wave_table
    sta ptr_lo
    lda #0
    adc #>level1_wave_table
    sta ptr_hi

    ldy #0
    lda (ptr_lo), y
    sta wave_quota
    iny
    lda (ptr_lo), y
    sta wave_b_quota
    iny
    lda (ptr_lo), y
    sta wave_a_quota
    iny
    lda (ptr_lo), y
    sta wave_cd_min
    iny
    lda (ptr_lo), y
    sta wave_cd_max
    iny
    lda (ptr_lo), y
    sta wave_max_active
    iny
    lda (ptr_lo), y
    sta wave_quad_mask
    iny
    lda (ptr_lo), y
    sta wave_flags

    lda #0
    sta wave_kills_c
    sta wave_kills_b
    sta wave_kills_a
    sta piggy_timer
    lda #$FF
    sta spawn_last_quad
    ; seed RNG from frame if zero
    lda rng_state
    bne load_timer
    lda frame_count
    ora #1
    sta rng_state
load_timer:
    jsr drones::roll_cooldown
    rts
.endproc

.proc check_clear
    lda pending_mode
    bne cc_done
    lda wave_kills_c
    cmp wave_quota
    bcc cc_done
    lda wave_kills_b
    cmp wave_b_quota
    bcc cc_done
    lda wave_kills_a
    cmp wave_a_quota
    bcc cc_done
    jsr drones::count_active_drones
    cmp #0
    bne cc_done
    lda #MODE_NEXT_WAVE
    sta pending_mode
cc_done:
    rts
.endproc

.proc note_kill
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_C
    beq nk_c
    cmp #OBJ_DRONE_B
    beq nk_b
    cmp #OBJ_DRONE_A
    beq nk_a
    rts
nk_c:
    inc wave_kills_c
    rts
nk_b:
    inc wave_kills_b
    rts
nk_a:
    inc wave_kills_a
    rts
.endproc

.endscope
