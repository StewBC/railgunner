; C cargo → orange parcel sprite → one of GHIJ (round-robin) → arm mines.
; Stacks live in rail_data::ghij_stack[4] (rail.asm OBJECTS segment).
; Four hubs at ≥ K arm mines; detonate when player enters centre while armed.

.segment "CODE_HI"
.scope cargo

; G H I J sprite top-left (disc centred on hub chars)
cargo_tgt_x_lo:
    .byte CARGO_TGT_X0, CARGO_TGT_X1, CARGO_TGT_X0, CARGO_TGT_X1
cargo_tgt_x_hi:
    .byte 0, 0, 0, 0
cargo_tgt_y:
    .byte CARGO_TGT_Y0, CARGO_TGT_Y0, CARGO_TGT_Y1, CARGO_TGT_Y1

; ---------------------------------------------------------------------------
.proc init
    lda #$FF
    sta cargo_slot
    sta ghij_last                   ; no deposit yet
    lda #0
    sta cargo_target
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

; X = C drone that reached rail. Spawn cargo sprite at impact, or deposit if busy.
.proc on_c_impact
    lda player_dead
    beq oci_live
    rts                             ; dying: no cargo
oci_live:
    lda cargo_slot
    cmp #$FF
    beq oci_start
    jmp deposit_centre              ; already in flight — instant deposit

oci_start:
    stx score_work0                 ; save drone slot (alloc clobbers X)
    ; Claim next GHIJ now so concurrent pressure deposits skip this tile
    lda ghij_rr
    sta cargo_target
    tax
    inx
    txa
    and #3
    sta ghij_rr

    jsr objects::alloc
    bcs oci_instant

    stx cargo_slot
    lda #OBJ_BONUS                  ; front priority (parcel class); not a drone
    sta objects::obj_kind, x
    lda #SPR_PTR_CARGO
    sta objects::obj_sprite_ptr, x
    lda #SPR_COLOR_CARGO
    sta objects::obj_sprite_color, x
    lda #0                          ; hires disc — own colour only
    sta objects::obj_sprite_attr, x

    lda #0
    sta objects::obj_x_frac, x
    sta objects::obj_y_frac, x
    sta objects::obj_vx_frac, x
    sta objects::obj_vx_lo, x
    sta objects::obj_vx_hi, x
    sta objects::obj_vy_frac, x
    sta objects::obj_vy_int, x

    ; Copy spawn pose from the C drone
    ldy score_work0
    lda objects::obj_x_lo, y
    sta objects::obj_x_lo, x
    lda objects::obj_x_hi, y
    and #1
    sta objects::obj_x_hi, x
    lda objects::obj_y_int, y
    sta objects::obj_y_int, x

    lda #(OBJF_ALLOCATED | OBJF_RENDER)
    sta objects::obj_flags, x
    jsr objects::mark_dirty
    rts

oci_instant:
    ; Pool full: undo claim and deposit immediately onto claimed tile
    lda cargo_target
    sta ghij_rr
    jmp deposit_centre
.endproc

; ---------------------------------------------------------------------------
.proc update
    lda cargo_slot
    cmp #$FF
    beq cu_done
    tax
    lda objects::obj_flags, x
    and #OBJF_ALLOCATED
    bne cu_move
    ; slot lost
    lda #$FF
    sta cargo_slot
    rts

cu_move:
    jsr step_toward_target
    bcs cu_arrived
    jsr objects::mark_dirty
cu_done:
    rts
cu_arrived:
    jsr despawn_sprite
    jmp deposit_target
.endproc

; Move cargo toward cargo_tgt_*[cargo_target]. C set = arrived (within step).
.proc step_toward_target
    ldx cargo_slot
    ldy cargo_target

    ; --- X axis ---
    lda objects::obj_x_hi, x
    cmp cargo_tgt_x_hi, y
    bne st_x_hi
    lda objects::obj_x_lo, x
    cmp cargo_tgt_x_lo, y
    beq st_y
    bcc st_x_inc
    ; x > target: dec
    lda objects::obj_x_lo, x
    sec
    sbc #CARGO_SPEED
    sta objects::obj_x_lo, x
    lda objects::obj_x_hi, x
    sbc #0
    and #1
    sta objects::obj_x_hi, x
    ; clamp if overshot
    lda objects::obj_x_hi, x
    cmp cargo_tgt_x_hi, y
    bne st_y
    lda objects::obj_x_lo, x
    cmp cargo_tgt_x_lo, y
    bcs st_y
    lda cargo_tgt_x_lo, y
    sta objects::obj_x_lo, x
    lda cargo_tgt_x_hi, y
    sta objects::obj_x_hi, x
    jmp st_y
st_x_inc:
    lda objects::obj_x_lo, x
    clc
    adc #CARGO_SPEED
    sta objects::obj_x_lo, x
    lda objects::obj_x_hi, x
    adc #0
    and #1
    sta objects::obj_x_hi, x
    lda objects::obj_x_hi, x
    cmp cargo_tgt_x_hi, y
    bne st_y
    lda objects::obj_x_lo, x
    cmp cargo_tgt_x_lo, y
    bcc st_y
    beq st_y
    lda cargo_tgt_x_lo, y
    sta objects::obj_x_lo, x
    lda cargo_tgt_x_hi, y
    sta objects::obj_x_hi, x
    jmp st_y
st_x_hi:
    ; hi differs: if our hi < target hi, increase; else decrease
    bcc st_x_inc
    lda objects::obj_x_lo, x
    sec
    sbc #CARGO_SPEED
    sta objects::obj_x_lo, x
    lda objects::obj_x_hi, x
    sbc #0
    and #1
    sta objects::obj_x_hi, x

