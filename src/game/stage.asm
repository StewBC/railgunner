; Stage init / re-init — player on H-rail left of centre, clear field, play.

.proc stage_init_enter
    lda #COL_LT_BLUE
    sta VIC_BORDER

    lda #0
    sta wave

    ; Bank 0 + RAM font already installed at cold init
    jsr screen_blank
    jsr vic_select_bank0
    lda #VIC_CTRL1_TEXT_BLANK
    sta VIC_CTRL1
    lda #VIC_CTRL2_HIRES
    sta VIC_CTRL2
    lda #VIC_MEM_TEXT_RAM
    sta VIC_MEM

    jsr screen_draw_playfield
    jsr bullets::init
    jsr video::init_sprite_palette
    jsr video::install_sprite_frames
    jsr player::init
    jsr drones::init                ; Stage 2: one C mover top→rail
    jsr screen_unblank

    lda #MODE_PLAY
    jsr mode_set
    rts
.endproc

.proc stage_init_update
    rts
.endproc
