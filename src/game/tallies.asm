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
; Game-over layout (rows 0..24, 40 cols)
;
;   1   GAME OVER              (red, centred)
;   3   YOUR RESULTS           (yellow, centred)
;   6   SCORE     000000       labels end col 15, values @ 21
;   7   RANK      title
;   8   WAVES SURVIVED  n
;   9   SHOTS FIRED     n
;  11   DESTRUCTION            (section, orange)
;  12   MINE LAYERS     n      (C)
;  13   MEDIUM BOMBERS  n      (B)
;  14   HEAVY BOMBERS   n      (A)
;  22   PRESS FIRE             (yellow, centred)
; ---------------------------------------------------------------------------
GO_ROW_GAMEOVER = 1
GO_ROW_RESULTS  = 3
GO_ROW_SCORE    = 6
GO_ROW_RANK     = 7
GO_ROW_WAVES    = 8
GO_ROW_SHOTS    = 9
GO_ROW_DEST     = 11
GO_ROW_C        = 12
GO_ROW_B        = 13
GO_ROW_A        = 14
GO_ROW_FIRE     = 22

GO_LABEL_END    = 15                ; last column of right-aligned labels
GO_VALUE_COL    = 21                ; first column of values

.proc paint_gameover
    ; --- GAME OVER ---
    lda #<str_game_over
    sta ptr_lo
    lda #>str_game_over
    sta ptr_hi
    ldx #15                         ; "GAME OVER" = 9 → centre ~15
    ldy #GO_ROW_GAMEOVER
    jsr screen_print
    lda #COL_RED
    ldy #GO_ROW_GAMEOVER
    jsr screen_color_row

    ; --- YOUR RESULTS ---
    lda #<str_go_results
    sta ptr_lo
    lda #>str_go_results
    sta ptr_hi
    ldx #13                         ; 13 chars → centre col 13
    ldy #GO_ROW_RESULTS
    jsr screen_print
    lda #COL_YELLOW
    ldy #GO_ROW_RESULTS
    jsr screen_color_row

    ; --- SCORE ---
    lda #<str_go_score
    sta ptr_lo
    lda #>str_go_score
    sta ptr_hi
    ldy #GO_ROW_SCORE
    jsr print_label_ra
    ldy #GO_ROW_SCORE
    jsr print_score6
    lda #COL_WHITE
    ldy #GO_ROW_SCORE
    jsr screen_color_row

    ; --- RANK (title only) ---
    lda #<str_go_rank
    sta ptr_lo
    lda #>str_go_rank
    sta ptr_hi
    ldy #GO_ROW_RANK
    jsr print_label_ra
    jsr wave_index_to_x             ; X = 0..14
    lda rank_title_lo, x
    sta ptr_lo
    lda rank_title_hi, x
    sta ptr_hi
    ldx #GO_VALUE_COL
    ldy #GO_ROW_RANK
    jsr screen_print
    lda #COL_WHITE
    ldy #GO_ROW_RANK
    jsr screen_color_row

    ; --- WAVES SURVIVED (completed waves = level-1) ---
    lda #<str_go_waves
    sta ptr_lo
    lda #>str_go_waves
    sta ptr_hi
    ldy #GO_ROW_WAVES
    jsr print_label_ra
    lda level
    beq go_w0
    sec
    sbc #1
    jmp go_wput
go_w0:
    lda #0
go_wput:
    ldx #GO_VALUE_COL
    ldy #GO_ROW_WAVES
    jsr print_u8
    lda #COL_WHITE
    ldy #GO_ROW_WAVES
    jsr screen_color_row

    ; --- SHOTS FIRED ---
    lda #<str_go_shots
    sta ptr_lo
    lda #>str_go_shots
    sta ptr_hi
    ldy #GO_ROW_SHOTS
    jsr print_label_ra
    lda tally_shots0
    sta score_work0
    lda tally_shots1
    sta score_work1
    ldx #GO_VALUE_COL
    ldy #GO_ROW_SHOTS
    jsr print_u16
    lda #COL_WHITE
    ldy #GO_ROW_SHOTS
    jsr screen_color_row

    ; --- DESTRUCTION ---
    lda #<str_go_destruction
    sta ptr_lo
    lda #>str_go_destruction
    sta ptr_hi
    ldx #14                         ; 11 chars, slight centre bias
    ldy #GO_ROW_DEST
    jsr screen_print
    lda #COL_ORANGE
    ldy #GO_ROW_DEST
    jsr screen_color_row

    ; C mine layers
    lda #<str_go_mine
    sta ptr_lo
    lda #>str_go_mine
    sta ptr_hi
    ldy #GO_ROW_C
    jsr print_label_ra
    lda tally_kill_c0
    sta score_work0
    lda tally_kill_c1
    sta score_work1
    ldx #GO_VALUE_COL
    ldy #GO_ROW_C
    jsr print_u16
    lda #COL_WHITE
    ldy #GO_ROW_C
    jsr screen_color_row

    ; B medium bombers
    lda #<str_go_medium
    sta ptr_lo
    lda #>str_go_medium
    sta ptr_hi
    ldy #GO_ROW_B
    jsr print_label_ra
    lda tally_kill_b0
    sta score_work0
    lda tally_kill_b1
    sta score_work1
    ldx #GO_VALUE_COL
    ldy #GO_ROW_B
    jsr print_u16
    lda #COL_WHITE
    ldy #GO_ROW_B
    jsr screen_color_row

    ; A heavy bombers
    lda #<str_go_heavy
    sta ptr_lo
    lda #>str_go_heavy
    sta ptr_hi
    ldy #GO_ROW_A
    jsr print_label_ra
    lda tally_kill_a0
    sta score_work0
    lda tally_kill_a1
    sta score_work1
    ldx #GO_VALUE_COL
    ldy #GO_ROW_A
    jsr print_u16
    lda #COL_WHITE
    ldy #GO_ROW_A
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

