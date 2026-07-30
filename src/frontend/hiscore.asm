; High-score table helpers + name entry mode.
; Table rows live in DATA (hs_line_*) — mutable in place (disk save later).
; Title and entry share hs_paint_table / colour wheel.
; Lives in CODE_HI (low CODE is tight against CHARSET $2800).

.segment "CODE_HI"

; ---------------------------------------------------------------------------
; Shared table paint — PAST HEROES, column header, 10 score lines.
; Clobbers A,X,Y,ptr_*,draw_i,tmp*,print_ptr_*.
; ---------------------------------------------------------------------------
.proc hs_paint_table
    lda #<str_past_heroes
    sta ptr_lo
    lda #>str_past_heroes
    sta ptr_hi
    ldx #HS_COL_HEROES
    ldy #HS_ROW_HEROES
    jsr screen_print
    lda #COL_CYAN
    ldy #HS_ROW_HEROES
    jsr screen_color_row

    lda #<str_hs_header
    sta ptr_lo
    lda #>str_hs_header
    sta ptr_hi
    ldx #HS_COL_TABLE
    ldy #HS_ROW_HEAD
    jsr screen_print
    lda #COL_WHITE
    ldy #HS_ROW_HEAD
    jsr screen_color_row

    lda #0
    sta draw_i
hpt_loop:
    lda draw_i
    asl a
    tax
    lda hs_line_ptrs, x
    sta ptr_lo
    lda hs_line_ptrs + 1, x
    sta ptr_hi
    ldx #HS_COL_TABLE
    lda draw_i
    clc
    adc #HS_ROW_SCORE0
    tay
    jsr screen_print
    inc draw_i
    lda draw_i
    cmp #10
    bcc hpt_loop
    rts
.endproc

; ---------------------------------------------------------------------------
; hiscore_reset — cold init. Disk load later; RAM defaults in strings.
; ---------------------------------------------------------------------------
.proc hiscore_reset
    rts
.endproc

; ---------------------------------------------------------------------------
; hiscore_qualifies — C set if session score earns a top-10 slot.
; Key is score only. Clobbers A,X,Y,ptr_*,score_work*,tmp*,mux_i/j/k,draw_i.
; ---------------------------------------------------------------------------
.proc hiscore_qualifies
    lda #0
    sta mux_j                       ; count of entries with score >= session
    sta draw_i
hq_loop:
    lda draw_i
    asl a
    tax
    lda hs_line_ptrs, x
    sta ptr_lo
    lda hs_line_ptrs + 1, x
    sta ptr_hi
    jsr hs_parse_score
    jsr hs_cmp_session              ; C if entry >= session
    bcc hq_next
    inc mux_j
hq_next:
    inc draw_i
    lda draw_i
    cmp #10
    bcc hq_loop
    lda mux_j
    cmp #10
    bcc hq_yes
    clc
    rts
hq_yes:
    sec
    rts
.endproc

; ptr → line. Parse 6 ASCII digits at HS_SCORE_OFF → score_work0..2.
.proc hs_parse_score
    lda #0
    sta score_work0
    sta score_work1
    sta score_work2
    ldy #HS_SCORE_OFF
    ldx #6
hps_digit:
    jsr hs_work_mul10
    lda (ptr_lo), y
    sec
    sbc #'0'
    clc
    adc score_work0
    sta score_work0
    lda score_work1
    adc #0
    sta score_work1
    lda score_work2
    adc #0
    sta score_work2
    iny
    dex
    bne hps_digit
    rts
.endproc

; score_work0..2 *= 10. Clobbers A, mux_i, mux_k, tmp0.
.proc hs_work_mul10
    lda score_work0
    sta mux_i
    lda score_work1
    sta mux_k
    lda score_work2
    sta tmp0
    asl score_work0
    rol score_work1
    rol score_work2
    asl score_work0
    rol score_work1
    rol score_work2
    asl score_work0
    rol score_work1
    rol score_work2
    asl mux_i
    rol mux_k
    rol tmp0
    lda score_work0
    clc
    adc mux_i
    sta score_work0
    lda score_work1
    adc mux_k
    sta score_work1
    lda score_work2
    adc tmp0
    sta score_work2
    rts
.endproc

; C set if score_work (entry) >= score0..2 (session).
.proc hs_cmp_session
    lda score_work2
    cmp score2
    bcc hcs_lt
    bne hcs_ge
    lda score_work1
    cmp score1
    bcc hcs_lt
    bne hcs_ge
    lda score_work0
    cmp score0
    bcc hcs_lt
