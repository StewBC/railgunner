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

    ; objects::init wipes $C000–$C8FF (includes display_hz and all mux state).
    ; Hold IRQs through the complete reset. Mux init disables/clears hardware
    ; sprites immediately; video detection restores cadence. irq_install must
    ; run last to select line 0 and acknowledge any raster source that became
    ; pending while IRQs were masked, leaving the IRQ owner in a coherent
    ; frame-start state before interrupts resume.
    sei
    jsr objects::init
    jsr sprite_mux_irq::init
    jsr video::detect_standard
    jsr video::init_sprite_palette
    jsr irq_install
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
