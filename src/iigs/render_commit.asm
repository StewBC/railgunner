; Descriptor-driven production copy kernel. No scheduling/waits/tools/callbacks.
; Native M=X16, DBR=renderer bank, DP untouched; A/X/Y/flags clobbered.
; rw_mode=2 is approved blank-transition path (checks C029 bit7 is clear).
; rw_mode=1 requires whole-generation controller rw_admitted=1; caller
; must already have excluded IRQs and proved entire immutable wave deadline.
; rw_mode=3 calibration requires full equality proof plus IRQ exclusion.
; Mode1 may only be reached through the complete generation controller.
; rw_strip0..24, immutable trusted rd_emit list. A=0 copied,1 rejected no writes.
; Counters accumulate all copied words/spans for diagnostic whole blank rebuild.
                          longa on
                          longi on
rw_copy_strip             lda rw_strip
                          cmp #25
                          bcc rw_strip_valid
                          jmp rw_reject
rw_strip_valid            lda rw_mode
                          cmp #1
                          beq rw_ordinary
                          cmp #2
                          beq rw_blank
                          cmp #3
                          bne rw_reject
                          lda rw_equal_proof
                          cmp #1
                          bne rw_reject
                          bra rw_require_irq
rw_ordinary               lda rw_admitted
                          cmp #1
                          bne rw_reject
rw_require_irq            php
                          sep #$20
                          longa off
                          pla
                          and #4
                          rep #$20
                          longa on
                          and #$ff
                          bne rw_permitted
                          bra rw_reject
rw_blank                  sep #$20
                          longa off
                          lda >$e0c029
                          and #$80
                          rep #$20
                          longa on
                          and #$ff
                          bne rw_reject
rw_permitted              anop
                          lda rw_strip
                          asl a
                          tax
                          lda rd_boundary,x
                          sta rw_index
                          lda rd_boundary+2,x
                          sta rw_limit
                          cmp #8001
                          bcs rw_reject
                          cmp rw_index
                          bcc rw_reject
                          lda rw_limit
                          sec
                          sbc rw_index
                          clc
                          adc rw_spans
                          sta rw_spans
                          lda rd_strip_words,x
                          clc
                          adc rw_words
                          sta rw_words
                          lda rw_index
                          cmp #4000
                          bcc rw_start_a
                          sec
                          sbc #4000
rw_start_a                asl a
                          sta rw_temp
                          asl a
                          clc
                          adc rw_temp
                          sta rw_descriptor
                          bra rw_next
rw_reject                 lda #1
                          rts
rw_next                   lda rw_index
                          cmp rw_limit
                          bcc rw_load
                          lda #0
                          rts
rw_load                   cmp #4000
                          bne rw_same_bank
                          stz rw_descriptor
rw_same_bank              ldx rw_descriptor
                          cmp #4000
                          bcs rw_load_b
                          lda >rd_spans_a,x
                          sta rw_offset
                          lda >rd_spans_a+2,x
                          bra rw_loaded
rw_load_b                 lda >rd_spans_b,x
                          sta rw_offset
                          lda >rd_spans_b+2,x
rw_loaded                 cmp #8
                          beq rw_four_words
                          tax
                          lda rw_jump_table,x
                          dec a
                          pha
                          ldx rw_offset
                          rts
rw_four_words             ldx rw_offset
                          lda >rr_candidate+6,x
                          sta >$e12000+6,x
                          lda >rr_candidate+4,x
                          sta >$e12000+4,x
                          lda >rr_candidate+2,x
                          sta >$e12000+2,x
                          lda >rr_candidate,x
                          sta >$e12000,x
rw_span_done              inc rw_index
                          lda rw_descriptor
                          clc
                          adc #6
                          sta rw_descriptor
                          bra rw_next
