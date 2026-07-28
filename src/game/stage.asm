; Stage init — first enter only (new game / rare re-init). Level-ups do not reset.

.proc stage_init_enter
    lda #COL_LT_BLUE
    sta VIC_BORDER

    jsr screen_blank
    jsr vic_select_bank0
    lda #VIC_CTRL1_TEXT_BLANK
    sta VIC_CTRL1
    lda #VIC_CTRL2_HIRES
    sta VIC_CTRL2
    lda #VIC_MEM_TEXT_RAM
    sta VIC_MEM

    jsr screen_draw_playfield
    jsr rail::redraw_from_state
    jsr bullets::init
    jsr video::init_sprite_palette
    jsr video::install_sprite_frames
    jsr player::init
    jsr drones::init
    jsr cargo::init
    jsr parcels::init
    jsr waves::load

    jsr hud::paint_full_line
    jsr hud_color_static
    jsr screen_unblank

    lda #MODE_PLAY
    jsr mode_set
    rts
.endproc

.proc stage_init_update
    rts
.endproc
