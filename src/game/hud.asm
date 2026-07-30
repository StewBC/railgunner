; Play HUD — score (score.asm), wave, progress bar, pilots (RESERVE lives).
; Layout: 000000 - WAVE 01 - ######## -PILOTS:AAAA
; lives ZP = ships in reserve (max 4). Active ship is not drawn as a pilot.

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
    lda level_banner_t
    bne paint_skip                  ; rank banner owns the top line
    jsr paint_level
    jsr paint_progress
    jsr paint_lives
paint_skip:
    rts
.endproc

; Full template + dynamics (stage enter / after banner).
.proc paint_full_line
    lda #<str_hud
    sta ptr_lo
    lda #>str_hud
    sta ptr_hi
    ldx #0
    ldy #HUD_ROW
    jsr screen_print
    lda #1
    sta score_dirty
    jsr score::paint_if_dirty
    jsr paint_level
    jsr paint_progress
    jsr paint_lives
    rts
.endproc

.proc paint_level
    lda level
    ldx #0
tens_loop:
    cmp #10
    bcc tens_done
    sec
    sbc #10
    inx
    jmp tens_loop
tens_done:
    sta score_work0
    stx score_work1
    lda score_work1
    clc
    adc #SC_ZERO
    ldx #HUD_LEVEL_COL
    ldy #HUD_ROW
    jsr screen_put_xy
    lda score_work0
    clc
    adc #SC_ZERO
    ldx #HUD_LEVEL_COL + 1
    ldy #HUD_ROW
    jsr screen_put_xy
    rts
.endproc

; Progress full→empty. steps_left ≈ rem_kills * 8 / (quota/4) capped 32.
.proc paint_progress
    lda level_quota
    bne pp_q
    lda #16
    sta level_quota
pp_q:
    lda level_quota
    sec
    sbc level_kills
    bcs pp_rem
    lda #0
pp_rem:
    sta mux_i                       ; rem kills
    lda level_quota
    lsr a
    lsr a                           ; quota/4
    bne pp_den
    lda #1
pp_den:
    sta mux_k
    lda mux_i
    asl a
    asl a
    asl a                           ; rem*8
    sta mux_i
    lda #0
    sta mux_j                       ; steps
pp_div:
    lda mux_i
    cmp mux_k
    bcc pp_draw
    sec
    sbc mux_k
    sta mux_i
    inc mux_j
    lda mux_j
    cmp #LEVEL_BAR_STEPS + 1
    bcc pp_div
    lda #LEVEL_BAR_STEPS
    sta mux_j
pp_draw:
    lda mux_j
    sta score_work0
    ldx #0
pp_cell:
    lda score_work0
    beq pp_empty
    cmp #4
    bcc pp_part
    lda #SC_UDG_BAR8
    sta score_work2
    lda score_work0
    sec
    sbc #4
    sta score_work0
    jmp pp_put
pp_part:
    cmp #1
    beq pp1
    cmp #2
    beq pp2
    lda #SC_UDG_BAR6
    jmp ppst
pp2:
    lda #SC_UDG_BAR4
    jmp ppst
pp1:
    lda #SC_UDG_BAR2
ppst:
    sta score_work2
    lda #0
    sta score_work0
    jmp pp_put
pp_empty:
    lda #SC_SPACE
    sta score_work2
pp_put:
    stx score_work1
    txa
    clc
    adc #HUD_PROGRESS_COL
    tax
    ldy #HUD_ROW
    lda score_work2
    jsr screen_put_xy
    ldx score_work1
    inx
    cpx #HUD_PROGRESS_LEN
    bcc pp_cell
    rts
.endproc

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
    sta score_work0
    lda #HUD_LIVES_COL + HUD_LIVES_MAX_SHOW - 1
    sta score_work1
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
