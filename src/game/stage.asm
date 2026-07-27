; Stage init / re-init — player on H-rail left of centre, clear field, play.

.proc stage_init_enter
    lda #COL_LT_BLUE
    sta VIC_BORDER

    lda #0
    sta wave

    jsr screen_draw_playfield
    jsr video::init_sprite_palette
    jsr video::install_sprite_frames
    jsr player::init

    lda #MODE_PLAY
    jsr mode_set
    rts
.endproc

.proc stage_init_update
    rts
.endproc
