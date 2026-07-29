; Rank banner on HUD row (level complete). Centred overlay; rest of top line stays.
; Colour-cycles once through the high-score palette over LEVEL_BANNER_FRAMES.

.scope message

; Show rank line for current level (about to advance). Overlay only — no full clear.
.proc show_rank_banner
    ; Index = level - 1 (completed this level)
    lda level
    bne srb_nz
    lda #1
srb_nz:
    cmp #MAX_LEVEL + 1
    bcc srb_cap
    lda #MAX_LEVEL
srb_cap:
    tax
    dex
    lda rank_msg_lo, x
    sta ptr_lo
    lda rank_msg_hi, x
    sta ptr_hi

    ; Measure string length → score_work0
    ldy #0
srb_len:
    lda (ptr_lo), y
    beq srb_len_done
    iny
    bne srb_len
srb_len_done:
    sty score_work0                 ; text length

    ; Pad with BANNER_PAD_SPACES each side if room
    lda #BANNER_PAD_SPACES
    sta score_work1
srb_pad_try:
    lda score_work0
    clc
    adc score_work1
    bcc srb_pad_sum
    jmp srb_pad_zero
srb_pad_sum:
    clc
    adc score_work1                 ; + pad both sides
    bcs srb_pad_shrink
    cmp #SCREEN_W + 1
    bcc srb_pad_ok
srb_pad_shrink:
    dec score_work1
    bpl srb_pad_try
srb_pad_zero:
    lda #0
    sta score_work1
srb_pad_ok:
    ; total = len + 2*pad → score_work2
    lda score_work0
    clc
    adc score_work1
    clc
    adc score_work1
    sta score_work2
    sta banner_len

    ; start col = (40 - total) / 2
    lda #SCREEN_W
    sec
    sbc score_work2
    lsr a
    sta banner_col

    ; Paint leading pad spaces
    ldx banner_col
    ldy score_work1
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
    ; Print rank string at banner_col + pad
    lda banner_col
    clc
    adc score_work1
    tax
    ; restore string ptr (screen_put_xy clobbers ptr_*)
    lda level
    bne srb2_nz
    lda #1
srb2_nz:
    cmp #MAX_LEVEL + 1
    bcc srb2_cap
    lda #MAX_LEVEL
srb2_cap:
    tay
    dey
    lda rank_msg_lo, y
    sta ptr_lo
    lda rank_msg_hi, y
    sta ptr_hi
    ldy #HUD_ROW
    jsr screen_print

    ; Trailing pad spaces after text
    lda score_work1
    beq srb_color
    lda banner_col
    clc
    adc score_work1                 ; past lead pad
    clc
    ; + text length: remeasure quickly from print — use banner_len - 2*pad
    sta score_work0
    lda banner_len
    sec
    sbc score_work1
    sec
    sbc score_work1                 ; text len
    clc
    adc score_work0                 ; col of first trail space
    tax
    ldy score_work1
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
    ; First colour of the wheel
    jsr paint_banner_color
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
    ; elapsed = LEVEL_BANNER_FRAMES - level_banner_t
    ; (at first paint, level_banner_t is already set by caller)
    lda #LEVEL_BANNER_FRAMES
    sec
    sbc level_banner_t
    ; idx = min(BANNER_NUM_COLORS-1, elapsed / BANNER_COLOR_HOLD)
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
    sta score_work2                 ; colour
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
