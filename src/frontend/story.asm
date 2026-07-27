; Story screen — typewriter reveal (gray glyph, then white when the next lands).
; Left-justified. FIRE skips typing or returns to text title when done.

.proc story_enter
    jsr vic_text_mode               ; black bg/border, clear

    lda #<story_text
    sta type_src_lo
    lda #>story_text
    sta type_src_hi

    lda #STORY_MARGIN_X
    sta type_col
    lda #STORY_START_Y
    sta type_row

    lda #$ff                        ; no previous glyph to whiten yet
    sta type_prev_col
    sta type_prev_row

    lda #STORY_STATE_TYPING
    sta mode_state
    lda #STORY_TYPE_DELAY
    sta mode_timer
    rts
.endproc

.proc story_update
    lda mode_state
    cmp #STORY_STATE_DONE
    beq story_done_phase

    ; Typing: FIRE skips to fully revealed text
    lda input_fire_edge
    beq story_type_tick
    jsr story_skip_to_end
    rts

story_type_tick:
    lda mode_timer
    beq story_emit
    dec mode_timer
    rts
story_emit:
    lda #STORY_TYPE_DELAY
    sta mode_timer
    jsr story_type_one
    rts

story_done_phase:
    ; Guard against held fire after skip/finish
    lda mode_timer
    beq story_accept_fire
    dec mode_timer
    rts
story_accept_fire:
    lda input_fire_edge
    beq story_upd_exit
    lda #MODE_TITLE_TEXT
    jsr mode_set
story_upd_exit:
    rts
.endproc

; Emit one source unit: glyph, newline, or finish.
.proc story_type_one
    ldy #0
    lda (type_src_lo), y
    bne story_have_char
    ; End of text — whiten last glyph, show continue
    jsr story_whiten_prev
    jsr story_show_continue
    rts

story_have_char:
    cmp #$0A
    bne story_glyph
    ; Newline: advance source, pen to next line (no whitening needed for NL)
    jsr story_src_advance
    lda #STORY_MARGIN_X
    sta type_col
    inc type_row
    rts

story_glyph:
    ; Previous gray glyph ages to white as this one appears
    jsr story_whiten_prev

    ; Map and plot new glyph in gray
    ldy #0
    lda (type_src_lo), y
    jsr ascii_to_screen
    ldx type_col
    ldy type_row
    jsr screen_put_xy

    lda #COL_GRAY
    ldx type_col
    ldy type_row
    jsr screen_color_xy

    ; Remember for whitening on next step
    lda type_col
    sta type_prev_col
    lda type_row
    sta type_prev_row

    inc type_col
    jsr story_src_advance
    rts
.endproc

.proc story_src_advance
    inc type_src_lo
    bne src_adv_done
    inc type_src_hi
src_adv_done:
    rts
.endproc

; If type_prev_* valid, set that cell to white.
.proc story_whiten_prev
    lda type_prev_col
    cmp #$ff
    beq whiten_none
    lda #COL_WHITE
    ldx type_prev_col
    ldy type_prev_row
    jsr screen_color_xy
whiten_none:
    rts
.endproc

; Burst-type the rest (all white), then continue prompt.
.proc story_skip_to_end
skip_loop:
    ldy #0
    lda (type_src_lo), y
    beq skip_finish
    cmp #$0A
    bne skip_glyph
    jsr story_src_advance
    lda #STORY_MARGIN_X
    sta type_col
    inc type_row
    jmp skip_loop
skip_glyph:
    jsr ascii_to_screen
    ldx type_col
    ldy type_row
    jsr screen_put_xy
    lda #COL_WHITE
    ldx type_col
    ldy type_row
    jsr screen_color_xy
    inc type_col
    jsr story_src_advance
    jmp skip_loop
skip_finish:
    lda #$ff
    sta type_prev_col
    jsr story_show_continue
    rts
.endproc

.proc story_show_continue
    lda #STORY_STATE_DONE
    sta mode_state

    lda #<str_fire_to_continue
    sta ptr_lo
    lda #>str_fire_to_continue
    sta ptr_hi
    ldx #STORY_MARGIN_X             ; left-justified with the body
    ldy #24
    jsr screen_print
    lda #COL_LT_GREEN
    ldy #24
    jsr screen_color_row

    lda #MENU_FIRE_GUARD
    sta mode_timer
    rts
.endproc
