; Native background cell expansion. rg_cell=0..999 from immutable candidate.
; A=0 success,1 invalid; DBR=renderer bank, M=X16; A/X/Y/flags clobbered.
; Only the selected four bytes x eight rows are written to clean background.
; Original glyph/color/title bitplanes; no whole-frame clear. No E1/tools/DP.
                          longa on
                          longi on
rg_expand                 lda rg_cell
                          cmp #1000
                          bcc rg_valid
                          lda #1
                          rts
rg_valid                  ldy #0
rg_divide                 cmp #40
                          bcc rg_column
                          sec
                          sbc #40
                          iny
                          bra rg_divide
rg_column                 asl a
                          asl a
                          sta rg_offset
                          tya
                          asl a
                          asl a
                          clc
                          adc #0
                          sta rg_temp
                          tya
                          clc
                          adc rg_temp
                          xba
                          clc
                          adc rg_offset
                          sta rg_offset
                          lda rc_candidate_present
                          cmp #1
                          beq rg_title
                          ldx rg_cell
                          sep #$20
                          longa off
                          lda >rc_candidate_glyphs,x
                          rep #$20
                          longa on
                          and #$ff
                          asl a
                          asl a
                          asl a
                          sta rg_source
                          sep #$20
                          longa off
                          lda >rc_candidate_colors,x
                          rep #$20
                          longa on
                          and #15
                          sta rg_fg
                          stz rg_bg
                          bra rg_palette
rg_title                  lda rg_cell
                          asl a
                          asl a
                          asl a
                          sta rg_source
                          ldx rg_cell
                          sep #$20
                          longa off
                          lda >rg_title_colors,x
                          rep #$20
                          longa on
                          and #$ff
                          pha
                          and #15
                          sta rg_bg
                          pla
                          lsr a
                          lsr a
                          lsr a
                          lsr a
                          sta rg_fg
rg_palette                lda rg_bg
                          asl a
                          asl a
                          asl a
                          asl a
                          ora rg_bg
                          sta rg_temp
                          xba
                          ora rg_temp
                          sta rg_background_word
                          lda rg_fg
                          asl a
                          asl a
                          asl a
                          asl a
                          ora rg_fg
                          sta rg_temp
                          xba
                          ora rg_temp
                          eor rg_background_word
                          sta rg_delta_word
                          stz rg_row
rg_row_loop               ldx rg_source
                          lda rc_candidate_present
                          cmp #1
                          beq rg_title_read
                          sep #$20
                          longa off
                          lda >rg_charset,x
                          bra rg_bits_ready
rg_title_read             sep #$20
                          longa off
                          lda >rg_title_bits,x
rg_bits_ready             rep #$20
                          longa on
                          and #$ff
                          sta rg_bits
; A nibble selects the foreground mask for four
; pixels, in SHR little-endian packed-word order.
                          and #$F0
                          lsr a
                          lsr a
                          lsr a
                          tax
                          lda rg_nibble_masks,x
                          and rg_delta_word
                          eor rg_background_word
                          ldx rg_offset
                          sta >rr_background,x
                          lda rg_bits
                          and #15
                          asl a
                          tax
                          lda rg_nibble_masks,x
                          and rg_delta_word
                          eor rg_background_word
                          ldx rg_offset
                          sta >rr_background+2,x
                          lda rg_offset
                          clc
                          adc #160
                          sta rg_offset
                          inc rg_source
                          inc rg_row
                          lda rg_row
                          cmp #8
                          bcc rg_row_loop
                          lda #0
                          rts
; A source nibble's bits3..0 select pixels0..3. The masks follow
; the two SHR bytes in memory, so pixel0 occupies word bits7..4.
rg_nibble_masks           dc h'0000000F00F000FF0F000F0F0FF00FFFF000F00FF0F0F0FFFF00FF0FFFF0FFFF'
rg_cell                   ds 2
rg_offset                 ds 2
rg_source                 ds 2
rg_row                    ds 2
rg_bits                   ds 2
rg_fg                     ds 2
rg_bg                     ds 2
rg_background_word        ds 2
rg_delta_word             ds 2
rg_temp                   ds 2
