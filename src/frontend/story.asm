; Story placeholder — FIRE returns to text title.

.proc story_enter
    jsr vic_text_mode

    lda #<str_story_here
    sta ptr_lo
    lda #>str_story_here
    sta ptr_hi
    ldx #15                         ; "STORY HERE" = 10 → centre 15
    ldy #10
    jsr screen_print
    lda #COL_YELLOW
    ldy #10
    jsr screen_color_row

    lda #<str_fire_to_continue
    sta ptr_lo
    lda #>str_fire_to_continue
    sta ptr_hi
    ldx #12                         ; 16 chars → centre 12
    ldy #14
    jsr screen_print
    lda #COL_WHITE
    ldy #14
    jsr screen_color_row

    lda #MENU_FIRE_GUARD
    sta mode_timer
    rts
.endproc

.proc story_update
    lda mode_timer
    beq story_ready
    dec mode_timer
    rts
story_ready:
    lda input_fire_edge
    beq story_done
    lda #MODE_TITLE_TEXT
    jsr mode_set
story_done:
    rts
.endproc
