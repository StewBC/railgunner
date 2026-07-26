; PETSCII/ASCII uppercase strings for screen_print (0-terminated).
; Must live in DATA (or CODE); included under .segment "DATA".

str_title:
    .byte "RAILGUNNER", 0

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
