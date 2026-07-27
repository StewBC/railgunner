; Shared typewriter reveal: gray glyph, then white when the next lands.
; Caller sets type_src_lo/hi to 0-terminated text ($0A = newline) and calls
; typewriter_init after clearing the screen. typewriter_update each frame:
;   mode_state = STORY_STATE_TYPING / STORY_STATE_DONE
; FIRE while typing skips; FIRE when done is left to the caller.

.proc typewriter_init
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

; While typing: advance / skip. When done: only runs the fire-guard timer
; (caller handles exit on fire). Clobbers temps.
.proc typewriter_update
    lda mode_state
    cmp #STORY_STATE_DONE
    beq tw_done_phase

    lda input_fire_edge
    beq tw_type_tick
    jsr typewriter_skip_to_end
    rts

tw_type_tick:
    lda mode_timer
    beq tw_emit
    dec mode_timer
    rts
tw_emit:
    lda #STORY_TYPE_DELAY
    sta mode_timer
    jsr typewriter_type_one
    rts

tw_done_phase:
    lda mode_timer
    beq tw_upd_exit
    dec mode_timer
tw_upd_exit:
    rts
.endproc

; Emit one source unit: glyph, newline, or finish.
.proc typewriter_type_one
    ldy #0
    lda (type_src_lo), y
    bne tw_have_char
    jsr typewriter_whiten_prev
    jsr typewriter_show_continue
    rts

tw_have_char:
    cmp #$0A
    bne tw_glyph
    jsr typewriter_src_advance
    lda #STORY_MARGIN_X
    sta type_col
    inc type_row
    rts

tw_glyph:
    jsr typewriter_whiten_prev

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

    lda type_col
    sta type_prev_col
    lda type_row
    sta type_prev_row

    inc type_col
    jsr typewriter_src_advance
    rts
.endproc

.proc typewriter_src_advance
    inc type_src_lo
    bne tw_src_done
    inc type_src_hi
tw_src_done:
    rts
.endproc

.proc typewriter_whiten_prev
    lda type_prev_col
    cmp #$ff
    beq tw_whiten_none
    lda #COL_WHITE
    ldx type_prev_col
    ldy type_prev_row
    jsr screen_color_xy
tw_whiten_none:
    rts
.endproc

.proc typewriter_skip_to_end
    ; Age any glyph already on screen in gray (last typed before Fire).
    jsr typewriter_whiten_prev
    lda #$ff
    sta type_prev_col

tw_skip_loop:
    ldy #0
    lda (type_src_lo), y
    beq tw_skip_finish
    cmp #$0A
    bne tw_skip_glyph
    jsr typewriter_src_advance
    lda #STORY_MARGIN_X
    sta type_col
    inc type_row
    jmp tw_skip_loop
tw_skip_glyph:
    jsr ascii_to_screen
    ldx type_col
    ldy type_row
    jsr screen_put_xy
    lda #COL_WHITE
    ldx type_col
    ldy type_row
    jsr screen_color_xy
    inc type_col
    jsr typewriter_src_advance
    jmp tw_skip_loop
tw_skip_finish:
    jsr typewriter_show_continue
    rts
.endproc

.proc typewriter_show_continue
    lda #STORY_STATE_DONE
    sta mode_state

    lda #<str_fire_to_continue
    sta ptr_lo
    lda #>str_fire_to_continue
    sta ptr_hi
    ldx #STORY_MARGIN_X
    ldy #24
    jsr screen_print
    lda #COL_LT_GREEN
    ldy #24
    jsr screen_color_row

    lda #MENU_FIRE_GUARD
    sta mode_timer
    rts
.endproc
