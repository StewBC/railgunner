; Production damage/span engine, native M=X=16, DBR=code bank, decimal clear.
; No tools, E1 accesses, allocation, or IRQ masking. A/X/Y and flags clobbered.
; bitmap rows: 10 bytes, low bit = leftmost word. 25 immutable 8-row strips.
; Caller owns serialization: do not call while a generation is being committed.
; rd_mark: clipped half-open WORD rectangle rd_left/right=0..80, top/bottom=0..200.
; Reject malformed bounds before any write; A=1 invalid, otherwise A=0.
; rd_emit: descriptors (offset, byte length, row) in two independent segments;
; global descriptor indices; rd_boundary[0..25] are indices, not byte offsets.
; All code/state is bank-local. Loaded span placement must be validated by caller.
                      longa  on
                      longi  on
rd_clear              ldx    #1998
                      lda    #0
rd_clear_loop         sta    rd_bitmap,x
                      dex
                      dex
                      bpl    rd_clear_loop
                      stz    rd_count
                      stz    rd_words
                      rts
rd_mark               lda    rd_right
                      cmp    #81
                      bcc    rd_mark_right_valid
                      jmp    rd_mark_bad
rd_mark_right_valid   anop
                      lda    rd_bottom
                      cmp    #201
                      bcs    rd_mark_bad
                      lda    rd_top
                      cmp    rd_bottom
                      bcc    rd_mark_yordered
                      beq    rd_mark_yordered
                      bra    rd_mark_bad
rd_mark_yordered      lda    rd_left
                      cmp    rd_right
                      bcc    rd_mark_xvalid
                      beq    rd_mark_empty
                      bra    rd_mark_bad
rd_mark_xvalid        lda    rd_top
                      cmp    rd_bottom
                      beq    rd_mark_empty
                      bra    rd_mark_yvalid
rd_mark_empty         lda    #0
                      rts
rd_mark_bad           lda    #1
                      rts
rd_mark_yvalid        lda    rd_top
                      asl    a
                      sta    rd_temp
                      asl    a
                      asl    a
                      clc
                      adc    rd_temp
                      sta    rd_row_offset
                      lda    rd_top
                      sta    rd_row
; A bounded ten-byte mask row; no repeated per-sprite bit tests.
                      ldx    #0
rd_mask_zero          stz    rd_range_mask,x
                      inx
                      inx
                      cpx    #10
                      bcc    rd_mask_zero
                      lda    rd_left
                      lsr    a
                      lsr    a
                      lsr    a
                      sta    rd_range_first
                      tax
                      lda    rd_right
                      dec    a
                      lsr    a
                      lsr    a
                      lsr    a
                      sta    rd_range_last
; Fill at most ten bytes, then mask the two ends. A one-byte range receives
; both masks. Empty ranges returned before this point, so right-1 is safe.
                      sep    #$20
                      longa  off
                      lda    #$ff
rd_mask_fill          sta    rd_range_mask,x
                      inx
                      cpx    rd_range_last
                      bcc    rd_mask_fill
                      beq    rd_mask_fill
                      rep    #$20
                      longa  on
                      lda    rd_left
                      and    #7
                      asl    a
                      tax
                      lda    rd_left_masks,x
                      ldx    rd_range_first
                      sep    #$20
                      longa  off
                      and    rd_range_mask,x
                      sta    rd_range_mask,x
                      rep    #$20
                      longa  on
                      lda    rd_right
                      and    #7
                      asl    a
                      tax
                      lda    rd_right_masks,x
                      ldx    rd_range_last
                      sep    #$20
                      longa  off
                      and    rd_range_mask,x
                      sta    rd_range_mask,x
                      rep    #$20
                      longa  on
                      jmp    rd_mark_row
rd_mark_row           jsr    render_service
                      ldy    #0
