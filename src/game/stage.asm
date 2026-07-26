; Stage init / re-init — player to cross centre, wave counter, draw field.

.proc stage_init_enter
    lda #COL_LT_BLUE
    sta VIC_BORDER

    lda #0
    sta wave

    ; Centre of cross (char coords; design uses intersection)
    lda #19
    sta player_col
    lda #12
    sta player_row

    jsr screen_draw_playfield

    lda #MODE_PLAY
    jsr mode_set
    rts
.endproc

.proc stage_init_update
    rts
.endproc
