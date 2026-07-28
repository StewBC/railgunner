; Session score — 1 hit = 1 point; paint 6 HUD digits when dirty.
; score0..score2 = 24-bit binary (lo, mid, hi), capped at 999999.

.scope score

; ---------------------------------------------------------------------------
; Clear score (game init). Leaves HUD template until paint_if_dirty.
; ---------------------------------------------------------------------------
.proc reset
    lda #0
    sta score0
    sta score1
    sta score2
    sta score_dirty
    rts
.endproc

; ---------------------------------------------------------------------------
; Award SCORE_HIT_POINTS for one registered bullet hit. Caps at 999999.
; Sets score_dirty. Clobbers A.
; ---------------------------------------------------------------------------
.proc add_hit
    lda #SCORE_HIT_POINTS
    jmp add_n
.endproc

; ---------------------------------------------------------------------------
; Award A points (0–255). Caps at 999999. Clobbers A.
; ---------------------------------------------------------------------------
.proc add_n
    clc
    adc score0
    sta score0
    lda score1
    adc #0
    sta score1
    lda score2
    adc #0
    sta score2
    ; Cap at 999999 if overflow past max
    lda score2
    cmp #SCORE_MAX2
    bcc hit_ok
    bne hit_cap
    lda score1
    cmp #SCORE_MAX1
    bcc hit_ok
    bne hit_cap
    lda score0
    cmp #SCORE_MAX0
    bcc hit_ok
    beq hit_ok
hit_cap:
    lda #SCORE_MAX0
    sta score0
    lda #SCORE_MAX1
    sta score1
    lda #SCORE_MAX2
    sta score2
hit_ok:
    lda #1
    sta score_dirty
    rts
.endproc

; ---------------------------------------------------------------------------
; If dirty: write score0..2 as 6 decimal digits to HUD row 0 cols 0–5.
; Working value lives in score_work* so screen_put_xy (tmp*/ptr*) is safe.
; Clobbers A,X,Y,tmp0-2,ptr_*,mux_i (digit),mux_j (place idx),mux_k (glyph).
; ---------------------------------------------------------------------------
.proc paint_if_dirty
    lda score_dirty
    bne do_paint
    rts
do_paint:
    lda #0
    sta score_dirty
    lda score0
    sta score_work0
    lda score1
    sta score_work1
    lda score2
    sta score_work2
    ldx #0                          ; place index 0..5
digit_loop:
    lda #0
    sta mux_i                       ; digit accumulator
sub_loop:
    jsr cmp_place                   ; C set if work >= place[X]
    bcc digit_done
    jsr sub_place
    inc mux_i
    lda mux_i
    cmp #10                         ; hard stop — digits are 0..9
    bcc sub_loop
digit_done:
    stx mux_j
    lda mux_i
    cmp #10
    bcc digit_ok
    lda #9                          ; should not happen; clamp glyph
digit_ok:
    clc
    adc #SC_ZERO
    sta mux_k
    lda mux_j
    clc
    adc #HUD_SCORE_COL
    tax
    ldy #HUD_ROW
    lda mux_k
    jsr screen_put_xy
    ldx mux_j
    inx
    cpx #6
    bcc digit_loop
    rts
.endproc

; C set if score_work >= place[X] (24-bit). Preserves X.
.proc cmp_place
    lda score_work2
    cmp score_place_hi, x
    bcc cmp_lt
    bne cmp_ge
    lda score_work1
    cmp score_place_mid, x
    bcc cmp_lt
    bne cmp_ge
    lda score_work0
    cmp score_place_lo, x
    bcc cmp_lt
cmp_ge:
    sec
    rts
cmp_lt:
    clc
    rts
.endproc

; score_work -= place[X] (assumes work >= place). Preserves X.
.proc sub_place
    lda score_work0
    sec
    sbc score_place_lo, x
    sta score_work0
    lda score_work1
    sbc score_place_mid, x
    sta score_work1
    lda score_work2
    sbc score_place_hi, x
    sta score_work2
    rts
.endproc

; Place values 100000, 10000, 1000, 100, 10, 1 as 24-bit lo/mid/hi tables.
score_place_lo:
    .byte $A0, $10, $E8, $64, $0A, $01
score_place_mid:
    .byte $86, $27, $03, $00, $00, $00
score_place_hi:
    .byte $01, $00, $00, $00, $00, $00

.endscope