; Immutable emitted span length is1..80words; select exact unrolled suffix.
; Reverse order within released row is beam-safe, no extra envelope writes.
rw_jump_table             dc i2'0'
                          dc a2'rw_words_1'
                          dc a2'rw_words_2'
                          dc a2'rw_words_3'
                          dc a2'rw_words_4'
                          dc a2'rw_words_5'
                          dc a2'rw_words_6'
                          dc a2'rw_words_7'
                          dc a2'rw_words_8'
                          dc a2'rw_words_9'
                          dc a2'rw_words_10'
                          dc a2'rw_words_11'
                          dc a2'rw_words_12'
                          dc a2'rw_words_13'
                          dc a2'rw_words_14'
                          dc a2'rw_words_15'
                          dc a2'rw_words_16'
                          dc a2'rw_words_17'
                          dc a2'rw_words_18'
                          dc a2'rw_words_19'
                          dc a2'rw_words_20'
                          dc a2'rw_words_21'
                          dc a2'rw_words_22'
                          dc a2'rw_words_23'
                          dc a2'rw_words_24'
                          dc a2'rw_words_25'
                          dc a2'rw_words_26'
                          dc a2'rw_words_27'
                          dc a2'rw_words_28'
                          dc a2'rw_words_29'
                          dc a2'rw_words_30'
                          dc a2'rw_words_31'
                          dc a2'rw_words_32'
                          dc a2'rw_words_33'
                          dc a2'rw_words_34'
                          dc a2'rw_words_35'
                          dc a2'rw_words_36'
                          dc a2'rw_words_37'
                          dc a2'rw_words_38'
                          dc a2'rw_words_39'
                          dc a2'rw_words_40'
                          dc a2'rw_words_41'
                          dc a2'rw_words_42'
                          dc a2'rw_words_43'
                          dc a2'rw_words_44'
                          dc a2'rw_words_45'
                          dc a2'rw_words_46'
                          dc a2'rw_words_47'
                          dc a2'rw_words_48'
                          dc a2'rw_words_49'
                          dc a2'rw_words_50'
                          dc a2'rw_words_51'
                          dc a2'rw_words_52'
                          dc a2'rw_words_53'
                          dc a2'rw_words_54'
                          dc a2'rw_words_55'
                          dc a2'rw_words_56'
                          dc a2'rw_words_57'
                          dc a2'rw_words_58'
                          dc a2'rw_words_59'
                          dc a2'rw_words_60'
                          dc a2'rw_words_61'
                          dc a2'rw_words_62'
                          dc a2'rw_words_63'
                          dc a2'rw_words_64'
                          dc a2'rw_words_65'
                          dc a2'rw_words_66'
                          dc a2'rw_words_67'
                          dc a2'rw_words_68'
                          dc a2'rw_words_69'
                          dc a2'rw_words_70'
                          dc a2'rw_words_71'
                          dc a2'rw_words_72'
                          dc a2'rw_words_73'
                          dc a2'rw_words_74'
                          dc a2'rw_words_75'
                          dc a2'rw_words_76'
                          dc a2'rw_words_77'
                          dc a2'rw_words_78'
                          dc a2'rw_words_79'
                          dc a2'rw_words_80'
rw_words_80               lda >rr_candidate+158,x
                          sta >$e12000+158,x
rw_words_79               lda >rr_candidate+156,x
                          sta >$e12000+156,x
rw_words_78               lda >rr_candidate+154,x
                          sta >$e12000+154,x
rw_words_77               lda >rr_candidate+152,x
                          sta >$e12000+152,x
rw_words_76               lda >rr_candidate+150,x
                          sta >$e12000+150,x
rw_words_75               lda >rr_candidate+148,x
                          sta >$e12000+148,x
rw_words_74               lda >rr_candidate+146,x
                          sta >$e12000+146,x
rw_words_73               lda >rr_candidate+144,x
                          sta >$e12000+144,x
rw_words_72               lda >rr_candidate+142,x
                          sta >$e12000+142,x
rw_words_71               lda >rr_candidate+140,x
                          sta >$e12000+140,x
rw_words_70               lda >rr_candidate+138,x
                          sta >$e12000+138,x
rw_words_69               lda >rr_candidate+136,x
                          sta >$e12000+136,x
rw_words_68               lda >rr_candidate+134,x
                          sta >$e12000+134,x
rw_words_67               lda >rr_candidate+132,x
                          sta >$e12000+132,x
rw_words_66               lda >rr_candidate+130,x
                          sta >$e12000+130,x
rw_words_65               lda >rr_candidate+128,x
                          sta >$e12000+128,x
rw_words_64               lda >rr_candidate+126,x
                          sta >$e12000+126,x
rw_words_63               lda >rr_candidate+124,x
                          sta >$e12000+124,x
rw_words_62               lda >rr_candidate+122,x
                          sta >$e12000+122,x
rw_words_61               lda >rr_candidate+120,x
                          sta >$e12000+120,x
rw_words_60               lda >rr_candidate+118,x
                          sta >$e12000+118,x
rw_words_59               lda >rr_candidate+116,x
                          sta >$e12000+116,x
rw_words_58               lda >rr_candidate+114,x
                          sta >$e12000+114,x
rw_words_57               lda >rr_candidate+112,x
                          sta >$e12000+112,x
rw_words_56               lda >rr_candidate+110,x
                          sta >$e12000+110,x
rw_words_55               lda >rr_candidate+108,x
                          sta >$e12000+108,x
rw_words_54               lda >rr_candidate+106,x
                          sta >$e12000+106,x
rw_words_53               lda >rr_candidate+104,x
                          sta >$e12000+104,x
rw_words_52               lda >rr_candidate+102,x
                          sta >$e12000+102,x
rw_words_51               lda >rr_candidate+100,x
                          sta >$e12000+100,x
