; G5 explicit hardware services. Enter/return M=X=8, DBR=GAME, private GAME D.
; No hardware, IRQ ownership, audio state, or renderer storage is touched.
title_gfx_enter            lda #1
                          sta native_present
                          jsr attract_reset_timer
                          lda #MENU_FIRE_GUARD
                          sta mode_timer
                          rts
title_park_hires           rts
music__start_title        rts
music__stop               rts
play_enter                lda #COL_GREEN
                          sta native_border
                          lda #0
                          sta pending_mode
                          rts
game_init_enter           jsr music__stop
                          lda #COL_CYAN
                          sta native_border
                          jsr score__reset
                          jsr tallies__reset
                          lda #START_LIVES
                          sta lives
                          lda #START_LEVEL
                          sta level
                          lda #0
                          sta level_kills
                          sta level_banner_t
                          sta pending_mode
                          sta victory
                          sta kill_extra_cnt
                          sta parcel_flags
                          sta power_2x
                          sta score_2x
                          sta clear_armed
                          sta repair_timer
                          sta deploy_timer
                          sta player_was_centre
                          lda #1
                          sta hud_status_dirty
                          jsr objects__init
                          jsr rail__reset
                          jsr cargo__init
                          lda #MODE_STAGE_INIT
                          jsr mode_set
                          rts
stage_init_enter          lda #COL_LT_BLUE
                          sta native_border
                          lda #0
                          sta native_present
                          jsr screen_draw_playfield
                          jsr rail__redraw_from_state
                          jsr bullets__init
                          jsr drones__init
                          jsr cargo__init
                          jsr parcels__init
                          jsr waves__load
                          jsr player__begin_deploy
                          jsr hud__paint_full_line
                          jsr hud_color_static
                          lda #SFX_WAVE
                          jsr sfx__play
                          lda #MODE_PLAY
                          jsr mode_set
                          rts
collision__update         ldx #1
native_collision_loop     lda objects__obj_flags,x
                          and #OBJF_ALLOCATED+OBJF_RETIRING
                          cmp #OBJF_ALLOCATED
                          bne native_collision_next
                          lda objects__obj_kind,x
                          cmp #OBJ_DRONE_A
                          bcc native_collision_next
                          cmp #OBJ_BONUS
                          bcs native_collision_next
                          lda objects__obj_anim_state,x
                          bmi native_collision_next
                          stx mode_state
                          jsr collision__mode_soft_only
                          ldx mode_state
native_collision_next     inx
                          cpx #OBJECT_CAPACITY
                          bne native_collision_loop
                          rts
input_poll                lda #0
                          sta input_fire_edge
                          sta input_key_s_edge
                          sta input_key_i_edge
                          sta input_runstop_edge
                          lda input_fire
                          beq native_fire_save
                          lda input_fire_prev
                          bne native_fire_save
                          lda #1
                          sta input_fire_edge
native_fire_save          lda input_fire
                          sta input_fire_prev
                          lda input_key_s
                          beq native_s_save
                          lda input_key_s_prev
                          bne native_s_save
                          lda #1
                          sta input_key_s_edge
native_s_save             lda input_key_s
                          sta input_key_s_prev
                          lda input_key_i
                          beq native_i_save
                          lda input_key_i_prev
                          bne native_i_save
                          lda #1
                          sta input_key_i_edge
native_i_save             lda input_key_i
                          sta input_key_i_prev
                          lda input_runstop
                          beq native_stop_save
                          lda input_runstop_prev
                          bne native_stop_save
                          lda #1
                          sta input_runstop_edge
native_stop_save          lda input_runstop
                          sta input_runstop_prev
                          inc frame_count
                          rts
; Diagnostic tick: current inputs are supplied by the command mailbox.
native_fixed_tick         jsr objects__reap
                          lda >core_input_dirs
                          and #15
                          sta input_dirs
                          lda >core_input_fire
                          sta input_fire
                          lda >core_input_key_s
                          sta input_key_s
                          lda >core_input_key_i
                          sta input_key_i
                          lda >core_input_runstop
                          sta input_runstop
                          jsr input_poll
                          jsr mode_run
                          rts
native_cold_init          lda #MODE_TITLE_GFX
                          sta game_mode
                          jsr hiscore_reset
                          jsr title_gfx_enter
                          rts