hcs_ge:
    sec
    rts
hcs_lt:
    clc
    rts
.endproc

; ---------------------------------------------------------------------------
; Insert session into table by score (descending). Sets hs_rank.
; Name A--; wave/rank/shots/score from session. Clobbers heavily.
; ---------------------------------------------------------------------------
.proc hiscore_insert
    ; Find first rank where session > entry score
    lda #0
    sta hs_rank
hi_find:
    lda hs_rank
    cmp #10
    bcs hi_last                     ; should not qualify; clamp to 10th
    asl a
    tax
    lda hs_line_ptrs, x
    sta ptr_lo
    lda hs_line_ptrs + 1, x
    sta ptr_hi
    jsr hs_parse_score
    jsr hs_cmp_session              ; C if entry >= session
    bcc hi_shift                    ; entry < session → insert here
    inc hs_rank
    jmp hi_find
hi_last:
    lda #9
    sta hs_rank

hi_shift:
    ; Shift rows 9..hs_rank+1 down (fields only; rank prefix stays)
    lda #9
    sta draw_i
hi_sh_loop:
    lda draw_i
    cmp hs_rank
    beq hi_fill
    ; dst = draw_i, src = draw_i - 1
    asl a
    tax
    lda hs_line_ptrs, x
    sta print_ptr_lo                ; dst lo
    lda hs_line_ptrs + 1, x
    sta print_ptr_hi
    lda draw_i
    sec
    sbc #1
    asl a
    tax
    lda hs_line_ptrs, x
    sta ptr_lo                      ; src
    lda hs_line_ptrs + 1, x
    sta ptr_hi
    ldy #HS_INITIALS_OFF
hi_copy:
    lda (ptr_lo), y
    sta (print_ptr_lo), y
    iny
    cpy #HS_LINE_LEN
    bcc hi_copy
    dec draw_i
    jmp hi_sh_loop

hi_fill:
    ; Point at insert row
    lda hs_rank
    asl a
    tax
    lda hs_line_ptrs, x
    sta ptr_lo
    lda hs_line_ptrs + 1, x
    sta ptr_hi
    ; Name A--
    lda #'A'
    ldy #HS_INITIALS_OFF
    sta (ptr_lo), y
    lda #'-'
    iny
    sta (ptr_lo), y
    iny
    sta (ptr_lo), y
    ; Wave (2 digits, centred under WAVE @ off 11)
    jsr hs_session_waves            ; A = 0..15
    sta score_work2                 ; keep for rank title
    ldx #HS_WAVE_OFF
    jsr hs_write_u8_2
    ; Military rank title (7 chars) from waves survived
    lda score_work2
    jsr hs_write_rank
    ; Shots (5 digits)
    lda tally_shots0
    sta score_work0
    lda tally_shots1
    sta score_work1
    ldx #HS_SHOTS_OFF
    jsr hs_write_u16_5
    ; Score (6 digits)
    ldx #HS_SCORE_OFF
    jsr hs_write_score_6
    rts
.endproc

; A = waves survived for table (victory → 15, else level-1).
.proc hs_session_waves
    lda victory
    beq hsw_normal
    lda #MAX_LEVEL
    rts
hsw_normal:
    lda level
    beq hsw_0
    sec
    sbc #1
    rts
hsw_0:
    lda #0
    rts
.endproc

; Write 7-char rank title at (ptr)+HS_RANK_OFF from waves survived in A (0..15).
; 0 → blank; 1..15 → str_rank_title_01..15 left-justified, space-padded.
; Clobbers A,X,Y,tmp0,tmp1,print_ptr_*.
.proc hs_write_rank
    cmp #0
    beq hwr_blank
    cmp #MAX_LEVEL + 1
    bcc hwr_ok
    lda #MAX_LEVEL
hwr_ok:
    sec
    sbc #1                          ; 0..14 index
    tax
    lda rank_title_lo, x
    sta print_ptr_lo
    lda rank_title_hi, x
    sta print_ptr_hi
    lda #0
    sta tmp1                        ; source index
