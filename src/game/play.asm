; Play loop — player, drones, cargo, parcels; RUN/STOP → game over.

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
    jsr cargo::update
    jsr parcels::update
    jsr bullets::update
    jsr collision::update
    jsr waves::update_banner
    lda pending_mode
    bne play_hud
    jsr waves::check_clear
play_hud:
    jsr score::paint_if_dirty
    jsr hud::paint_status_if_dirty
    lda pending_mode
    beq play_done
    jsr mode_set
    lda #0
    sta pending_mode
play_done:
    rts
.endproc

; Legacy mode table entries (unused level flow — kept for mode IDs)
.proc next_wave_enter
    lda #MODE_PLAY
    jsr mode_set
    rts
.endproc
.proc next_wave_update
    rts
.endproc
.proc next_level_enter
    lda #MODE_PLAY
    jsr mode_set
    rts
.endproc
.proc next_level_update
    rts
.endproc
