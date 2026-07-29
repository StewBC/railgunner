; Level spawn controller (ex-waves). No player-facing waves.
; Level kill quota + dice launcher params from level / progress.

.scope waves

; ---------------------------------------------------------------------------
; load — start or restart level spawn params (call on stage enter / level up)
; ---------------------------------------------------------------------------
.proc load
    ; level_quota from table
    lda level
    bne ld_nz
    lda #1
ld_nz:
    cmp #MAX_LEVEL + 1
    bcc ld_cap
    lda #MAX_LEVEL
ld_cap:
    tax
    dex                             ; 0-based
    lda level_kill_quota_tbl, x
    sta level_quota
    lda #0
    sta level_kills
    sta level_banner_t
    sta piggy_timer
    lda #$FF
    sta spawn_last_quad

    ; speed cap = level (clamped)
    lda level
    bne sc_nz
    lda #1
sc_nz:
    cmp #MAX_LEVEL + 1
    bcc sc_ok
    lda #MAX_LEVEL
sc_ok:
    sta drone_speed_cap

    jsr apply_spawn_params

    lda rng_state
    bne ld_timer
    lda frame_count
    ora #1
    sta rng_state
ld_timer:
    jsr drones::roll_cooldown
    jsr parcels::level_reset
    lda #1
    sta hud_status_dirty
    rts
.endproc

; Spawn density / mix from level and kill progress (thirds of level_quota).
.proc apply_spawn_params
    ; default: all quads, main C, mid density
    lda #WAVE_Q_ALL
    sta wave_quad_mask
    lda #WAVE_F_MAIN_C
    sta wave_flags
    lda #50
    sta wave_cd_min
    lda #90
    sta wave_cd_max
    lda #3
    sta wave_max_active

    ; Early third: top-only on low levels
    lda level
    cmp #3
    bcs asp_mid
    lda level_kills
    cmp #1
    bcs asp_mid
    lda #WAVE_Q_TOP
    sta wave_quad_mask
    lda #70
    sta wave_cd_min
    lda #110
    sta wave_cd_max
    lda #2
    sta wave_max_active
    rts

asp_mid:
    ; progress phase via kills * 3 vs quota
    lda level_kills
    sta tmp0
    lda level_quota
    lsr a                           ; ~quota/2 rough
    cmp tmp0
    bcs asp_early_half
    ; late half: denser, piggy, more active
    lda #WAVE_F_MAIN_C | WAVE_F_PIGGY_C
    sta wave_flags
    lda #28
    sta wave_cd_min
    lda #55
    sta wave_cd_max
    lda #5
    sta wave_max_active
    ; scale max_active with level a bit
    lda level
    cmp #8
    bcc asp_cap
    lda #7
    sta wave_max_active
asp_cap:
    lda wave_max_active
    cmp #WAVE_MAX_ACTIVE_CAP + 1
    bcc asp_done
    lda #WAVE_MAX_ACTIVE_CAP
    sta wave_max_active
    rts
asp_early_half:
    lda level
    cmp #2
    bcc asp_done
    lda #WAVE_F_MAIN_C | WAVE_F_PIGGY_C
    sta wave_flags
    lda #40
    sta wave_cd_min
    lda #75
    sta wave_cd_max
    lda #4
    sta wave_max_active
asp_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; Kill registration: 1 kill per destroyed drone toward level_quota
; ---------------------------------------------------------------------------
.proc note_kill
    lda level_kills
    cmp #255
    beq nk_hud
    inc level_kills
nk_hud:
    lda #1
    sta hud_status_dirty
    jsr apply_spawn_params          ; densify as progress advances
    jsr parcels::on_kill
    rts
.endproc

; ---------------------------------------------------------------------------
; Level complete: quota met + field empty → start banner (spawn already stopped)
; ---------------------------------------------------------------------------
.proc check_clear
    lda level_banner_t
    bne cc_done
    lda level_kills
    cmp level_quota
    bcc cc_done
    jsr drones::count_active_drones
    cmp #0
    bne cc_done
    ; Start rank banner (live play continues)
    lda #LEVEL_BANNER_FRAMES
    sta level_banner_t
    jsr message::show_rank_banner
cc_done:
    rts
.endproc

; Tick banner colour wheel; on expiry advance level and restore HUD.
.proc update_banner
    lda level_banner_t
    beq ub_done
    jsr message::tick_banner_color
    dec level_banner_t
    bne ub_done
    jsr advance_level
ub_done:
    rts
.endproc

.proc advance_level
    lda level
    cmp #MAX_LEVEL
    bcs adv_cap
    inc level
    jmp adv_load
adv_cap:
    ; endless at max intensity for now (victory hook later)
    lda #MAX_LEVEL
    sta level
adv_load:
    lda #0
    sta level_kills
    sta level_banner_t
    jsr load                        ; new quota + parcels reset + spawn params
    jsr message::restore_hud_line
    rts
.endproc

.endscope
