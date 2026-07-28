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
hud_status_dirty: .res 1            ; nonzero → rewrite health / level / lives
lives:          .res 1
health:         .res 1
ammo:           .res 1
level:          .res 1
wave:           .res 1

; Player (logical slot 0; position also in objects:: SoA)
player_rail:    .res 1              ; PLAYER_RAIL_H or PLAYER_RAIL_V
player_rest_dir:.res 1              ; SPR_DIR_* rest aim (U/D on H, L/R on V)
player_swing_t: .res 1              ; 0 = at rest; else mid-swing frames remaining
player_swing_to:.res 1              ; rest facing after mid frame expires
player_move_dir:.res 1              ; PLAYER_DIR_*; last travel (coast through centre)
player_cross_decided: .res 1        ; 1 = centre eval done this rail-walk; clear off intersection

; Wave-driven multi-C spawner (Step 8.3–8.4)
drone_spawn_timer: .res 1           ; ticks until next spawn attempt
drone_spawn_seq:   .res 1           ; 0..3 approach rotation
drone_spawn_lane:  .res 1           ; alternate left/right or top/bot lane
wave_quota:        .res 1           ; C to spawn this wave
wave_spawned:      .res 1           ; C spawned so far this wave
wave_cadence:      .res 1           ; C ticks between spawn attempts
wave_max_active:   .res 1           ; concurrent C cap
wave_approach_mask:.res 1           ; WAVE_EDGE_* bits (C)
wave_b_quota:      .res 1           ; B (medium) to spawn
wave_a_quota:      .res 1           ; A (large) to spawn
wave_b_spawned:    .res 1
wave_a_spawned:    .res 1
wave_ab_timer:     .res 1           ; separate slower cadence for A/B

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
