; Compiled original-art sprite dispatcher. Foreground M=X16, DBR renderer.
; ro_x/y screen coords; ns_first/stop are sprite-local inclusive/exclusive rows.
; Fast entry requires whole object x0..296,y8..179; vertical row variants
; clamp source rows; horizontal edges use bounded byte-role masks. No stack mapping outside generated call.
 longa on
 longi on
ns_draw php
 cld
 lda ro_frame
 cmp #31
 bcs ns_bad
 lda ns_first
 cmp ns_stop
 bcs ns_empty
 lda ns_stop
 cmp #22
 bcs ns_bad
 lda ro_x
 bmi ns_edge
 cmp #297
 bcs ns_edge
 lda ro_y
 cmp #8
 bcc ns_vertical
 cmp #180
 bcs ns_vertical
ns_compiled_prepare lda ro_attr
 and #1
 asl a
 sta ns_variant
 lda ro_x
 and #1
 ora ns_variant
 sta ns_variant
 lda ro_y
 asl a
 asl a
 asl a
 asl a
 asl a
 sta ns_address
 asl a
 asl a
 clc
 adc ns_address
 clc
 adc #$2000
 sta ns_address
 lda ro_x
 lsr a
 clc
 adc ns_address
 sta ns_address
 jsr ns_prepare_inks
 jsr ns_call_frame
ns_empty lda #0
 plp
 rts
ns_bad lda #1
 plp
 rts
ns_edge jsr ns_edge_draw
 plp
 rts
ns_vertical lda ro_y
 bmi ns_vertical_negative
 cmp #200
 bcc ns_vertical_visible
 jmp ns_empty
ns_vertical_negative cmp #$ffec
 bcs ns_vertical_visible
 jmp ns_empty
ns_vertical_visible lda #8
 sec
 sbc ro_y
 bmi ns_vertical_first
 cmp ns_first
 bcc ns_vertical_first
 sta ns_first
ns_vertical_first lda #200
 sec
 sbc ro_y
 cmp ns_stop
 bcs ns_vertical_stop
 sta ns_stop
ns_vertical_stop lda ns_first
 cmp ns_stop
 bcc ns_vertical_ready
 jmp ns_empty
ns_vertical_ready jmp ns_compiled_prepare
; Expand all16 nibble masks before entering the moved-stack interval.
ns_prepare_inks lda ro_color
 and #15
 cmp ns_ink_color
 beq ns_inks_ready
 sta ns_ink_color
 asl a
 asl a
 asl a
 asl a
 ora ns_ink_color
 sta ns_ink_value
 xba
 ora ns_ink_value
 sta ns_ink_value
 ldx #30
ns_ink_loop lda ns_ink_value
 and ns_nibble_masks,x
 sta >ns_inks,x
 dex
 dex
 bpl ns_ink_loop
ns_inks_ready rts
ns_nibble_masks dc i2'$0000,$000f,$00f0,$00ff,$0f00,$0f0f,$0ff0,$0fff'
 dc i2'$f000,$f00f,$f0f0,$f0ff,$ff00,$ff0f,$fff0,$ffff'
ns_address ENTRY
 ds 2
ns_first ENTRY
 ds 2
ns_stop ENTRY
 ds 2
ns_variant ENTRY
 ds 2
ns_dispatch ENTRY
 ds 2
ns_inks ENTRY
 ds 32
ns_ink_color dc i2'$ffff'
ns_ink_value ds 2
ns_ink_mask ds 2

; Bounded clipped scalar fallback: explicit bank01 accesses, normal stack.
ns_edge_draw php
 sei
 cld
 rep #$30
 longa on
 longi on
 sep #$20
 longa off
 lda >$e0c035
 sta nse_shadow
 and #$f7
 sta >$e0c035
 rep #$20
 longa on
 lda ns_first
 sta nse_row_index
nse_row_loop lda nse_row_index
 cmp ns_stop
 bcs nse_edge_done
 clc
 adc ro_y
 bmi nse_next_row
 cmp #8
 bcc nse_next_row
 cmp #200
 bcs nse_next_row
 sta nse_span_row
 asl a
 asl a
 asl a
 asl a
 asl a
 sta nse_span_offset
 asl a
 asl a
 clc
 adc nse_span_offset
 sta nse_span_offset
 lda #160
 sta nse_span_length
 jsr nsm_draw
nse_next_row inc nse_row_index
 bra nse_row_loop
nse_edge_done sep #$20
 longa off
 lda nse_shadow
 sta >$e0c035
 rep #$20
 longa on
 plp
 lda #0
 rts
nse_row_index ds 2
nse_shadow ds 1
nse_span_row ds 2
nse_span_offset ds 2
nse_span_length ds 2

; Bounded byte-role horizontal edge kernel. At most13bytes/row,21rows;
; full canvas/strip intersection computed before any bank01 read or write.
nsm_draw                   lda ro_frame
                          cmp #31
                          bcc nsm_frame_ok
                          lda #1
                          rts
nsm_frame_ok               lda nse_span_row
                          cmp #200
                          bcc nsm_row_ok
                          lda #1
                          rts
