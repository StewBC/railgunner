; Wave state — load table row into ZP; detect wave clear → next wave.

.scope waves

; ---------------------------------------------------------------------------
.proc load
    lda wave
    cmp #WAVES_PER_LEVEL
    bcc load_idx
    lda #WAVES_PER_LEVEL - 1
load_idx:
    ; index * 6 = *4 + *2
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
    sta wave_spawned
    sta wave_b_spawned
    sta wave_a_spawned
    sta drone_spawn_seq
    sta drone_spawn_lane
    lda #1
    sta drone_spawn_timer
    lda #WAVE_AB_CADENCE / 2        ; first A/B a bit after C starts
    sta wave_ab_timer
    rts
.endproc

; ---------------------------------------------------------------------------
; Clear when all quotas spawned and no A/B/C remain.
; ---------------------------------------------------------------------------
.proc check_clear
    lda pending_mode
    bne cc_done
    lda wave_spawned
    cmp wave_quota
    bcc cc_done
    lda wave_b_spawned
    cmp wave_b_quota
    bcc cc_done
    lda wave_a_spawned
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

.endscope
