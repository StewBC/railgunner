; Wave load + kill clear (launcher v2 + level knobs, Step 8.7).
; Builds wave_* and drone_speed_cap from wave index + level.

.scope waves

; ---------------------------------------------------------------------------
; load — fill wave_* for current wave/level
; Scratch: mux_i = wave idx, mux_j = L0 (level-1 clamped), mux_k = temp
; ---------------------------------------------------------------------------
.proc load
    lda wave
    cmp #WAVES_PER_LEVEL
    bcc load_wave_ok
    lda #WAVES_PER_LEVEL - 1
load_wave_ok:
    sta mux_i

    ; L0 = min(level, MAX_LEVEL) - 1  (level is 1-based; 0 treated as 1)
    lda level
    bne load_lvl_nz
    lda #1
load_lvl_nz:
    cmp #MAX_LEVEL + 1
    bcc load_lvl_cap
    lda #MAX_LEVEL
load_lvl_cap:
    sec
    sbc #1
    sta mux_j                       ; 0 .. MAX_LEVEL-1

    ; C max velocity tier this level (1..MAX_LEVEL); B/A step down at spawn
    lda mux_j
    clc
    adc #1
    sta drone_speed_cap

    ; --- base row ---
    ldy mux_i
    lda wave_base_c, y
    sta wave_quota
    lda wave_base_b, y
    sta wave_b_quota
    lda wave_base_a, y
    sta wave_a_quota
    lda wave_base_cd_min, y
    sta wave_cd_min
    lda wave_base_cd_max, y
    sta wave_cd_max
    lda wave_base_max_active, y
    sta wave_max_active
    lda wave_base_quad_mask, y
    sta wave_quad_mask
    lda wave_base_flags, y
    sta wave_flags

    ; --- kill-quota growth: base + grow[w] * L0 ---
    lda wave_grow_c, y
    ldx mux_j
    jsr mul8x8                      ; A = grow * L0
    clc
    adc wave_quota
    bcc load_c_ok
    lda #255
load_c_ok:
    sta wave_quota

    ldy mux_i
    lda wave_grow_b, y
    ldx mux_j
    jsr mul8x8
    clc
    adc wave_b_quota
    bcc load_b_ok
    lda #255
load_b_ok:
    sta wave_b_quota

    ldy mux_i
    lda wave_grow_a, y
    ldx mux_j
    jsr mul8x8
    clc
    adc wave_a_quota
    bcc load_a_ok
    lda #255
load_a_ok:
    sta wave_a_quota

    ; --- composition shift: earlier A/B, slightly less pure-C open ---
    jsr apply_composition_shift

    ; --- cooldown shrink (denser launches) ---
    jsr apply_cd_shrink

    ; --- max concurrent growth ---
    jsr apply_max_active_growth

    ; --- session counters ---
    lda #0
    sta wave_kills_c
    sta wave_kills_b
    sta wave_kills_a
    sta piggy_timer
    lda #$FF
    sta spawn_last_quad
    lda rng_state
    bne load_timer
    lda frame_count
    ora #1
    sta rng_state
load_timer:
    jsr drones::roll_cooldown
    jsr parcels::wave_reset
    rts
.endproc

; ---------------------------------------------------------------------------
; Composition: push A/B earlier as level rises; keep a real open, just shorter
; and less pure-C. Late band (L0 >= 9) can put light A/B in W0.
; mux_i = wave, mux_j = L0
; ---------------------------------------------------------------------------
.proc apply_composition_shift
    lda mux_i
    bne acs_w1

    ; ---- Wave 0 (open / breather) ----
    ; L0 >= 4: introduce B (grows slowly)
    lda mux_j
    cmp #4
    bcc acs_w0_c
    sec
    sbc #4                          ; 0 at L5
    lsr a                           ; /2
    clc
    adc #1
    cmp wave_b_quota
    bcc acs_w0_a
    sta wave_b_quota
acs_w0_a:
    ; L0 >= 8: light A pressure in open
    lda mux_j
    cmp #8
    bcc acs_w0_c
    lda wave_a_quota
    bne acs_w0_c
    lda #1
    sta wave_a_quota
acs_w0_c:
    ; Soften pure-C a little once B/A appear (never below 3 on open)
    lda wave_b_quota
    ora wave_a_quota
    beq acs_flags
    lda wave_quota
    cmp #4
    bcc acs_flags
    sec
    sbc #1
    sta wave_quota
    jmp acs_flags

acs_w1:
    lda mux_i
    cmp #1
    bne acs_w2

    ; ---- Wave 1 ----
    ; L0 >= 2: at least one B
    lda mux_j
    cmp #2
    bcc acs_flags
    lda wave_b_quota
    bne acs_w1_a
    lda #1
    sta wave_b_quota
