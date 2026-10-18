; Correctness baseline: one object clipped to one immutable span row.
; Native M=X16, DBR=renderer bank, no DP/tools/E1; A/X/Y/flags clobbered.
; ro_x/y signed screen coords, frame0..30, color low4, attr bit0 multicolor.
; ro_span_row0..199; offset even and within that row, len even2..160.
; Caller iterates current objects in rank3..0, slot0..23, including unchanged.
; Source is original64byte C64 frames; transparent pixels preserve candidate.
; Scalar baseline is intentionally not a throughput claim. Pending optimization
; replaces role extraction with generated parity mask/data after pixel proof.
                    longa  on
                    longi  on
ro_draw             lda    ro_attr
                    and    #1
                    beq    ro_scalar
                    jmp    rm_draw
ro_scalar           lda    ro_frame
                    cmp    #31
                    bcc    ro_frame_valid
                    lda    #1
                    rts
ro_frame_valid      lda    ro_span_row
                    cmp    #200
                    bcc    ro_row_valid
                    lda    #1
                    rts
ro_row_valid        sec
                    sbc    ro_y
                    bmi    ro_empty
                    cmp    #21
                    bcs    ro_empty
                    sta    ro_sprite_row
                    asl    a
                    clc
                    adc    ro_sprite_row
                    sta    ro_source_row
                    lda    ro_frame
                    asl    a
                    asl    a
                    asl    a
                    asl    a
                    asl    a
                    asl    a
                    clc
                    adc    ro_source_row
                    sta    ro_source_row
                    lda    ro_span_row
                    asl    a
                    asl    a
                    asl    a
                    asl    a
                    asl    a
                    sta    ro_temp
                    asl    a
                    asl    a
                    clc
                    adc    ro_temp
                    sta    ro_screen_row
                    lda    ro_span_offset
                    sec
                    sbc    ro_screen_row
                    asl    a
                    sta    ro_left
                    lda    ro_span_length
                    asl    a
                    clc
                    adc    ro_left
                    sta    ro_right
                    lda    ro_x
                    bmi    ro_left_ready
                    cmp    ro_left
                    bcc    ro_left_ready
                    sta    ro_left
ro_left_ready       lda    ro_x
                    clc
                    adc    #24
                    bmi    ro_empty
                    beq    ro_empty
                    cmp    ro_right
                    bcs    ro_right_ready
                    sta    ro_right
ro_right_ready      lda    ro_left
                    cmp    ro_right
                    bcc    ro_pixel_loop
ro_empty            lda    #0
                    rts
ro_pixel_loop       sec
                    sbc    ro_x
                    sta    ro_sprite_x
                    lsr    a
                    lsr    a
                    lsr    a
                    clc
                    adc    ro_source_row
                    tax
                    sep    #$20
                    longa  off
                    lda    >ro_assets,x
                    rep    #$20
                    longa  on
                    and    #$ff
                    sta    ro_bits
                    lda    ro_attr
                    and    #1
                    beq    ro_mono
                    lda    ro_sprite_x
                    and    #6
                    eor    #6
                    tay
                    lda    ro_bits
                    cpy    #0
                    beq    ro_multicolor_role
ro_mc_shift         lsr    a
                    dey
                    bne    ro_mc_shift
ro_multicolor_role  and    #3
                    beq    ro_next_pixel
                    cmp    #2
                    beq    ro_dynamic
                    cmp    #1
                    beq    ro_mc0
                    lda    #7
                    bra    ro_ink
ro_mc0              lda    #11
                    bra    ro_ink
ro_mono             lda    ro_sprite_x
                    and    #7
                    eor    #7
                    tay
                    lda    ro_bits
                    cpy    #0
                    beq    ro_mono_role
ro_mono_shift       lsr    a
                    dey
                    bne    ro_mono_shift
ro_mono_role        and    #1
                    beq    ro_next_pixel
ro_dynamic          lda    ro_color
                    and    #15
ro_ink              sta    ro_color_pixel
                    lda    ro_left
                    lsr    a
                    clc
                    adc    ro_screen_row
                    tax
                    lda    ro_left
                    and    #1
                    bne    ro_odd
                    lda    ro_color_pixel
                    asl    a
                    asl    a
                    asl    a
                    asl    a
                    sta    ro_color_pixel
                    sep    #$20
                    longa  off
                    lda    >rr_candidate,x
                    and    #15
                    ora    ro_color_pixel
                    sta    >rr_candidate,x
                    rep    #$20
                    longa  on
                    bra    ro_next_pixel
ro_odd              sep    #$20
                    longa  off
                    lda    >rr_candidate,x
                    and    #$f0
                    ora    ro_color_pixel
                    sta    >rr_candidate,x
                    rep    #$20
                    longa  on
ro_next_pixel       inc    ro_left
                    lda    ro_left
                    cmp    ro_right
                    bcc    ro_more_pixels
                    lda    #0
                    rts
ro_more_pixels      jmp    ro_pixel_loop
ro_x                ds     2
ro_y                ds     2
ro_frame            ds     2
ro_color            ds     2
ro_attr             ds     2
ro_span_row         ds     2
ro_span_offset      ds     2
ro_span_length      ds     2
ro_sprite_row       ds     2
ro_source_row       ds     2
ro_screen_row       ds     2
ro_temp             ds     2
ro_left             ds     2
ro_right            ds     2
ro_sprite_x         ds     2
ro_bits             ds     2
ro_color_pixel      ds     2
