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
    lda #PROFILE_PLAY_MODE_SET
    sta objects::profile_marker
    lda #MODE_GAME_OVER
    jsr mode_set
    jmp play_done

play_logic:
    lda #0
    sta pending_mode
    jsr rail::strike_frame_reset    ; one rail apply per drone per tick max
    lda #PROFILE_PLAY_PLAYER
    sta objects::profile_marker
    jsr player::update
    lda #PROFILE_PLAY_DRONES
    sta objects::profile_marker
    jsr drones::update
    lda #PROFILE_PLAY_CARGO
    sta objects::profile_marker
    jsr cargo::update
    lda #PROFILE_PLAY_PARCELS
    sta objects::profile_marker
    jsr parcels::update
    lda #PROFILE_PLAY_BULLETS
    sta objects::profile_marker
    jsr bullets::update
    lda #PROFILE_PLAY_COLLISION
    sta objects::profile_marker
    jsr collision::update
    lda #PROFILE_PLAY_WAVE_BANNER
    sta objects::profile_marker
    jsr waves::update_banner
    lda pending_mode
    bne play_hud
    lda player_dead
    bne play_hud                    ; no level-clear while dying
    lda #PROFILE_PLAY_WAVE_CLEAR
    sta objects::profile_marker
    jsr waves::check_clear
play_hud:
    lda #PROFILE_PLAY_SCORE
    sta objects::profile_marker
    jsr score::paint_if_dirty
    lda #PROFILE_PLAY_HUD
    sta objects::profile_marker
    jsr hud::paint_status_if_dirty
    lda pending_mode
    beq play_done
    lda #PROFILE_PLAY_MODE_SET
    sta objects::profile_marker
    lda pending_mode
    jsr mode_set
    lda #0
    sta pending_mode
play_done:
    lda #PROFILE_PLAY_DONE
    sta objects::profile_marker
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
