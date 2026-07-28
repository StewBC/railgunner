; Per-session reset (new game from title).

.proc game_init_enter
    lda #COL_CYAN
    sta VIC_BORDER

    jsr score::reset

    lda #START_LIVES
    sta lives
    lda #START_HEALTH
    sta health
    lda #START_AMMO
    sta ammo
    lda #START_LEVEL
    sta level
    lda #0
    sta wave
    sta pending_mode
    lda #1
    sta hud_status_dirty

    ; Fresh object pool each session (slot 0 = player; rest free)
    jsr objects::init
    jsr video::init_sprite_palette
    jsr rail::reset                 ; new game: pristine rails

    ; Fall through immediately to stage init (no multi-frame work yet)
    lda #MODE_STAGE_INIT
    jsr mode_set
    rts
.endproc

.proc game_init_update
    ; enter already advanced mode; nothing per frame
    rts
.endproc
