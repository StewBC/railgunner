/* AAPCS, ARM2: four masked words per sprite row. Tokens index deduplicated masks
 * and precoloured words. No SWIs or IRQ work here. */
.text
.align 2
.global rg_blit_words
.type rg_blit_words,%function
rg_blit_words:
    stmfd sp!,{r4-r11,lr}
    mov r11,r3
    ldr lr,[sp,#36]
    ldr r3,[sp,#40]
    sub lr,lr,r3,lsl #2
    rsb r12,r3,#4
    mov r12,r12,lsl #2
    cmp r11,#0
    beq 2f
    adr r8,1f
    ldr pc,[r8,r3,lsl #2]
1:
    .word 2f
    .word blit1
    .word blit2
    .word blit3
    .word blit4
.macro word index
    cmp \index,#0
    addne r8,r2,\index,lsl #3
    ldmneia r8,{r8-r9}
    ldrne r10,[r0]
    bicne r10,r10,r8
    orrne r10,r10,r9
    strne r10,[r0]
    add r0,r0,#4
.endm
blit1:
    ldmia r1!,{r4}
    word r4
    add r1,r1,r12
    add r0,r0,lr
    subs r11,r11,#1
    bne blit1
    b 2f
blit2:
    ldmia r1!,{r4,r5}
    word r4
    word r5
    add r1,r1,r12
    add r0,r0,lr
    subs r11,r11,#1
    bne blit2
    b 2f
blit3:
    ldmia r1!,{r4,r5,r6}
    word r4
    word r5
    word r6
    add r1,r1,r12
    add r0,r0,lr
    subs r11,r11,#1
    bne blit3
    b 2f
blit4:
    ldmia r1!,{r4,r5,r6,r7}
    word r4
    word r5
    word r6
    word r7
    add r1,r1,r12
    add r0,r0,lr
    subs r11,r11,#1
    bne blit4
    b 2f
2:
    ldmfd sp!,{r4-r11,pc}
.size rg_blit_words,.-rg_blit_words

/* Eight rows of one to eight adjacent cells, using sequential transfers. */
.align 2
.global rg_copy_tiles
.type rg_copy_tiles,%function
rg_copy_tiles:
    stmfd sp!,{r4-r11,lr}
    sub r3,r3,r2,lsl #2
    rsb lr,r2,#40
    mov lr,lr,lsl #2
    adr r12,3f
    ldr pc,[r12,r2,lsl #2]
3:
    .word 12f
    .word copy1
    .word copy2
    .word copy3
    .word copy4
    .word copy5
    .word copy6
    .word copy7
    .word copy8
copy1:
    mov r2,#8
copy1_row:
    ldmia r1!,{r4}
    stmia r0!,{r4}
    add r1,r1,lr
    add r0,r0,r3
    subs r2,r2,#1
    bne copy1_row
    b 12f
copy2:
    mov r2,#8
copy2_row:
    ldmia r1!,{r4,r5}
    stmia r0!,{r4,r5}
    add r1,r1,lr
    add r0,r0,r3
    subs r2,r2,#1
    bne copy2_row
    b 12f
copy3:
    mov r2,#8
copy3_row:
    ldmia r1!,{r4,r5,r6}
    stmia r0!,{r4,r5,r6}
    add r1,r1,lr
    add r0,r0,r3
    subs r2,r2,#1
    bne copy3_row
    b 12f
copy4:
    mov r2,#8
copy4_row:
    ldmia r1!,{r4,r5,r6,r7}
    stmia r0!,{r4,r5,r6,r7}
    add r1,r1,lr
    add r0,r0,r3
    subs r2,r2,#1
    bne copy4_row
    b 12f
copy5:
    mov r2,#8
copy5_row:
    ldmia r1!,{r4,r5,r6,r7,r8}
    stmia r0!,{r4,r5,r6,r7,r8}
    add r1,r1,lr
    add r0,r0,r3
    subs r2,r2,#1
    bne copy5_row
    b 12f
copy6:
    mov r2,#8
copy6_row:
    ldmia r1!,{r4,r5,r6,r7,r8,r9}
    stmia r0!,{r4,r5,r6,r7,r8,r9}
    add r1,r1,lr
    add r0,r0,r3
    subs r2,r2,#1
    bne copy6_row
    b 12f
copy7:
    mov r2,#8
copy7_row:
    ldmia r1!,{r4,r5,r6,r7,r8,r9,r10}
    stmia r0!,{r4,r5,r6,r7,r8,r9,r10}
    add r1,r1,lr
    add r0,r0,r3
    subs r2,r2,#1
    bne copy7_row
    b 12f
copy8:
    mov r2,#8
copy8_row:
    ldmia r1!,{r4,r5,r6,r7,r8,r9,r10,r11}
    stmia r0!,{r4,r5,r6,r7,r8,r9,r10,r11}
    add r1,r1,lr
    add r0,r0,r3
    subs r2,r2,#1
    bne copy8_row
    b 12f
12:
    ldmfd sp!,{r4-r11,pc}
.size rg_copy_tiles,.-rg_copy_tiles

/* Compare four aligned words per block without touching the snapshot. */
.align 2
.global rg_cells_blocks
.type rg_cells_blocks,%function
rg_cells_blocks:
    stmfd sp!,{r4-r11,lr}
    cmp r3,#0
    beq 14f
13:
    ldmia r0!,{r4-r7}
    ldmia r1!,{r8-r11}
    eor r4,r4,r8
    eor r5,r5,r9
    eor r6,r6,r10
    eor r7,r7,r11
    orr r4,r4,r5
    orr r4,r4,r6
    orrs r4,r4,r7
    movne r12,#1
    moveq r12,#0
    strb r12,[r2],#1
    subs r3,r3,#1
    bne 13b
14:
    ldmfd sp!,{r4-r11,pc}
.size rg_cells_blocks,.-rg_cells_blocks

.align 2
.global rg_paint_glyph
.type rg_paint_glyph,%function
rg_paint_glyph:
    stmfd sp!,{r4-r11,lr}
    ldmia r1,{r4-r11}
    str r4,[r0],r2
    str r5,[r0],r2
    str r6,[r0],r2
    str r7,[r0],r2
    str r8,[r0],r2
    str r9,[r0],r2
    str r10,[r0],r2
    str r11,[r0]
    ldmfd sp!,{r4-r11,pc}
.size rg_paint_glyph,.-rg_paint_glyph

/* Full text scene: fetch a glyph once, store its eight rows without C calls. */
.align 2
.global rg_background_text
.type rg_background_text,%function
rg_background_text:
    stmfd sp!,{r4-r11,lr}
    mov lr,#25
15:
    mov r12,#40
16:
    ldrb r4,[r1],#1
    ldrb r5,[r1],#1
    and r5,r5,#15
    add r4,r2,r4,lsl #5
    add r4,r4,r5,lsl #13
    ldmia r4,{r4-r11}
    str r4,[r0,#0]
    str r5,[r0,#160]
    str r6,[r0,#320]
    str r7,[r0,#480]
    str r8,[r0,#640]
    str r9,[r0,#800]
    str r10,[r0,#960]
    str r11,[r0,#1120]
    add r0,r0,#4
    subs r12,r12,#1
    bne 16b
    add r0,r0,#1120
    subs lr,lr,#1
    bne 15b
    ldmfd sp!,{r4-r11,pc}
.size rg_background_text,.-rg_background_text

/* Paint all dirty text glyphs in one call, sharing saved registers. */
.align 2
.global rg_background_dirty
.type rg_background_dirty,%function
rg_background_dirty:
    stmfd sp!,{r4-r11,lr}
    mov r4,#25
    stmfd sp!,{r4}
.Ldirty_row:
    mov lr,#5
.Ldirty_group:
    ldrb r12,[r3],#1
    cmp r12,#0
    beq .Ldirty_skip_group
    orr r12,r12,#256
.Ldirty_cell:
    tst r12,#1
    beq .Ldirty_skip_cell
    ldrb r4,[r1]
    ldrb r5,[r1,#1]
    and r5,r5,#15
    add r4,r2,r4,lsl #5
    add r4,r4,r5,lsl #13
    ldmia r4,{r4-r11}
    str r4,[r0,#0]
    str r5,[r0,#160]
    str r6,[r0,#320]
    str r7,[r0,#480]
    str r8,[r0,#640]
    str r9,[r0,#800]
    str r10,[r0,#960]
    str r11,[r0,#1120]
.Ldirty_skip_cell:
    add r0,r0,#4
    add r1,r1,#2
    mov r12,r12,lsr #1
    cmp r12,#1
    bne .Ldirty_cell
    b .Ldirty_next_group
.Ldirty_skip_group:
    add r0,r0,#32
    add r1,r1,#16
.Ldirty_next_group:
    subs lr,lr,#1
    bne .Ldirty_group
    add r0,r0,#1120
    ldr r4,[sp]
    subs r4,r4,#1
    str r4,[sp]
    bne .Ldirty_row
    add sp,sp,#4
    ldmfd sp!,{r4-r11,pc}
.size rg_background_dirty,.-rg_background_dirty

.align 2
.global rg_copy_words
.type rg_copy_words,%function
rg_copy_words:
    stmfd sp!,{r4-r11,lr}
    cmp r2,#8
    blo 18f
17:
    ldmia r1!,{r4-r11}
    stmia r0!,{r4-r11}
    sub r2,r2,#8
    cmp r2,#8
    bhs 17b
18:
    cmp r2,#0
    beq 20f
19:
    ldr r3,[r1],#4
    str r3,[r0],#4
    subs r2,r2,#1
    bne 19b
20:
    ldmfd sp!,{r4-r11,pc}
.size rg_copy_words,.-rg_copy_words
