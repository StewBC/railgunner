; Gameplay collision — COLLISION_MODE in const.asm:
;   0 = HW only  ($D01F / OBJE_BG kills; no software authority)
;   1 = hybrid   (latch + soft; yellow/brown vs green/blue mismatch)
;   2 = soft only
;
; Y-arrival in drones.asm still retires at the rail without latch.

.scope collision

HIT_NONE        = 0
HIT_BULLET      = 1
HIT_RAIL        = 2

HIT_X0          = 0
HIT_X1          = 23
HIT_Y0          = 3
HIT_Y1          = 16

; ---------------------------------------------------------------------------
.proc update
    ldx #1
upd_loop:
    lda objects::obj_flags, x
    and #(OBJF_ALLOCATED | OBJF_RETIRING)
    cmp #OBJF_ALLOCATED
    bne upd_next
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_A
    bcc upd_next
    cmp #OBJ_BONUS
    bcs upd_next

    stx mode_state

    ; c64m: conditions need .eq/.ne (not "=") or the wrong modes get assembled in.
    .if COLLISION_MODE .eq 0
    jsr mode_hw_only
    .endif
    .if COLLISION_MODE .eq 1
    jsr mode_hybrid
    .endif
    .if COLLISION_MODE .eq 2
    jsr mode_soft_only
    .endif

    ldx mode_state
    lda objects::obj_pending_events, x
    and #($FF ^ OBJE_BG)
    sta objects::obj_pending_events, x

upd_next:
    inx
    cpx #OBJECT_CAPACITY
    bne upd_loop
    jsr drones::ensure_slice_mover
    rts
.endproc

; Mode 0: $D01F latch = candidate only. Disambiguate with software:
;   soft bullet AABB hit → score, consume that bullet, retire drone
;   else → rail arrival (retire, no score)
; Old center-column bullet search missed left-wing half-cell lanes (same
; char col as center only on the right half of the 24px sprite).
.proc mode_hw_only
    ldx mode_state
    lda objects::obj_pending_events, x
    and #OBJE_BG
    beq hw_done
    jsr test_bullets                ; C clear + X = bullet slot
    bcs hw_rail
    jsr bullets::destroy
    jsr score::add_hit
    ldx mode_state
    jsr objects::retire_and_try_free
    rts
hw_rail:
    jsr rail_arrival_retire         ; C blast if needed, then free
hw_done:
    rts
.endproc

; Rail path (no bullet): C → player; A/B → rail cells; then retire.
.proc rail_arrival_retire
    ldx mode_state
    lda objects::obj_kind, x
    cmp #OBJ_DRONE_C
    beq ra_c
    cmp #OBJ_DRONE_A
    beq ra_ab
    cmp #OBJ_DRONE_B
    beq ra_ab
    jmp ra_free
ra_c:
    txa
    pha
    jsr player::apply_c_blast_full
    pla
    tax
    jmp ra_free
ra_ab:
    txa
    pha
    jsr rail::apply_ab_hit
    pla
    tax
ra_free:
    jsr objects::retire_and_try_free
    rts
.endproc

.proc mode_hybrid
    ldx mode_state
    lda objects::obj_pending_events, x
    and #OBJE_BG
    sta mux_key
    jsr eval_soft
    sta mux_forbidden
    lda mux_key
    beq hy_nolatch
    lda mux_forbidden
    bne hy_agree
    jsr diag_fp_border
    rts
hy_agree:
    jsr apply_soft_hit
    rts
hy_nolatch:
    lda mux_forbidden
    beq hy_done
    jsr diag_fn_border
hy_done:
    rts
.endproc

.proc mode_soft_only
    jsr eval_soft
    sta mux_forbidden
    jsr apply_soft_hit
    rts
.endproc

.proc eval_soft
    ldx mode_state
    jsr test_bullets
    bcs es_rail
    stx mux_key_prio
    lda #HIT_BULLET
    rts
es_rail:
    ldx mode_state
    jsr test_rail
    bcs es_none
    lda #HIT_RAIL
    rts
