; Next life — explode / lives-- / stage re-init or game over.
; Scaffold stub only (not reached until death logic exists).

.proc next_life_enter
    lda #COL_ORANGE
    sta VIC_BORDER

    lda lives
    beq life_to_gameover
    dec lives
    lda lives
    beq life_to_gameover

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
