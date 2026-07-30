; Rank banner on HUD row (wave complete).
; Clears only cols HUD_BANNER_COL .. HUD_BANNER_END-1 (score + pilots stay).
; Colour-cycles once through the high-score palette over LEVEL_BANNER_FRAMES.
; Banner text = nicety + ", " + rank title (tables split for future mix-match).

.scope message

; Show rank line for current wave (about to advance). Overlay only — no full clear.
.proc show_rank_banner
    jsr clear_banner_zone

    jsr wave_idx                    ; X = 0..14
    stx score_work1                 ; save index

    ; Measure nicety length → score_work0
    lda nicety_lo, x
    sta ptr_lo
    lda nicety_hi, x
    sta ptr_hi
    jsr strlen
    sta score_work0

    ; + ", " (2) + rank title length
    ldx score_work1
    lda rank_title_lo, x
    sta ptr_lo
    lda rank_title_hi, x
    sta ptr_hi
    jsr strlen
    clc
    adc score_work0
    clc
    adc #2                          ; comma + space
    sta score_work0                 ; total text length
    bcs srb_max
    cmp #HUD_BANNER_ZONE_LEN + 1
    bcc srb_len_ok
srb_max:
    lda #HUD_BANNER_ZONE_LEN
    sta score_work0
srb_len_ok:

    ; Pad with BANNER_PAD_SPACES each side if room inside zone
    lda #BANNER_PAD_SPACES
    sta mux_i                       ; pad count
srb_pad_try:
    lda score_work0
    clc
    adc mux_i
    bcc srb_pad_sum
    jmp srb_pad_zero
srb_pad_sum:
    clc
    adc mux_i
    bcs srb_pad_shrink
    cmp #HUD_BANNER_ZONE_LEN + 1
    bcc srb_pad_ok
srb_pad_shrink:
    dec mux_i
    bpl srb_pad_try
srb_pad_zero:
    lda #0
    sta mux_i
srb_pad_ok:
    ; total = text + 2*pad → banner_len
    lda score_work0
    clc
    adc mux_i
    clc
    adc mux_i
    sta banner_len

    ; start col = HUD_BANNER_COL + (zone_len - total) / 2
    lda #HUD_BANNER_ZONE_LEN
    sec
    sbc banner_len
    lsr a
    clc
    adc #HUD_BANNER_COL
    sta banner_col

    ; Leading pad spaces
    ldx banner_col
    ldy mux_i
    beq srb_text
srb_lead:
    sty score_work2
    stx score_work0
    ldy #HUD_ROW
    lda #SC_SPACE
    jsr screen_put_xy
    ldx score_work0
    inx
    ldy score_work2
    dey
    bne srb_lead

srb_text:
    ; Print nicety at banner_col + pad
    lda banner_col
    clc
    adc mux_i
    tax
    stx mux_j                       ; running print col
    ldx score_work1
    lda nicety_lo, x
    sta ptr_lo
    lda nicety_hi, x
    sta ptr_hi
    ldx mux_j
    ldy #HUD_ROW
    jsr screen_print

    ; Advance col by nicety length
    ldx score_work1
    lda nicety_lo, x
    sta ptr_lo
    lda nicety_hi, x
    sta ptr_hi
    jsr strlen
    clc
    adc mux_j
    tax
    stx mux_j

    ; ", "
    ldy #HUD_ROW
    lda #','
    jsr screen_put_xy
    inc mux_j
    ldx mux_j
    ldy #HUD_ROW
    lda #SC_SPACE
    jsr screen_put_xy
    inc mux_j

    ; Rank title
    ldx score_work1
    lda rank_title_lo, x
    sta ptr_lo
    lda rank_title_hi, x
    sta ptr_hi
    ldx mux_j
    ldy #HUD_ROW
    jsr screen_print

    ; Trailing pad
    lda mux_i
    beq srb_color
    lda banner_col
    clc
    adc banner_len
    sec
    sbc mux_i                       ; first trail col
    tax
    ldy mux_i
srb_trail:
    sty score_work2
    stx score_work0
    ldy #HUD_ROW
    lda #SC_SPACE
    jsr screen_put_xy
    ldx score_work0
    inx
    ldy score_work2
    dey
    bne srb_trail

srb_color:
    jsr paint_banner_color
    rts
.endproc

; Blank HUD cols HUD_BANNER_COL .. HUD_BANNER_END-1 (glyphs + white colour).
; Clobbers A,X,Y,score_work0.
.proc clear_banner_zone
    ldx #HUD_BANNER_COL
cbz_loop:
    stx score_work0
    ldy #HUD_ROW
    lda #SC_SPACE
    jsr screen_put_xy
    ldx score_work0
    ldy #HUD_ROW
    lda #COL_WHITE
    jsr screen_color_xy
    ldx score_work0
    inx
    cpx #HUD_BANNER_END
    bcc cbz_loop
    rts
.endproc

; X = wave index 0..14 from level. Clobbers A.
.proc wave_idx
    lda level
    bne wi_nz
    lda #1
wi_nz:
    cmp #MAX_LEVEL + 1
    bcc wi_cap
    lda #MAX_LEVEL
wi_cap:
    tax
    dex
    rts
.endproc

; A = strlen(ptr_*). Clobbers Y.
.proc strlen
    ldy #0
sl_loop:
    lda (ptr_lo), y
    beq sl_done
    iny
    bne sl_loop
sl_done:
    tya
    rts
.endproc

; Tick while level_banner_t > 0: advance colour through high-score palette once.
.proc tick_banner_color
    lda level_banner_t
    beq tbc_done
    jsr paint_banner_color
tbc_done:
    rts
.endproc

; Colour banner_col .. banner_col+banner_len-1 from elapsed frame / hold.
.proc paint_banner_color
    lda banner_len
    beq pbc_done
    lda #LEVEL_BANNER_FRAMES
    sec
    sbc level_banner_t
    ldx #0
pbc_div:
    cmp #BANNER_COLOR_HOLD
    bcc pbc_idx
    sec
    sbc #BANNER_COLOR_HOLD
    inx
    cpx #BANNER_NUM_COLORS - 1
    bcc pbc_div
pbc_idx:
    lda score_color_table, x
    sta score_work2
    ldx banner_col
    ldy banner_len
pbc_loop:
    sty score_work1
    stx score_work0
    lda score_work2
    ldy #HUD_ROW
    jsr screen_color_xy
    ldx score_work0
    inx
    ldy score_work1
    dey
    bne pbc_loop
pbc_done:
    rts
.endproc

.proc restore_hud_line
    jsr hud::paint_full_line
    jsr hud_color_static
    rts
.endproc

.endscope
