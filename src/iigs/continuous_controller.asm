; Beam-following immutable-generation presentation. No admission/rejection.
; Each eight-row region restores then redraws in stable layer/slot order.
; Regions are disjoint: later old erasures cannot wipe earlier new fragments.
; IRQs remain enabled except inside the existing bounded stack fragments.
; Return0 complete,3 unchanged,2 actual invalid state/drawing failure.
                     longa  on
                     longi  on
rwp_init             stz    rwp_fault
                     stz    rw_admitted
                     lda    #1
                     sta    rwp_ready
                     lda    #0
                     rts
rwp_present          lda    rwp_fault
                     beq    rwp_check_ready
                     lda    #2
                     rts
rwp_check_ready      lda    rwp_ready
                     beq    rwp_fail
                     lda    rc_pending
                     beq    rwp_fail
                     stz    rwp_wrote
                     lda    rd_count
                     bne    rwp_start
; Unchanged candidates leave the image stable; exclude idle from busy cadence.
                     stz    beam_commit_valid
                     jsr    rc_publish
                     inc    rwp_nochanges
                     lda    #3
                     rts
rwp_fail             lda    #1
                     sta    rwp_fault
                     stz    rw_admitted
                     stz    rw_mode
                     lda    #2
                     rts
rwp_start            lda    ng_profile_enabled
                     beq    rwp_begin
                     jsr    clock_sample
                     lda    clock_time
                     sta    rwp_draw_before
                     lda    clock_time+2
                     sta    rwp_draw_before+2
rwp_begin            lda    #1
                     sta    rw_admitted
                     sta    rw_mode
                     stz    rw_strip
                     stz    rw_words
                     stz    rw_spans
rwp_strip_loop       lda    rw_strip
                     asl    a
                     tax
                     lda    rd_boundary,x
                     cmp    rd_boundary+2,x
                     beq    rwp_strip_next
                     jsr    beam_wait_strip
                     jsr    beam_trace_begin
                     jsr    sw_choose_strip
                     jsr    beam_trace_end
                     cmp    #0
                     bne    rwp_fail
                     inc    rwp_wrote
                     jsr    render_service
rwp_strip_next       anop
                     inc    rw_strip
                     lda    rw_strip
                     cmp    #25
                     bcc    rwp_strip_loop
rwp_pixels_complete  jsr    beam_commit
                     stz    rw_admitted
                     stz    rw_mode
                     lda    rd_words
                     sta    rwp_last_words
                     lda    rd_count
                     sta    rwp_last_spans
                     lda    ng_profile_enabled
                     beq    rwp_publish
                     jsr    clock_sample
                     sec
                     lda    clock_time
                     sbc    rwp_draw_before
                     sta    rwp_draw_last
                     lda    clock_time+2
                     sbc    rwp_draw_before+2
                     sta    rwp_draw_last+2
                     cmp    rwp_draw_max+2
                     bcc    rwp_publish
                     bne    rwp_draw_maximum
                     lda    rwp_draw_last
                     cmp    rwp_draw_max
                     bcc    rwp_publish
rwp_draw_maximum     lda    rwp_draw_last
                     sta    rwp_draw_max
                     lda    rwp_draw_last+2
                     sta    rwp_draw_max+2
rwp_publish          jsr    rc_publish
                     inc    rwp_commits
                     inc    debug_frames
                     lda    sw_enabled
                     beq    rwp_complete
                     inc    sw_commits
rwp_complete         lda    #0
                     rts
rwp_ready            ds     2
rwp_fault            ds     2
rwp_commits          ds     2
; Compatibility diagnostic: never incremented by this controller.
rwp_repeats          ds     2
rwp_nochanges        ds     2
rwp_wrote            ds     2
rwp_last_words       ds     2
rwp_last_spans       ds     2
rwp_max_blackout     ds     2
rwp_draw_before      ds     4
rwp_draw_last        ds     4
rwp_draw_max         ds     4
