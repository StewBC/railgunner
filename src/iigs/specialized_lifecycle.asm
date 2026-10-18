; Own exactly the bank01 SHR bitmap introduced by shadow rendering. Main's
; accepted caller E1/display/register restoration remains unchanged.
; Normal stack/C068 mapping, renderer DBR, M=X16. A/X clobbered; P/D/DBR/S
; preserved. The saved buffer is published only after a complete backup.
 longa on
 longi on
sw_save_bank01 php
 cld
 rep #$30
 longa on
 longi on
 lda swl_saved_valid
 bne swl_save_done
 ldx #0
swl_save_word lda >$012000,x
 sta >swl_caller_01,x
 inx
 inx
 cpx #32000
 bcc swl_save_word
 lda #1
 sta swl_saved_valid
swl_save_done plp
 rts
; Called after owned input callbacks drain, before existing E1 restore. Disable
; 01->E1 shadowing for the restore so distinct original fast/slow buffers survive.
sw_restore_bank01 php
 cld
 rep #$30
 longa on
 longi on
 lda swl_saved_valid
 beq swl_restore_done
 sep #$20
 longa off
 lda >$e0c035
 sta swl_saved_shadow
 ora #8
 sta >$e0c035
 rep #$20
 longa on
 ldx #0
swl_restore_word lda >swl_caller_01,x
 sta >$012000,x
 inx
 inx
 cpx #32000
 bcc swl_restore_word
 sep #$20
 longa off
 lda swl_saved_shadow
 sta >$e0c035
 rep #$20
 longa on
 stz swl_saved_valid
swl_restore_done plp
 rts
swl_saved_valid ds 2
swl_saved_shadow ds 1
