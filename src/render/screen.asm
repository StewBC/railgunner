; Screen helpers and placeholder playfield draw.
; Real rail/HUD character art comes later.

; ---------------------------------------------------------------------------
; Blank / unblank via $D011 DEN (simplest transition hide).
; ---------------------------------------------------------------------------
.proc screen_blank
    lda VIC_CTRL1
    and #VIC_DEN_MASK
    and #$7f                        ; $D011 read bit 7 is live raster, not shadow
    sta VIC_CTRL1
    rts
.endproc

.proc screen_unblank
    lda VIC_CTRL1
    and #$7f                        ; keep raster compare in common 0..255 range
    ora #VIC_DEN
    sta VIC_CTRL1
    rts
.endproc

; ---------------------------------------------------------------------------
; VIC bank 0 (play + all text UI). Clobbers A.
; ---------------------------------------------------------------------------
.proc vic_select_bank0
    lda CIA2_PRA
    and #%11111100
    ora #VIC_BANK0_BITS
    sta CIA2_PRA
    rts
.endproc

; ---------------------------------------------------------------------------
; VIC bank 3 (title hires under KERNAL). Clobbers A.
; ---------------------------------------------------------------------------
.proc vic_select_bank3
    lda CIA2_PRA
    and #%11111100
    ora #VIC_BANK3_BITS
    sta CIA2_PRA
    rts
.endproc

; ---------------------------------------------------------------------------
; Text mode: bank 0, RAM charset @ $2000, clear. Display left blanked.
; ---------------------------------------------------------------------------
.proc vic_text_mode
    jsr screen_blank
    jsr vic_select_bank0
    lda #VIC_CTRL1_TEXT_BLANK
    sta VIC_CTRL1
    lda #VIC_CTRL2_HIRES
    sta VIC_CTRL2
    lda #VIC_MEM_TEXT_RAM           ; always our RAM font — never ROM after install
    sta VIC_MEM
    lda #COL_BLACK
    sta VIC_BORDER
    sta VIC_BG0
    jmp screen_clear
.endproc

; ---------------------------------------------------------------------------
; Clear screen RAM to spaces and colour RAM to white.
; ---------------------------------------------------------------------------
.proc screen_clear
    lda #SC_SPACE
    ldx #0
scr_loop:
    sta SCREEN_RAM + $000, x
    sta SCREEN_RAM + $100, x
    sta SCREEN_RAM + $200, x
    inx
    bne scr_loop
    ldx #(SCREEN_SIZE - 768)        ; 232 bytes
scr_tail:
    sta SCREEN_RAM + $300 - 1, x
    dex
    bne scr_tail

    lda #COL_WHITE
    ldx #0
col_loop:
    sta COLOR_RAM + $000, x
    sta COLOR_RAM + $100, x
    sta COLOR_RAM + $200, x
    inx
    bne col_loop
    ldx #(SCREEN_SIZE - 768)
col_tail:
    sta COLOR_RAM + $300 - 1, x
    dex
    bne col_tail
    rts
.endproc

; Compute screen address for column X, row Y → ptr_lo/hi.
;   ptr = SCREEN_RAM + Y*40 + X
; Clobbers A, tmp1, tmp2, ptr_lo/hi. X and Y are read, not modified.
; Shared by screen_put_xy (single glyph) and screen_print (compute base once).
.proc screen_addr_xy
    tya
    sta ptr_lo
    lda #0
    sta ptr_hi
    asl ptr_lo
    rol ptr_hi                      ; *2
    asl ptr_lo
    rol ptr_hi                      ; *4
    asl ptr_lo
    rol ptr_hi                      ; *8
    lda ptr_lo
    sta tmp1                        ; save *8
    lda ptr_hi
    sta tmp2
    asl ptr_lo
    rol ptr_hi                      ; *16
    asl ptr_lo
    rol ptr_hi                      ; *32
    lda ptr_lo
    clc
    adc tmp1                        ; *40
    sta ptr_lo
    lda ptr_hi
    adc tmp2
    sta ptr_hi
    txa
    clc
    adc ptr_lo                      ; + X
    sta ptr_lo
    bcc addr_add_base
    inc ptr_hi
addr_add_base:
    lda ptr_lo
    clc
    adc #<SCREEN_RAM
    sta ptr_lo
    lda ptr_hi
    adc #>SCREEN_RAM
    sta ptr_hi
    rts
.endproc

; Put screen code in A at column X, row Y.
; Uses ptr_lo/hi, tmp0-tmp2. Does not preserve A,Y (X survives).
.proc screen_put_xy
    sta tmp0
    jsr screen_addr_xy              ; ptr = SCREEN + Y*40 + X
    lda tmp0
    ldy #0
    sta (ptr_lo), y
    rts
.endproc