rw_words_50               lda >rr_candidate+98,x
                          sta >$e12000+98,x
rw_words_49               lda >rr_candidate+96,x
                          sta >$e12000+96,x
rw_words_48               lda >rr_candidate+94,x
                          sta >$e12000+94,x
rw_words_47               lda >rr_candidate+92,x
                          sta >$e12000+92,x
rw_words_46               lda >rr_candidate+90,x
                          sta >$e12000+90,x
rw_words_45               lda >rr_candidate+88,x
                          sta >$e12000+88,x
rw_words_44               lda >rr_candidate+86,x
                          sta >$e12000+86,x
rw_words_43               lda >rr_candidate+84,x
                          sta >$e12000+84,x
rw_words_42               lda >rr_candidate+82,x
                          sta >$e12000+82,x
rw_words_41               lda >rr_candidate+80,x
                          sta >$e12000+80,x
rw_words_40               lda >rr_candidate+78,x
                          sta >$e12000+78,x
rw_words_39               lda >rr_candidate+76,x
                          sta >$e12000+76,x
rw_words_38               lda >rr_candidate+74,x
                          sta >$e12000+74,x
rw_words_37               lda >rr_candidate+72,x
                          sta >$e12000+72,x
rw_words_36               lda >rr_candidate+70,x
                          sta >$e12000+70,x
rw_words_35               lda >rr_candidate+68,x
                          sta >$e12000+68,x
rw_words_34               lda >rr_candidate+66,x
                          sta >$e12000+66,x
rw_words_33               lda >rr_candidate+64,x
                          sta >$e12000+64,x
rw_words_32               lda >rr_candidate+62,x
                          sta >$e12000+62,x
rw_words_31               lda >rr_candidate+60,x
                          sta >$e12000+60,x
rw_words_30               lda >rr_candidate+58,x
                          sta >$e12000+58,x
rw_words_29               lda >rr_candidate+56,x
                          sta >$e12000+56,x
rw_words_28               lda >rr_candidate+54,x
                          sta >$e12000+54,x
rw_words_27               lda >rr_candidate+52,x
                          sta >$e12000+52,x
rw_words_26               lda >rr_candidate+50,x
                          sta >$e12000+50,x
rw_words_25               lda >rr_candidate+48,x
                          sta >$e12000+48,x
rw_words_24               lda >rr_candidate+46,x
                          sta >$e12000+46,x
rw_words_23               lda >rr_candidate+44,x
                          sta >$e12000+44,x
rw_words_22               lda >rr_candidate+42,x
                          sta >$e12000+42,x
rw_words_21               lda >rr_candidate+40,x
                          sta >$e12000+40,x
rw_words_20               lda >rr_candidate+38,x
                          sta >$e12000+38,x
rw_words_19               lda >rr_candidate+36,x
                          sta >$e12000+36,x
rw_words_18               lda >rr_candidate+34,x
                          sta >$e12000+34,x
rw_words_17               lda >rr_candidate+32,x
                          sta >$e12000+32,x
rw_words_16               lda >rr_candidate+30,x
                          sta >$e12000+30,x
rw_words_15               lda >rr_candidate+28,x
                          sta >$e12000+28,x
rw_words_14               lda >rr_candidate+26,x
                          sta >$e12000+26,x
rw_words_13               lda >rr_candidate+24,x
                          sta >$e12000+24,x
rw_words_12               lda >rr_candidate+22,x
                          sta >$e12000+22,x
rw_words_11               lda >rr_candidate+20,x
                          sta >$e12000+20,x
rw_words_10               lda >rr_candidate+18,x
                          sta >$e12000+18,x
rw_words_9                lda >rr_candidate+16,x
                          sta >$e12000+16,x
rw_words_8                lda >rr_candidate+14,x
                          sta >$e12000+14,x
rw_words_7                lda >rr_candidate+12,x
                          sta >$e12000+12,x
rw_words_6                lda >rr_candidate+10,x
                          sta >$e12000+10,x
rw_words_5                lda >rr_candidate+8,x
                          sta >$e12000+8,x
rw_words_4                lda >rr_candidate+6,x
                          sta >$e12000+6,x
rw_words_3                lda >rr_candidate+4,x
                          sta >$e12000+4,x
rw_words_2                lda >rr_candidate+2,x
                          sta >$e12000+2,x
rw_words_1                lda >rr_candidate+0,x
                          sta >$e12000+0,x
                          jmp rw_span_done
rw_admitted               ds 2
rw_equal_proof            ds 2
rw_mode                   ds 2
rw_strip                  ds 2
rw_index                  ds 2
rw_limit                  ds 2
rw_descriptor             ds 2
rw_offset                 ds 2
rw_temp                   ds 2
rw_words                  ds 2
rw_spans                  ds 2
