; Character set @ CHARSET_RAM ($2800) — PRG-resident futuristic font (seg CHARSET).
; Cold init only overlays bullet + bar UDGs (glyphs 0..63 already loaded).

; ---------------------------------------------------------------------------
; charset_install — cold init (once). Clobbers A,X,Y,ptr_*,print_ptr_*,tmp0
; ---------------------------------------------------------------------------
.proc charset_install
    ; Base font is already at $2800 via segment CHARSET (no ROM copy).
    ; Overlay bullet UDGs at SC_BULLET_FIRST ($F0)
    lda #<chr_bullet_udg
    sta ptr_lo
    lda #>chr_bullet_udg
    sta ptr_hi
    lda #<(CHARSET_RAM + SC_BULLET_FIRST * 8)
    sta print_ptr_lo
    lda #>(CHARSET_RAM + SC_BULLET_FIRST * 8)
    sta print_ptr_hi

    ldy #0
overlay_bul:
    lda (ptr_lo), y
    sta (print_ptr_lo), y
    iny
    cpy #CHR_BULLET_UDG_BYTES
    bne overlay_bul

    ; Overlay HUD bar UDGs at SC_UDG_BAR_FIRST ($D7)
    lda #<chr_bar_udg
    sta ptr_lo
    lda #>chr_bar_udg
    sta ptr_hi
    lda #<(CHARSET_RAM + SC_UDG_BAR_FIRST * 8)
    sta print_ptr_lo
    lda #>(CHARSET_RAM + SC_UDG_BAR_FIRST * 8)
    sta print_ptr_hi

    ldy #0
overlay_bar:
    lda (ptr_lo), y
    sta (print_ptr_lo), y
    iny
    cpy #CHR_BAR_UDG_BYTES
    bne overlay_bar

    rts
.endproc
