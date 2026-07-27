; Next life — lives-- / stage re-init or game over.
; Entered when health hits 0 (player::apply_c_blast_full).

.proc next_life_enter
    lda #COL_ORANGE
    sta VIC_BORDER

    ; Consume one life. lives is remaining stock including the one just lost.
    lda lives
    beq life_to_gameover
    dec lives
    lda #1
    sta hud_status_dirty
    lda lives
    beq life_to_gameover

    ; Another life: full health, re-enter stage (score kept)
    lda #START_HEALTH
    sta health
    lda #MODE_STAGE_INIT
    jsr mode_set
    rts

life_to_gameover:
    lda #MODE_GAME_OVER
    jsr mode_set
    rts
.endproc

.proc next_life_update
    rts
.endproc
