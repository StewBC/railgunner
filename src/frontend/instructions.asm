; Instructions placeholder — FIRE returns to text title.

.proc instructions_enter
    jsr vic_text_mode

    lda #<str_instructions_here
    sta ptr_lo
    lda #>str_instructions_here
    sta ptr_hi
    ldx #12                         ; "INSTRUCTIONS HERE" = 17 → centre ~11.5
    ldy #10
    jsr screen_print
    lda #COL_CYAN
    ldy #10
    jsr screen_color_row

    lda #<str_fire_to_continue
    sta ptr_lo
    lda #>str_fire_to_continue
    sta ptr_hi
    ldx #12
    ldy #14
    jsr screen_print
    lda #COL_WHITE
    ldy #14
    jsr screen_color_row

    lda #MENU_FIRE_GUARD
    sta mode_timer
    rts
.endproc

.proc instructions_update
    lda mode_timer
    beq instr_ready
    dec mode_timer
    rts
instr_ready:
    lda input_fire_edge
    beq instr_done
    lda #MODE_TITLE_TEXT
    jsr mode_set
instr_done:
    rts
.endproc