st_y:
    ldy cargo_target
    lda objects::obj_y_int, x
    cmp cargo_tgt_y, y
    beq st_check
    bcc st_y_inc
    sec
    sbc #CARGO_SPEED
    sta objects::obj_y_int, x
    cmp cargo_tgt_y, y
    bcs st_check
    lda cargo_tgt_y, y
    sta objects::obj_y_int, x
    jmp st_check
st_y_inc:
    clc
    adc #CARGO_SPEED
    sta objects::obj_y_int, x
    cmp cargo_tgt_y, y
    bcc st_check
    beq st_check
    lda cargo_tgt_y, y
    sta objects::obj_y_int, x

st_check:
    ; Arrived when both axes match
    ldy cargo_target
    lda objects::obj_x_hi, x
    cmp cargo_tgt_x_hi, y
    bne st_moving
    lda objects::obj_x_lo, x
    cmp cargo_tgt_x_lo, y
    bne st_moving
    lda objects::obj_y_int, x
    cmp cargo_tgt_y, y
    bne st_moving
    sec
    rts
st_moving:
    clc
    rts
.endproc

.proc despawn_sprite
    lda cargo_slot
    cmp #$FF
    beq ds_done
    tax
    jsr objects::retire_and_try_free
    lda #$FF
    sta cargo_slot
ds_done:
    rts
.endproc

; Instant deposit onto next RR tile (busy cargo / pressure). Advances ghij_rr.
.proc deposit_centre
    ldx ghij_rr
    jsr stack_one
    stx ghij_last
    inx
    txa
    and #3
    sta ghij_rr
    jsr paint_ghij
    jmp check_arm
.endproc

; Sprite arrived: deposit onto the tile claimed at spawn (cargo_target).
.proc deposit_target
    ldx cargo_target
    jsr stack_one
    stx ghij_last
    jsr paint_ghij
    jmp check_arm
.endproc

; X = stack index. Inc ghij_stack[X] (sat 255). Clobbers A; preserves X.
.proc stack_one
    lda rail_data::ghij_stack, x
    clc
    adc #1
    bcc so_store
    lda #255
so_store:
    sta rail_data::ghij_stack, x
    rts
.endproc

; Level clear reward: peel the most recently stacked cargo (one unit).
; e.g. G,H,I each at 1 → restore I. No-op if nothing stacked.
.proc reward_level_clear
    lda ghij_last
    cmp #4
    bcs rlc_scan                    ; $FF or garbage → find any non-empty
    tax
    lda rail_data::ghij_stack, x
    bne rlc_dec
rlc_scan:
    ; Walk G..J for a non-empty stack (prefer highest index = later RR)
    ldx #3
rlc_find:
    lda rail_data::ghij_stack, x
    bne rlc_dec
    dex
    bpl rlc_find
    rts                             ; nothing to remove
rlc_dec:
    dec rail_data::ghij_stack, x
    stx ghij_last                   ; still valid if count left; else ok
    lda rail_data::ghij_stack, x
    bne rlc_paint
    lda #$FF
    sta ghij_last
rlc_paint:
    jsr paint_ghij
    jmp check_arm                   ; may disarm mines if we broke a full set
.endproc

; All four hub tiles at ≥ K → arm for centre-pass detonate.
; Glyphs are per-tile in paint_ghij (not gated on mine_armed).
; Clink only on 0→1 arm edge (not every re-check while armed).
.proc check_arm
    lda mine_armed
    pha                             ; prior arm state
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
    pla
    bne ca_done                     ; already armed
    lda #SFX_MINE
    jsr sfx::play
ca_done:
    rts
ca_no:
    lda #0
    sta mine_armed
    pla                             ; discard prior
    rts
.endproc

; Blow the player: clear hub, start death sequence (respawn or game over).
; lives = reserve only. Die with 0 reserve → game over; else respawn peels one.
; Called on centre-pass while mine_armed (not when the fourth stack lands).
.proc detonate
    lda player_dead
    bne det_done                    ; already dying
    lda mine_armed
    beq det_done                    ; not armed (e.g. clear wiped hubs first)
    jsr clear_stacks
    lda lives
    beq det_fatal                   ; no reserve → last ship just died
    jsr player::begin_death_respawn
det_done:
    rts
det_fatal:
    jsr player::begin_death_fatal
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

; X = stack index 0..3 (G,H,I,J), draw_i=col draw_j=row
; Per-tile: stack ≥ K → mine glyph as soon as cargo lands; else hub.
; Colour always COL_RAIL (no orange tint). mine_armed is detonate-only.
.proc paint_one
    lda rail_data::ghij_stack, x
    cmp #MINE_STACK_K
    bcc po_base
    lda hub_mine_glyph, x
    jmp po_put
po_base:
    lda hub_glyph, x
po_put:
    sta tmp0
    ldx draw_i
    ldy draw_j
    lda tmp0
    jsr screen_put_xy
    ldx draw_i
    ldy draw_j
    lda #COL_RAIL
    jmp screen_color_xy
.endproc

; G,H,I,J hub / mine glyphs (screen codes)
hub_glyph:
    .byte SC_RAIL_G, SC_RAIL_H, SC_RAIL_I, SC_RAIL_J
hub_mine_glyph:
    .byte SC_RAIL_G_MINE, SC_RAIL_H_MINE, SC_RAIL_I_MINE, SC_RAIL_J_MINE

.proc clear_stacks
    lda #0
    sta mine_armed
    jsr despawn_sprite
    lda #0
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
