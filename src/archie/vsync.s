/* EventV pass-on contract: RISC OS PRM Software vectors / Events.
 * ARM2 26-bit return preserves entry flags/mode via saved R14.
 * No C calls, allocation or SWIs in the IRQ handler. */
.syntax unified
.arm
.text
.align 2
.global archie_vsync_handler
.type archie_vsync_handler,%function
archie_vsync_handler:
    stmfd sp!, {r1,lr}
    cmp r0, #4
    ldreq r1, [r12]
    addeq r1, r1, #1
    streq r1, [r12]
    ldmfd sp!, {r1,pc}^
.size archie_vsync_handler, .-archie_vsync_handler
