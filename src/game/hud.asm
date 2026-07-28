; Thin play HUD — health bar, level digits, lives (right-aligned A's).
; Score digits live in score.asm. screen_put_xy clobbers tmp0–2 — use score_work*.

.scope hud

.proc mark_status_dirty
    lda #1
    sta hud_status_dirty
    rts
.endproc

.proc paint_status_if_dirty
    lda hud_status_dirty
    bne do_paint
    rts
do_paint:
    lda #0
    sta hud_status_dirty
    jsr paint_health
    jsr paint_level
    jsr paint_lives
    rts
.endproc

; ---------------------------------------------------------------------------
; Health: 8 cells × 4 HP. Per cell: BAR8/6/4/2 or space (left → right).
; ---------------------------------------------------------------------------
.proc paint_health
    lda health
    sta score_work0                 ; HP remaining to place
    ldx #0                          ; cell index 0..7
health_cell:
    lda score_work0
    beq health_empty
    cmp #4
    bcc health_partial
    ; full cell
    lda #SC_UDG_BAR8
    sta score_work2
    lda score_work0
    sec
    sbc #4
    sta score_work0
    jmp health_put
health_partial:
    ; 1→BAR2, 2→BAR4, 3→BAR6
    cmp #1
    beq hp1
    cmp #2
    beq hp2
    lda #SC_UDG_BAR6
    sta score_work2
    lda #0
    sta score_work0
    jmp health_put
hp2:
    lda #SC_UDG_BAR4
    sta score_work2
    lda #0
    sta score_work0
    jmp health_put
hp1:
    lda #SC_UDG_BAR2
    sta score_work2
    lda #0
    sta score_work0
    jmp health_put
health_empty:
    lda #SC_SPACE
    sta score_work2
health_put:
    stx score_work1                 ; save cell index (put_xy keeps X but we use work)
    txa
    clc
    adc #HUD_HEALTH_BAR_COL
    tax
    ldy #HUD_ROW
    lda score_work2
    jsr screen_put_xy
    ldx score_work1
    inx
    cpx #HUD_HEALTH_BAR_LEN
    bcc health_cell
    rts
.endproc

; ---------------------------------------------------------------------------
; Level: 2 decimal digits at HUD_LEVEL_COL (template ships L:01).
; Displays 00–99 (values ≥100 wrap the tens count; fine for the thin HUD).
; ---------------------------------------------------------------------------
.proc paint_level
    lda level
    ldx #0                          ; tens
tens_loop:
    cmp #10
    bcc tens_done
    sec
    sbc #10
    inx
    jmp tens_loop
tens_done:
    sta score_work0                 ; ones 0..9
    stx score_work1                 ; tens
    ; tens glyph
    lda score_work1
    clc
    adc #SC_ZERO
    sta score_work2
    ldx #HUD_LEVEL_COL
    ldy #HUD_ROW
    lda score_work2
    jsr screen_put_xy
    ; ones glyph
    lda score_work0
    clc
    adc #SC_ZERO
    sta score_work2
    ldx #HUD_LEVEL_COL + 1
    ldy #HUD_ROW
    lda score_work2
    jsr screen_put_xy
    rts
.endproc

; ---------------------------------------------------------------------------
; Lives: right-aligned in cols 36–39; last life always col 39.
; ---------------------------------------------------------------------------
.proc paint_lives
    ldx #0
lives_clear:
    stx score_work1
    txa
    clc
    adc #HUD_LIVES_COL
    tax
    ldy #HUD_ROW
    lda #SC_SPACE
    jsr screen_put_xy
    ldx score_work1
    inx
    cpx #HUD_LIVES_MAX_SHOW
    bcc lives_clear

    lda lives
    beq lives_done
    cmp #HUD_LIVES_MAX_SHOW + 1
    bcc lives_n
    lda #HUD_LIVES_MAX_SHOW
lives_n:
    sta score_work0                 ; n icons
    lda #HUD_LIVES_COL + HUD_LIVES_MAX_SHOW - 1
    sta score_work1                 ; col from the right
lives_draw:
    ldx score_work1
    ldy #HUD_ROW
    lda #SC_LETTER_A
    jsr screen_put_xy
    dec score_work1
    dec score_work0
    bne lives_draw
lives_done:
    rts
.endproc

.endscope