; ptr_* = NUL-string; Y = row. Right-align so last char is at GO_LABEL_END.
; Clobbers A,X,Y,tmp*,ptr may be restored from measure.
.proc print_label_ra
    sty score_work2                 ; row
    ; strlen → score_work0
    ldy #0
pl_len:
    lda (ptr_lo), y
    beq pl_len_done
    iny
    bne pl_len
pl_len_done:
    sty score_work0
    ; start col = GO_LABEL_END + 1 - len
    lda #GO_LABEL_END + 1
    sec
    sbc score_work0
    tax
    ldy score_work2
    jsr screen_print
    rts
.endproc

; Wave index 0..14 from level (for rank title). Clobbers A; result in X.
.proc wave_index_to_x
    lda level
    bne wix_nz
    lda #1
wix_nz:
    cmp #MAX_LEVEL + 1
    bcc wix_cap
    lda #MAX_LEVEL
wix_cap:
    tax
    dex
    rts
.endproc

; 6-digit score with leading zeros at GO_VALUE_COL, row Y.
; Uses score0..2 (24-bit). Clobbers A,X,Y,score_work*,mux_i/j/k,tmp*.
.proc print_score6
    sty score_work2                 ; row
    lda score0
    sta score_work0
    lda score1
    sta score_work1
    lda score2
    sta mux_k                       ; hi byte of working value
    lda #GO_VALUE_COL
    sta mux_j                       ; col
    ldx #0                          ; place 0..5
ps6_place:
    stx mux_ref0                    ; save place index
    lda #0
    sta mux_i                       ; digit
ps6_sub:
    jsr cmp_s24
    bcc ps6_emit
    jsr sub_s24
    inc mux_i
    lda mux_i
    cmp #10
    bcc ps6_sub
ps6_emit:
    lda mux_i
    clc
    adc #SC_ZERO
    ldx mux_j
    ldy score_work2
    jsr screen_put_xy
    inc mux_j
    ldx mux_ref0
    inx
    cpx #6
    bcc ps6_place
    rts
.endproc

; C set if score_work0/1 + mux_k >= go_score_place[X]
.proc cmp_s24
    lda mux_k
    cmp go_score_hi, x
    bcc cs_lt
    bne cs_ge
    lda score_work1
    cmp go_score_mid, x
    bcc cs_lt
    bne cs_ge
    lda score_work0
    cmp go_score_lo, x
    bcc cs_lt
cs_ge:
    sec
    rts
cs_lt:
    clc
    rts
.endproc

.proc sub_s24
    lda score_work0
    sec
    sbc go_score_lo, x
    sta score_work0
    lda score_work1
    sbc go_score_mid, x
    sta score_work1
    lda mux_k
    sbc go_score_hi, x
    sta mux_k
    rts
.endproc

; 100000, 10000, 1000, 100, 10, 1 as 24-bit lo/mid/hi
go_score_lo:
    .byte $A0, $10, $E8, $64, $0A, $01
go_score_mid:
    .byte $86, $27, $03, $00, $00, $00
go_score_hi:
    .byte $01, $00, $00, $00, $00, $00

; Print A (0–255) decimal at col X, row Y. Returns next col in X.
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

    ldx #0
    jsr div_place
    ldx #1
    jsr div_place
    ldx #2
    jsr div_place
    ldx #3
    jsr div_place
    lda #1
    sta mux_k
    ldx #4
    jsr div_place
    ldx mux_j
    rts
.endproc

.proc div_place
    lda #0
    sta mux_i
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
    beq dp_skip
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

tally_place_lo:
    .byte <10000, <1000, <100, <10, <1
tally_place_hi:
    .byte >10000, >1000, >100, >10, >1

.endscope
