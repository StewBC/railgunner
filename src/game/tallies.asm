; Session tallies — shots fired + A/B/C kills. Painted on game over.

.scope tallies

; ---------------------------------------------------------------------------
.proc reset
    lda #0
    sta tally_shots0
    sta tally_shots1
    sta tally_kill_a0
    sta tally_kill_a1
    sta tally_kill_b0
    sta tally_kill_b1
    sta tally_kill_c0
    sta tally_kill_c1
    rts
.endproc

; One successful bullet spawn (slot claimed).
.proc note_shot
    inc tally_shots0
    bne ns_done
    inc tally_shots1
    bne ns_done
    ; sat $FFFF
    lda #$FF
    sta tally_shots0
    sta tally_shots1
ns_done:
    rts
.endproc

; X = drone object slot just killed. Count by kind A/B/C.
.proc note_kill
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_A
    beq nk_a
    cmp #OBJ_DRONE_B
    beq nk_b
    cmp #OBJ_DRONE_C
    beq nk_c
    rts
nk_a:
    inc tally_kill_a0
    bne nk_done
    inc tally_kill_a1
    bne nk_done
    lda #$FF
    sta tally_kill_a0
    sta tally_kill_a1
    rts
nk_b:
    inc tally_kill_b0
    bne nk_done
    inc tally_kill_b1
    bne nk_done
    lda #$FF
    sta tally_kill_b0
    sta tally_kill_b1
    rts
nk_c:
    inc tally_kill_c0
    bne nk_done
    inc tally_kill_c1
    bne nk_done
    lda #$FF
    sta tally_kill_c0
    sta tally_kill_c1
nk_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; Game-over layout (row, approx centred labels)
;   4  GAME OVER
;   7  TALLIES:
;   9  YOU SURVIVED n ATTACK WAVES
;  11  YOU FIRED: n BULLETS
;  13  DESTROYED:
;  14  CLASS A n
;  15  CLASS B n
;  16  CLASS C n
;  20  PRESS FIRE
; ---------------------------------------------------------------------------
GO_ROW_TITLE    = 4
GO_ROW_TALLIES  = 7
GO_ROW_SURVIVED = 9
GO_ROW_FIRED    = 11
GO_ROW_DEST     = 13
GO_ROW_A        = 14
GO_ROW_B        = 15
GO_ROW_C        = 16
GO_ROW_FIRE     = 20
GO_COL_LEFT     = 8                 ; common left margin for body lines

.proc paint_gameover
    ; --- GAME OVER ---
    lda #<str_game_over
    sta ptr_lo
    lda #>str_game_over
    sta ptr_hi
    ldx #15
    ldy #GO_ROW_TITLE
    jsr screen_print
    lda #COL_RED
    ldy #GO_ROW_TITLE
    jsr screen_color_row

    ; --- TALLIES: ---
    lda #<str_tallies
    sta ptr_lo
    lda #>str_tallies
    sta ptr_hi
    ldx #GO_COL_LEFT
    ldy #GO_ROW_TALLIES
    jsr screen_print
    lda #COL_YELLOW
    ldy #GO_ROW_TALLIES
    jsr screen_color_row

    ; --- YOU SURVIVED n ATTACK WAVES ---
    lda #<str_survived_pre
    sta ptr_lo
    lda #>str_survived_pre
    sta ptr_hi
    ldx #GO_COL_LEFT
    ldy #GO_ROW_SURVIVED
    jsr screen_print
    ; col after "YOU SURVIVED " (13 chars) = GO_COL_LEFT+13
    lda level
    beq surv_zero
    sec
    sbc #1                          ; completed levels = level - 1
    jmp surv_put
surv_zero:
    lda #0
