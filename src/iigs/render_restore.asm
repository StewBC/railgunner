; Restore only emitted damaged spans from the clean background to candidate.
; DBR=renderer code bank, native M=X=16, no DP scratch. A/X/Y/flags clobbered.
; Call after rd_emit and before object composition. No visible/E1 stores.
; Image and span bases are matching relocations, never guessed bank numbers.
; rd_count <=8000, generated offsets/lengths within [0,32000) by rd_emit.
rr_restore       stz   rr_index
                 stz   rr_descriptor
                 stz   rr_words
rr_next          lda   rr_index
                 and   #7
                 bne   rr_service_done
                 jsr   render_service
rr_service_done  lda   rr_index
                 cmp   rd_count
                 bcc   rr_load
                 rts
rr_load          cmp   #4000
                 bne   rr_same_bank
                 stz   rr_descriptor
rr_same_bank     ldx   rr_descriptor
                 cmp   #4000
                 bcs   rr_load_b
                 lda   >rd_spans_a,x
                 sta   rr_offset
                 lda   >rd_spans_a+2,x
                 bra   rr_loaded
rr_load_b        lda   >rd_spans_b,x
                 sta   rr_offset
                 lda   >rd_spans_b+2,x
rr_loaded        lsr   a
                 tay
                 ldx   rr_offset
rr_copy          lda   >rr_background,x
                 sta   >rr_candidate,x
                 inc   rr_words
                 inx
                 inx
                 dey
                 bne   rr_copy
                 inc   rr_index
                 lda   rr_descriptor
                 clc
                 adc   #6
                 sta   rr_descriptor
                 bra   rr_next
rr_index         ds    2
rr_descriptor    ds    2
rr_offset        ds    2
rr_words         ds    2
