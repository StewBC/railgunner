; Time Pilot-style release after affected bottom, physical NTSC lines 0..261.
; SHR rows are physical lines 0..199 (raw raster $100..$1c7).
; The rails/glyph field can occupy row199 even with no sprites: conservatively
; use200 as the lowest relevant displayed bound. No whole-frame budget gate.
; Main-loop wait leaves the completed image intact. Preparation can run late;
; all pending work still completes. Services within preparation remain enabled.
                         longa  on
                         longi  on
beam_prepare_window      lda    rc_pending
                         bne    beam_prepare_done
                         lda    rc_displayed_mode
                         cmp    #3
                         beq    beam_prepare_sample
                         stz    beam_prepare_valid
                         rts
beam_prepare_sample      jsr    clock_sample
                         lda    beam_prepare_valid
                         beq    beam_prepare_first
                         sec
                         lda    clock_time
                         sbc    beam_prepare_next
                         lda    clock_time+2
                         sbc    beam_prepare_next+2
                         bpl    beam_prepare_release
                         bra    beam_prepare_sample
beam_prepare_first       lda    clock_line
                         cmp    #200
                         bcc    beam_prepare_sample
; A crossing during previous preparation/drawing already grants this work.
; Do not add another refresh wait simply because completion wrapped to the top.
beam_prepare_release     lda    #462
                         sec
                         sbc    clock_line
                         cmp    #263
                         bcc    beam_prepare_offset
                         sbc    #262
beam_prepare_offset      clc
                         adc    clock_time
                         sta    beam_prepare_next
                         lda    clock_time+2
                         adc    #0
                         sta    beam_prepare_next+2
                         lda    #1
                         sta    beam_prepare_valid
beam_prepare_done        rts
beam_prepare_valid       ds     2
beam_prepare_next        ds     4

; Wait only while the beam has not yet cleared this region in this refresh.
; If already in the release window, proceed immediately. A wrap before release
; selects the next safe crossing; never reject or recapture the candidate.
; Do not call gameplay while waiting here: the main loop/preparation and the
; completed-strip boundary provide service, outside the erase exposure window.
beam_wait_strip          lda    rw_strip
                         inc    a
                         asl    a
                         asl    a
                         asl    a
                         sta    beam_bottom
beam_wait_poll           jsr    raster_line
                         sec
                         sbc    beam_bottom
                         bcs    beam_wait_phase
                         clc
                         adc    #262
beam_wait_phase          anop
; Release in the first half-refresh behind the bottom. The other half is
; reserved for bounded redraw, including IRQs. This is a region wait only:
; a pending generation is never rejected, restarted, or abandoned.
                         cmp    #128
                         bcs    beam_wait_poll
                         rts
beam_bottom              ds     2

; Optional measured exposure bounds. Samples bracket ALL stores in a region,
; including IRQ time and mapping restoration. No simulation runs between them.
; A transaction is scan-safe only if it ends before the beam returns to its TOP.
; The monotonically sampled clock detects refreshes during long drawing as well
; as raster wrap. A late transaction is counted, completed, and never discarded.
beam_trace_begin         lda    ng_profile_enabled
                         bne    beam_trace_start
                         rts
beam_trace_start         jsr    clock_sample
                         lda    clock_time
                         sta    beam_start
                         lda    clock_time+2
                         sta    beam_start+2
                         lda    clock_line
                         sta    beam_start_line
                         rts
beam_trace_end           pha
                         lda    ng_profile_enabled
                         bne    beam_trace_finish
                         pla
                         rts
beam_trace_finish        jsr    clock_sample
                         inc    beam_trace_seq
                         sec
                         lda    clock_time
                         sbc    beam_start
                         sta    beam_duration
                         lda    clock_time+2
                         sbc    beam_start+2
                         sta    beam_duration+2
                         lda    beam_duration+2
                         bne    beam_duration_saturated
                         lda    beam_duration
                         bra    beam_max_check
beam_duration_saturated  lda    #$ffff
beam_max_check           cmp    beam_max_exposure
                         bcc    beam_check_deadline
                         sta    beam_max_exposure
beam_check_deadline      stz    beam_available
                         lda    rw_strip
                         asl    a
                         asl    a
                         asl    a
                         sec
                         sbc    beam_start_line
                         beq    beam_exposed
                         bpl    beam_deadline_ready
                         clc
                         adc    #262
