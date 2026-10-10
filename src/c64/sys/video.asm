; PAL/NTSC detection, normalized 50 Hz cadence, and global sprite palette.

.scope video

; Shared multicolour sprite colours ($D025/$D026). Stage/global — never
; rewritten per object; object colour goes only to $D027–$D02E via the mux.
; Safe for tst/c64/ demos (they share this file with the game).
.proc init_sprite_palette
    lda #SPR_MC0_COLOR
    sta VIC_SPR_MC0
    lda #SPR_MC1_COLOR
    sta VIC_SPR_MC1
    rts
.endproc

; Detect PAL by observing that the high-raster region reaches low byte $20.
; NTSC wraps after line 262 (low byte $06) and cannot reach it.
.proc detect_standard
wait_low:
    lda VIC_CTRL1
    bmi wait_low
wait_high:
    lda VIC_CTRL1
    bpl wait_high
high_region:
    lda VIC_CTRL1
    bpl detected_ntsc
    lda VIC_RASTER
    cmp #$20
    bcc high_region

    lda #VIDEO_PAL
    sta objects::video_standard
    lda #PAL_DISPLAY_HZ
    sta objects::display_hz
    rts

detected_ntsc:
    lda #VIDEO_NTSC
    sta objects::video_standard
    lda #NTSC_DISPLAY_HZ
    sta objects::display_hz
    rts
.endproc

.endscope