hwr_copy:
    ldy tmp1
    lda (print_ptr_lo), y
    beq hwr_pad                     ; hit NUL → pad rest
    sta tmp0
    lda tmp1
    clc
    adc #HS_RANK_OFF
    tay                             ; dest offset in line (Y for (zp),Y)
    lda tmp0
    sta (ptr_lo), y
    inc tmp1
    lda tmp1
    cmp #HS_RANK_LEN
    bcc hwr_copy
    rts
hwr_pad:
    lda tmp1
    clc
    adc #HS_RANK_OFF
    tay
hwr_pad_loop:
    lda #' '
    sta (ptr_lo), y
    iny
    inc tmp1
    lda tmp1
    cmp #HS_RANK_LEN
    bcc hwr_pad_loop
    rts
hwr_blank:
    ldy #HS_RANK_OFF
    ldx #HS_RANK_LEN
hwr_bl_loop:
    lda #' '
    sta (ptr_lo), y
    iny
    dex
    bne hwr_bl_loop
    rts
.endproc

; Write A as 2 zero-padded digits at (ptr)+X. Clobbers A,Y,score_work0.
.proc hs_write_u8_2
    sta score_work0
    txa
    clc
    adc #1                          ; ones place
    tay
    lda score_work0
hw2_ones:
    cmp #10
    bcc hw2_ones_ok
    sec
    sbc #10
    jmp hw2_ones
hw2_ones_ok:
    clc
    adc #'0'
    sta (ptr_lo), y
    dey
    lda #0
    sta score_work1                 ; tens
    lda score_work0
hw2_tens:
    cmp #10
    bcc hw2_tens_ok
    sec
    sbc #10
    inc score_work1
    jmp hw2_tens
hw2_tens_ok:
    lda score_work1
    clc
    adc #'0'
    sta (ptr_lo), y
    rts
.endproc

; Write score_work0/1 as 5 zero-padded digits at (ptr)+X.
; Clobbers A,Y,mux_i/j/k,score_work2,tmp0.
.proc hs_write_u16_5
    stx mux_j                       ; base offset
    lda #0
    sta mux_k                       ; place index 0..4
hw5_place:
    lda #0
    sta mux_i                       ; digit
hw5_sub:
    ; cmp work >= place value
    ldx mux_k
    lda score_work1
    cmp hs_u16_hi, x
    bcc hw5_emit
    bne hw5_do
    lda score_work0
    cmp hs_u16_lo, x
    bcc hw5_emit
hw5_do:
    lda score_work0
    sec
    sbc hs_u16_lo, x
    sta score_work0
    lda score_work1
    sbc hs_u16_hi, x
    sta score_work1
    inc mux_i
    lda mux_i
    cmp #10
    bcc hw5_sub
hw5_emit:
    lda mux_j
    clc
    adc mux_k
    tay
    lda mux_i
    clc
    adc #'0'
    sta (ptr_lo), y
    inc mux_k
    lda mux_k
    cmp #5
    bcc hw5_place
    rts
.endproc

hs_u16_lo:
    .byte <10000, <1000, <100, <10, <1
hs_u16_hi:
    .byte >10000, >1000, >100, >10, >1

; Write score0..2 as 6 zero-padded digits at (ptr)+X.
; Clobbers A,Y,mux_*,score_work*,tmp0.
.proc hs_write_score_6
    stx mux_j                       ; base offset
    lda score0
    sta score_work0
    lda score1
    sta score_work1
    lda score2
    sta score_work2
    lda #0
    sta mux_k                       ; place 0..5
hws_place:
    lda #0
    sta mux_i
hws_sub:
    ldx mux_k
    lda score_work2
    cmp hs_s24_hi, x
    bcc hws_emit
    bne hws_do
    lda score_work1
    cmp hs_s24_mid, x
    bcc hws_emit
    bne hws_do
    lda score_work0
    cmp hs_s24_lo, x
    bcc hws_emit
hws_do:
    lda score_work0
    sec
    sbc hs_s24_lo, x
    sta score_work0
    lda score_work1
    sbc hs_s24_mid, x
    sta score_work1
    lda score_work2
    sbc hs_s24_hi, x
    sta score_work2
    inc mux_i
    lda mux_i
    cmp #10
    bcc hws_sub
hws_emit:
    lda mux_j
    clc
    adc mux_k
    tay
    lda mux_i
    clc
    adc #'0'
    sta (ptr_lo), y
    inc mux_k
    lda mux_k
    cmp #6
    bcc hws_place
    rts
.endproc

; 100000, 10000, 1000, 100, 10, 1
hs_s24_lo:
    .byte $A0, $10, $E8, $64, $0A, $01