beam_deadline_ready      sta    beam_available
; A wrap during the timestamp sampler can leave us above the region again.
; That is safe only when redraw still finishes before its upcoming top edge.
                         lda    beam_start_line
                         cmp    beam_bottom
                         bcs    beam_deadline_duration
                         lda    beam_bottom
                         sec
                         sbc    #8
                         cmp    beam_start_line
                         bcc    beam_exposed
                         beq    beam_exposed
beam_deadline_duration   anop
                         lda    beam_duration+2
                         bne    beam_exposed
                         lda    beam_duration
                         cmp    beam_available
                         bcc    beam_safe
beam_exposed             inc    beam_exposures
                         ldx    beam_bad_cursor
                         lda    rw_strip
                         sta    beam_bad,x
                         lda    beam_start_line
                         sta    beam_bad+2,x
                         lda    beam_duration
                         sta    beam_bad+4,x
                         lda    beam_available
                         sta    beam_bad+6,x
                         txa
                         clc
                         adc    #8
                         and    #127
                         sta    beam_bad_cursor
beam_safe                inc    beam_transactions
                         lda    clock_line
                         cmp    beam_start_line
                         bcs    beam_no_wrap
                         inc    beam_draw_wraps
beam_no_wrap             ldx    beam_trace_cursor
                         lda    rc_generation
                         sta    beam_trace,x
                         lda    rw_strip
                         sta    beam_trace+2,x
                         lda    beam_start
                         sta    beam_trace+4,x
                         lda    beam_start+2
                         sta    beam_trace+6,x
                         lda    clock_time
                         sta    beam_trace+8,x
                         lda    clock_time+2
                         sta    beam_trace+10,x
                         lda    beam_start_line
                         sta    beam_trace+12,x
                         lda    clock_line
                         sta    beam_trace+14,x
                         txa
                         clc
                         adc    #16
                         and    #$07ff
                         sta    beam_trace_cursor
                         inc    beam_trace_seq
beam_trace_end_done      pla
beam_trace_return        rts
beam_start               ds     4
beam_start_line          ds     2
beam_duration            ds     4
beam_available           ds     2
beam_max_exposure        ds     2
beam_exposures           ds     2
beam_transactions        ds     2
beam_draw_wraps          ds     2
beam_trace_cursor        ds     2
beam_trace_seq           ds     2
beam_trace               ds     2048

; Exact completed PLAY presentation gaps, in physical scanlines. Called only
; after the last store, before publication. Frontend intervals reset the chain.
beam_commit              lda    ng_profile_enabled
                         beq    beam_commit_done
                         lda    sw_enabled
                         bne    beam_commit_play
                         stz    beam_commit_valid
                         rts
beam_commit_play         jsr    clock_sample
                         lda    beam_commit_valid
                         beq    beam_commit_save
                         sec
                         lda    clock_time
                         sbc    beam_commit_time
                         sta    beam_commit_gap
                         lda    clock_time+2
                         sbc    beam_commit_time+2
                         sta    beam_commit_gap+2
; Histogram uses ceiling(gap/262), saturated in the sixteenth bin.
                         ldx    #30
                         lda    beam_commit_gap+2
                         bne    beam_gap_record
                         ldx    #0
                         lda    beam_commit_gap
beam_gap_bucket          cmp    #263
                         bcc    beam_gap_record
                         sec
                         sbc    #262
                         inx
                         inx
                         cpx    #30
                         bcc    beam_gap_bucket
beam_gap_record          inc    beam_gap_hist,x
                         lda    beam_commit_gap+2
                         cmp    beam_commit_max+2
                         bcc    beam_commit_save
                         bne    beam_commit_maximum
                         lda    beam_commit_gap
                         cmp    beam_commit_max
                         bcc    beam_commit_save
beam_commit_maximum      lda    beam_commit_gap
                         sta    beam_commit_max
                         lda    beam_commit_gap+2
                         sta    beam_commit_max+2
beam_commit_save         lda    clock_time
                         sta    beam_commit_time
                         lda    clock_time+2
                         sta    beam_commit_time+2
                         lda    #1
                         sta    beam_commit_valid
beam_commit_done         rts
beam_commit_valid        ds     2
beam_commit_time         ds     4
beam_commit_gap          ds     4
beam_commit_max          ds     4

beam_bad_cursor          ds     2
beam_bad                 ds     128

beam_gap_hist            ds     32
