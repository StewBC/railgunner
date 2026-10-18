; Raw producer sprite_ptr -> asset ordinal. A=zeroextended rawC64pointer,
; ro_player_frame=current captured logical playerframe; A=$ffff means skip.
; Both playerbuffer pointers resolve through original logical frameorder.
; DBR=rendererbank,M=X16; A/X/flags clobbered. Tablesgeneratedfromcoreauthority.
ro_lookup         and   #$ff
                  cmp   #$f8
                  beq   ro_lookup_player
                  cmp   #$f9
                  beq   ro_lookup_player
                  asl   a
                  tax
                  lda   ro_pointer_map,x
                  rts
ro_lookup_player  lda   ro_player_frame
                  and   #3
                  asl   a
                  tax
                  lda   ro_player_map,x
                  rts
ro_player_frame   ds    2
