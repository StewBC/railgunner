; Ordinary PLAY direct cell plan. Every candidate completes before another is
; prepared. Background therefore needs only changed glyph/color expansion.
; Dirty grid bit0=regenerate,bit1=old drone requires black before current glyph.
 longa on
 longi on
sw_prepare stz rb_full
 stz rb_changed
 stz rd_count
 stz rd_words
 ldx #998
sd_clear stz sd_cells,x
 dex
 dex
 bpl sd_clear
 ldx #46
sd_clear_objects stz sw_selected,x
 stz sw_object_ranks,x
 dex
 dex
 bpl sd_clear_objects
; Fast unchanged pair comparisons. Cold changed halves call the glyph expander.
 ldx #0
 ldy #64
sd_glyph_pair lda >rc_candidate_glyphs,x
 eor >rc_displayed_glyphs,x
 sta sd_diff
 lda >rc_candidate_colors,x
 eor >rc_displayed_colors,x
 ora sd_diff
 beq sd_glyph_next
 sta sd_diff
 phx
 phy
 stx sd_cell
 and #$ff
 beq sd_glyph_high
 jsr sd_change_glyph
sd_glyph_high inc sd_cell
 lda sd_diff
 and #$ff00
 beq sd_glyph_restore
 jsr sd_change_glyph
sd_glyph_restore ply
 plx
sd_glyph_next inx
 inx
 dey
 bne sd_glyph_continue
 jsr render_service
 ldy #64
sd_glyph_continue cpx #1000
 bcc sd_glyph_pair
; Old objects contribute erasure, including stationary objects.
 stz sw_slot
sd_old_loop lda sw_slot
 and #127
 bne sd_old_loop_ready
 jsr render_service
sd_old_loop_ready lda sw_slot
 sta rs_slot
 jsr rs_load_old
 jsr rs_normalize
 beq sd_old_next
 jsr sw_bounds
 beq sd_old_next
 lda #1
 sta sd_mark_flags
 lda rs_record+12
 cmp #1
 bcc sd_old_mark
 cmp #4
 bcs sd_old_mark
 lda #3
 sta sd_mark_flags
sd_old_mark jsr sd_mark
sd_old_next lda sw_slot
 clc
 adc #16
 sta sw_slot
 cmp #384
 bcc sd_old_loop
; Cache all visible current objects once; flag arrays are reset above.
 stz sw_slot
sd_current_loop lda sw_slot
 and #127
 bne sd_current_loop_ready
 jsr render_service
sd_current_loop_ready lda sw_slot
 sta rs_slot
 jsr rs_load_current
 jsr rs_normalize
 beq sd_current_next
 jsr sw_bounds
 beq sd_current_next
 lda #1
 sta sd_mark_flags
 jsr sd_mark
 lda sw_slot
 lsr a
 lsr a
 lsr a
 tax
 lda #1
 sta sw_selected,x
 lda rs_object_rank
 sta sw_object_ranks,x
 lda rd_top
 lsr a
 lsr a
 lsr a
 sta sd_first_strip,x
 lda rd_bottom
 lsr a
 lsr a
 lsr a
 sta sd_stop_strip,x
 lda sw_slot
 jsr sw_cache_offset
 ldy #0
sd_cache_word lda ro_x,y
 sta sw_objects,x
 inx
 inx
 iny
 iny
 cpy #10
 bcc sd_cache_word
sd_current_next lda sw_slot
 clc
 adc #16
 sta sw_slot
 cmp #384
 bcc sd_current_loop
 jsr sd_plan_cells
 jsr sd_plan_sprites
 lda #0
 rts
sd_change_glyph ldx sd_cell
 sep #$20
 longa off
 lda #1
 sta sd_cells,x
 rep #$20
 longa on
 lda sd_cell
 sta rg_cell
 jsr rg_expand
 inc rb_changed
; Changed glyph batches remain bounded even when every pair differs.
 lda rb_changed
 and #7
 bne sd_change_done
 jsr render_service
sd_change_done rts
; Mark cell-expanded WORD rectangle supplied by the existing bounds helper.
sd_mark lda rd_top
 lsr a
 lsr a
 lsr a
 asl a
 asl a
 asl a
 sta sd_temp
 asl a
 asl a
 clc
 adc sd_temp
 sta sd_row_cell
 lda rd_left
 lsr a
 clc
 adc sd_row_cell
 sta sd_row_cell
 lda rd_right
 sec
 sbc rd_left
 lsr a
 sta sd_columns
 lda rd_bottom
 sec
 sbc rd_top
 lsr a
 lsr a
 lsr a
 sta sd_rows
