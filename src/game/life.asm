; Next life — reserved. Lives currently consumed by centre mines (cargo.asm).
; Rail total collapse → game over (rail.asm). Full stage re-init if needed later.

.proc next_life_enter
    lda #MODE_GAME_OVER
    jsr mode_set
    rts
.endproc

.proc next_life_update
    rts
.endproc