nsm_row_ok                 sec
                          sbc ro_y
                          bpl nsm_skip_far_0
                          jmp nsm_empty_far
nsm_skip_far_0 anop
                          cmp #21
                          bcc nsm_skip_far_1
                          jmp nsm_empty_far
nsm_skip_far_1 anop
                          sta nsm_row
                          asl a
                          asl a
                          asl a
                          sta nsm_temp
                          asl a
                          asl a
                          clc
                          adc nsm_temp
                          sec
                          sbc nsm_row
                          sta nsm_source
                          stz nsm_bank
                          lda ro_frame
                          cmp #15
                          bcc nsm_frame_a
                          sec
                          sbc #15
                          inc nsm_bank
nsm_frame_a                asl a
                          tax
                          lda nsm_frame_offsets,x
                          clc
                          adc nsm_source
                          sta nsm_source
                          lda ro_x
                          and #1
                          beq nsm_even
                          lda nsm_source
                          clc
                          adc #819
                          sta nsm_source
nsm_even                   lda nse_span_row
                          asl a
                          asl a
                          asl a
                          asl a
                          asl a
                          sta nsm_temp
                          asl a
                          asl a
                          clc
                          adc nsm_temp
                          sta nsm_screen_row
                          lda nse_span_offset
                          sec
                          sbc nsm_screen_row
                          sta nsm_left
                          clc
                          adc nse_span_length
                          sta nsm_right
                          lda ro_x
                          cmp #$8000
                          ror a
                          sta nsm_base
                          bmi nsm_left_ready
                          cmp nsm_left
                          bcc nsm_left_ready
                          sta nsm_left
nsm_left_ready             lda nsm_base
                          clc
                          adc #13
                          bpl nsm_skip_far_2
                          jmp nsm_empty_far
nsm_skip_far_2 anop
                          bne nsm_skip_far_3
                          jmp nsm_empty_far
nsm_skip_far_3 anop
                          cmp nsm_right
                          bcs nsm_right_ready
                          sta nsm_right
nsm_right_ready            lda nsm_left
                          cmp nsm_right
                          bcc nsm_intersection
nsm_empty_far              lda #0
                          rts
nsm_intersection           clc
                          adc nsm_screen_row
                          sta nsm_dest
                          lda nsm_left
                          sec
                          sbc nsm_base
                          sta nsm_temp
                          asl a
                          clc
                          adc nsm_temp
                          adc nsm_source
                          sta nsm_source
                          lda ro_color
                          and #15
                          sta nsm_ink
                          asl a
                          asl a
                          asl a
                          asl a
                          ora nsm_ink
                          sta nsm_ink
                          stz nsm_dynamic
nsm_byte_loop ldx nsm_source
 lda ro_attr
 and #1
 beq nsm_mono_source
 lda nsm_bank
 bne nsm_load_b
 lda >ro_parity_0,x
 sta nsm_pair
 sep #$20
 longa off
 lda >ro_parity_0+2,x
 bra nsm_loaded
nsm_load_b longa on
 lda >ro_parity_1,x
 sta nsm_pair
 sep #$20
 longa off
 lda >ro_parity_1+2,x
 bra nsm_loaded
nsm_mono_source longa on
 lda nsm_bank
 bne nsm_mono_b
 lda >ns_mono0,x
 sta nsm_pair
 sep #$20
 longa off
 lda >ns_mono0+2,x
 bra nsm_loaded
nsm_mono_b longa on
 lda >ns_mono1,x
 sta nsm_pair
 sep #$20
 longa off
 lda >ns_mono1+2,x
nsm_loaded                 and nsm_ink
                          sta nsm_dynamic
                          rep #$20
                          longa on
                          lda nsm_pair
                          xba
                          and #$ff
                          ora nsm_dynamic
                          sta nsm_result
                          lda nsm_pair
                          and #$ff
                          cmp #$ff
                          beq nsm_next_byte
                          ldx nsm_dest
                          sep #$20
                          longa off
                          lda >$012000,x
                          and nsm_pair
                          ora nsm_result
                          sta >$012000,x
                          rep #$20
                          longa on
nsm_next_byte             inc nsm_dest
                          lda nsm_source
                          clc
                          adc #3
                          sta nsm_source
                          inc nsm_left
                          lda nsm_left
                          cmp nsm_right
                          bcs nsm_bytes_done
                          jmp nsm_byte_loop
nsm_bytes_done           anop
                          lda #0
                          rts
nsm_frame_offsets          dc i2'0,1638,3276,4914,6552,8190,9828,11466,13104,14742,16380,18018,19656,21294,22932,24570'
nsm_row                    ds 2
nsm_temp                   ds 2
nsm_source                 ds 2
nsm_bank                   ds 2
nsm_screen_row             ds 2
nsm_left                   ds 2
nsm_right                  ds 2
nsm_base                   ds 2
nsm_dest                   ds 2
nsm_ink                    ds 2
nsm_pair                   ds 2
nsm_dynamic                ds 2
nsm_result                 ds 2