sd_mark_row ldx sd_row_cell
 ldy sd_columns
 sep #$20
 longa off
sd_mark_column lda sd_cells,x
 ora sd_mark_flags
 sta sd_cells,x
 inx
 dey
 bne sd_mark_column
 rep #$20
 longa on
 lda sd_row_cell
 clc
 adc #40
 sta sd_row_cell
 dec sd_rows
 bne sd_mark_row
 rts
; Single grid scan; immutable jobs use low two aligned-address bits as flags.
sd_plan_cells stz sw_cell_job_end
 stz sd_cell
 stz sd_strip
 stz sd_address
sd_cell_strip jsr render_service
 stz sd_dirty_batch
 lda sd_strip
 asl a
 tax
 lda sw_cell_job_end
 sta sw_cell_start,x
 stz sd_column
sd_cell_scan ldx sd_cell
 sep #$20
 longa off
 lda sd_cells,x
 rep #$20
 longa on
 and #3
 beq sd_cell_next
 sta sd_flags
 jsr sd_classify
 ora sd_address
 ldx sw_cell_job_end
 sta sw_cell_jobs,x
 inc sw_cell_job_end
 inc sw_cell_job_end
 inc rd_count
 lda rd_words
 clc
 adc #16
 sta rd_words
 inc sd_dirty_batch
 lda sd_dirty_batch
 cmp #8
 bcc sd_cell_next
 jsr render_service
 stz sd_dirty_batch
sd_cell_next inc sd_cell
 lda sd_address
 clc
 adc #4
 sta sd_address
 inc sd_column
 lda sd_column
 cmp #40
 bcc sd_cell_scan
 lda sd_address
 clc
 adc #1120
 sta sd_address
 inc sd_strip
 lda sd_strip
 cmp #25
 bcs sd_cells_complete
 jmp sd_cell_strip
sd_cells_complete anop
 lda sw_cell_job_end
 sta sw_cell_start+50
 rts
sd_classify lda sd_strip
 bne sd_classify_play
 lda #2
 rts
sd_classify_play stz sd_ink
 lda #8
 sta sd_rows
 ldx sd_address
sd_ink_row lda >rr_background,x
 ora >rr_background+2,x
 ora sd_ink
 sta sd_ink
 txa
 clc
 adc #160
 tax
 dec sd_rows
 bne sd_ink_row
 lda sd_ink
 bne sd_ink_present
 lda #1
 rts
sd_ink_present lda sd_flags
 lsr a
 and #1
 ora #2
 rts
; Count direct strip intersections, prefix-sum, then fill stable rank/slot order.
sd_plan_sprites ldx #48
sd_counts_zero stz sd_counts,x
 dex
 dex
 bpl sd_counts_zero
 stz sw_slot
sd_count_object lda sw_slot
 lsr a
 lsr a
 lsr a
 tax
 lda sw_selected,x
 beq sd_count_next
 lda sd_stop_strip,x
 sta sd_stop
 lda sd_first_strip,x
 asl a
 tax
sd_count_strip inc sd_counts,x
 inx
 inx
 txa
 lsr a
 cmp sd_stop
 bcc sd_count_strip
sd_count_next lda sw_slot
 clc
 adc #16
 sta sw_slot
 cmp #384
 bcc sd_count_object
 stz sw_job_end
 ldx #0
sd_prefix lda sw_job_end
 sta sw_job_start,x
 sta sd_fill,x
 lda sd_counts,x
 asl a
 clc
 adc sw_job_end
 sta sw_job_end
 inx
 inx
 cpx #50
 bcc sd_prefix
 lda sw_job_end
 sta sw_job_start+50
 lda #3
 sta sw_rank
sd_rank_loop stz sw_slot
sd_fill_object lda sw_slot
 and #127
 bne sd_fill_object_ready
 jsr render_service
sd_fill_object_ready lda sw_slot
 lsr a
 lsr a
 lsr a
 tax
 lda sw_selected,x
 bne sd_fill_valid
 jmp sd_fill_next
sd_fill_valid anop
 lda sw_object_ranks,x
 cmp sw_rank
 beq sd_fill_rank
 jmp sd_fill_next
