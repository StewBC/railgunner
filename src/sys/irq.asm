; IRQ / raster shell — stub for scaffold.
; Vertical slice will install a raster IRQ for sprite mux later.

.proc irq_install
    ; No IRQ installed yet; game loop is polled + wait_frame.
    rts
.endproc

.proc irq_handler
    ; Placeholder vector target (not installed).
    rti
.endproc

; Busy-wait one full frame (poll $D011 bit 7). Good enough for scaffold timers.
.proc wait_frame
:
    lda VIC_CTRL1
    bpl :-                          ; wait while raster < 256
:
    lda VIC_CTRL1
    bmi :-                          ; wait while raster >= 256
    rts
.endproc
