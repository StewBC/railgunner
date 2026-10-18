; Correctness baseline scene composer: snapshot -> background/object damage ->
; exact spans -> sparse restore -> all current objects in rank/slot order.
; No visible stores or publication. Pending immutable candidate is retained.
; Native M=X16, DBR=renderer bank; A/X/Y/flagsclobbered, noDP/tools/IRQmasking.
; Scalar object kernel and simple bounded loops are not a performance claim.
                          longa on
                          longi on
rs_render                 jsr rb_prepare
                          cmp #0
                          beq rs_background_ready
                          rts
rs_background_ready       jsr rs_mark_objects
                          jsr rco_expand
                          jsr rd_emit
                          cmp #0
                          beq rs_spans_ready
                          rts
rs_spans_ready            jsr rr_restore
                          jsr rs_compose
                          lda #0
                          rts

rs_mark_objects           lda rb_full
                          bne rs_mark_done
                          stz rs_slot
rs_mark_slot              lda rs_slot
                          and #127
                          bne rs_mark_service_done
                          jsr render_service
rs_mark_service_done      ldx rs_slot
                          ldy #0
rs_compare_record         lda >rc_candidate_objects,x
                          cmp >rc_displayed_objects,x
                          bne rs_record_changed
                          inx
                          inx
                          iny
                          iny
                          cpy #16
                          bcc rs_compare_record
                          bra rs_mark_next
rs_record_changed         jsr rs_load_old
                          jsr rs_normalize
                          beq rs_mark_current
                          lda rc_displayed_present
                          cmp #1
                          beq rs_mark_current
                          jsr rs_footprint
rs_mark_current           jsr rs_load_current
                          jsr rs_normalize
                          beq rs_mark_next
                          lda rc_candidate_present
                          cmp #1
                          beq rs_mark_next
                          jsr rs_footprint
rs_mark_next              lda rs_slot
                          clc
                          adc #16
                          sta rs_slot
                          cmp #384
                          bcc rs_mark_slot
rs_mark_done              rts

rs_load_current           ldx rs_slot
                          ldy #0
rs_current_word           lda >rc_candidate_objects,x
                          sta rs_record,y
                          inx
                          inx
                          iny
                          iny
                          cpy #16
                          bcc rs_current_word
                          rts
rs_load_old               ldx rs_slot
                          ldy #0
rs_old_word               lda >rc_displayed_objects,x
                          sta rs_record,y
                          inx
                          inx
                          iny
                          iny
                          cpy #16
                          bcc rs_old_word
                          rts
; Return A=1 for drawable source,0 skip. No visible side effects.
rs_normalize              lda rs_record+14
                          and #2
                          beq rs_skip
                          lda rs_record
                          beq rs_skip
                          cmp #344
                          bcs rs_skip
                          sec
                          sbc #24
                          sta ro_x
                          lda rs_record+2
                          cmp #250
                          bcs rs_skip
                          cmp #30
                          bcc rs_skip
                          sec
                          sbc #50
                          sta ro_y
                          lda rs_record+6
                          sta ro_player_frame
                          lda rs_record+4
                          jsr ro_lookup
                          cmp #$ffff
                          beq rs_skip
                          sta ro_frame
                          lda rs_record+8
                          sta ro_color
                          lda rs_record+10
                          sta ro_attr
                          lda rs_record+12
                          cmp #6
                          bcc rs_kind_known
                          lda #3
                          bra rs_rank_ready
rs_kind_known             asl a
                          tax
                          lda rs_ranks,x
rs_rank_ready             sta rs_object_rank
                          lda #1
                          rts
rs_skip                   lda #0
                          rts
rs_footprint              lda ro_frame
                          asl a
                          asl a
                          asl a
                          asl a
                          sta rs_bound_index
                          lda ro_attr
                          and #1
                          asl a
                          asl a
                          asl a
                          clc
                          adc rs_bound_index
                          tax
                          lda ro_x
                          clc
                          adc ro_bounds,x
                          bpl rs_bound_left
                          lda #0
rs_bound_left             cmp #320
                          bcs rs_footprint_empty
                          lsr a
                          lsr a
                          sta rd_left
                          lda ro_x
                          clc
                          adc ro_bounds+2,x
                          bmi rs_footprint_empty
                          beq rs_footprint_empty
                          cmp #320
                          bcc rs_bound_right
                          lda #320
rs_bound_right            clc
                          adc #3
                          lsr a
                          lsr a
                          sta rd_right
                          lda ro_y
                          clc
                          adc ro_bounds+4,x
                          bpl rs_bound_top
                          lda #0
