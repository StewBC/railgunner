; Common 24-slot graphical-object pool and IRQ event handoff.

.segment "OBJECTS"
.scope objects

; $C000: core page (ten 24-byte indexed arrays).
obj_flags:          .res OBJECT_CAPACITY
obj_kind:           .res OBJECT_CAPACITY
obj_x_frac:         .res OBJECT_CAPACITY
obj_x_lo:           .res OBJECT_CAPACITY
obj_x_hi:           .res OBJECT_CAPACITY
obj_y_frac:         .res OBJECT_CAPACITY
obj_y_int:          .res OBJECT_CAPACITY
obj_sprite_ptr:     .res OBJECT_CAPACITY
obj_sprite_color:   .res OBJECT_CAPACITY
obj_sprite_attr:    .res OBJECT_CAPACITY
.align 256

; $C100: future motion and main-thread event page.
obj_vx_frac:        .res OBJECT_CAPACITY
obj_vx_lo:          .res OBJECT_CAPACITY
obj_vx_hi:          .res OBJECT_CAPACITY
obj_vy_frac:        .res OBJECT_CAPACITY
obj_vy_int:         .res OBJECT_CAPACITY
obj_hitbox_id:      .res OBJECT_CAPACITY
obj_pending_events: .res OBJECT_CAPACITY
obj_anim_state:     .res OBJECT_CAPACITY
obj_user:           .res OBJECT_CAPACITY
obj_reserved:       .res OBJECT_CAPACITY
.align 256

; $C200: event banks, allocation state, HW ownership, and frame scalars.
irq_events_0:       .res OBJECT_CAPACITY
irq_events_1:       .res OBJECT_CAPACITY
free_stack:         .res OBJECT_FREE_CAPACITY
free_count:         .res 1
hw_owner:           .res MUX_HW_COUNT
hw_interest:        .res MUX_HW_COUNT
irq_bg_lane_mask:   .res 1
irq_ss_lane_mask:   .res 1
irq_event_write_id: .res 1
irq_event_read_id:  .res 1
irq_event_read_ready: .res 1

mux_front_plan:     .res 1
mux_back_plan:      .res 1
mux_ready_plan:     .res 1
mux_plan_ready:     .res 1
mux_build_valid_plan: .res 1
mux_front_command_count: .res 1
mux_front_ref0:     .res 1
mux_front_ref1:     .res 1
mux_front_ref2:     .res 1

video_standard:     .res 1
display_hz:         .res 1
logic_accum:        .res 1
logic_ticks_pending: .res 1
irq_frame_seq:      .res 1
main_frame_seq:     .res 1

mux_plan_miss:      .res 1
mux_event_overrun:  .res 1
mux_last_error:     .res 1
mux_build_seq:      .res 1
mux_lane_last:      .res MUX_HW_COUNT
mux_objects_dirty:  .res 1

.align 256

.endscope
.segment "CODE"

.scope objects

; Clear the entire $C000-$C8FF reserved runtime area, establish fixed player
; slot 0, and build a stack that allocates slots 1,2,3,... in that order.
.proc init
    lda #0
    sta ptr_lo
    lda #>OBJECT_STATE
    sta ptr_hi
    ldx #9
clear_page:
    ldy #0
    lda #0
:
    sta (ptr_lo), y
    iny
    bne :-
    inc ptr_hi
    dex
    bne clear_page

    lda #OBJF_ALLOCATED
    sta obj_flags
    lda #OBJ_PLAYER
    sta obj_kind
    lda #SPR_PTR_PLAYER_0
    sta obj_sprite_ptr

    ; stack[22]=1 ... stack[0]=23; pop returns the lowest fresh slot.
    ldx #0
    lda #OBJECT_LAST
fill_stack:
    sta free_stack, x
    sec
    sbc #1
    inx
    cpx #OBJECT_FREE_CAPACITY
    bne fill_stack
    lda #OBJECT_FREE_CAPACITY
    sta free_count

    lda #OBJECT_NONE
    ldx #0
clear_owners:
    sta hw_owner, x
    inx
    cpx #MUX_HW_COUNT
    bne clear_owners

    lda #1
    sta mux_back_plan
    sta mux_objects_dirty
    lda #OBJECT_NONE
    sta mux_ready_plan
    sta mux_build_valid_plan
    rts
.endproc

; Clear every per-object field for X. Caller establishes flags afterward.
.proc clear_slot
    lda #0
    sta obj_flags, x
    sta obj_kind, x
    sta obj_x_frac, x
    sta obj_x_lo, x
    sta obj_x_hi, x
    sta obj_y_frac, x
    sta obj_y_int, x
    sta obj_sprite_ptr, x
    sta obj_sprite_color, x
    sta obj_sprite_attr, x
    sta obj_vx_frac, x
    sta obj_vx_lo, x
    sta obj_vx_hi, x
    sta obj_vy_frac, x
    sta obj_vy_int, x
    sta obj_hitbox_id, x
    sta obj_pending_events, x
    sta obj_anim_state, x
    sta obj_user, x
    sta obj_reserved, x
    sta irq_events_0, x
    sta irq_events_1, x
    rts
