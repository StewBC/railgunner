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
; Keep lines ≤39 chars (STORY_MARGIN_X=1). Row 24 = FIRE TO CONTINUE.
instructions_text:
    .byte "YOU RIDE THE CROSS RAILS.", $0A
    .byte $0A
    .byte "JOYSTICK OR WASD TO MOVE.", $0A
    .byte "FIRE OR SPACE TO SHOOT.", $0A
    .byte $0A
    .byte "DRONES STRIKE FROM THE EDGES:", $0A
    .byte "BLUE   3 SHOTS. 2 DAMAGE TO RAILS.", $0A
    .byte "GREEN  2 SHOTS. 1 DAMAGE TO RAILS.", $0A
    .byte "RED    1 SHOT.  DROPS CARGO.", $0A
    .byte $0A
    .byte "STOP DRONES BEFORE THEY REACH THE", $0A
    .byte "RAILS. CARGO ARMS MINES AT THE HUB.", $0A
    .byte "4 MINES MEAN DEATH WHEN THE GUNNER", $0A
    .byte "PASSES THROUGH. 1 MINE DISARMED WHEN", $0A
    .byte "A WAVE IS SURVIVED.", $0A
    .byte $0A
    .byte "POWERUP PARCELS HELP THE GUNNER.", $0A
    .byte "POINTS, 2X SCORE, 2X DAMAGE, CLEAR", $0A
    .byte "MINES, REPAIR THE RAIL OR EXTRA LIVES.", $0A
    .byte $0A
    .byte "GAME OVER WHEN ALL LIVES ARE LOST", $0A
    .byte "OR WHEN THE RAIL SUFFERS CRITICAL", $0A
    .byte "FAILURE.", 0

str_press_fire:
    .byte "PRESS FIRE", 0

str_game_over:
    .byte "GAME OVER", 0
; Death-hold HUD banners — 4 spaces each side, centred (col 11)
str_game_over_banner:
    .byte "    GAME OVER    ", 0          ; 17 chars
str_rip_pilot_banner:
    .byte "    RIP  PILOT    ", 0         ; 18 chars (extra space for balance)

; Game-over results (tallies::paint_gameover). Labels right-align to col 15.
str_go_results:
    .byte "YOUR RESULTS", 0
str_go_score:
    .byte "SCORE", 0
str_go_rank:
    .byte "RANK", 0
str_go_waves:
    .byte "WAVES SURVIVED", 0
str_go_shots:
    .byte "SHOTS FIRED", 0
str_go_destruction:
    .byte "DESTRUCTION", 0
str_go_mine:
    .byte "MINE LAYERS", 0
str_go_medium:
    .byte "MEDIUM BOMBERS", 0
str_go_heavy:
    .byte "HEAVY BOMBERS", 0

str_hiscore:
    .byte "HIGH SCORES", 0

; Top HUD (exactly 40 cols). WAVE +1 vs LVL → no space after dash before PILOTS.
; PILOTS = reserve only. Max 4. Start: 3 peel → 2.
str_hud:
    .byte "000000 - WAVE 01 - ######## -PILOTS:AAAA", 0
str_hud_placeholder = str_hud

; ---------------------------------------------------------------------------
; Rank system: nicety + rank title are separate (future: random mix-match).
; Banner = nicety + ", " + title. Game over RANK line = title only.
; Wave complete 1..15 → index 0..14.
; ---------------------------------------------------------------------------
str_nicety_01: .byte "NICE WORK", 0
str_nicety_02: .byte "GOOD WORK", 0
str_nicety_03: .byte "GREAT WORK", 0
str_nicety_04: .byte "WELL DONE", 0
str_nicety_05: .byte "NICE WORK", 0
str_nicety_06: .byte "SOLID WORK", 0
str_nicety_07: .byte "EXCELLENT", 0
str_nicety_08: .byte "OUTSTANDING", 0
str_nicety_09: .byte "FINE WORK", 0
str_nicety_10: .byte "SUPERB", 0
str_nicety_11: .byte "REMARKABLE", 0
str_nicety_12: .byte "EXCEPTIONAL", 0
str_nicety_13: .byte "BRILLIANT", 0
str_nicety_14: .byte "OUTSTANDING", 0
str_nicety_15: .byte "LEGENDARY", 0

str_rank_title_01: .byte "PRIVATE", 0
str_rank_title_02: .byte "L-CPL", 0
str_rank_title_03: .byte "CPL", 0
str_rank_title_04: .byte "SGT", 0
str_rank_title_05: .byte "S-SGT", 0
str_rank_title_06: .byte "WO2", 0
str_rank_title_07: .byte "WO1", 0
str_rank_title_08: .byte "LT", 0
str_rank_title_09: .byte "CAPT", 0
str_rank_title_10: .byte "MAJOR", 0
str_rank_title_11: .byte "LT COL", 0
str_rank_title_12: .byte "COL", 0
str_rank_title_13: .byte "BRIG", 0
str_rank_title_14: .byte "MAJ GEN", 0
str_rank_title_15: .byte "GENERAL", 0

nicety_lo:
    .byte <str_nicety_01, <str_nicety_02, <str_nicety_03, <str_nicety_04, <str_nicety_05
    .byte <str_nicety_06, <str_nicety_07, <str_nicety_08, <str_nicety_09, <str_nicety_10
    .byte <str_nicety_11, <str_nicety_12, <str_nicety_13, <str_nicety_14, <str_nicety_15
nicety_hi:
    .byte >str_nicety_01, >str_nicety_02, >str_nicety_03, >str_nicety_04, >str_nicety_05
    .byte >str_nicety_06, >str_nicety_07, >str_nicety_08, >str_nicety_09, >str_nicety_10
    .byte >str_nicety_11, >str_nicety_12, >str_nicety_13, >str_nicety_14, >str_nicety_15

rank_title_lo:
    .byte <str_rank_title_01, <str_rank_title_02, <str_rank_title_03, <str_rank_title_04
    .byte <str_rank_title_05, <str_rank_title_06, <str_rank_title_07, <str_rank_title_08
    .byte <str_rank_title_09, <str_rank_title_10, <str_rank_title_11, <str_rank_title_12
    .byte <str_rank_title_13, <str_rank_title_14, <str_rank_title_15
rank_title_hi:
    .byte >str_rank_title_01, >str_rank_title_02, >str_rank_title_03, >str_rank_title_04
    .byte >str_rank_title_05, >str_rank_title_06, >str_rank_title_07, >str_rank_title_08
    .byte >str_rank_title_09, >str_rank_title_10, >str_rank_title_11, >str_rank_title_12
    .byte >str_rank_title_13, >str_rank_title_14, >str_rank_title_15

; Wave kill quotas W1..W15 (code still uses level_* symbols)
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
