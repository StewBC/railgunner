; Prepare clean background and cell damage for the pending immutable snapshot.
; Foreground native M=X16, DBR=rendererbank; A/X/Y/flagsclobbered,noDP/tools/E1.
; Resets bitmap, so call BEFORE marking changed old/new object footprints.
; Invalidate on firstpresentation or mode/presentchange; titlecells use original
; fixed title asset and ignore mutable text planes exactly as scalar authority.
; Ordinary updates expand ONLY changed glyph/color cells. Composition later
; restores the resulting spans then draws every current intersecting object.
                          longa on
                          longi on
rb_prepare                lda rc_pending
                          bne rb_have_snapshot
                          lda #1
                          rts
rb_have_snapshot          jsr rd_clear
                          stz rb_changed
                          stz rb_full
                          stz rb_cell
                          stz rb_column
                          stz rb_top
                          lda rc_display_valid
                          beq rb_invalidate
                          lda rc_candidate_present
                          cmp rc_displayed_present
                          bne rb_invalidate
                          lda rc_candidate_mode
                          cmp rc_displayed_mode
                          bne rb_invalidate
                          lda rc_candidate_present
                          cmp #1
                          bne rb_pair_start
                          lda #0
                          rts
rb_invalidate             lda #1
                          sta rb_full
                          stz rd_left
                          stz rd_top
                          lda #80
                          sta rd_right
                          lda #200
                          sta rd_bottom
                          jsr rd_mark
rb_cell_loop              jsr rb_expand_one
                          jsr rb_advance_one
                          lda rb_cell
                          cmp #1000
                          bcc rb_cell_loop
                          jmp rb_done
; Compare two adjacent glyph/color cells in native 16-bit mode. Raw color
; bytes participate, including their upper nibble, matching prior damage rules.
; Two cells never cross a 40-cell row boundary. Only differing halves expand.
rb_pair_start             ldx #0
                          ldy #64
                          jsr render_service
; X alone owns the scan offset. Geometry and XOR masks are cold-path work.
rb_pair_loop              lda >rc_candidate_glyphs,x
                          cmp >rc_displayed_glyphs,x
                          bne rb_pair_changed
                          lda >rc_candidate_colors,x
                          cmp >rc_displayed_colors,x
                          bne rb_pair_changed
rb_pair_next              inx
                          inx
                          dey
                          bne rb_pair_count
                          jsr render_service
                          ldy #64
rb_pair_count             cpx #1000
                          bcc rb_pair_loop
; Preserve the original public scratch metadata at successful completion.
                          lda #1000
                          sta rb_cell
                          stz rb_column
                          lda #200
                          sta rb_top
                          jmp rb_done
rb_pair_changed           phx
                          phy
                          stx rb_cell
                          lda >rc_candidate_glyphs,x
                          eor >rc_displayed_glyphs,x
                          sta rb_pair_diff
                          lda >rc_candidate_colors,x
                          eor >rc_displayed_colors,x
                          ora rb_pair_diff
                          sta rb_pair_diff
; Only a changed pair pays for divide-by-40 cell geometry. Even X means the
; pair cannot cross a 40-cell row. At most 24 subtraction iterations.
                          txa
                          stz rb_top
rb_pair_geometry          cmp #40
                          bcc rb_pair_geometry_ready
                          sec
                          sbc #40
                          pha
                          lda rb_top
                          clc
                          adc #8
                          sta rb_top
                          pla
                          bra rb_pair_geometry
rb_pair_geometry_ready    asl a
                          sta rb_column
                          lda rb_pair_diff
                          and #$ff
                          beq rb_pair_low_same
                          jsr rb_change_one
rb_pair_low_same          jsr rb_advance_one
                          lda rb_pair_diff
                          and #$ff00
                          beq rb_pair_high_same
                          jsr rb_change_one
rb_pair_high_same         jsr rb_advance_one
                          ply
                          plx
                          jmp rb_pair_next
rb_done                   lda #0
                          rts
rb_change_one             lda rb_column
                          sta rd_left
                          clc
                          adc #2
                          sta rd_right
                          lda rb_top
                          sta rd_top
                          clc
                          adc #8
                          sta rd_bottom
                          jsr rd_mark
rb_expand_one             lda rb_cell
                          sta rg_cell
                          jsr rg_expand
                          inc rb_changed
                          lda rb_changed
                          and #7
                          bne rb_expand_done
                          jsr render_service
rb_expand_done            rts
rb_advance_one            lda rb_column
                          clc
                          adc #2
                          cmp #80
                          bcc rb_column_ready
                          lda rb_top
                          clc
                          adc #8
                          sta rb_top
                          lda #0
rb_column_ready           sta rb_column
                          inc rb_cell
                          rts
rb_changed                ds 2
rb_full                   ds 2
rb_cell                   ds 2
rb_column                 ds 2
rb_top                    ds 2
rb_pair_diff              ds 2
