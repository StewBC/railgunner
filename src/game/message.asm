; Rank banner on HUD row (level complete). No wave messages.

.scope message

; Show rank line for current level (about to advance). Full top row.
.proc show_rank_banner
    ; Clear row to spaces
    ldx #0
srb_clr:
    stx score_work1
    ldy #HUD_ROW
    lda #SC_SPACE
    jsr screen_put_xy
    ldx score_work1
    inx
    cpx #40
    bcc srb_clr

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
    ldx #0
    ldy #HUD_ROW
    jsr screen_print

    ; Yellow whole row
    lda #COL_YELLOW
    ldy #HUD_ROW
    jsr screen_color_row
    rts
.endproc

.proc restore_hud_line
    jsr hud::paint_full_line
    jsr hud_color_static
    rts
.endproc

.endscope
