; Per-session reset (new game from title).

.proc game_init_enter
    lda #COL_CYAN
    sta VIC_BORDER

    jsr score::reset

    lda #START_LIVES
    sta lives
    lda #START_LEVEL
    sta level
    lda #0
    sta level_kills
    sta level_banner_t
    sta pending_mode
    lda #1
    sta hud_status_dirty

    jsr objects::init
    jsr video::init_sprite_palette
    jsr rail::reset
    jsr cargo::init

    lda #MODE_STAGE_INIT
    jsr mode_set
    rts
.endproc

.proc game_init_update
    rts
.endproc
