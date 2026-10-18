; Stable raster sample, native 16-bit. Reads only C02E/F, never C030.
raster_line  lda   >$E0C02E
             and   #$80FF
             sta   beam_sample
             lda   >$E0C02E
             and   #$80FF
             cmp   beam_sample
             bne   raster_line
             asl   a
             and   #$01FE
             adc   #0
             cmp   #$100
             bcc   raster_tail
             sbc   #$100
             rts
raster_tail  adc   #6
             rts