; Put colour A at column X, row Y (colour RAM).
; Clobbers tmp0-tmp2,ptr_lo/hi; does not preserve A,Y (X survives).
.proc screen_color_xy
    sta tmp0
    jsr screen_addr_xy              ; ptr = SCREEN + Y*40 + X
    lda ptr_lo
    clc
    adc #<(COLOR_RAM - SCREEN_RAM)
    sta ptr_lo
    lda ptr_hi
    adc #>(COLOR_RAM - SCREEN_RAM)
    sta ptr_hi
    lda tmp0
    ldy #0
    sta (ptr_lo), y
    rts
.endproc

; Map accumulator ASCII letter form → screen code (uppercase set).
.proc ascii_to_screen
    cmp #' '
    bne not_space
    lda #SC_SPACE
    rts
not_space:
    cmp #'0'
    bcc a2s_done
    cmp #'9' + 1
    bcs try_alpha
    rts                             ; digits already screen codes
try_alpha:
    cmp #'A'
    bcc a2s_done
    cmp #'Z' + 1
    bcs a2s_done
    sec
    sbc #('A' - 1)                  ; 'A' → 1
a2s_done:
    rts
.endproc

; Print 0-terminated string at ptr_lo/hi to column X, row Y.
; The destination base address is computed ONCE; source and destination then
; advance together under Y, so cost is linear in string length (no per-character
; row*40 multiply). Non-wrapping: intended for short HUD/menu labels on one row.
.proc screen_print
    ; Save the source pointer before screen_addr_xy overwrites ptr_lo/hi.
    lda ptr_lo
    sta print_ptr_lo
    lda ptr_hi
    sta print_ptr_hi
    jsr screen_addr_xy              ; ptr_lo/hi = destination base (col X, row Y)
    ldy #0
print_loop:
    lda (print_ptr_lo), y           ; next source char
    beq print_done                  ; 0 terminator
    jsr ascii_to_screen
    sta (ptr_lo), y                 ; same Y offset into destination row
    iny
    bne print_loop
print_done:
    rts
.endproc

; Paint all 40 colour-RAM cells of row Y with colour A.
; Clobbers A,X,Y,tmp0-tmp2,ptr_lo/hi. Colour is low nybble only.
.proc screen_color_row
    sta tmp0
    ldx #0                          ; column
    ; ptr = COLOR_RAM + Y*40
    tya
    sta ptr_lo
    lda #0
    sta ptr_hi
    asl ptr_lo
    rol ptr_hi
    asl ptr_lo
    rol ptr_hi
    asl ptr_lo
    rol ptr_hi                      ; *8
    lda ptr_lo
    sta tmp1
    lda ptr_hi
    sta tmp2
    asl ptr_lo
    rol ptr_hi
    asl ptr_lo
    rol ptr_hi                      ; *32
    lda ptr_lo
    clc
    adc tmp1                        ; *40
    sta ptr_lo
    lda ptr_hi
    adc tmp2
    sta ptr_hi
    lda ptr_lo
    clc
    adc #<COLOR_RAM
    sta ptr_lo
    lda ptr_hi
    adc #>COLOR_RAM
    sta ptr_hi
    ldy #0
    lda tmp0
color_row_loop:
    sta (ptr_lo), y
    iny
    cpy #SCREEN_W
    bne color_row_loop
    rts
.endproc

; ---------------------------------------------------------------------------
; Placeholder HUD + cross rails (plain screen codes).
; ---------------------------------------------------------------------------
.proc screen_draw_playfield
    jsr screen_clear

    lda #<str_hud_placeholder
    sta ptr_lo
    lda #>str_hud_placeholder
    sta ptr_hi
    ldx #0
    ldy #0
    jsr screen_print

    ; Vertical rail band: cols 19–21 (quadrants are 0–18 and 22–39)
    ; (use draw_i — screen_put_xy clobbers tmp1/tmp2)
    lda #1
vloop:
    sta draw_i
    cmp #12
    bcc vdraw
    cmp #14
    bcc vnext
vdraw:
    ldx #19
    ldy draw_i
    lda #SC_VBAR
    jsr screen_put_xy
    ldx #20
    ldy draw_i
    lda #SC_VBAR
    jsr screen_put_xy
    ldx #21
    ldy draw_i
    lda #SC_VBAR
    jsr screen_put_xy
vnext:
    lda draw_i
    clc
    adc #1
    cmp #25
    bcc vloop

    ; Horizontal arms: rows 12–13, cols 0..18 and 22..39 (gap 19–21)
    lda #0
hloop:
    sta draw_j
    cmp #19
    bcc hdraw
    cmp #22
    bcc hnext
hdraw:
    ldx draw_j
    ldy #12
    lda #SC_DASH
    jsr screen_put_xy
    ldx draw_j
    ldy #13
    lda #SC_DASH
    jsr screen_put_xy
hnext:
    lda draw_j
    clc
    adc #1
    cmp #40
    bcc hloop
    ; Player is a hardware sprite (slot 0); no character stand-in.
    rts
.endproc