acs_w1_a:
    ; L0 >= 5: at least one A
    lda mux_j
    cmp #5
    bcc acs_flags
    lda wave_a_quota
    bne acs_flags
    lda #1
    sta wave_a_quota
    jmp acs_flags

acs_w2:
    ; W2/W3 already have A/B bases + growth — no forced inject
    ; Fall through to flags
acs_flags:
    ; Piggy when any A/B quota exists
    lda wave_b_quota
    ora wave_a_quota
    beq acs_quad
    lda wave_flags
    ora #WAVE_F_PIGGY_C
    sta wave_flags
acs_quad:
    ; From L3 (L0>=2), open also uses all quads
    lda mux_i
    bne acs_done
    lda mux_j
    cmp #2
    bcc acs_done
    lda #WAVE_Q_ALL
    sta wave_quad_mask
acs_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; Shrink inter-drone launch window with level.
; Late band (L0 >= 9) squeezes W0 further so L14→L15 open approaches prior peak.
; mux_i = wave, mux_j = L0
; ---------------------------------------------------------------------------
.proc apply_cd_shrink
    ; shrink = min(L0 * 3, 48)
    lda mux_j
    asl a
    clc
    adc mux_j                       ; *3
    cmp #49
    bcc acd_sh_ok
    lda #48
acd_sh_ok:
    sta mux_k                       ; base shrink

    ; Extra open squeeze for L10–15: (L0 - 8) * 4 on wave 0
    lda mux_i
    bne acd_apply
    lda mux_j
    cmp #9
    bcc acd_apply
    sec
    sbc #8
    asl a
    asl a                           ; *4
    clc
    adc mux_k
    sta mux_k

acd_apply:
    lda wave_cd_min
    sec
    sbc mux_k
    bcs acd_min_ok
    lda #WAVE_CD_MIN_FLOOR
acd_min_ok:
    cmp #WAVE_CD_MIN_FLOOR
    bcs acd_min_store
    lda #WAVE_CD_MIN_FLOOR
acd_min_store:
    sta wave_cd_min

    lda wave_cd_max
    sec
    sbc mux_k
    bcs acd_max_ok
    lda #0
acd_max_ok:
    sta wave_cd_max

    ; Enforce cd_max >= cd_min + WAVE_CD_SPAN_MIN
    lda wave_cd_min
    clc
    adc #WAVE_CD_SPAN_MIN
    bcc acd_span_ok
    lda #255
acd_span_ok:
    cmp wave_cd_max
    bcc acd_done
    beq acd_done
    sta wave_cd_max
acd_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; max_active = min(CAP, base + L0/2)
; L1 peak 4 → L10 ~8 → L15 ~10 (mux pressure)
; mux_i = wave, mux_j = L0
; ---------------------------------------------------------------------------
.proc apply_max_active_growth
    lda mux_j
    lsr a                           ; L0/2
    clc
    adc wave_max_active
    cmp #WAVE_MAX_ACTIVE_CAP + 1
    bcc ama_ok
    lda #WAVE_MAX_ACTIVE_CAP
ama_ok:
    sta wave_max_active
    rts
.endproc

; ---------------------------------------------------------------------------
; mul8x8: A * X → A (low 8 bits; saturates not needed for our small factors)
; Clobbers tmp0, tmp1
; ---------------------------------------------------------------------------
.proc mul8x8
    sta tmp0                        ; multiplicand
    stx tmp1                        ; multiplier
    lda #0
    ldx #8
m88_loop:
    lsr tmp1
    bcc m88_no
    clc
    adc tmp0
m88_no:
    asl tmp0
    dex
    bne m88_loop
    rts
.endproc

; ---------------------------------------------------------------------------
.proc check_clear
    lda pending_mode
    bne cc_done
    lda wave_kills_c
    cmp wave_quota
    bcc cc_done
    lda wave_kills_b
    cmp wave_b_quota
    bcc cc_done
    lda wave_kills_a
    cmp wave_a_quota
    bcc cc_done
    jsr drones::count_active_drones
    cmp #0
    bne cc_done
    ; Field clear — award any live parcel (be nice) before wave advance
    jsr parcels::award_if_active
    lda #MODE_NEXT_WAVE
    sta pending_mode
cc_done:
    rts
.endproc

.proc note_kill
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_C
    beq nk_c
    cmp #OBJ_DRONE_B
    beq nk_b
    cmp #OBJ_DRONE_A
    beq nk_a
    rts
nk_c:
    inc wave_kills_c
    jmp nk_progress
nk_b:
    inc wave_kills_b
    jmp nk_progress
nk_a:
    inc wave_kills_a
nk_progress:
    jsr parcels::on_kill
    rts
.endproc

.endscope
