/* RMA-owned, position-independent native voice. PRM Sound system contract.
 * No r14, application pointers, SWIs or calls in the IRQ fill path. */
.text
.align 2
.global rg_voice_start,rg_voice_end,rg_voice_state
rg_voice_start:
    b .Lfill
    b .Lfill
    b .Lfill
    b .Lfill
    b .Linstantiate
    ldmfd sp!,{pc}
    ldmfd sp!,{pc}
    .word .Lname-rg_voice_start
.Lname: .asciz "RailGunner"
.align 2
.Linstantiate:
    cmp r0,#0
    movne r0,#-1
    ldmfd sp!,{pc}
.Lfill:
    adr r1,rg_voice_state
    ldr r2,[r1,#4]
    ldr r3,[r1,#12]
    ldr r4,[r1,#8]
    add r4,r4,#1
    str r4,[r1,#8]
    str r8,[r1,#20]
    str r10,[r1,#24]
    str r11,[r1,#28]
    str r12,[r1,#32]
    add r5,r1,#40
    ldr r4,[r1,#0]
    mov r8,#0
.Lsample:
    cmp r2,r4
    moveq r0,#0
    addeq r3,r3,#1
    movne r6,r2,lsl #22
    movne r6,r6,lsr #22
    ldrneb r0,[r5,r6]
    addne r2,r2,#1
    strb r0,[r12],r11
    add r8,r8,#1
    cmp r12,r10
    bhs .Ldone
    cmp r8,#208
    blo .Lsample
.Ldone:
    str r8,[r1,#36]
    str r2,[r1,#4]
    str r3,[r1,#12]
    ldr r4,[r1,#16]
    add r4,r4,r8
    str r4,[r1,#16]
    mov r0,#8
    ldmfd sp!,{pc}
.align 2
rg_voice_state:
    .space 40 /* counters plus callback DMA geometry */
    .space 1024
rg_voice_end:
