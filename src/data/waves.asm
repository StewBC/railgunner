; Wave / level tables (Step 8.4–8.5).
; Row: c_kills, c_cadence, max_c, approach_mask, b_kills, a_kills
; Quotas are *kills required* (rail-suicides do not count; spawner replaces).
; Level 1: teach C → open cross → B → A. A/B top/bottom only. Tune in 8.7.

level1_wave_table:
    ; W0: C top only, single-file — learn
    .byte 3, 96, 1, WAVE_EDGE_DOWN, 0, 0
    ; W1: C top+bottom
    .byte 4, 80, 2, WAVE_EDGE_TB, 0, 0
    ; W2: C all edges + two slow B (rail intro)
    .byte 5, 64, 2, WAVE_EDGE_ALL, 2, 0
    ; W3: C denser + two B + one A
    .byte 6, 56, 3, WAVE_EDGE_ALL, 2, 1
level1_wave_table_end:

.if (level1_wave_table_end - level1_wave_table) .ne (WAVES_PER_LEVEL * WAVE_ROW_BYTES)
    .byte ERR_wave_table_length
.endif