sd_fill_rank anop
 lda sd_first_strip,x
 sta sd_strip
 lda sd_stop_strip,x
 sta sd_stop
 lda sw_slot
 jsr sw_cache_offset
 stx sd_object_offset
 lda sw_objects+2,x
 sta sd_object_y
 lda sw_objects+4,x
 sta ro_frame
 lda sw_objects+8,x
 sta ro_attr
 jsr sw_art_index
 lda ro_bounds+4,x
 sta sd_source_first
 lda ro_bounds+6,x
 sta sd_source_stop
sd_fill_strip lda sd_strip
 asl a
 tax
 lda sd_fill,x
 tay
 inc sd_fill,x
 inc sd_fill,x
 lda sd_object_offset
 sta sw_jobs,y
 lda sd_strip
 asl a
 asl a
 asl a
 sec
 sbc sd_object_y
 bpl sd_source_nonnegative
 lda #0
sd_source_nonnegative cmp sd_source_first
 bcs sd_first_ready
 lda sd_source_first
sd_first_ready sta sw_job_firsts,y
 lda sd_strip
 inc a
 asl a
 asl a
 asl a
 sec
 sbc sd_object_y
 cmp sd_source_stop
 bcc sd_stop_ready
 lda sd_source_stop
sd_stop_ready sta sw_job_stops,y
 inc sd_strip
 lda sd_strip
 cmp sd_stop
 bcc sd_fill_strip
sd_fill_next lda sw_slot
 clc
 adc #16
 sta sw_slot
 cmp #384
 bcs sd_rank_done
 jmp sd_fill_object
sd_rank_done dec sw_rank
 bmi sd_sprites_done
 jmp sd_rank_loop
sd_sprites_done rts
sw_cache_offset lsr a
 lsr a
 lsr a
 sta sd_temp
 asl a
 asl a
 clc
 adc sd_temp
 tax
 rts
sw_objects ds 240
sw_selected ds 48
sw_object_ranks ds 48
sw_job_start ds 52
sw_jobs ds 192
sw_job_firsts ds 192
sw_job_stops ds 192
sw_job_end ds 2
sw_cell_start ds 52
sw_cell_jobs ds 2000
sw_cell_job_end ds 2
sw_slot ds 2
sd_cells ds 1000
sd_first_strip ds 48
sd_stop_strip ds 48
sd_counts ds 50
sd_fill ds 50
sd_diff ds 2
sd_cell ds 2
sd_dirty_batch ds 2
sd_flags ds 2
sd_mark_flags ds 2
sd_row_cell ds 2
sd_columns ds 2
sd_column ds 2
sd_rows ds 2
sd_temp ds 2
sd_strip ds 2
sd_stop ds 2
sd_address ds 2
sd_ink ds 2
sd_object_offset ds 2
sd_object_y ds 2
sd_source_first ds 2
sd_source_stop ds 2

sw_bounds jsr sw_art_index
 lda ro_bounds,x
 cmp ro_bounds+2,x
 bcs sw_bound_empty
 lda ro_bounds+4,x
 cmp ro_bounds+6,x
 bcs sw_bound_empty
 lda ro_x
 clc
 adc ro_bounds+2,x
 bmi sw_bound_empty
 beq sw_bound_empty
 cmp #320
 bcc sw_bound_right
 lda #320
sw_bound_right clc
 adc #7
 and #$fff8
 lsr a
 lsr a
 sta rd_right
 lda ro_x
 clc
 adc ro_bounds,x
 bpl sw_bound_left
 lda #0
sw_bound_left cmp #320
 bcs sw_bound_empty
 and #$fff8
 lsr a
 lsr a
 sta rd_left
 lda ro_y
 clc
 adc ro_bounds+6,x
 bmi sw_bound_empty
 cmp #9
 bcc sw_bound_empty
 cmp #200
 bcc sw_bound_bottom
 lda #200
sw_bound_bottom clc
 adc #7
 and #$fff8
 sta rd_bottom
 lda ro_y
 clc
 adc ro_bounds+4,x
 cmp #8
 bpl sw_bound_top
 lda #8
sw_bound_top cmp #200
 bcs sw_bound_empty
 and #$fff8
 sta rd_top
 lda #1
 rts
sw_bound_empty lda #0
 rts

sw_art_index lda ro_frame
 asl a
 asl a
 asl a
 asl a
 sta sw_bound_index
 lda ro_attr
 and #1
 asl a
 asl a
 asl a
 clc
 adc sw_bound_index
 tax
 rts
sw_bound_index ds 2
