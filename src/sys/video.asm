; PAL/NTSC detection, normalized 50 Hz cadence, and global sprite palette.

.scope video

; Shared multicolour sprite colours ($D025/$D026). Stage/global — never
; rewritten per object; object colour goes only to $D027–$D02E via the mux.
.proc init_sprite_palette
    lda #SPR_MC0_COLOR
    sta VIC_SPR_MC0
    lda #SPR_MC1_COLOR
    sta VIC_SPR_MC1
    rts
.endproc

; Copy drone frames from DATA (spr_frames_src) into VIC bank $3000 and clear
; player compositing buffers. Call on stage enter (title bitmap wipes $2000–$3F3F).
.proc install_sprite_frames
    lda #<spr_frames_src
    sta ptr_lo
    lda #>spr_frames_src
    sta ptr_hi
    lda #<SPRITE_BLOCK
    sta print_ptr_lo
    lda #>SPRITE_BLOCK
    sta print_ptr_hi

    ldx #>SPRITE_FRAMES_BYTES       ; pages (768 = 3 pages)
    ldy #0
copy_pages:
    lda (ptr_lo), y
    sta (print_ptr_lo), y
    iny
    bne copy_pages
    inc ptr_hi
    inc print_ptr_hi
    dex
    bne copy_pages

    ; Clear player buffers at $3E00 / $3E40
    lda #0
    tax
clear_player:
    sta PLAYER_BUF_0, x
    sta PLAYER_BUF_1, x
    inx
    cpx #64
    bne clear_player
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
