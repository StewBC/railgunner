; Shipping IIgs frontend only. Native M=X=8, DBR=GAME, private game D.
; Keep the original ten-tick cadence and descending phase (highlight moves down).
; Entry/hold refresh paints the base once. Animation touches exactly two rows.
                         longa off
                         longi off
title_text_rotate_colors inc score_color_tick
                         lda score_color_tick
                         cmp #SCORE_COLOR_PERIOD
                         bcc hs_color_done
                         stz score_color_tick
                         jsr hs_color_row
                         lda #COL_LT_GRAY
                         jsr screen_color_row
                         dec score_color_phase
                         lda score_color_phase
                         cmp #10
                         bcc hs_color_highlight
                         lda #9
                         sta score_color_phase
hs_color_highlight       jsr hs_color_row
                         lda #COL_YELLOW
                         jmp screen_color_row
hs_color_done            rts
; The caller resets phase/tick on entry. Also used after initials are accepted.
title_text_color_scores  stz draw_i
hs_color_base            lda draw_i
                         clc
                         adc #HS_ROW_SCORE0
                         tay
                         lda #COL_LT_GRAY
                         jsr screen_color_row
                         inc draw_i
                         lda draw_i
                         cmp #10
                         bcc hs_color_base
                         bra hs_color_highlight
; phase 0,9,8,...,1 maps to table row 0,1,2,...,9.
hs_color_row             lda score_color_phase
                         beq hs_color_first
                         lda #10
                         sec
                         sbc score_color_phase
hs_color_first           clc
                         adc #HS_ROW_SCORE0
                         tay
                         rts
