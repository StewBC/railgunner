; Wave / level tables (Step 8.4).
; Row: quota, cadence, max_active, approach_mask (WAVE_EDGE_*).
; Level 1 only for now — short teach → open the cross. Tune in 8.7.

; Wave 0: top only, one at a time — learn the board
; Wave 1: top+bottom
; Wave 2: all edges, max 2
; Wave 3: all edges, denser (still capped at 3)
level1_wave_table:
    .byte 3, 96, 1, WAVE_EDGE_DOWN
    .byte 4, 80, 2, WAVE_EDGE_TB
    .byte 5, 64, 2, WAVE_EDGE_ALL
    .byte 6, 56, 3, WAVE_EDGE_ALL
level1_wave_table_end:

; Sanity: table length must match WAVES_PER_LEVEL in const.asm
.if (level1_wave_table_end - level1_wave_table) .ne (WAVES_PER_LEVEL * WAVE_ROW_BYTES)
    .byte ERR_wave_table_length
.endif