es_none:
    lda #HIT_NONE
    rts
.endproc

.proc apply_soft_hit
    lda mux_forbidden
    cmp #HIT_BULLET
    beq as_bullet
    cmp #HIT_RAIL
    beq as_rail
    rts
as_bullet:
    ldx mux_key_prio
    jsr bullets::destroy
    jsr score::add_hit
    ldx mode_state
    jsr objects::retire_and_try_free
    rts
as_rail:
    jsr rail_arrival_retire
    rts
.endproc

.proc diag_fp_border
    lda coll_fp_phase
    eor #1
    sta coll_fp_phase
    beq fp_brown
    lda #COL_YELLOW
    sta VIC_BORDER
    rts
fp_brown:
    lda #COL_BROWN
    sta VIC_BORDER
    rts
.endproc

.proc diag_fn_border
    lda coll_fn_phase
    eor #1
    sta coll_fn_phase
    beq fn_blue
    lda #COL_GREEN
    sta VIC_BORDER
    rts
fn_blue:
    lda #COL_LT_BLUE
    sta VIC_BORDER
    rts
.endproc

; ---------------------------------------------------------------------------
; Pixel AABB: each active bullet vs drone mode_state hitbox.
; C clear + X=bullet slot on hit; C set if none.
; ---------------------------------------------------------------------------
.proc test_bullets
    ; Build drone hitbox in mux_i..mux_k / draw_* as pixel coords
    ; hit_x0 = obj_x + HIT_X0 (16-bit)
    ldx mode_state
    lda objects::obj_x_lo, x
    clc
    adc #HIT_X0
    sta mux_i                       ; hit_x0 lo
    lda objects::obj_x_hi, x
    adc #0
    sta mux_j                       ; hit_x0 hi

    lda objects::obj_x_lo, x
    clc
    adc #HIT_X1
    sta mux_k                       ; hit_x1 lo
    lda objects::obj_x_hi, x
    adc #0
    sta mux_cursor                  ; hit_x1 hi

    lda objects::obj_y_int, x
    clc
    adc #HIT_Y0
    sta draw_i                      ; hit_y0
    lda objects::obj_y_int, x
    clc
    adc #HIT_Y1
    sta draw_j                      ; hit_y1

    ldx #0
    jmp tb_loop
tb_next:
    inx
    cpx #BULLET_MAX
    bne tb_loop
    sec
    rts

tb_loop:
    lda bullets::bullet_active, x
    beq tb_next
    lda bullets::bullet_dir, x
    cmp #SPR_DIR_UP
    beq tb_vert
    cmp #SPR_DIR_DOWN
    beq tb_vert
    jmp tb_next

tb_vert:
    ; Bullet 2×2 top-left: X = 24 + col*8 + half*4, Y = 50 + row*8 + phase*2
    lda bullets::bullet_col, x
    sta tmp0
    lda #0
    sta tmp1
    asl tmp0
    rol tmp1
    asl tmp0
    rol tmp1
    asl tmp0
    rol tmp1                        ; col*8
    lda tmp0
    clc
    adc #24
    sta tmp0
    lda tmp1
    adc #0
    sta tmp1
    lda bullets::bullet_half, x
    beq tb_half0
    lda tmp0
    clc
    adc #4
    sta tmp0
    lda tmp1
    adc #0
    sta tmp1
tb_half0:
    ; tmp0/1 = bullet x0; bullet x1 = x0+1 (2px wide)

    lda bullets::bullet_row, x
    asl a
    asl a
    asl a
    clc
    adc #50
    sta tmp2
    lda bullets::bullet_phase, x
    asl a
    clc
    adc tmp2
    sta tmp2                        ; bullet y0; y1 = y0+1

    ; Rect overlap: bx0<=hit_x1 && bx1>=hit_x0 && by0<=hit_y1 && by1>=hit_y0
    ; bx0 <= hit_x1
    lda mux_cursor
    cmp tmp1
    bcc tb_next_j
    bne tb_bx1
    lda mux_k
    cmp tmp0
    bcc tb_next_j