hs_s24_mid:
    .byte $86, $27, $03, $00, $00, $00
hs_s24_hi:
    .byte $01, $00, $00, $00, $00, $00

; ---------------------------------------------------------------------------
; Charset: A–Z . 0–9 space ←
; ---------------------------------------------------------------------------
hs_charset:
    .byte "ABCDEFGHIJKLMNOPQRSTUVWXYZ.0123456789 "
    .byte PET_LEFT_ARROW

; ---------------------------------------------------------------------------
; MODE_HISCORE enter — insert, paint table + prompt, start at A--.
; ---------------------------------------------------------------------------
.proc hiscore_enter
    jsr hiscore_insert

    lda #COL_YELLOW
    sta VIC_BORDER
    jsr vic_text_mode               ; blank + text + clear

    ; CONGRATULATIONS PILOT! (title row)
    lda #<str_hs_congrats
    sta ptr_lo
    lda #>str_hs_congrats
    sta ptr_hi
    ldx #HS_COL_CONGRATS
    ldy #HS_ROW_CONGRATS
    jsr screen_print
    lda #COL_YELLOW
    ldy #HS_ROW_CONGRATS
    jsr screen_color_row

    jsr hs_paint_table

    ; YOU HAVE A NEW HIGH SCORE (where prompt used to sit)
    lda #<str_hs_new_score
    sta ptr_lo
    lda #>str_hs_new_score
    sta ptr_hi
    ldx #HS_COL_NEW
    ldy #HS_ROW_NEW
    jsr screen_print
    lda #COL_LT_GREEN
    ldy #HS_ROW_NEW
    jsr screen_color_row

    ; Reset prompt name to A--
    lda #'A'
    sta str_hs_prompt + HS_PROMPT_NAME_OFF
    lda #'-'
    sta str_hs_prompt + HS_PROMPT_NAME_OFF + 1
    sta str_hs_prompt + HS_PROMPT_NAME_OFF + 2

    jsr hs_paint_prompt

    ; Control hint
    lda #<str_hs_help
    sta ptr_lo
    lda #>str_hs_help
    sta ptr_hi
    ldx #HS_COL_HELP
    ldy #HS_ROW_HELP
    jsr screen_print
    lda #COL_LT_GRAY
    ldy #HS_ROW_HELP
    jsr screen_color_row

    lda #0
    sta hs_cursor
    sta hs_char_idx                 ; 'A'
    sta hs_phase                    ; typing
    sta hs_dirs_prev
    sta hs_repeat_t
    sta score_color_phase
    sta score_color_tick
    jsr title_text_color_scores
    jsr hs_paint_name_colors

    lda #MENU_FIRE_GUARD
    sta mode_timer
    jsr screen_unblank
    rts
.endproc

.proc hs_paint_prompt
    lda #<str_hs_prompt
    sta ptr_lo
    lda #>str_hs_prompt
    sta ptr_hi
    ldx #HS_COL_PROMPT
    ldy #HS_ROW_PROMPT
    jsr screen_print
    lda #COL_WHITE
    ldy #HS_ROW_PROMPT
    jsr screen_color_row
    rts
.endproc

; ---------------------------------------------------------------------------
; Update — typing or hold.
; ---------------------------------------------------------------------------
.proc hiscore_update
    lda hs_phase
    bne hs_do_hold
    jmp hs_do_type
hs_do_hold:
    jsr title_text_rotate_colors
    lda mode_timer
    beq hs_hold_fire
    dec mode_timer
hs_hold_fire:
    lda input_fire_edge
    bne hs_to_title
    lda mode_timer
    bne hs_hold_done
hs_to_title:
    lda #MODE_TITLE_TEXT
    jsr mode_set
hs_hold_done:
    rts

hs_do_type:
    ; Fire guard after enter
    lda mode_timer
    beq hs_type_ok
    dec mode_timer
    jsr title_text_rotate_colors
    jsr hs_paint_name_colors
    ; Still track dirs so release doesn't false-edge later
    lda input_dirs
    sta hs_dirs_prev
    rts
hs_type_ok:
    jsr title_text_rotate_colors
    jsr hs_handle_dirs
    jsr hs_handle_fire
    jsr hs_paint_name_colors
    lda input_dirs
    sta hs_dirs_prev
    rts
.endproc

