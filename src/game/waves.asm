; Wave state — load table row; clear on *kills*, not rail-suicides.
; Quotas = kills required. Spawn until kill targets met (replacements OK).

.scope waves

; ---------------------------------------------------------------------------
.proc load
    lda wave
    cmp #WAVES_PER_LEVEL
    bcc load_idx
    lda #WAVES_PER_LEVEL - 1
load_idx:
    sta tmp0
    asl a
    sta tmp1                        ; *2
    asl a                           ; *4
    clc
    adc tmp1                        ; *6
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
    sta wave_cadence
    iny
    lda (ptr_lo), y
    sta wave_max_active
    iny
    lda (ptr_lo), y
    sta wave_approach_mask
    iny
    lda (ptr_lo), y
    sta wave_b_quota
    iny
    lda (ptr_lo), y
    sta wave_a_quota

    lda #0
    sta wave_kills_c
    sta wave_kills_b
    sta wave_kills_a
    sta drone_spawn_seq
    sta drone_spawn_lane
    lda #1
    sta drone_spawn_timer
    lda #WAVE_AB_CADENCE / 2
    sta wave_ab_timer
    rts
.endproc

; ---------------------------------------------------------------------------
; Clear when kill targets met and field empty. Suicides do not count.
; ---------------------------------------------------------------------------
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

; ---------------------------------------------------------------------------
; Register a bullet kill for drone slot X (kind from obj_kind).
; ---------------------------------------------------------------------------
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
