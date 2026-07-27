; Mode dispatcher — one entry per frame after input_poll.

.proc mode_run
    lda game_mode
    cmp #MODE_COUNT
    bcc mode_run_ok
    lda #MODE_TITLE_TEXT
    sta game_mode
mode_run_ok:
    asl a
    tax
    lda mode_table, x
    sta mode_run_jmp + 1
    lda mode_table + 1, x
    sta mode_run_jmp + 2
mode_run_jmp:
    jmp $0000                       ; patched target
.endproc

mode_table:
    .word title_gfx_update          ; MODE_TITLE_GFX
    .word game_init_update
    .word stage_init_update
    .word play_update
    .word next_wave_update
    .word next_level_update
    .word next_life_update
    .word gameover_update
    .word hiscore_update
    .word title_text_update         ; MODE_TITLE_TEXT
    .word story_update
    .word instructions_update

; Set game_mode and call enter routine. A = new mode.
.proc mode_set
    sta game_mode
    lda #0
    sta mode_timer
    sta mode_state
    lda game_mode
    asl a
    tax
    lda mode_enter_table, x
    sta mode_set_jmp + 1
    lda mode_enter_table + 1, x
    sta mode_set_jmp + 2
mode_set_jmp:
    jmp $0000
.endproc

mode_enter_table:
    .word title_gfx_enter
    .word game_init_enter
    .word stage_init_enter
    .word play_enter
    .word next_wave_enter
    .word next_level_enter
    .word next_life_enter
    .word gameover_enter
    .word hiscore_enter
    .word title_text_enter
    .word story_enter
    .word instructions_enter