; Up/down with classic auto-repeat: step on press, delay, then rate while held.
.proc hs_handle_dirs
    lda input_dirs
    and #(JOY_UP | JOY_DOWN)
    bne hsd_held
    ; released — reset repeat
    lda #0
    sta hs_repeat_t
    rts
hsd_held:
    ; Which direction? Prefer up if both.
    lda input_dirs
    and #JOY_UP
    beq hsd_down_path
    ; --- UP ---
    lda hs_dirs_prev
    and #JOY_UP
    bne hsd_up_rep                  ; still held → maybe repeat
    ; fresh press
    jsr hs_step_up
    lda #HS_REPEAT_DELAY
    sta hs_repeat_t
    rts
hsd_up_rep:
    lda hs_repeat_t
    beq hsd_up_fire                 ; 0 = ready (shouldn't linger)
    dec hs_repeat_t
    bne hsd_done
hsd_up_fire:
    jsr hs_step_up
    lda #HS_REPEAT_RATE
    sta hs_repeat_t
    rts
hsd_down_path:
    lda input_dirs
    and #JOY_DOWN
    beq hsd_done
    lda hs_dirs_prev
    and #JOY_DOWN
    bne hsd_dn_rep
    jsr hs_step_down
    lda #HS_REPEAT_DELAY
    sta hs_repeat_t
    rts
hsd_dn_rep:
    lda hs_repeat_t
    beq hsd_dn_fire
    dec hs_repeat_t
    bne hsd_done
hsd_dn_fire:
    jsr hs_step_down
    lda #HS_REPEAT_RATE
    sta hs_repeat_t
hsd_done:
    rts
.endproc

.proc hs_step_up
    inc hs_char_idx
    lda hs_char_idx
    cmp #HS_CHARSET_LEN
    bcc hsu_apply
    lda #0
    sta hs_char_idx
hsu_apply:
    lda #SFX_HS_TICK
    jsr sfx::play
    jsr hs_apply_char
    jmp hs_refresh_name
.endproc

.proc hs_step_down
    lda hs_char_idx
    bne hsdn_dec
    lda #HS_CHARSET_LEN
hsdn_dec:
    sec
    sbc #1
    sta hs_char_idx
    lda #SFX_HS_TICK
    jsr sfx::play
    jsr hs_apply_char
    jmp hs_refresh_name
.endproc

; Fire edge: accept / back / finish.
.proc hs_handle_fire
    lda input_fire_edge
    bne hsf_go
    rts
hsf_go:
    lda #SFX_UI_FIRE
    jsr sfx::play
    lda hs_char_idx
    cmp #HS_CHAR_BACK
    beq hsf_back
    ; Accept current glyph
    lda hs_cursor
    cmp #2
    beq hsf_finish
    ; Advance cursor; carry glyph to next slot
    inc hs_cursor
    jsr hs_apply_char               ; write same char into new cursor slot
    ; Clear slots to the right of new cursor to '-'
    jsr hs_clear_right
    jsr hs_refresh_name
    rts
hsf_back:
    lda hs_cursor
    beq hsf_done                    ; first slot: ignore
    ; Clear current, move left
    lda #'-'
    jsr hs_store_at_cursor
    dec hs_cursor
    jsr hs_clear_right
    ; Active char = glyph already in new cursor position
    jsr hs_load_char_idx
    jsr hs_refresh_name
hsf_done:
    rts
hsf_finish:
    ; Final accept on 3rd char
    jsr hs_apply_char
    jsr hs_refresh_name
    ; Drop prompt line
    jsr hs_clear_prompt
    ; Hold ~1s (colour wheel keeps running; restore full-row colours)
    lda #1
    sta hs_phase
    lda #HS_HOLD_FRAMES
    sta mode_timer
    jsr title_text_color_scores
    rts
.endproc

; Write hs_charset[hs_char_idx] into name at hs_cursor (table + prompt).
.proc hs_apply_char
    ldx hs_char_idx
    lda hs_charset, x
    jmp hs_store_at_cursor
.endproc

; A = char → table row + prompt at hs_cursor.
.proc hs_store_at_cursor
    sta tmp0
    ; Table row
    lda hs_rank
    asl a
    tax
    lda hs_line_ptrs, x
    sta ptr_lo
    lda hs_line_ptrs + 1, x
    sta ptr_hi
    lda #HS_INITIALS_OFF
    clc
    adc hs_cursor
    tay
    lda tmp0
    sta (ptr_lo), y
    ; Prompt
    lda #HS_PROMPT_NAME_OFF
    clc
    adc hs_cursor
    tax
    lda tmp0
    sta str_hs_prompt, x
    rts
.endproc

; Set positions cursor+1..2 to '-'.
.proc hs_clear_right
    lda hs_cursor
    cmp #2
    bcs hcr_done
    lda #'-'
    sta tmp0
    lda hs_cursor
    clc
    adc #1
    sta draw_i
hcr_loop:
    ; table
    lda hs_rank
    asl a
    tax
    lda hs_line_ptrs, x
    sta ptr_lo
    lda hs_line_ptrs + 1, x
    sta ptr_hi
    lda #HS_INITIALS_OFF
    clc
    adc draw_i
    tay
    lda tmp0
    sta (ptr_lo), y
    ; prompt
    lda #HS_PROMPT_NAME_OFF
    clc
    adc draw_i
    tax
    lda tmp0
    sta str_hs_prompt, x
    inc draw_i
    lda draw_i
    cmp #3
    bcc hcr_loop
hcr_done:
    rts
.endproc

; hs_char_idx from table name at cursor (after back).
.proc hs_load_char_idx
    lda hs_rank
    asl a
    tax
    lda hs_line_ptrs, x
    sta ptr_lo
    lda hs_line_ptrs + 1, x
    sta ptr_hi
    lda #HS_INITIALS_OFF
    clc
    adc hs_cursor
    tay
    lda (ptr_lo), y
    sta tmp0
    ldx #0
hlc_loop:
    lda hs_charset, x
    cmp tmp0
    beq hlc_found
    inx
    cpx #HS_CHARSET_LEN
    bcc hlc_loop
    ldx #0                          ; fallback A
hlc_found:
    stx hs_char_idx
    rts
.endproc

; Redraw name on table row + prompt (3 glyphs).
.proc hs_refresh_name
    ; Table line (full reprint is fine — short)
    lda hs_rank
    asl a
    tax
    lda hs_line_ptrs, x
    sta ptr_lo
    lda hs_line_ptrs + 1, x
    sta ptr_hi
    ldx #HS_COL_TABLE
    lda hs_rank
    clc
    adc #HS_ROW_SCORE0
    tay
    jsr screen_print
    ; Prompt
    jsr hs_paint_prompt
    rts
.endproc

; Active initial yellow; other two white — on table row + prompt name.
; Rest of table row keeps colour-wheel (applied first).
.proc hs_paint_name_colors
    lda hs_phase
    bne hnc_done                    ; hold: full wheel only
    ; Table name cols
    lda #0
    sta draw_i
hnc_tbl:
    lda draw_i
    cmp hs_cursor
    beq hnc_ty
    lda #COL_WHITE
    jmp hnc_tput
hnc_ty:
    lda #COL_YELLOW
hnc_tput:
    pha
    lda #HS_COL_TABLE
    clc
    adc #HS_INITIALS_OFF
    clc
    adc draw_i
    tax
    lda hs_rank
    clc
    adc #HS_ROW_SCORE0
    tay
    pla
    jsr screen_color_xy
    inc draw_i
    lda draw_i
    cmp #3
    bcc hnc_tbl
    ; Prompt name cols
    lda #0
    sta draw_i
hnc_pr:
    lda draw_i
    cmp hs_cursor
    beq hnc_py
    lda #COL_WHITE
    jmp hnc_pput
hnc_py:
    lda #COL_YELLOW
hnc_pput:
    pha
    lda #HS_COL_PROMPT
    clc
    adc #HS_PROMPT_NAME_OFF
    clc
    adc draw_i
    tax
    ldy #HS_ROW_PROMPT
    pla
    jsr screen_color_xy
    inc draw_i
    lda draw_i
    cmp #3
    bcc hnc_pr
hnc_done:
    rts
.endproc

; Blank prompt + help after 3rd initial (congrats / new-score / table stay).
.proc hs_clear_prompt
    ldy #HS_ROW_PROMPT
    jsr hs_blank_row
    ldy #HS_ROW_HELP
    jmp hs_blank_row
.endproc

.proc hs_blank_row
    sty score_work2                 ; row
    ldx #0
hbr_loop:
    lda #SC_SPACE
    ldy score_work2
    jsr screen_put_xy               ; X survives
    inx
    cpx #40
    bcc hbr_loop
    rts
.endproc
