; Cold init — bring-up before any game mode.

; KERNAL: $CC BLNSW — 0 = cursor blinks, non-zero = cursor off
BLNSW           = $CC

.proc cold_init
    sei
    cld

    ; Kill READY-prompt cursor (KERNAL IRQ still runs until we own it)
    lda #1
    sta BLNSW

    ; Point VIC at RAM font early (CHARSET segment already at $2800 from load)
    lda #VIC_CTRL1_TEXT
    sta VIC_CTRL1
    lda #VIC_CTRL2_HIRES
    sta VIC_CTRL2
    jsr vic_select_bank0
    lda #VIC_MEM_TEXT_RAM
    sta VIC_MEM

    lda #COL_BLUE
    sta VIC_BORDER
    lda #COL_BLACK
    sta VIC_BG0

    jsr screen_clear

    ; Title hires under KERNAL; overlay bullet/bar UDGs onto CHARSET
    jsr title_park_hires
    jsr charset_install
    jsr vic_select_bank0
    lda #VIC_MEM_TEXT_RAM
    sta VIC_MEM

    jsr hiscore_reset
    jsr objects::init
    jsr video::detect_standard
    jsr video::init_sprite_palette
    jsr sprite_mux_irq::init
    jsr sfx::init
    jsr irq_install

    lda #0
    sta frame_count
    sta input_fire_prev
    sta input_key_s_prev
    sta input_key_i_prev
    sta input_runstop_prev
    sta mode_timer
    sta mode_state
    sta attract_lo
    sta attract_hi
    sta score_color_phase
    sta score_color_tick

    ; Attract starts on parked hires (no re-copy)
    lda #MODE_TITLE_GFX
    sta game_mode
    jsr title_gfx_enter

    cli
    rts
.endproc