surv_put:
    ldx #GO_COL_LEFT + 13
    ldy #GO_ROW_SURVIVED
    jsr print_u8
    stx score_work0                 ; next col
    lda #<str_survived_post
    sta ptr_lo
    lda #>str_survived_post
    sta ptr_hi
    ldx score_work0
    ldy #GO_ROW_SURVIVED
    jsr screen_print
    lda #COL_WHITE
    ldy #GO_ROW_SURVIVED
    jsr screen_color_row

    ; --- YOU FIRED: n BULLETS ---
    lda #<str_fired_pre
    sta ptr_lo
    lda #>str_fired_pre
    sta ptr_hi
    ldx #GO_COL_LEFT
    ldy #GO_ROW_FIRED
    jsr screen_print
    lda tally_shots0
    sta score_work0
    lda tally_shots1
    sta score_work1
    ldx #GO_COL_LEFT + 11           ; after "YOU FIRED: "
    ldy #GO_ROW_FIRED
    jsr print_u16
    stx score_work2
    lda #<str_fired_post
    sta ptr_lo
    lda #>str_fired_post
    sta ptr_hi
    ldx score_work2
    ldy #GO_ROW_FIRED
    jsr screen_print
    lda #COL_WHITE
    ldy #GO_ROW_FIRED
    jsr screen_color_row

    ; --- DESTROYED: ---
    lda #<str_destroyed
    sta ptr_lo
    lda #>str_destroyed
    sta ptr_hi
    ldx #GO_COL_LEFT
    ldy #GO_ROW_DEST
    jsr screen_print
    lda #COL_CYAN
    ldy #GO_ROW_DEST
    jsr screen_color_row

    ; CLASS A / B / C
    lda #<str_class_a
    sta ptr_lo
    lda #>str_class_a
    sta ptr_hi
    ldx #GO_COL_LEFT + 2
    ldy #GO_ROW_A
    jsr screen_print
    lda tally_kill_a0
    sta score_work0
    lda tally_kill_a1
    sta score_work1
    ldx #GO_COL_LEFT + 2 + 8        ; after "CLASS A "
    ldy #GO_ROW_A
    jsr print_u16
    lda #COL_WHITE
    ldy #GO_ROW_A
    jsr screen_color_row

    lda #<str_class_b
    sta ptr_lo
    lda #>str_class_b
    sta ptr_hi
    ldx #GO_COL_LEFT + 2
    ldy #GO_ROW_B
    jsr screen_print
    lda tally_kill_b0
    sta score_work0
    lda tally_kill_b1
    sta score_work1
    ldx #GO_COL_LEFT + 2 + 8
    ldy #GO_ROW_B
    jsr print_u16
    lda #COL_WHITE
    ldy #GO_ROW_B
    jsr screen_color_row

    lda #<str_class_c
    sta ptr_lo
    lda #>str_class_c
    sta ptr_hi
    ldx #GO_COL_LEFT + 2
    ldy #GO_ROW_C
    jsr screen_print
    lda tally_kill_c0
    sta score_work0
    lda tally_kill_c1
    sta score_work1
    ldx #GO_COL_LEFT + 2 + 8
    ldy #GO_ROW_C
    jsr print_u16
    lda #COL_WHITE
    ldy #GO_ROW_C
    jsr screen_color_row

    ; PRESS FIRE
    lda #<str_press_fire
    sta ptr_lo
    lda #>str_press_fire
    sta ptr_hi
    ldx #15
    ldy #GO_ROW_FIRE
    jsr screen_print
    lda #COL_YELLOW
    ldy #GO_ROW_FIRE
    jsr screen_color_row
    rts
.endproc

; Print A (0–255) decimal at col X, row Y. Returns next col in X.
; Clobbers A,Y,tmp*,ptr*,score_work0/1/2,mux_i/j.
.proc print_u8
    sta score_work0
    lda #0
    sta score_work1
    jmp print_u16
.endproc

; Print 16-bit score_work0/1 at col X, row Y (no leading zeros; "0" if zero).
; Returns next col in X. Row preserved via score_work2 during digit loop.
.proc print_u16
    sty score_work2                 ; row
    stx mux_j                       ; current col
    lda #0
    sta mux_k                       ; 0 = still leading zeros

    ; 10000s
    ldx #0
    jsr div_place
    ; 1000s
    ldx #1
    jsr div_place
    ; 100s
    ldx #2
    jsr div_place
    ; 10s
    ldx #3
    jsr div_place
    ; 1s always
    lda #1
    sta mux_k
    ldx #4
    jsr div_place
    ldx mux_j
    rts
.endproc

; Place index X: subtract tally_place from score_work while >=; emit digit if
; non-leading or last place. mux_j = col, score_work2 = row, mux_k = seen digit.
.proc div_place
    lda #0
    sta mux_i                       ; digit
dp_sub:
    jsr cmp_place
    bcc dp_emit
    jsr sub_place
    inc mux_i
    lda mux_i
    cmp #10
    bcc dp_sub
dp_emit:
    lda mux_k
    bne dp_put
    lda mux_i
    beq dp_skip                     ; leading zero
    lda #1
    sta mux_k
dp_put:
    lda mux_i
    clc
    adc #SC_ZERO
    ldx mux_j
    ldy score_work2
    jsr screen_put_xy
    inc mux_j
dp_skip:
    rts
.endproc

.proc cmp_place
    lda score_work1
    cmp tally_place_hi, x
    bcc cmp_lt
    bne cmp_ge
    lda score_work0
    cmp tally_place_lo, x
    bcc cmp_lt
cmp_ge:
    sec
    rts
cmp_lt:
    clc
    rts
.endproc

.proc sub_place
    lda score_work0
    sec
    sbc tally_place_lo, x
    sta score_work0
    lda score_work1
    sbc tally_place_hi, x
    sta score_work1
    rts
.endproc

; 10000, 1000, 100, 10, 1
tally_place_lo:
    .byte <10000, <1000, <100, <10, <1
tally_place_hi:
    .byte >10000, >1000, >100, >10, >1

.endscope
