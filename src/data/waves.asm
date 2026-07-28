; Wave tables — launcher v2 (Step 8.6).
; Row (8 bytes):
;   c_kills, b_kills, a_kills, cd_min, cd_max, max_active, quad_mask, flags
; flags: WAVE_F_PIGGY_C | WAVE_F_MAIN_C
; Quads: Q1 UR, Q2 LR, Q3 LL, Q4 UL
; Kill targets only; launcher dice until quotas met (or death).

level1_wave_table:
    ; W0 teach: C only, top quads, long cooldown
    .byte 5, 0, 0, 70, 110, 2, WAVE_Q_TOP, WAVE_F_MAIN_C
    ; W1: C, all quads, slightly faster
    .byte 6, 0, 0, 50, 90, 3, WAVE_Q_ALL, WAVE_F_MAIN_C
    ; W2: B + piggy C (main dice prefers B; C kills via piggy + some main)
    .byte 4, 2, 0, 40, 75, 3, WAVE_Q_ALL, WAVE_F_PIGGY_C | WAVE_F_MAIN_C
    ; W3: A+B + piggy C
    .byte 4, 2, 1, 35, 65, 4, WAVE_Q_ALL, WAVE_F_PIGGY_C | WAVE_F_MAIN_C
level1_wave_table_end:

.if (level1_wave_table_end - level1_wave_table) .ne (WAVES_PER_LEVEL * WAVE_ROW_BYTES)
    .byte ERR_wave_table_length
.endif
