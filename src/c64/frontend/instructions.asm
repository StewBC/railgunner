; Instructions — typewriter reveal of instructions_text. FIRE skips / returns.

.proc instructions_enter
    jsr music::stop
    jsr vic_text_mode               ; blank + text mode + clear

    lda #<instructions_text
    sta type_src_lo
    lda #>instructions_text
    sta type_src_hi
    jsr typewriter_init
    jsr screen_unblank
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
    lda #SFX_UI_FIRE
    jsr sfx::play
    lda #MODE_TITLE_TEXT
    jsr mode_set
instr_upd_exit:
    rts
.endproc
