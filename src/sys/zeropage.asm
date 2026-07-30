; Zero-page map — single owner of ZP layout.
; Included under .segment "ZEROPAGE" (noemit).

; Mode / frame
game_mode:      .res 1              ; MODE_* constant
frame_count:    .res 1              ; free-running low byte (poll ticks)

; Input (normalized)
input_dirs:     .res 1              ; bit0=U bit1=D bit2=L bit3=R (1 = pressed)
input_fire:     .res 1              ; 1 = fire held
input_fire_edge:.res 1              ; 1 = fire pressed this frame (edge)
input_fire_prev:.res 1              ; previous frame fire (edge detect)

; Session state
score0:         .res 1              ; 24-bit binary score, lo..hi (cap 999999)
score1:         .res 1
score2:         .res 1
score_dirty:    .res 1              ; nonzero → rewrite HUD score digits
score_work0:    .res 1              ; paint scratch (not tmp* — put_xy clobbers those)
score_work1:    .res 1
score_work2:    .res 1
hud_status_dirty: .res 1            ; nonzero → rewrite level / progress / lives
lives:          .res 1              ; RESERVE ships (HUD); active ship not counted
deploy_timer:   .res 1              ; 0=playing; >0 frames until peel + show player
level:          .res 1
level_kills:    .res 1              ; kills this level toward level_quota
level_quota:    .res 1              ; kills required to complete level
level_banner_t: .res 1              ; 0=play; >0 rank banner frames left (spawn paused)
kill_extra_cnt: .res 1              ; 0..EXTRA_KILL_EVERY-1; wrap → extra due

; Session tallies (game over). 16-bit lo,hi each; saturate at $FFFF.
tally_shots0:   .res 1              ; bullets successfully launched
tally_shots1:   .res 1
tally_kill_a0:  .res 1              ; class A drones destroyed
tally_kill_a1:  .res 1
tally_kill_b0:  .res 1
tally_kill_b1:  .res 1
tally_kill_c0:  .res 1
tally_kill_c1:  .res 1

; Player (logical slot 0; position also in objects:: SoA)
player_rail:    .res 1              ; PLAYER_RAIL_H or PLAYER_RAIL_V
player_rest_dir:.res 1              ; SPR_DIR_* rest aim (U/D on H, L/R on V)
player_swing_t: .res 1              ; 0 = at rest; else mid-swing frames remaining
player_swing_to:.res 1              ; rest facing after mid frame expires
player_move_dir:.res 1              ; PLAYER_DIR_*; last travel (coast through centre)
player_cross_decided: .res 1        ; 1 = centre eval done this rail-walk; clear off intersection
; Death sequence (cargo mine / rail collapse). Nonzero = ignore input; drones inert at rail.
player_dead:    .res 1              ; 0 = alive; 1 = exploding / hold
death_phase:    .res 1              ; 0..6 explode steps; DEATH_HOLD_PHASE = hold
death_timer:    .res 1              ; frames left in current phase
death_fatal:    .res 1              ; 1 = game over after hold; 0 = respawn level
death_flash:    .res 1              ; 0 = COL_RED, 1 = COL_LT_RED (fatal hold banner)
death_flash_t:  .res 1              ; frames until next colour toggle

; Launcher — dice composer (level quota + random cooldown)
rng_state:         .res 1           ; 8-bit LFSR seed (never leave 0 long)
drone_spawn_timer: .res 1           ; ticks until next main launch attempt
wave_cd_min:       .res 1
wave_cd_max:       .res 1
wave_max_active:   .res 1
wave_quad_mask:    .res 1           ; WAVE_Q1..Q4
wave_flags:        .res 1           ; WAVE_F_*
drone_speed_cap:   .res 1           ; 1..MAX_LEVEL — C max velocity tier this level
spawn_last_quad:   .res 1           ; anti-streak (0..3, $FF = none)
spawn_kind:        .res 1           ; OBJ_DRONE_* for in-flight launch (not tmp*)
spawn_quad:        .res 1           ; 0..3
spawn_approach:    .res 1           ; DRONE_APPROACH_*
; Piggyback C after A/B
piggy_timer:       .res 1           ; 0 = idle; else countdown to C spawn
piggy_quad:        .res 1
piggy_approach:    .res 1
spawn_quad_list:   .res 4           ; scratch for roll_quad candidates

