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

; Read screen code at column X, row Y → A.
; Clobbers tmp1/tmp2,ptr_*; Y not preserved; X survives.
.proc screen_get_xy
    jsr screen_addr_xy
    ldy #0
    lda (ptr_lo), y
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
; Playfield: HUD + a–j rail map (stock font A–J until UDGs).
;
; Rows 1–11, 15–24: vertical ABC at cols 18–20
; Row 12: D… DGBHDD…D   Row 13: E×40   Row 14: F… FIBJFF…F
; ---------------------------------------------------------------------------
.proc screen_draw_playfield
    jsr screen_clear

    lda #<str_hud
    sta ptr_lo
    lda #>str_hud
    sta ptr_hi
    ldx #0
    ldy #HUD_ROW
    jsr screen_print
    jsr hud_color_static

    ; --- Vertical shafts (rows 1–11 and 15–24) ---
    lda #1
vloop:
    sta draw_i
    cmp #RAIL_ROW_TOP               ; skip 12–14 (H-rail)
    bcc vdraw
    cmp #RAIL_ROW_BOT + 1
    bcc vnext
vdraw:
    ldx #RAIL_COL_LEFT
    ldy draw_i
    lda #SC_RAIL_A
    jsr screen_put_xy
    ldx #RAIL_COL_MID
    ldy draw_i
    lda #SC_RAIL_B
    jsr screen_put_xy
    ldx #RAIL_COL_RIGHT
    ldy draw_i
    lda #SC_RAIL_C
    jsr screen_put_xy
vnext:
    lda draw_i
    clc
    adc #1
    cmp #25
    bcc vloop

    ; --- Row 12: top H-edge D with elbows G B H ---
    lda #0
h12:
    sta draw_j
    cmp #RAIL_COL_LEFT
    bcc h12_d
    cmp #RAIL_COL_RIGHT + 1
    bcs h12_d
    ; centre junction
    lda draw_j
    cmp #RAIL_COL_LEFT
    beq h12_g
    cmp #RAIL_COL_MID
    beq h12_b
    lda #SC_RAIL_H                  ; right elbow top→R
    jmp h12_put
h12_g:
    lda #SC_RAIL_G
    jmp h12_put
h12_b:
    lda #SC_RAIL_B
    jmp h12_put
h12_d:
    lda #SC_RAIL_D
h12_put:
    ldx draw_j
    ldy #RAIL_ROW_TOP
    jsr screen_put_xy
    inc draw_j
    lda draw_j
    cmp #40
    bcc h12

    ; --- Row 13: solid mid E full width ---
    lda #0
h13:
    sta draw_j
    ldx draw_j
    ldy #RAIL_ROW_MID
    lda #SC_RAIL_E
    jsr screen_put_xy
    inc draw_j
    lda draw_j
    cmp #40
    bcc h13

    ; --- Row 14: bottom H-edge F with elbows I B J ---
    lda #0
h14:
    sta draw_j
    cmp #RAIL_COL_LEFT
    bcc h14_f
    cmp #RAIL_COL_RIGHT + 1
    bcs h14_f
    lda draw_j
    cmp #RAIL_COL_LEFT
    beq h14_i
    cmp #RAIL_COL_MID
    beq h14_b
    lda #SC_RAIL_J
    jmp h14_put
h14_i:
    lda #SC_RAIL_I
    jmp h14_put
h14_b:
    lda #SC_RAIL_B
    jmp h14_put
h14_f:
    lda #SC_RAIL_F
h14_put:
    ldx draw_j
    ldy #RAIL_ROW_BOT
    jsr screen_put_xy
    inc draw_j
    lda draw_j
    cmp #40
    bcc h14

    ; Colour whole rail structure mid-gray (screen_color_row clobbers Y —
    ; row index must live in draw_i, not Y).
    lda #1
    sta draw_i
rail_col_rows:
    ldy draw_i
    lda #COL_GRAY
    jsr screen_color_row
    inc draw_i
    lda draw_i
    cmp #25
    bcc rail_col_rows
    jsr hud_color_static            ; restore HUD colours after full-row paints
    rts
.endproc

; Colour HUD: score white, progress cyan, rest white.
.proc hud_color_static
    ldx #0
hud_all:
    cpx #HUD_PROGRESS_COL
    bcc hud_white
    cpx #HUD_PROGRESS_COL + HUD_PROGRESS_LEN
    bcs hud_white
    lda #COL_CYAN
    jmp hud_put
hud_white:
    lda #COL_WHITE
hud_put:
    ldy #HUD_ROW
    jsr screen_color_xy
    inx
    cpx #40
    bcc hud_all
    rts
.endproc
