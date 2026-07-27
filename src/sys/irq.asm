; Raster IRQ owner and main-thread frame wait.

.proc irq_install
    sei

    ; Own the frame clock: disable/clear both CIA interrupt controllers.
    lda #$7f
    sta CIA1_ICR
    sta CIA2_ICR
    lda CIA1_ICR
    lda CIA2_ICR

    lda #<irq_handler
    sta IRQ_VECTOR_LO
    lda #>irq_handler
    sta IRQ_VECTOR_HI

    ; Raster compare always stays in the common PAL/NTSC 0..255 range.
    lda VIC_CTRL1
    and #$7f
    sta VIC_CTRL1
    lda #0
    sta VIC_RASTER

    ; Clear collision latches before ownership begins.
    lda VIC_SPR_BG_COLL
    lda VIC_SPR_SPR_COLL
    lda #$01
    sta VIC_IRQ_STATUS
    sta VIC_IRQ_ENABLE
    rts
.endproc

.proc irq_handler
    jmp sprite_mux_irq::handler
.endproc

; Wait for the line-0 IRQ to advance the physical-frame sequence.
.proc wait_frame
    lda objects::main_frame_seq
wait_next:
    cmp objects::irq_frame_seq
    beq wait_next
    lda objects::irq_frame_seq
    sta objects::main_frame_seq
    rts
.endproc
