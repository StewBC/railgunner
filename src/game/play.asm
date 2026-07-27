; Play loop — player, bullets; RUN/STOP → game over (kill switch).

.proc play_enter
    lda #COL_GREEN
    sta VIC_BORDER
    rts
.endproc

.proc play_update
    lda input_runstop_edge
    beq play_logic
    lda #MODE_GAME_OVER
    jsr mode_set
    rts

play_logic:
    jsr player::update
    jsr drones::update
    jsr bullets::update
    jsr collision::update
    rts
.endproc

; ---------------------------------------------------------------------------
; Next wave / next level stubs (roadmap hooks; not reached in scaffold path)
; ---------------------------------------------------------------------------
.proc next_wave_enter
    lda #COL_LT_GREEN
    sta VIC_BORDER
    ; TODO: "WAVE CLEAR" message + pause
    inc wave
    lda wave
    cmp #WAVES_PER_LEVEL
    bcc next_wave_more
    lda #MODE_NEXT_LEVEL
    jsr mode_set
    rts
next_wave_more:
    lda #MODE_PLAY
    jsr mode_set
    rts
.endproc

.proc next_wave_update
    rts
.endproc

.proc next_level_enter
    lda #COL_PURPLE
    sta VIC_BORDER
    ; TODO: "LEVEL CLEAR" message + pause
    inc level
    lda #0
    sta wave
    lda #MODE_STAGE_INIT
    jsr mode_set
    rts
.endproc

.proc next_level_update
    rts
.endproc
