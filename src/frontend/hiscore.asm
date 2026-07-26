; High score table / entry — scaffold stubs only.

.proc hiscore_reset
    ; Default empty table (disk load later). No storage yet.
    rts
.endproc

.proc hiscore_enter
    lda #COL_YELLOW
    sta VIC_BORDER
    jsr screen_clear

    lda #<str_hiscore
    sta ptr_lo
    lda #>str_hiscore
    sta ptr_hi
    ldx #14
    ldy #10
    jsr screen_print

    lda #<str_press_fire
    sta ptr_lo
    lda #>str_press_fire
    sta ptr_hi
    ldx #15
    ldy #14
    jsr screen_print
    rts
.endproc

.proc hiscore_update
    lda input_fire_edge
    beq hiscore_done
    lda #MODE_TITLE
    jsr mode_set
hiscore_done:
    rts
.endproc