.endproc

; Output: C clear and X=slot; C set and A=OBJ_ERR_POOL_FULL.
.proc alloc
    lda free_count
    beq pool_full
    dec free_count
    ldy free_count
    ldx free_stack, y
    jsr clear_slot
    lda #OBJF_ALLOCATED
    sta obj_flags, x
    lda #1
    sta mux_objects_dirty
    clc
    rts
pool_full:
    lda #OBJ_ERR_POOL_FULL
    sec
    rts
.endproc

; X=slot. Destruction is deferred until no front/pending plan references it.
.proc retire
    cpx #0
    bne retire_regular
    lda #OBJ_ERR_PLAYER_FIXED
    sec
    rts
retire_regular:
    lda obj_flags, x
    and #OBJF_ALLOCATED
    beq retire_done
    lda obj_flags, x
    and #%11111101                  ; clear OBJF_RENDER
    ora #OBJF_RETIRING
    sta obj_flags, x
    lda #1
    sta mux_objects_dirty
retire_done:
    clc
    rts
.endproc

; Call after changing any render-visible field in an allocated slot. Movement
; helpers will do this internally when they are added in a later round.
.proc mark_dirty
    lda #1
    sta mux_objects_dirty
    rts
.endproc

; C set when slot X is referenced by the current front plan or a plan waiting
; for the next line-0 swap. Clobbers A,Y,mux_bit.
.proc slot_referenced
    lda object_slot_bit, x
    sta mux_bit
    ldy object_slot_byte, x

    lda mux_front_ref0, y
    and mux_bit
    bne referenced

    lda mux_plan_ready
    beq not_referenced
    lda mux_ready_plan
    beq check_ready_0
    lda sprite_mux_data::plan1_ref0, y
    and mux_bit
    bne referenced
    clc
    rts
check_ready_0:
    lda sprite_mux_data::plan0_ref0, y
    and mux_bit
    bne referenced
not_referenced:
    clc
    rts
referenced:
    sec
    rts
.endproc

; Clear OBJF_RENDER on every allocated slot and force a mux rebuild so VIC
; sprites disable on frontend screens (game over, title, etc.).
.proc hide_all
    ldx #0
hide_loop:
    lda obj_flags, x
    and #OBJF_ALLOCATED
    beq hide_next
    lda obj_flags, x
    and #%11111101                  ; clear OBJF_RENDER
    sta obj_flags, x
hide_next:
    inx
    cpx #OBJECT_CAPACITY
    bne hide_loop
    lda #1
    sta mux_objects_dirty
    rts
.endproc

; Return retired, no-longer-displayed slots to the free stack.
.proc reap
    ldx #1
reap_loop:
    lda obj_flags, x
    and #(OBJF_ALLOCATED | OBJF_RETIRING)
    cmp #(OBJF_ALLOCATED | OBJF_RETIRING)
    bne reap_next
    jsr slot_referenced
    bcs reap_next
    jsr clear_slot
    ldy free_count
    txa
    sta free_stack, y
    inc free_count
reap_next:
    inx
    cpx #OBJECT_CAPACITY
    bne reap_loop
    rts
.endproc

; Merge a stable completed IRQ bank into main-owned sticky events. The IRQ does
; not swap banks while irq_event_read_ready remains set.
.proc drain_irq_events
    lda irq_event_read_ready
    beq drain_done
    lda irq_event_read_id
    beq drain_bank_0

    ldx #0
drain_1_loop:
    lda obj_pending_events, x
    ora irq_events_1, x
    sta obj_pending_events, x
    lda #0
    sta irq_events_1, x
    inx
    cpx #OBJECT_CAPACITY
    bne drain_1_loop
    jmp drain_ack

drain_bank_0:
    ldx #0
drain_0_loop:
    lda obj_pending_events, x
    ora irq_events_0, x
    sta obj_pending_events, x
    lda #0
    sta irq_events_0, x
    inx
    cpx #OBJECT_CAPACITY
    bne drain_0_loop

drain_ack:
    php
    sei
    lda #0
    sta irq_event_read_ready
    plp
drain_done:
    rts
.endproc

; Tables avoid variable shifts in retirement/reference checks.
object_slot_byte:
    .repeat 8
        .byte 0
    .endrepeat
    .repeat 8
        .byte 1
    .endrepeat
    .repeat 8
        .byte 2
    .endrepeat

object_slot_bit:
    .repeat 3
        .byte $01,$02,$04,$08,$10,$20,$40,$80
    .endrepeat

.endscope