; Bonus parcel — at most one live; 2 drops per level
parcel_slot:       .res 1           ; object index, or $FF = none
parcel_due:        .res 1           ; sticky bit: spawn when free
parcel_flip:       .res 1           ; global end flip-flop (0/1)
parcel_drop_mask:  .res 1           ; PARCEL_DROP_T1/T2 already fired this level
parcel_dir:        .res 1           ; SPR_DIR_* travel for active parcel
parcel_flags:      .res 1           ; PARCEL_FLAG_* due bits + block_clear
parcel_type:       .res 1           ; PARCEL_TYPE_* of live parcel
power_2x:          .res 1           ; nonzero = 2 HP per hit until level end
score_2x:          .res 1           ; nonzero = 2 pts per hit until level end
clear_armed:       .res 1           ; pickup: wipe GHIJ on next centre pass
repair_timer:      .res 1           ; >0 = mark window; 0 idle
player_was_centre: .res 1           ; edge detect for clear_armed

; C cargo sprite in transit → one of GHIJ; stacks in rail_data
cargo_slot:        .res 1           ; object index, or $FF = none
cargo_target:      .res 1           ; 0..3 = G,H,I,J destination this trip
ghij_rr:           .res 1           ; 0..3 next stack tile to assign
ghij_last:         .res 1           ; 0..3 last tile that received a stack ($FF = none)
mine_armed:        .res 1           ; 1 = GHIJ full → detonate this frame

; Rank banner paint region (centred overlay; rest of HUD stays)
banner_col:        .res 1           ; first column of banner (incl. pad spaces)
banner_len:        .res 1           ; width of coloured/padded banner text

; Mode-local timers / scratch
mode_timer:     .res 1
mode_state:     .res 1
; Deferred mode change from mid-tick combat (never mode_set inside drones/collision)
pending_mode:   .res 1              ; 0 = none; else MODE_* applied end of play_update

; Attract loop countdown (16-bit frames remaining on current attract page)
attract_lo:     .res 1
attract_hi:     .res 1

; Text-title score colour wheel
score_color_phase: .res 1           ; 0..9 base index into palette
score_color_tick:  .res 1           ; frames until next rotate

; Menu letter keys (level + edge); S also drives joy-down in play
input_key_s:    .res 1
input_key_i:    .res 1
input_key_s_edge: .res 1
input_key_i_edge: .res 1
input_key_s_prev: .res 1
input_key_i_prev: .res 1

; RUN/STOP kill switch (play → game over)
input_runstop:      .res 1
input_runstop_edge: .res 1
input_runstop_prev: .res 1

; Collision dogfood border toggles (hybrid latch vs software)
coll_fp_phase:  .res 1              ; 0/1 — HW latch, no soft hit
coll_fn_phase:  .res 1              ; 0/1 — soft hit, no HW latch

; Typewriter (story screen): source cursor + screen pen + previous cell
type_src_lo:    .res 1
type_src_hi:    .res 1
type_col:       .res 1
type_row:       .res 1
type_prev_col:  .res 1              ; $FF = no previous glyph yet
type_prev_row:  .res 1

; General temps / pointers
tmp0:           .res 1
tmp1:           .res 1
tmp2:           .res 1
ptr_lo:         .res 1
ptr_hi:         .res 1
; screen_print source pointer (dest base is computed into ptr_* once per string)
print_ptr_lo:   .res 1
print_ptr_hi:   .res 1
draw_i:         .res 1              ; playfield draw loops (put_xy clobbers tmp*)
draw_j:         .res 1

; Graphical objects / mux builder (main-thread scratch)
mux_i:          .res 1
mux_j:          .res 1
mux_k:          .res 1
mux_key:        .res 1
mux_key_prio:   .res 1
mux_current:    .res 1
mux_current_top:.res 1
mux_current_bottom_lo: .res 1
mux_current_bottom_hi: .res 1
mux_forbidden:  .res 1
mux_min_lane:   .res 1
mux_cursor:     .res 1
mux_best_slot:  .res 1
mux_best_value: .res 1
mux_lane:       .res 1
mux_bit:        .res 1
mux_clear:      .res 1
mux_ref0:       .res 1
mux_ref1:       .res 1
mux_ref2:       .res 1
mux_shadow_enable: .res 1
mux_shadow_xmsb:   .res 1
mux_shadow_xexp:   .res 1
mux_shadow_yexp:   .res 1
mux_shadow_multi:  .res 1
mux_shadow_bgprio: .res 1

; Raster IRQ scratch/state
irq_command_index: .res 1
irq_lane:       .res 1
irq_owner:      .res 1
irq_interest:   .res 1
irq_value_x:    .res 1
irq_value_y:    .res 1
irq_value_ptr:  .res 1
irq_value_color:.res 1
irq_bit:        .res 1
irq_plan_delta: .res 1
irq_pending_mask: .res 1
irq_clear_lane: .res 1
irq_shadow_enable: .res 1
irq_shadow_xmsb:   .res 1
irq_shadow_xexp:   .res 1
irq_shadow_yexp:   .res 1
irq_shadow_multi:  .res 1
irq_shadow_bgprio: .res 1
