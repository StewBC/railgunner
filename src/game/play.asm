; Play loop — player, bullets; RUN/STOP → game over (kill switch).

.proc play_enter
    lda #COL_GREEN
    sta VIC_BORDER
    lda #0
    sta pending_mode
    rts
.endproc

.proc play_update
    lda input_runstop_edge
    beq play_logic
    lda #MODE_GAME_OVER
    jsr mode_set
    rts

play_logic:
    lda #0
    sta pending_mode
    jsr player::update
    jsr drones::update
    jsr bullets::update
    jsr collision::update
    ; Wave clear only if combat did not already request death / rail-loss
    lda pending_mode
    bne play_hud
    jsr waves::check_clear
play_hud:
    jsr score::paint_if_dirty
    jsr hud::paint_status_if_dirty
    ; Apply deferred mode after combat + mux-safe window
    lda pending_mode
    beq play_done
    jsr mode_set
    lda #0
    sta pending_mode
play_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; Next wave / next level (driven by wave quota clear)
; ---------------------------------------------------------------------------
.proc next_wave_enter
    lda #COL_LT_GREEN
    sta VIC_BORDER
    ; TODO: "WAVE CLEAR" message + pause (Polish / 9.2)
    inc wave
    lda wave
    cmp #WAVES_PER_LEVEL
    bcc next_wave_more
    lda #MODE_NEXT_LEVEL
    jsr mode_set
    rts
next_wave_more:
    jsr waves::load
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
    lda #1
    sta hud_status_dirty            ; stage_init will paint_status (incl. level)
    lda #0
    sta wave
    lda #MODE_STAGE_INIT
    jsr mode_set
    rts
.endproc

.proc next_level_update
    rts
.endproc
