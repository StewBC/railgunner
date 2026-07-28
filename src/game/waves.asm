; Wave state — load table row into ZP; detect wave clear → next wave.
; Spawn policy still lives in drones::; this owns quota / clear / table index.

.scope waves

; ---------------------------------------------------------------------------
; Load params for current `wave` (0..WAVES_PER_LEVEL-1). Resets spawn counters.
; Clobbers A,X,Y,tmp0,ptr_*.
; ---------------------------------------------------------------------------
.proc load
    lda wave
    cmp #WAVES_PER_LEVEL
    bcc load_idx
    lda #WAVES_PER_LEVEL - 1        ; clamp (should not happen in play)
load_idx:
    sta tmp0
    asl a
    asl a                           ; * WAVE_ROW_BYTES (4)
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

    lda #0
    sta wave_spawned
    sta drone_spawn_seq
    sta drone_spawn_lane
    lda #1
    sta drone_spawn_timer           ; first spawn soon
    rts
.endproc

; ---------------------------------------------------------------------------
; If this wave's quota is done and no C left → pending MODE_NEXT_WAVE.
; Does nothing if pending_mode already set (death wins).
; ---------------------------------------------------------------------------
.proc check_clear
    lda pending_mode
    bne cc_done
    lda wave_spawned
    cmp wave_quota
    bcc cc_done
    jsr drones::count_active_c
    cmp #0
    bne cc_done
    lda #MODE_NEXT_WAVE
    sta pending_mode
cc_done:
    rts
.endproc

.endscope
