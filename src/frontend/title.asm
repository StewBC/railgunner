; Title screen — hires bitmap, wait for FIRE → restore text → game init.

; ---------------------------------------------------------------------------
; title_enter — copy art into VIC buffers and enable standard bitmap mode.
; ---------------------------------------------------------------------------
.proc title_enter
    lda #COL_BLACK
    sta VIC_BORDER
    sta VIC_BG0

    ; VIC bank 0 ($0000–$3FFF): bits 0–1 of $DD00 are inverted select.
    lda CIA2_PRA
    and #%11111100
    ora #%00000011
    sta CIA2_PRA

    jsr title_copy_bitmap
    jsr title_copy_colors

    ; Hires bitmap: BMM=1, screen $0400, bitmap $2000
    lda #VIC_CTRL1_BITMAP
    sta VIC_CTRL1
    lda #VIC_CTRL2_HIRES
    sta VIC_CTRL2
    lda #VIC_MEM_BITMAP
    sta VIC_MEM
    rts
.endproc

; ---------------------------------------------------------------------------
; title_update — FIRE edge/level leaves title (text mode restored first).
; ---------------------------------------------------------------------------
.proc title_update
    lda input_fire_edge
    ora input_fire
    beq title_upd_done
    jsr vic_text_mode
    lda #MODE_GAME_INIT
    jsr mode_set
title_upd_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; Copy title_bitmap (8000) → BITMAP_RAM ($2000).
; ---------------------------------------------------------------------------
.proc title_copy_bitmap
    lda #<title_bitmap
    sta ptr_lo
    lda #>title_bitmap
    sta ptr_hi
    lda #<BITMAP_RAM
    sta print_ptr_lo
    lda #>BITMAP_RAM
    sta print_ptr_hi

    ldx #31                         ; 31×256 = 7936
    ldy #0
bmp_page:
    lda (ptr_lo), y
    sta (print_ptr_lo), y
    iny
    bne bmp_page
    inc ptr_hi
    inc print_ptr_hi
    dex
    bne bmp_page

    ; Remaining 8000 − 7936 = 64 bytes
    ldy #0
bmp_tail:
    lda (ptr_lo), y
    sta (print_ptr_lo), y
    iny
    cpy #64
    bne bmp_tail
    rts
.endproc

; ---------------------------------------------------------------------------
; Copy title_colors (1000) → SCREEN_RAM ($0400) — hires colour matrix.
; ---------------------------------------------------------------------------
.proc title_copy_colors
    lda #<title_colors
    sta ptr_lo
    lda #>title_colors
    sta ptr_hi
    lda #<SCREEN_RAM
    sta print_ptr_lo
    lda #>SCREEN_RAM
    sta print_ptr_hi

    ldx #3                          ; 3×256 = 768
    ldy #0
col_page:
    lda (ptr_lo), y
    sta (print_ptr_lo), y
    iny
    bne col_page
    inc ptr_hi
    inc print_ptr_hi
    dex
    bne col_page

    ; Remaining 1000 − 768 = 232 bytes
    ldy #0
col_tail:
    lda (ptr_lo), y
    sta (print_ptr_lo), y
    iny
    cpy #(BITMAP_COLOR_SIZE - 768)
    bne col_tail
    rts
.endproc
