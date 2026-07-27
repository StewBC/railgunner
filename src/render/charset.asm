; Character set: copy C64 char ROM → RAM once, install bullet UDGs.
; All text modes use this font (VIC bank 0, CHARSET_RAM @ $2000).

; ---------------------------------------------------------------------------
; charset_install — cold init (once). Clobbers A,X,Y,ptr_*,print_ptr_*,tmp0
; ---------------------------------------------------------------------------
.proc charset_install
    sei

    lda $01
    sta tmp0
    lda #$33                        ; CHAR ROM at $D000
    sta $01

    lda #<CHAR_ROM
    sta ptr_lo
    lda #>CHAR_ROM
    sta ptr_hi
    lda #<CHARSET_RAM
    sta print_ptr_lo
    lda #>CHARSET_RAM
    sta print_ptr_hi

    ldx #>CHARSET_SIZE              ; 8 pages
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

    lda tmp0
    sta $01
    cli

    ; Overlay bullet UDGs at SC_BULLET_FIRST
    lda #<chr_bullet_udg
    sta ptr_lo
    lda #>chr_bullet_udg
    sta ptr_hi
    lda #<(CHARSET_RAM + SC_BULLET_FIRST * 8)
    sta print_ptr_lo
    lda #>(CHARSET_RAM + SC_BULLET_FIRST * 8)
    sta print_ptr_hi

    ldy #0
overlay:
    lda (ptr_lo), y
    sta (print_ptr_lo), y
    iny
    cpy #CHR_BULLET_UDG_BYTES
    bne overlay

    rts
.endproc
