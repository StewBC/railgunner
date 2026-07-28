; C cargo → GHIJ hub stacks → armed mines → life loss in centre.
; Stacks live in rail_data::ghij_stack[4] (rail.asm OBJECTS segment).

.segment "CODE_HI"
.scope cargo

; ---------------------------------------------------------------------------
.proc init
    lda #0
    sta cargo_active
    sta cargo_timer
    sta ghij_rr
    sta mine_armed
    ldx #0
clr:
    sta rail_data::ghij_stack, x
    inx
    cpx #4
    bcc clr
    rts
.endproc

; X = C drone that reached rail. Spawn cargo at impact, or deposit if busy.
.proc on_c_impact
    lda cargo_active
    beq oci_start
    ; Already a cargo — instant deposit (don't lose pressure)
    jmp deposit_centre

oci_start:
    lda #1
    sta cargo_active
    lda #CARGO_STEP_FRAMES
    sta cargo_timer
    lda objects::obj_user, x
    sta cargo_approach

    ; Char position from drone
    lda objects::obj_user, x
    cmp #DRONE_APPROACH_DOWN
    beq oci_from_top
    cmp #DRONE_APPROACH_UP
    beq oci_from_bot
    cmp #DRONE_APPROACH_RIGHT
    beq oci_from_left
    ; LEFT
    lda #RAIL_COL_RIGHT
    sta cargo_col
    jsr drone_y_to_row
    sta cargo_row
    jmp oci_draw

oci_from_top:
    lda #RAIL_ROW_TOP
    sta cargo_row
    jsr drone_x_to_col
    sta cargo_col
    jmp oci_draw
oci_from_bot:
    lda #RAIL_ROW_BOT
    sta cargo_row
    jsr drone_x_to_col
    sta cargo_col
    jmp oci_draw
oci_from_left:
    lda #RAIL_COL_LEFT
    sta cargo_col
    jsr drone_y_to_row
    sta cargo_row
oci_draw:
    jsr draw_dot
    rts
.endproc

; X still drone — use its coords
.proc drone_x_to_col
    lda objects::obj_x_lo, x
    clc
    adc #DRONE_IMPACT_X_OFF
    sta tmp0
    lda objects::obj_x_hi, x
    adc #0
    sta tmp1
    lda tmp0
    sec
    sbc #24
    sta tmp0
    lda tmp1
    sbc #0
    bcc dx0
    lsr a
    ror tmp0
    lsr a
    ror tmp0
    lsr a
    ror tmp0
    lda tmp0
    cmp #40
    bcc dx_ok
    lda #39
dx_ok:
    rts
dx0:
    lda #0
    rts
.endproc

.proc drone_y_to_row
    lda objects::obj_y_int, x
    clc
    adc #DRONE_IMPACT_Y_OFF
    sec
    sbc #50
    bcc dy0
    lsr a
    lsr a
    lsr a
    cmp #SCREEN_H
    bcc dy_ok
    lda #SCREEN_H - 1
dy_ok:
    rts
dy0:
    lda #0
    rts
.endproc

.proc update
    jsr check_player_mine
    lda cargo_active
    beq cu_done
    dec cargo_timer
    bne cu_done
    lda #CARGO_STEP_FRAMES
    sta cargo_timer
    jsr erase_dot
    jsr step_toward_centre
    bcs cu_arrived
    jsr draw_dot
cu_done:
    rts
cu_arrived:
    lda #0
    sta cargo_active
    jmp deposit_centre
.endproc

; C set = arrived at hub
.proc step_toward_centre
    lda cargo_approach
    cmp #DRONE_APPROACH_DOWN
    beq st_down
    cmp #DRONE_APPROACH_UP
    beq st_up
    cmp #DRONE_APPROACH_RIGHT
    beq st_right
    ; LEFT: move left toward mid col
    lda cargo_col
    cmp #RAIL_COL_MID
    beq st_here
    bcc st_here
    dec cargo_col
    clc
    rts
st_right:
    lda cargo_col
    cmp #RAIL_COL_MID
    bcs st_here
    inc cargo_col
    clc
    rts
st_down:
    lda cargo_row
    cmp #RAIL_ROW_MID
    bcs st_here
    inc cargo_row
    clc
    rts
st_up:
    lda cargo_row
    cmp #RAIL_ROW_MID
    beq st_here
    bcc st_here
    dec cargo_row
    clc
    rts
st_here:
    sec
    rts
.endproc

.proc deposit_centre
    ldx ghij_rr
    lda rail_data::ghij_stack, x
    clc
    adc #1
    bcc dep_store
    lda #255
dep_store:
    sta rail_data::ghij_stack, x
    inx
    txa
    and #3
    sta ghij_rr
    jsr paint_ghij
    jsr check_arm
    rts
.endproc

.proc check_arm
    ldx #0
ca_loop:
    lda rail_data::ghij_stack, x
    cmp #MINE_STACK_K
    bcc ca_no
    inx
    cpx #4
    bcc ca_loop
    lda #1
    sta mine_armed
    jsr paint_ghij
    rts
ca_no:
    lda #0
    sta mine_armed
    rts
.endproc

.proc paint_ghij
    ; G col18 row12
    ldx #0
    lda #RAIL_COL_LEFT
    sta draw_i
    lda #RAIL_ROW_TOP
    sta draw_j
    jsr paint_one
    ; H col20 row12
    ldx #1
    lda #RAIL_COL_RIGHT
    sta draw_i
    lda #RAIL_ROW_TOP
    sta draw_j
    jsr paint_one
    ; I col18 row14
    ldx #2
    lda #RAIL_COL_LEFT
    sta draw_i
    lda #RAIL_ROW_BOT
    sta draw_j
    jsr paint_one
    ; J col20 row14
    ldx #3
    lda #RAIL_COL_RIGHT
    sta draw_i
    lda #RAIL_ROW_BOT
    sta draw_j
    jmp paint_one
.endproc

; X = stack index, draw_i=col draw_j=row
.proc paint_one
    lda mine_armed
    bne po_mine
    lda rail_data::ghij_stack, x
    beq po_base
    ; stacked but not armed — show star light
    lda #SC_STAR
    jmp po_put
po_mine:
    lda #SC_MINE
    jmp po_put
po_base:
    ; restore elbow letter
    cpx #0
    beq po_g
    cpx #1
    beq po_h
    cpx #2
    beq po_i
    lda #SC_RAIL_J
    jmp po_put
po_g:
    lda #SC_RAIL_G
    jmp po_put
po_h:
    lda #SC_RAIL_H
    jmp po_put
po_i:
    lda #SC_RAIL_I
po_put:
    sta tmp0
    ldx draw_i
    ldy draw_j
    lda tmp0
    jsr screen_put_xy
    lda #COL_ORANGE
    ldx draw_i
    ldy draw_j
    jmp screen_color_xy
.endproc

.proc draw_dot
    ldx cargo_col
    ldy cargo_row
    lda #SC_CARGO_DOT
    jsr screen_put_xy
    lda #COL_YELLOW
    ldx cargo_col
    ldy cargo_row
    jmp screen_color_xy
.endproc

.proc erase_dot
    ; restore rail char under cargo (approx by row/col)
    lda cargo_row
    cmp #RAIL_ROW_TOP
    beq ed_top
    cmp #RAIL_ROW_BOT
    beq ed_bot
    cmp #RAIL_ROW_MID
    beq ed_mid
    lda #SC_SPACE
    jmp ed_put
ed_top:
    lda #SC_RAIL_D
    jmp ed_put
ed_bot:
    lda #SC_RAIL_F
    jmp ed_put
ed_mid:
    lda cargo_col
    cmp #RAIL_COL_LEFT
    beq ed_a
    cmp #RAIL_COL_RIGHT
    beq ed_c
    lda #SC_RAIL_E
    jmp ed_put
ed_a:
    lda #SC_RAIL_A
    jmp ed_put
ed_c:
    lda #SC_RAIL_C
ed_put:
    ldx cargo_col
    ldy cargo_row
    jsr screen_put_xy
    lda #COL_GRAY
    ldx cargo_col
    ldy cargo_row
    jmp screen_color_xy
.endproc

; If mines armed and player in centre → lose life
.proc check_player_mine
    lda mine_armed
    beq cpm_done
    jsr player::at_intersection
    bcc cpm_done
    ; Clear stacks / disarm
    jsr clear_stacks
    lda lives
    beq cpm_go
    dec lives
    lda #1
    sta hud_status_dirty
    lda lives
    beq cpm_go
    rts
cpm_go:
    lda #MODE_GAME_OVER
    sta pending_mode
cpm_done:
    rts
.endproc

.proc clear_stacks
    lda #0
    sta mine_armed
    sta cargo_active
    ldx #0
cs_loop:
    sta rail_data::ghij_stack, x
    inx
    cpx #4
    bcc cs_loop
    jsr paint_ghij
    rts
.endproc

.endscope
