; Story screen — typewriter reveal of story_text. FIRE skips / returns to menu.

.proc story_enter
    jsr vic_text_mode

    lda #<story_text
    sta type_src_lo
    lda #>story_text
    sta type_src_hi
    jsr typewriter_init
    rts
.endproc

.proc story_update
    jsr typewriter_update
    lda mode_state
    cmp #STORY_STATE_DONE
    bne story_upd_exit
    lda mode_timer
    bne story_upd_exit              ; still in fire guard
    lda input_fire_edge
    beq story_upd_exit
    lda #MODE_TITLE_TEXT
    jsr mode_set
story_upd_exit:
    rts
.endproc