tb_bx1:
    ; bx1 = bx0+1 >= hit_x0  =>  bx0+1 >= hit_x0  => bx0 >= hit_x0-1
    ; simpler: bx0+1 >= hit_x0
    lda tmp0
    clc
    adc #1
    sta print_ptr_lo
    lda tmp1
    adc #0
    sta print_ptr_hi
    lda print_ptr_hi
    cmp mux_j
    bcc tb_next_j
    bne tb_by
    lda print_ptr_lo
    cmp mux_i
    bcc tb_next_j
tb_by:
    ; by0 <= hit_y1
    lda tmp2
    cmp draw_j
    beq tb_by1
    bcs tb_next_j
tb_by1:
    ; by1 = by0+1 >= hit_y0
    lda tmp2
    clc
    adc #1
    cmp draw_i
    bcc tb_next_j
tb_hit:
    clc
    rts
tb_next_j:
    jmp tb_next
.endproc

; ---------------------------------------------------------------------------
; Rail: any dash/vbar under tight hitbox char cells. C clear = rail hit.
; ---------------------------------------------------------------------------
.proc test_rail
    ldx mode_state
    ; col0 from x+HIT_X0, col1 from x+HIT_X1
    lda objects::obj_x_lo, x
    clc
    adc #HIT_X0
    sta tmp0
    lda objects::obj_x_hi, x
    adc #0
    sta tmp1
    jsr px_to_col
    sta mux_cursor                  ; col0

    lda objects::obj_x_lo, x
    clc
    adc #HIT_X1
    sta tmp0
    lda objects::obj_x_hi, x
    adc #0
    sta tmp1
    jsr px_to_col
    sta mux_k                       ; col1

    lda objects::obj_y_int, x
    clc
    adc #HIT_Y0
    sec
    sbc #50
    bcc tr_r0z
    lsr a
    lsr a
    lsr a
    jmp tr_r0s
tr_r0z:
    lda #0
tr_r0s:
    sta mux_i                       ; row0

    lda objects::obj_y_int, x
    clc
    adc #HIT_Y1
    sec
    sbc #50
    bcc tr_r1z
    lsr a
    lsr a
    lsr a
    jmp tr_r1s
tr_r1z:
    lda #0
tr_r1s:
    cmp #SCREEN_H
    bcc tr_r1ok
    lda #SCREEN_H - 1
tr_r1ok:
    sta mux_j                       ; row1

    lda mux_i
tr_row:
    sta draw_j
    lda mux_cursor
    sta draw_i
tr_col:
    lda draw_i
    cmp #40
    bcs tr_cn
    lda draw_j
    cmp #SCREEN_H
    bcs tr_cn
    ldx draw_i
    ldy draw_j
    jsr screen_get_xy
    cmp #SC_RAIL_FIRST
    bcc tr_cn
    cmp #SC_RAIL_LAST + 1
    bcs tr_cn
    ; A–J rail tiles (placeholders or UDGs)
    jmp tr_hit
tr_cn:
    inc draw_i
    lda draw_i
    cmp mux_k
    bcc tr_col
    beq tr_col
    inc draw_j
    lda draw_j
    cmp mux_j
    bcc tr_row_more
    beq tr_row_more
    sec                             ; no rail
    rts
tr_row_more:
    lda mux_cursor
    sta draw_i
    lda draw_j
    jmp tr_row
tr_hit:
    clc
    rts
.endproc

; ---------------------------------------------------------------------------
.proc px_to_col
    lda tmp0
    sec
    sbc #24
    sta tmp0
    lda tmp1
    sbc #0
    bcc px0
    lsr a
    ror tmp0
    lsr a
    ror tmp0
    lsr a
    ror tmp0
    lda tmp0
    cmp #40
    bcc pxok
    lda #39
pxok:
    rts
px0:
    lda #0
    rts
.endproc

.endscope
