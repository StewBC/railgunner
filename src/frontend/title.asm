; Title screen — wait for FIRE → game init.

.proc title_enter
    lda #COL_BLUE
    sta VIC_BORDER
    jsr screen_clear

    lda #<str_title
    sta ptr_lo
    lda #>str_title
    sta ptr_hi
    ldx #15                         ; roughly centred (10 chars)
    ldy #10
    jsr screen_print

    lda #<str_press_fire
    sta ptr_lo
    lda #>str_press_fire
    sta ptr_hi
    ldx #15
    ldy #14
    jsr screen_print
    rts
.endproc

.proc title_update
    ; Accept edge or level (level helps if a frame is missed)
    lda input_fire_edge
    ora input_fire
    beq title_upd_done
    lda #MODE_GAME_INIT
    jsr mode_set
title_upd_done:
    rts
.endproc
