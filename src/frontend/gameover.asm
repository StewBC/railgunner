; Game over / victory results — tallies; FIRE → high-score entry or title.
; victory ZP (set when L15 banner completes) selects VICTORY! vs GAME OVER title.

.proc gameover_enter
    lda victory
    beq go_border_red
    lda #COL_GREEN
    jmp go_border
go_border_red:
    lda #COL_RED
go_border:
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
    jsr hiscore_qualifies           ; C set → top-10 by score
    bcc go_to_title
    lda #MODE_HISCORE
    jsr mode_set
    rts
go_to_title:
    lda #MODE_TITLE_TEXT
    jsr mode_set
gameover_done:
    rts
.endproc