rd_mark_bytes         tya
                      clc
                      adc    rd_row_offset
                      tax
                      lda    rd_bitmap,x
                      ora    rd_range_mask,y
                      sta    rd_bitmap,x
                      iny
                      iny
                      cpy    #10
                      bcc    rd_mark_bytes
                      lda    rd_row_offset
                      clc
                      adc    #10
                      sta    rd_row_offset
                      inc    rd_row
                      lda    rd_row
                      cmp    rd_bottom
                      bcc    rd_mark_row
                      lda    #0
                      rts

rd_emit               ldx    #48
                      lda    #0
rd_emit_zero_meta     sta    rd_strip_words,x
                      dex
                      dex
                      bpl    rd_emit_zero_meta
                      ldx    #48
                      lda    #$ffff
rd_emit_zero_last     sta    rd_strip_last,x
                      dex
                      dex
                      bpl    rd_emit_zero_last
                      lda    #200
                      sta    rd_first_dirty
                      stz    rd_count
                      stz    rd_words
                      stz    rd_row
                      stz    rd_row_offset
                      stz    rd_screen_offset
                      stz    rd_descriptor_offset
                      stz    rd_strip
                      stz    rd_boundary
                      lda    #1
                      sta    rd_bank_a
rd_emit_row           lda    rd_row
                      and    #7
                      bne    rd_emit_check_row
; Empty rows are bounded in eight-row batches; dense rows additionally service
; every eight emitted descriptors, keeping the alternating-span case bounded.
                      jsr    render_service
                      lda    rd_strip
                      asl    a
                      tax
                      lda    rd_count
                      sta    rd_boundary,x
                      inc    rd_strip
rd_emit_check_row     ldx    rd_row_offset
                      lda    rd_bitmap,x
                      ora    rd_bitmap+2,x
                      ora    rd_bitmap+4,x
                      ora    rd_bitmap+6,x
                      ora    rd_bitmap+8,x
                      bne    rd_emit_columns
                      jmp    rd_emit_next_row
rd_emit_columns       stz    rd_column
                      stz    rd_byte_column
                      stz    rd_bits_left
; Cache each bitmap byte once. Empty bytes skip eight clean words; runs cross
; byte boundaries without splitting descriptors. No read past the ten-byte row.
rd_emit_find          lda    rd_bits_left
                      bne    rd_find_cached
                      jsr    rd_load_byte
rd_find_cached        lda    rd_bits
                      bne    rd_find_set
                      lda    rd_column
                      clc
                      adc    rd_bits_left
                      sta    rd_column
                      stz    rd_bits_left
                      cmp    #80
                      bcc    rd_emit_find
                      jmp    rd_emit_next_row
rd_find_set           lda    rd_bits
                      and    #1
                      bne    rd_emit_run
                      lsr    rd_bits
                      dec    rd_bits_left
                      inc    rd_column
                      bra    rd_find_set
rd_emit_run           lda    rd_column
                      sta    rd_run_start
rd_emit_run_next      lda    rd_bits
                      cmp    #$ff
                      bne    rd_run_partial
; All eight cached bits are set: consume the whole byte in constant time.
                      lda    rd_column
                      clc
                      adc    rd_bits_left
                      sta    rd_column
                      stz    rd_bits_left
                      bra    rd_run_boundary
rd_run_partial        lsr    rd_bits
                      dec    rd_bits_left
                      inc    rd_column
                      lda    rd_bits_left
                      beq    rd_run_boundary
                      lda    rd_bits
                      and    #1
                      bne    rd_emit_run_next
                      bra    rd_emit_store
rd_run_boundary       lda    rd_column
                      cmp    #80
                      bcs    rd_emit_store
                      jsr    rd_load_byte
                      lda    rd_bits
                      and    #1
                      bne    rd_emit_run_next
rd_emit_store         lda    rd_count
                      cmp    #8000
                      bcc    rd_emit_capacity_ok
                      jmp    rd_emit_bad
rd_emit_capacity_ok   anop
                      cmp    #4000
                      bne    rd_emit_same_bank
                      stz    rd_descriptor_offset
                      stz    rd_bank_a
rd_emit_same_bank     lda    rd_column
                      sec
                      sbc    rd_run_start
                      clc
                      adc    rd_words
                      sta    rd_words
                      lda    rd_column
                      sec
                      sbc    rd_run_start
                      asl    a
                      sta    rd_length
                      lsr    a
                      sta    rd_temp
                      lda    rd_strip
                      dec    a
                      asl    a
                      tax
                      lda    rd_strip_words,x
                      clc
                      adc    rd_temp
                      sta    rd_strip_words,x
                      lda    rd_row
                      sta    rd_strip_last,x
                      cmp    rd_first_dirty
                      bcs    rd_emit_first_set
                      sta    rd_first_dirty
rd_emit_first_set     lda    rd_run_start
                      asl    a
                      clc
                      adc    rd_screen_offset
                      ldx    rd_descriptor_offset
                      ldy    rd_bank_a
                      beq    rd_emit_b
                      sta    >rd_spans_a,x
                      lda    rd_length
                      sta    >rd_spans_a+2,x
                      lda    rd_row
                      sta    >rd_spans_a+4,x
                      bra    rd_emit_stored
rd_emit_b             sta    >rd_spans_b,x
                      lda    rd_length
                      sta    >rd_spans_b+2,x
                      lda    rd_row
                      sta    >rd_spans_b+4,x
rd_emit_stored        inc    rd_count
                      lda    rd_count
                      and    #7
                      bne    rd_emit_no_service
                      jsr    render_service
rd_emit_no_service    lda    rd_descriptor_offset
                      clc
                      adc    #6
                      sta    rd_descriptor_offset
                      lda    rd_column
                      cmp    #80
                      bcs    rd_emit_next_row
                      jmp    rd_emit_find
rd_emit_next_row      lda    rd_screen_offset
                      clc
                      adc    #160
                      sta    rd_screen_offset
                      lda    rd_row_offset
                      clc
                      adc    #10
                      sta    rd_row_offset
                      inc    rd_row
                      lda    rd_row
                      cmp    #200
                      bcs    rd_emit_done
                      jmp    rd_emit_row
rd_emit_done          lda    rd_count
                      sta    rd_boundary+50
                      lda    #0
                      rts
rd_emit_bad           lda    #1
                      rts
; Load exactly one byte, zero extended, at the current row byte cursor.
rd_load_byte          lda    rd_row_offset
                      clc
                      adc    rd_byte_column
                      tax
                      sep    #$20
                      longa  off
                      lda    rd_bitmap,x
                      rep    #$20
                      longa  on
                      and    #$ff
                      sta    rd_bits
                      lda    #8
                      sta    rd_bits_left
                      inc    rd_byte_column
                      rts
rd_masks              dc     i2'1,2,4,8,16,32,64,128'
rd_left               ds     2
rd_right              ds     2
rd_top                ds     2
rd_bottom             ds     2
rd_count              ds     2
rd_words              ds     2
rd_boundary           ds     52
rd_strip_words        ds     50
rd_strip_last         ds     50
rd_first_dirty        ds     2
rd_bitmap             ds     2000
rd_row                ds     2
rd_column             ds     2
rd_row_offset         ds     2
rd_screen_offset      ds     2
rd_run_start          ds     2
rd_mask               ds     2
rd_length             ds     2
rd_temp               ds     2
rd_descriptor_offset  ds     2
rd_strip              ds     2
rd_bank_a             ds     2
rd_range_mask         ds     10
rd_byte_column        ds     2
rd_bits               ds     2
rd_bits_left          ds     2
rd_range_first        ds     2
rd_range_last         ds     2
rd_left_masks         dc     i2'255,254,252,248,240,224,192,128'
rd_right_masks        dc     i2'255,1,3,7,15,31,63,127'
