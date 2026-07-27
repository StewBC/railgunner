; PETSCII/ASCII uppercase strings for screen_print (0-terminated).
; Must live in DATA (or CODE); included under .segment "DATA".
;
; High-score lines are mutable in place (initials + score digits) for a future
; load/save path. Rank prefixes are fixed text.

; ---------------------------------------------------------------------------
; Title / menu
; ---------------------------------------------------------------------------
str_title:
    .byte "RAIL GUNNER", 0

str_past_heroes:
    .byte "PAST HEROES", 0

str_fire_to_play:
    .byte "FIRE TO PLAY", 0

str_s_for_story:
    .byte "S FOR STORY", 0

str_i_for_instructions:
    .byte "I FOR INSTRUCTIONS", 0

str_code_art_by:
    .byte "CODE AND ART BY", 0

str_credits_ai:
    .byte "GROK, CLAUDE AND CODEX", 0

str_produced_by:
    .byte "PRODUCED BY", 0

str_producer:
    .byte "STEFAN WESSELS, 2026", 0

str_fire_to_continue:
    .byte "FIRE TO CONTINUE", 0

str_story_here:
    .byte "STORY HERE", 0

str_instructions_here:
    .byte "INSTRUCTIONS HERE", 0

str_press_fire:
    .byte "PRESS FIRE", 0

str_game_over:
    .byte "GAME OVER", 0

str_hiscore:
    .byte "HIGH SCORES", 0

str_hud_placeholder:
    .byte "000000  H########  L01 AAA", 0

str_wave_clear:
    .byte "WAVE CLEAR", 0

str_level_clear:
    .byte "LEVEL CLEAR", 0

; ---------------------------------------------------------------------------
; Past Heroes table — 18 chars + NUL each.
; Format: "NN.   III   SSSSSS"  (3 spaces between columns; NN right-aligned)
; Initials at offset 6 (3 chars), score at offset 12 (6 digits).
; ---------------------------------------------------------------------------
HS_INITIALS_OFF = 6
HS_SCORE_OFF    = 12
HS_LINE_LEN     = 18

hs_line_1:
    .byte " 1.   ---   000000", 0
hs_line_2:
    .byte " 2.   ---   000000", 0
hs_line_3:
    .byte " 3.   ---   000000", 0
hs_line_4:
    .byte " 4.   ---   000000", 0
hs_line_5:
    .byte " 5.   ---   000000", 0
hs_line_6:
    .byte " 6.   ---   000000", 0
hs_line_7:
    .byte " 7.   ---   000000", 0
hs_line_8:
    .byte " 8.   ---   000000", 0
hs_line_9:
    .byte " 9.   ---   000000", 0
hs_line_10:
    .byte "10.   ---   000000", 0

; Pointer table for printing / recolour (lo, hi pairs)
hs_line_ptrs:
    .word hs_line_1, hs_line_2, hs_line_3, hs_line_4, hs_line_5
    .word hs_line_6, hs_line_7, hs_line_8, hs_line_9, hs_line_10
