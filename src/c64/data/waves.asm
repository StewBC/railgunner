; Wave / level difficulty tables (Step 8.7).
; waves::load builds live wave_* params from wave index + level using these
; knobs — do not hand-author 15 full level tables unless tuning needs it.
;
; Knobs:
;   level_speed_scale / drone_vel_tier — velocity tiers (C/B/A pick into these)
;   wave_base_*                       — L1 shape per wave (0 open → 3 hard tail)
;   wave_grow_*                       — kill-quota growth per (level-1)
;   composition / cd / max_active     — applied in waves::load

; ---------------------------------------------------------------------------
; Level speed scale (sixteenths). Index = tier 0..MAX_LEVEL-1 (L1..L15).
; Used only to document / regenerate drone_vel_tier. Runtime reads the table.
; L1 = 16 (1.0×) … L10 = 32 (2.0×); L11–15 hold peak velocity.
; ---------------------------------------------------------------------------
level_speed_scale:
    .byte 16, 18, 20, 22, 24, 26, 28, 30, 31, 32
    .byte 32, 32, 32, 32, 32

; ---------------------------------------------------------------------------
; Precomputed 8.8 velocities: tier 0=L1 .. 14=L15 × approach DOWN/UP/RIGHT/LEFT.
; Each pair: frac, int. Axes equalized for first-sight → rail time at that tier.
; Row stride = 8 bytes (4 approaches × 2).
; Regenerated: base(L1) * level_speed_scale[t] / 16
;   L1 bases: DOWN $00BC, UP $00A3, RIGHT $0124, LEFT $0133  (T≈140 ticks)
; ---------------------------------------------------------------------------
DRONE_VEL_TIER_STRIDE = 8
drone_vel_tier:
    .byte $BC,$00, $A3,$00, $24,$01, $33,$01  ; L1  scale=16
    .byte $D3,$00, $B7,$00, $48,$01, $59,$01  ; L2  scale=18
    .byte $EB,$00, $CB,$00, $6D,$01, $7F,$01  ; L3  scale=20
    .byte $02,$01, $E0,$00, $91,$01, $A6,$01  ; L4  scale=22
    .byte $1A,$01, $F4,$00, $B6,$01, $CC,$01  ; L5  scale=24
    .byte $31,$01, $08,$01, $DA,$01, $F2,$01  ; L6  scale=26
    .byte $49,$01, $1D,$01, $FF,$01, $19,$02  ; L7  scale=28
    .byte $60,$01, $31,$01, $23,$02, $3F,$02  ; L8  scale=30
    .byte $6C,$01, $3B,$01, $35,$02, $52,$02  ; L9  scale=31
    .byte $78,$01, $46,$01, $48,$02, $66,$02  ; L10 scale=32
    .byte $78,$01, $46,$01, $48,$02, $66,$02  ; L11 scale=32
    .byte $78,$01, $46,$01, $48,$02, $66,$02  ; L12 scale=32
    .byte $78,$01, $46,$01, $48,$02, $66,$02  ; L13 scale=32
    .byte $78,$01, $46,$01, $48,$02, $66,$02  ; L14 scale=32
    .byte $78,$01, $46,$01, $48,$02, $66,$02  ; L15 scale=32

; ---------------------------------------------------------------------------
; Per-wave L1 bases (index = wave 0..WAVES_PER_LEVEL-1)
; W0 open/teach → W3 hard tail
; ---------------------------------------------------------------------------
wave_base_c:
    .byte 5, 6, 4, 5
wave_base_b:
    .byte 0, 0, 2, 2
wave_base_a:
    .byte 0, 0, 0, 1
wave_base_cd_min:
    .byte 70, 50, 40, 32
wave_base_cd_max:
    .byte 110, 90, 75, 60
wave_base_max_active:
    .byte 2, 3, 4, 4
wave_base_quad_mask:
    .byte WAVE_Q_TOP, WAVE_Q_ALL, WAVE_Q_ALL, WAVE_Q_ALL
wave_base_flags:
    .byte WAVE_F_MAIN_C
    .byte WAVE_F_MAIN_C
    .byte WAVE_F_PIGGY_C | WAVE_F_MAIN_C
    .byte WAVE_F_PIGGY_C | WAVE_F_MAIN_C

; Kill-quota growth added per (level - 1). Hard tail (W3) grows fastest.
wave_grow_c:
    .byte 0, 1, 1, 2
wave_grow_b:
    .byte 0, 0, 1, 1
wave_grow_a:
    .byte 0, 0, 0, 1
