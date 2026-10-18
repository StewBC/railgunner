; Avoid rebuilding identical live state between simulation ticks. Stamp before
; capture: a tick delivered during preparation/drawing makes the next capture
; immediately eligible. Never modify/discard a pending immutable generation.
                  longa  on
                  longi  on
sw_capture_due    lda    sw_capture_valid
                  beq    sw_capture_ready
                  lda    platform_ticks
                  cmp    sw_capture_tick
                  bne    sw_capture_ready
                  lda    platform_ticks+2
                  cmp    sw_capture_tick+2
                  bne    sw_capture_ready
                  lda    #0
                  rts
sw_capture_ready  lda    #1
                  rts
sw_capture_stamp  lda    platform_ticks
                  sta    sw_capture_tick
                  lda    platform_ticks+2
                  sta    sw_capture_tick+2
                  lda    #1
                  sta    sw_capture_valid
                  rts
sw_capture_tick   ds     4
sw_capture_valid  ds     2
