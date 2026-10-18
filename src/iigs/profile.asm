; Optional foreground timing instrumentation. NativeM=X16, DBR=NATIVE, IRQsON.
; Disabled shipping path calls only real game_tick; enabled diagnostic includes
; clock sampling cost in recorded stages. Never runs inside a visible wave.
ng_timed_game_tick         lda ng_profile_enabled
                          bne ng_game_profiled
                          jsl game_tick
                          rts
ng_game_profiled          jsr clock_sample
                          lda clock_time
                          sta ng_game_before
                          lda clock_time+2
                          sta ng_game_before+2
                          jsl game_tick
                          jsl game_observe
                          jsr clock_sample
                          sec
                          lda clock_time
                          sbc ng_game_before
                          sta ng_game_last
                          lda clock_time+2
                          sbc ng_game_before+2
                          sta ng_game_last+2
                          cmp ng_game_max+2
                          bcc ng_game_timing_done
                          bne ng_game_new_max
                          lda ng_game_last
                          cmp ng_game_max
                          bcc ng_game_timing_done
ng_game_new_max           lda ng_game_last
                          sta ng_game_max
                          lda ng_game_last+2
                          sta ng_game_max+2
ng_game_timing_done        rts
ng_profile_render         lda ng_profile_enabled
                          bne ng_render_profiled
                          jmp rs_render
ng_render_profiled        jsr clock_sample
                          lda clock_time
                          sta ng_stage_before
                          lda clock_time+2
                          sta ng_stage_before+2
                          jsr rb_prepare
                          cmp #0
                          beq ng_profile_background
                          rts
ng_profile_background     ldx #0
                          jsr ng_record_stage
                          jsr rs_mark_objects
                          ldx #4
                          jsr ng_record_stage
                          jsr rco_expand
                          jsr rd_emit
                          cmp #0
                          beq ng_profile_emit
                          rts
ng_profile_emit           ldx #8
                          jsr ng_record_stage
                          jsr rr_restore
                          ldx #12
                          jsr ng_record_stage
                          jsr rs_compose
                          ldx #16
                          jsr ng_record_stage
                          lda #0
                          rts
ng_record_stage           stx ng_stage_index
                          jsr clock_sample
                          ldx ng_stage_index
                          sec
                          lda clock_time
                          sbc ng_stage_before
                          sta ng_stage_last,x
                          lda clock_time+2
                          sbc ng_stage_before+2
                          sta ng_stage_last+2,x
                          cmp ng_stage_max+2,x
                          bcc ng_stage_not_max
                          bne ng_stage_new_max
                          lda ng_stage_last,x
                          cmp ng_stage_max,x
                          bcc ng_stage_not_max
ng_stage_new_max          lda ng_stage_last,x
                          sta ng_stage_max,x
                          lda ng_stage_last+2,x
                          sta ng_stage_max+2,x
ng_stage_not_max          lda clock_time
                          sta ng_stage_before
                          lda clock_time+2
                          sta ng_stage_before+2
                          rts
ng_game_before            ds 4
ng_game_last              ds 4
ng_game_max               ds 4
ng_stage_before           ds 4
ng_stage_index            ds 2
ng_stage_last             ds 20
ng_stage_max              ds 20
; Optional deterministic benchmark input. These are held direction bits and
; one-tick fire pulses, fed through GAME's normal edge processing. Tool9 remains
; active and Ctrl-Q still takes precedence. Normal shipping build disables this.
ng_fixture_input          lda ng_fixture_enabled
                          beq ng_fixture_done
                          dec ng_fixture_dir_timer
                          bne ng_fixture_dir_ready
                          lda #53
                          sta ng_fixture_dir_timer
                          inc ng_fixture_phase
                          lda ng_fixture_phase
                          and #15
                          sta ng_fixture_phase
ng_fixture_dir_ready      stz ng_fixture_fire
                          dec ng_fixture_fire_timer
                          bne ng_fixture_fire_ready
                          lda #97
                          sta ng_fixture_fire_timer
                          lda #1
                          sta ng_fixture_fire
ng_fixture_fire_ready     lda ng_fixture_fire_hold
                          beq ng_fixture_fire_selected
                          lda #1
                          sta ng_fixture_fire
ng_fixture_fire_selected  sep #$20
                          longa off
                          lda ng_fixture_phase
                          sta >game_input_dirs
                          lda ng_fixture_fire
                          sta >game_input_fire
                          lda #0
                          sta >game_input_key_s
                          sta >game_input_key_i
                          sta >game_input_runstop
                          rep #$20
                          longa on
ng_fixture_done           rts
ng_fixture_phase          ds 2
ng_fixture_fire           ds 2
ng_fixture_dir_timer      dc i2'53'
ng_fixture_fire_timer     dc i2'97'
