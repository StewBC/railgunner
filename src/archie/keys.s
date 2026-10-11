/* OS_Byte 129 negative-key query, as in SDK k_checkKeypress.
 * X SWI errors mean not held. Only R0-R2 change. */
.text
.align 2
.global rg_key_held
.type rg_key_held,%function
rg_key_held:
    stmfd sp!,{lr}
    eor r1,r0,#255
    mov r0,#129
    mov r2,#255
    swi 0x20006
    movvs r2,#0
    and r0,r2,#255
    cmp r0,#0
    movne r0,#1
    ldmfd sp!,{pc}
.size rg_key_held,.-rg_key_held

/* XJoystick_Read: packed signed Y/X and buttons; -1 on unavailable/error.
 * Reserved high byte is zero in a valid result. */
.align 2
.global rg_joystick_read
.type rg_joystick_read,%function
rg_joystick_read:
    stmfd sp!,{lr}
    swi 0x63f40
    mvnvs r0,#0
    ldmfd sp!,{pc}
.size rg_joystick_read,.-rg_joystick_read

/* Checked VSync/display/write-bank SWIs; return NULL or OS error pointer. */
.align 2
.global rg_present_banks
.type rg_present_banks,%function
rg_present_banks:
    stmfd sp!,{r4,r5,lr}
    mov r4,r0
    mov r5,r1
    mov r0,#19
    mov r1,#0
    mov r2,#0
    swi 0x20006
    bvs 1f
    mov r0,#113
    mov r1,r4
    mov r2,#0
    swi 0x20006
    bvs 1f
    mov r0,#112
    mov r1,r5
    mov r2,#0
    swi 0x20006
    bvs 1f
    mov r0,#0
1:  ldmfd sp!,{r4,r5,pc}
.size rg_present_banks,.-rg_present_banks
