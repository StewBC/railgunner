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

    ; objects::init wipes $C000–$C8FF (includes display_hz, mux IRQ bookkeeping).
    ; Hold IRQs, re-detect video cadence, and re-init the mux IRQ state so a
    ; new game does not inherit display_hz=0 / stale plans (stall dogfood).
    sei
    jsr objects::init
    jsr video::detect_standard
    jsr video::init_sprite_palette
    jsr sprite_mux_irq::init
    cli

    jsr rail::reset
    jsr cargo::init

    lda #MODE_STAGE_INIT
    jsr mode_set
    rts
.endproc

.proc game_init_update
    rts
.endproc