rs_bound_top              cmp #200
                          bcs rs_footprint_empty
                          sta rd_top
                          lda ro_y
                          clc
                          adc ro_bounds+6,x
                          bmi rs_footprint_empty
                          beq rs_footprint_empty
                          cmp #200
                          bcc rs_bound_bottom
                          lda #200
rs_bound_bottom           sta rd_bottom
                          jsr rd_mark
rs_footprint_empty        rts

rs_compose                stz rs_span_visits
                          stz rs_pixel_jobs
                          lda rc_candidate_present
                          cmp #1
                          bne rs_compose_objects
                          rts
rs_compose_objects        lda #3
                          sta rs_rank
rs_rank_loop              jsr render_service
                          stz rs_slot
; Cheap immutable rawflag/rank prefilter before copying/normalizing8fields.
; Eachdrawable is normalized once, not once per each of four prioritypasses.
rs_object_loop            ldx rs_slot
                          lda >rc_candidate_objects+14,x
                          and #2
                          bne rs_raw_active
                          jmp rs_object_next
rs_raw_active             lda >rc_candidate_objects+12,x
                          cmp #6
                          bcc rs_raw_known_kind
                          lda #3
                          bra rs_raw_rank
rs_raw_known_kind         asl a
                          tax
                          lda rs_ranks,x
rs_raw_rank               cmp rs_rank
                          beq rs_raw_matching_rank
                          jmp rs_object_next
rs_raw_matching_rank      jsr rs_load_current
                          jsr rs_normalize
                          bne rs_active_object
                          jmp rs_object_next
rs_active_object          anop
; Restrict descriptor traversal to the fixed strips intersecting this object's
; clipped21rowcanvas, then reject rows outside before entering scalar pixelloop.
                          lda ro_y
                          bpl rs_first_row
                          lda #0
rs_first_row              lsr a
                          lsr a
                          lsr a
                          asl a
                          tax
                          lda rd_boundary,x
                          sta rs_span
                          cmp #4000
                          bcc rs_start_a
                          sec
                          sbc #4000
rs_start_a                asl a
                          sta rs_descriptor
                          asl a
                          clc
                          adc rs_descriptor
                          sta rs_descriptor
                          lda ro_y
                          clc
                          adc #20
                          cmp #200
                          bcc rs_last_row
                          lda #199
rs_last_row               lsr a
                          lsr a
                          lsr a
                          inc a
                          asl a
                          tax
                          lda rd_boundary,x
                          sta rs_limit
rs_span_loop              lda rs_span
                          and #7
                          bne rs_service_done
                          jsr render_service
rs_service_done           lda rs_span
                          cmp rs_limit
                          bcs rs_object_next
                          cmp #4000
                          bne rs_span_same_bank
                          stz rs_descriptor
rs_span_same_bank         ldx rs_descriptor
                          cmp #4000
                          bcs rs_span_b
                          lda >rd_spans_a,x
                          sta ro_span_offset
                          lda >rd_spans_a+2,x
                          sta ro_span_length
                          lda >rd_spans_a+4,x
                          bra rs_span_ready
rs_span_b                 lda >rd_spans_b,x
                          sta ro_span_offset
                          lda >rd_spans_b+2,x
                          sta ro_span_length
                          lda >rd_spans_b+4,x
rs_span_ready             sta ro_span_row
                          inc rs_span_visits
                          sec
                          sbc ro_y
                          bmi rs_skip_pixel_job
                          cmp #21
                          bcs rs_skip_pixel_job
                          inc rs_pixel_jobs
                          jsr ro_draw
rs_skip_pixel_job         anop
                          inc rs_span
                          lda rs_descriptor
                          clc
                          adc #6
                          sta rs_descriptor
                          bra rs_span_loop
rs_object_next            lda rs_slot
                          clc
                          adc #16
                          sta rs_slot
                          cmp #384
                          bcs rs_rank_next
                          jmp rs_object_loop
rs_rank_next              dec rs_rank
                          bmi rs_compose_done
                          jmp rs_rank_loop
rs_compose_done           rts
rs_ranks                  dc i2'3,2,1,0,0,3'
rs_slot                   ds 2
rs_rank                   ds 2
rs_object_rank            ds 2
rs_span                   ds 2
rs_descriptor             ds 2
rs_record                 ds 16
rs_limit                  ds 2
rs_span_visits            ds 2
rs_pixel_jobs             ds 2
rs_bound_index            ds 2
