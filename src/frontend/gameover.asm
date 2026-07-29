; Game over — tallies + FIRE returns to title.
; High-score branch is a stub (always skip hiscore for scaffold).

.proc gameover_enter
    lda #COL_RED
    sta VIC_BORDER
    jsr objects::hide_all
    jsr screen_clear
    jsr tallies::paint_gameover

    ; Small delay before accepting fire (avoid instant skip)
    lda #30
    sta mode_timer
    rts
.endproc

.proc gameover_update
    lda mode_timer
    beq gameover_ready
    dec mode_timer
    rts
gameover_ready:
    lda input_fire_edge
    ora input_fire
    beq gameover_done
    ; TODO Features: if top-10 → MODE_HISCORE
    lda #MODE_TITLE_TEXT
    jsr mode_set
gameover_done:
    rts
.endproc
