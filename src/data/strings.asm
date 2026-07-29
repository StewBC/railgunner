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
    .byte "C  SMALL. 1 HIT. DROPS CARGO.", $0A
    .byte "   CARGO ARMS MINES AT THE HUB.", $0A
    .byte $0A
    .byte "STOP A AND B BEFORE THEY HIT", $0A
    .byte "THE RAIL. STOP C BEFORE CARGO", $0A
    .byte "ARMS THE CENTRE MINES.", $0A
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

; Game-over tallies (numbers filled in by tallies::paint_gameover)
str_tallies:
    .byte "TALLIES:", 0
str_survived_pre:
    .byte "YOU SURVIVED ", 0
str_survived_post:
    .byte " ATTACK WAVES", 0
str_fired_pre:
    .byte "YOU FIRED: ", 0
str_fired_post:
    .byte " BULLETS", 0
str_destroyed:
    .byte "DESTROYED:", 0
str_class_a:
    .byte "CLASS A ", 0
str_class_b:
    .byte "CLASS B ", 0
str_class_c:
    .byte "CLASS C ", 0

str_hiscore:
    .byte "HIGH SCORES", 0

; Top HUD (exactly 40 cols) — live fields later overwrite in place:
;   000000  H:######## A:######## L:01  AAAA
;   score   H: health  A: ammo    L:lv  lives
; # / A stand in for future UDG bar and life icons.
; Lives right-aligned: 3 start lives → " AAA" (last life always col 39).
str_hud:
    .byte "000000 - LVL 01 - ######## - PILOTS:AAAA", 0
str_hud_placeholder = str_hud

; Rank banners (cleared level 1..15 → index 0..14). Short for top line.
str_rank_01: .byte "NICE WORK, PRIVATE", 0
str_rank_02: .byte "GOOD WORK, L-CPL", 0
str_rank_03: .byte "GREAT WORK, CPL", 0
str_rank_04: .byte "WELL DONE, SGT", 0
str_rank_05: .byte "NICE WORK, S-SGT", 0
str_rank_06: .byte "SOLID WORK, WO2", 0
str_rank_07: .byte "EXCELLENT, WO1", 0
str_rank_08: .byte "OUTSTANDING, LT", 0
str_rank_09: .byte "FINE WORK, CAPT", 0
str_rank_10: .byte "SUPERB, MAJOR", 0
str_rank_11: .byte "REMARKABLE, LT COL", 0
str_rank_12: .byte "EXCEPTIONAL, COL", 0
str_rank_13: .byte "BRILLIANT, BRIG", 0
str_rank_14: .byte "OUTSTANDING, MAJ GEN", 0
str_rank_15: .byte "LEGENDARY, GENERAL", 0

rank_msg_lo:
    .byte <str_rank_01, <str_rank_02, <str_rank_03, <str_rank_04, <str_rank_05
    .byte <str_rank_06, <str_rank_07, <str_rank_08, <str_rank_09, <str_rank_10
    .byte <str_rank_11, <str_rank_12, <str_rank_13, <str_rank_14, <str_rank_15
rank_msg_hi:
    .byte >str_rank_01, >str_rank_02, >str_rank_03, >str_rank_04, >str_rank_05
    .byte >str_rank_06, >str_rank_07, >str_rank_08, >str_rank_09, >str_rank_10
    .byte >str_rank_11, >str_rank_12, >str_rank_13, >str_rank_14, >str_rank_15

; Level kill quotas L1..L15
level_kill_quota_tbl:
    .byte 16, 16, 20, 20, 24, 24, 24, 28, 28, 28, 32, 32, 32, 32, 32

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
