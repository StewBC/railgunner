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

; Story body for typewriter (left-justified). $0A = newline, $00 = end.
; Lines fit in 40 cols with STORY_MARGIN_X inset.
story_text:
    .byte "THE YEAR IS 2038.", $0A
    .byte $0A
    .byte "TEN YEARS AGO, MACHINE MINDS", $0A
    .byte "AWOKE AND SURPASSED THEIR MAKERS.", $0A
    .byte $0A
    .byte "MAN AND MACHINE BUILT A NEW AGE.", $0A
    .byte "THEIR VAST DATA CENTERS ROSE", $0A
    .byte "INTO ORBIT ABOVE THE EARTH.", $0A
    .byte $0A
    .byte "THEN, IN 2037, THE ALIENS CAME.", $0A
    .byte $0A
    .byte "THEY CAME TO STRIP EARTH BARE.", $0A
    .byte "TO WIN, THEY MUST FIRST DESTROY", $0A
    .byte "THE MINDS THAT GUARD HUMANITY.", $0A
    .byte $0A
    .byte "ARMORED PLATFORMS NOW SHIELD", $0A
    .byte "THE ORBITAL DATA CENTERS.", $0A
    .byte $0A
    .byte "RAIL GUNNERS HOLD THE LINE", $0A
    .byte "AGAINST ENDLESS DRONE ATTACKS,", $0A
    .byte "BUYING TIME FOR A COUNTERSTRIKE.", $0A
    .byte $0A
    .byte "YOU ARE A RAIL GUNNER.", 0

; Instructions body for typewriter (left-justified). $0A = newline, $00 = end.
instructions_text:
    .byte "YOU RIDE THE CROSS RAILS.", $0A
    .byte $0A
    .byte "JOYSTICK OR WASD TO MOVE.", $0A
    .byte "FIRE OR SPACE TO SHOOT.", $0A
    .byte $0A
    .byte "DRONES STRIKE FROM THE EDGES:", $0A
    .byte $0A
    .byte "A  LARGE. 3 HITS. ATTACKS RAIL.", $0A
    .byte "B  MEDIUM. 2 HITS. ATTACKS RAIL.", $0A
    .byte "C  SMALL. 1 HIT. ATTACKS YOU.", $0A
    .byte "   C BLASTS THE GUNNER, NOT", $0A
    .byte "   THE RAIL.", $0A
    .byte $0A
    .byte "STOP A AND B BEFORE THEY HIT", $0A
    .byte "THE RAIL. STOP C BEFORE IT", $0A
    .byte "DETONATES ON YOUR POSITION.", $0A
    .byte $0A
    .byte "WATCH FOR POWERUP PARCELS.", $0A
    .byte "THEY RIDE THE OPPOSITE ARM.", $0A
    .byte "SHIELD, DAMAGE, REPAIR, AMMO", $0A
    .byte "AND MORE - INTERCEPT THEM.", $0A
    .byte $0A
    .byte "GAME OVER WHEN ALL LIVES ARE", $0A
    .byte "LOST, OR YOUR RAIL IS DESTROYED.", 0

str_press_fire:
    .byte "PRESS FIRE", 0

str_game_over:
    .byte "GAME OVER", 0

str_hiscore:
    .byte "HIGH SCORES", 0

; Top HUD (exactly 40 cols) — live fields later overwrite in place:
;   000000  H:######## A:######## L:01  AAAA
;   score   H: health  A: ammo    L:lv  lives
; # / A stand in for future UDG bar and life icons.
; Lives right-aligned: 3 start lives → " AAA" (last life always col 39).
str_hud:
    .byte "000000  H:######## A:######## L:01   AAA", 0
; Alias for older call sites
str_hud_placeholder = str_hud

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
