; Cold init — bring-up before any game mode.

; KERNAL: $CC BLNSW — 0 = cursor blinks, non-zero = cursor off
BLNSW           = $CC

.proc cold_init
    sei
    cld

    ; Kill READY-prompt cursor (KERNAL IRQ still runs until we own it)
    lda #1
    sta BLNSW

    ; Stock VIC text mode (safe defaults) before any mode enter
    lda #VIC_CTRL1_TEXT
    sta VIC_CTRL1
    lda #VIC_CTRL2_HIRES
    sta VIC_CTRL2
    lda #VIC_MEM_TEXT
    sta VIC_MEM

    lda #COL_BLUE
    sta VIC_BORDER
    lda #COL_BLACK
    sta VIC_BG0

    jsr screen_clear
    jsr charset_install_stub        ; no-op until assets exist
    jsr hiscore_reset               ; zeros in RAM (disk load later)
    jsr irq_install

    lda #0
    sta frame_count
    sta input_fire_prev
    sta mode_timer
    sta mode_state

    lda #MODE_TITLE
    sta game_mode
    jsr title_enter                 ; switches VIC to hires bitmap

    cli
    rts
.endproc

; Placeholder: copy char ROM → RAM / install UDGs later.
.proc charset_install_stub
    rts
.endproc
