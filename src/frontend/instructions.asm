; Instructions — typewriter reveal of instructions_text. FIRE skips / returns.

.proc instructions_enter
    jsr vic_text_mode

    lda #<instructions_text
    sta type_src_lo
    lda #>instructions_text
    sta type_src_hi
    jsr typewriter_init
    rts
.endproc

.proc instructions_update
    jsr typewriter_update
    lda mode_state
    cmp #STORY_STATE_DONE
    bne instr_upd_exit
    lda mode_timer
    bne instr_upd_exit
    lda input_fire_edge
    beq instr_upd_exit
    lda #MODE_TITLE_TEXT
    jsr mode_set
instr_upd_exit:
    rts
.endproc
