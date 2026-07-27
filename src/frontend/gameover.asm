; Game over — show message; FIRE returns to title.
; High-score branch is a stub (always skip hiscore for scaffold).

.proc gameover_enter
    lda #COL_RED
    sta VIC_BORDER
    jsr objects::hide_all
    jsr screen_clear

    lda #<str_game_over
    sta ptr_lo
    lda #>str_game_over
    sta ptr_hi
    ldx #15
    ldy #12
    jsr screen_print

    lda #<str_press_fire
    sta ptr_lo
    lda #>str_press_fire
    sta ptr_hi
    ldx #15
    ldy #16
    jsr screen_print

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
