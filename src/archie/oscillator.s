/* Foreground ARM2 oscillator loops. Same exact phase/noise recurrence as C.
 * AAPCS args: osc, voice, clocks/sample, extras, gains, mix, count. */
.text
.align 2
.global rg_clock_extras
.type rg_clock_extras,%function
rg_clock_extras:
    stmfd sp!,{r4,r5,lr}
    ldr r4,[sp,#12]
    cmp r4,#4
    blo 2f
1:  mov r5,#0
    add r2,r2,r1
    cmp r2,r0
    subhs r2,r2,r0
    orrhs r5,r5,#1
    add r2,r2,r1
    cmp r2,r0
    subhs r2,r2,r0
    orrhs r5,r5,#256
    add r2,r2,r1
    cmp r2,r0
    subhs r2,r2,r0
    orrhs r5,r5,#65536
    add r2,r2,r1
    cmp r2,r0
    subhs r2,r2,r0
    orrhs r5,r5,#16777216
    str r5,[r3],#4
    sub r4,r4,#4
    cmp r4,#4
    bhs 1b
2:  cmp r4,#0
    beq 4f
3:  add r2,r2,r1
    cmp r2,r0
    subhs r2,r2,r0
    movhs r5,#1
    movlo r5,#0
    strb r5,[r3],#1
    subs r4,r4,#1
    bne 3b
4:  mov r0,r2
    ldmfd sp!,{r4,r5,pc}
.size rg_clock_extras,.-rg_clock_extras

.align 2
.global rg_env_linear
.type rg_env_linear,%function
/* osc, gains, count, up, down, release, sustain. Gen/gate handled in C. */
rg_env_linear:
    stmfd sp!,{r4-r9,lr}
    ldr r4,[sp,#28]
    ldr r5,[sp,#32]
    ldr r6,[sp,#36]
    ldr r7,[r0,#8]
    ldr r8,[r0,#16]
    mov r9,r0
    cmp r8,#0
    beq .Lenv_attack
    cmp r8,#1
    beq .Lenv_decay
    cmp r8,#2
    beq .Lenv_sustain
    b .Lenv_release
.Lenv_attack:
    add r7,r7,r3
    cmp r7,#0x1000000
    movhs r7,#0x1000000
    movhs r8,#1
    mov r12,r7,lsr #9
    str r12,[r1],#4
    subs r2,r2,#1
    beq .Lenv_done
    cmp r8,#0
    beq .Lenv_attack
.Lenv_decay:
    add r12,r6,r4
    cmp r7,r12
    subhi r7,r7,r4
    movls r7,r6
    movls r8,#2
    mov r12,r7,lsr #9
    str r12,[r1],#4
    subs r2,r2,#1
    beq .Lenv_done
    cmp r8,#1
    beq .Lenv_decay
.Lenv_sustain:
    mov r7,r6
    mov r12,r7,lsr #9
5:  str r12,[r1],#4
    subs r2,r2,#1
    bne 5b
    b .Lenv_done
.Lenv_release:
    subs r7,r7,r5
    movlo r7,#0
    mov r12,r7,lsr #9
    str r12,[r1],#4
    subs r2,r2,#1
    bne .Lenv_release
.Lenv_done:
    str r7,[r9,#8]
    str r8,[r9,#16]
    ldmfd sp!,{r4-r9,pc}
.size rg_env_linear,.-rg_env_linear

.align 2
.global rg_osc_pulse,rg_osc_saw,rg_osc_tri,rg_osc_noise
rg_osc_pulse: mov r12,#0
    b .Lsetup
rg_osc_saw: mov r12,#1
    b .Lsetup
rg_osc_tri: mov r12,#2
    b .Lsetup
rg_osc_noise: mov r12,#3
.Lsetup:
    stmfd sp!,{r4-r11,lr}
    mov r8,r12
    ldmia r0,{r4,r5}
    ldrb r6,[r1,#0]
    ldrb r7,[r1,#1]
    orr r6,r6,r7,lsl #8
    mul r7,r6,r2
    ldr r9,[sp,#36]
    ldr r10,[sp,#40]
    ldr r12,[sp,#44]
    mov r11,r3
    stmfd sp!,{r0}
    tst r12,#0x80000000
    movne lr,#1
    moveq lr,#0
    bic r12,r12,#0x80000000
    cmp r8,#0
    beq .Lpulse_init
    cmp r8,#1
    beq .Lsaw_init
    cmp r8,#2
    beq .Ltri_init
    ldr r8,=.Lnoise_ptr
    ldr r8,[r8]
    cmp lr,#0
    bne .Lnoise_fixed
    b .Lnoise
.Lpulse_init:
    ldrb r8,[r1,#2]
    ldrb r0,[r1,#3]
    orr r8,r8,r0,lsl #8
    mov r8,r8,lsl #20
    mov r8,r8,lsr #20
    cmp lr,#0
    beq .Lpulse
    ldr r9,[r9]
    rsb lr,r9,#0
    cmp r9,#0
    subne r9,r9,#1
    b .Lpulse_fixed
.Lpulse:
    ldrb r0,[r11],#1
    cmp r0,#0
    add r4,r4,r7
    addne r4,r4,r6
    bic r4,r4,#0xff000000
    ldr r1,[r9],#4
    cmp r1,#0
    subne r2,r1,#1
    moveq r2,#0
    cmp r8,r4,lsr #12
    rsbhi r2,r1,#0
    ldr r0,[r10]
    add r0,r0,r2
    str r0,[r10],#4
    subs r12,r12,#1
    bne .Lpulse
    b .Ldone
.Lsaw_init:
    cmp lr,#0
    ldrne r9,[r9]
    bne .Lsaw_fixed
.Lsaw:
    ldrb r0,[r11],#1
    cmp r0,#0
    add r4,r4,r7
    addne r4,r4,r6
    bic r4,r4,#0xff000000
    mov r0,r4,lsr #8
    sub r0,r0,#32768
    ldr r1,[r9],#4
    mul r2,r0,r1
    ldr r0,[r10]
    add r0,r0,r2,asr #15
    str r0,[r10],#4
    subs r12,r12,#1
    bne .Lsaw
    b .Ldone
.Ltri_init:
    cmp lr,#0
    ldrne r9,[r9]
    bne .Ltri_fixed
.Ltri:
    ldrb r0,[r11],#1
    cmp r0,#0
    add r4,r4,r7
    addne r4,r4,r6
    bic r4,r4,#0xff000000
    tst r4,#0x800000
    mov r0,r4
    mvnne r0,r4
    bic r0,r0,#0xff000000
    mov r0,r0,lsr #7
    sub r0,r0,#32768
    ldr r1,[r9],#4
    mul r2,r0,r1
    ldr r0,[r10]
    add r0,r0,r2,asr #15
    str r0,[r10],#4
    subs r12,r12,#1
    bne .Ltri
    b .Ldone
.Lnoise:
    ldrb r0,[r11],#1
    cmp r0,#0
    mov r1,r4
    add r4,r4,r7
    addne r4,r4,r6
    add r0,r4,#0x80000
    add r1,r1,#0x80000
    mov r0,r0,lsr #20
    sub r0,r0,r1,lsr #20
    bic r4,r4,#0xff000000
    cmp r0,#0
    beq .Lnoise_sample
    /* Native sample rate ensures at most four crossings. */
    eor r1,r5,r5,lsl #5
    rsb r2,r0,#23
    mvn r3,#0
    mvn r3,r3,lsl r0
    and r1,r3,r1,lsr r2
    orr r5,r1,r5,lsl r0
    bic r5,r5,#0xff000000
    bic r5,r5,#0x800000
.Lnoise_sample:
    mov r0,r5,lsr #10
    ldrb r0,[r8,r0]
    mov r1,r5,lsl #22
    mov r1,r1,lsr #22
    add r3,r8,#8192
    ldrb r1,[r3,r1]
    orr r0,r0,r1
    sub r0,r0,#128
    ldr r1,[r9],#4
    mul r2,r0,r1
    ldr r0,[r10]
    add r0,r0,r2,asr #7
    str r0,[r10],#4
    subs r12,r12,#1
    bne .Lnoise
    b .Ldone
.Lpulse_fixed:
    ldrb r0,[r11],#1
    cmp r0,#0
    add r4,r4,r7
    addne r4,r4,r6
    bic r4,r4,#0xff000000
    cmp r8,r4,lsr #12
    movhi r2,lr
    movls r2,r9
    ldr r0,[r10]
    add r0,r0,r2
    str r0,[r10],#4
    subs r12,r12,#1
    bne .Lpulse_fixed
    b .Ldone
.Lsaw_fixed:
    ldrb r0,[r11],#1
    cmp r0,#0
    add r4,r4,r7
    addne r4,r4,r6
    bic r4,r4,#0xff000000
    mov r0,r4,lsr #8
    sub r0,r0,#32768
    mov r1,r9
    mul r2,r0,r1
    ldr r0,[r10]
    add r0,r0,r2,asr #15
    str r0,[r10],#4
    subs r12,r12,#1
    bne .Lsaw_fixed
    b .Ldone
.Ltri_fixed:
    ldrb r0,[r11],#1
    cmp r0,#0
    add r4,r4,r7
    addne r4,r4,r6
    bic r4,r4,#0xff000000
    tst r4,#0x800000
    mov r0,r4
    mvnne r0,r4
    bic r0,r0,#0xff000000
    mov r0,r0,lsr #7
    sub r0,r0,#32768
    mov r1,r9
    mul r2,r0,r1
    ldr r0,[r10]
    add r0,r0,r2,asr #15
    str r0,[r10],#4
    subs r12,r12,#1
    bne .Ltri_fixed
    b .Ldone
.Lnoise_fixed:
    ldrb r0,[r11],#1
    cmp r0,#0
    mov r1,r4
    add r4,r4,r7
    addne r4,r4,r6
    add r0,r4,#0x80000
    add r1,r1,#0x80000
    mov r0,r0,lsr #20
    sub r0,r0,r1,lsr #20
    bic r4,r4,#0xff000000
    cmp r0,#0
    beq .Lnoise_fixed_sample
    /* Native sample rate ensures at most four crossings. */
    eor r1,r5,r5,lsl #5
    rsb r2,r0,#23
    mvn r3,#0
    mvn r3,r3,lsl r0
    and r1,r3,r1,lsr r2
    orr r5,r1,r5,lsl r0
    bic r5,r5,#0xff000000
    bic r5,r5,#0x800000
.Lnoise_fixed_sample:
    mov r0,r5,lsr #10
    ldrb r0,[r8,r0]
    mov r1,r5,lsl #22
    mov r1,r1,lsr #22
    add r3,r8,#8192
    ldrb r1,[r3,r1]
    orr r0,r0,r1
    ldr r2,[r9,r0,lsl #2]
    ldr r0,[r10]
    add r0,r0,r2
    str r0,[r10],#4
    subs r12,r12,#1
    bne .Lnoise_fixed
    b .Ldone
.Ldone:
    ldmfd sp!,{r0}
    stmia r0,{r4,r5}
    ldmfd sp!,{r4-r11,pc}
.align 2
.Lnoise_ptr: .word rg_noise_table

.global rg_zero_mix
rg_zero_mix:
    stmfd sp!,{r4-r9,lr}
    mov r1,#26
    mov r2,#0
    mov r3,#0
    mov r4,#0
    mov r5,#0
    mov r6,#0
    mov r7,#0
    mov r8,#0
    mov r9,#0
.Lzero:
    stmia r0!,{r2-r9}
    subs r1,r1,#1
    bne .Lzero
    ldmfd sp!,{r4-r9,pc}
