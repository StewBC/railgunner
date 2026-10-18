; Packed multicolor parity consumer, oneobject clippedtoone spanrow.
; ro_* ABI sharedwithscalar; frame0..30, attrbit0=1. NativeM=X16,DBRrenderer.
; Each source token: preserve8,fixed8,dynamicrole8. Combine color*17 with role;
; clips byte range to exact span, leadingoddpixel token preserves othernibble.
; Two bank-local mask segments split atframe15; matching loaded relocations.
; No E1,tools,DP; A/X/Y/flagsclobbered. Mono continues original bitplane kernel.
                  longa  on
                  longi  on
rm_draw           lda    ro_frame
                  cmp    #31
                  bcc    rm_frame_ok
                  lda    #1
                  rts
rm_frame_ok       lda    ro_span_row
                  cmp    #200
                  bcc    rm_row_ok
                  lda    #1
                  rts
rm_row_ok         sec
                  sbc    ro_y
                  bpl    rm_skip_far_0
                  jmp    rm_empty_far
rm_skip_far_0     anop
                  cmp    #21
                  bcc    rm_skip_far_1
                  jmp    rm_empty_far
rm_skip_far_1     anop
                  sta    rm_row
                  asl    a
                  asl    a
                  asl    a
                  sta    rm_temp
                  asl    a
                  asl    a
                  clc
                  adc    rm_temp
                  sec
                  sbc    rm_row
                  sta    rm_source
                  stz    rm_bank
                  lda    ro_frame
                  cmp    #15
                  bcc    rm_frame_a
                  sec
                  sbc    #15
                  inc    rm_bank
rm_frame_a        asl    a
                  tax
                  lda    rm_frame_offsets,x
                  clc
                  adc    rm_source
                  sta    rm_source
                  lda    ro_x
                  and    #1
                  beq    rm_even
                  lda    rm_source
                  clc
                  adc    #819
                  sta    rm_source
rm_even           lda    ro_span_row
                  asl    a
                  asl    a
                  asl    a
                  asl    a
                  asl    a
                  sta    rm_temp
                  asl    a
                  asl    a
                  clc
                  adc    rm_temp
                  sta    rm_screen_row
                  lda    ro_span_offset
                  sec
                  sbc    rm_screen_row
                  sta    rm_left
                  clc
                  adc    ro_span_length
                  sta    rm_right
                  lda    ro_x
                  cmp    #$8000
                  ror    a
                  sta    rm_base
                  bmi    rm_left_ready
                  cmp    rm_left
                  bcc    rm_left_ready
                  sta    rm_left
rm_left_ready     lda    rm_base
                  clc
                  adc    #13
                  bpl    rm_skip_far_2
                  jmp    rm_empty_far
rm_skip_far_2     anop
                  bne    rm_skip_far_3
                  jmp    rm_empty_far
rm_skip_far_3     anop
                  cmp    rm_right
                  bcs    rm_right_ready
                  sta    rm_right
rm_right_ready    lda    rm_left
                  cmp    rm_right
                  bcc    rm_intersection
rm_empty_far      lda    #0
                  rts
rm_intersection   clc
                  adc    rm_screen_row
                  sta    rm_dest
                  lda    rm_left
                  sec
                  sbc    rm_base
                  sta    rm_temp
                  asl    a
                  clc
                  adc    rm_temp
                  adc    rm_source
                  sta    rm_source
                  lda    ro_color
                  and    #15
                  sta    rm_ink
                  asl    a
                  asl    a
                  asl    a
                  asl    a
                  ora    rm_ink
                  sta    rm_ink
                  stz    rm_dynamic
rm_byte_loop      ldx    rm_source
                  lda    rm_bank
                  bne    rm_load_b
                  lda    >ro_parity_0,x
                  sta    rm_pair
                  sep    #$20
                  longa  off
                  lda    >ro_parity_0+2,x
                  bra    rm_loaded
rm_load_b         lda    >ro_parity_1,x
                  sta    rm_pair
                  sep    #$20
                  longa  off
                  lda    >ro_parity_1+2,x
rm_loaded         and    rm_ink
                  sta    rm_dynamic
                  rep    #$20
                  longa  on
                  lda    rm_pair
                  xba
                  and    #$ff
                  ora    rm_dynamic
                  sta    rm_result
                  ldx    rm_dest
                  sep    #$20
                  longa  off
                  lda    >rr_candidate,x
                  and    rm_pair
                  ora    rm_result
                  sta    >rr_candidate,x
                  rep    #$20
                  longa  on
                  inc    rm_dest
                  lda    rm_source
                  clc
                  adc    #3
                  sta    rm_source
                  inc    rm_left
                  lda    rm_left
                  cmp    rm_right
                  bcc    rm_byte_loop
                  lda    #0
                  rts
rm_frame_offsets  dc     i2'0,1638,3276,4914,6552,8190,9828,11466,13104,14742,16380,18018,19656,21294,22932,24570'
rm_row            ds     2
rm_temp           ds     2
rm_source         ds     2
rm_bank           ds     2
rm_screen_row     ds     2
rm_left           ds     2
rm_right          ds     2
rm_base           ds     2
rm_dest           ds     2
rm_ink            ds     2
rm_pair           ds     2
rm_dynamic        ds     2
rm_result         ds     2
