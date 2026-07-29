; Raster-time execution of immutable sprite-mux command plans.

.scope sprite_mux_irq

.proc init
    lda #0
    sta VIC_SPR_ENABLE
    sta VIC_SPR_X_MSB
    sta VIC_SPR_X_EXPAND
    sta VIC_SPR_Y_EXPAND
    sta VIC_SPR_MULTICOLOR
    sta VIC_SPR_BG_PRIORITY
    sta objects::irq_bg_lane_mask
    sta objects::irq_ss_lane_mask
    sta objects::irq_event_write_id
    sta objects::irq_event_read_ready
    sta objects::mux_front_plan
    sta objects::mux_plan_ready
    sta objects::logic_accum
    sta objects::logic_ticks_pending
    sta objects::irq_frame_seq
    sta objects::main_frame_seq
    sta irq_command_index
    lda #1
    sta objects::irq_event_read_id
    sta objects::mux_back_plan
    lda #OBJECT_NONE
    sta objects::mux_ready_plan
    sta objects::mux_build_valid_plan

    lda #1
    sta sprite_mux_data::plan0_valid
    lda #0
    sta sprite_mux_data::plan0_count
    sta sprite_mux_data::plan0_ref0
    sta sprite_mux_data::plan0_ref1
    sta sprite_mux_data::plan0_ref2
    jsr select_front_plan
    rts
.endproc

; Hardware IRQ entry has already saved A/X/Y in the KERNAL prologue.
; The command cursor, not the beam position, identifies the IRQ phase. A
; line-0 raster IRQ can be serviced after the beam has advanced past line 0;
; treating every nonzero current raster as a command then runs one stale
; entry beyond the completed plan. Coop snap-017 did exactly that: count=4,
; cursor=4, but stale command 4 briefly drew an off-right A drone at X=43 and
; replaced $D010 with zero, wrapping the player left too.
.proc handler
    lda #PROFILE_IRQ_ENTER
    sta objects::profile_marker
    lda #$01
    sta VIC_IRQ_STATUS
    ldx irq_command_index
    cpx objects::mux_front_command_count
    bcs handler_frame
    jmp command
handler_frame:
    jmp frame_start
.endproc

; Read-clear both hardware latches into software lane masks.
.proc capture_collision_latches
    lda VIC_SPR_BG_COLL
    ora objects::irq_bg_lane_mask
    sta objects::irq_bg_lane_mask
    lda VIC_SPR_SPR_COLL
    ora objects::irq_ss_lane_mask
    sta objects::irq_ss_lane_mask
    rts
.endproc

; X=hardware lane. Attribute accumulated bits to its old logical owner, then
; clear this lane from both software masks. Preserves X.
.proc attribute_lane
    lda #0
    sta irq_value_x                  ; temporary OBJE_* result
    lda sprite_mux_build::lane_bit_table, x
    sta irq_bit

    lda objects::irq_bg_lane_mask
    and irq_bit
    beq no_bg
    lda objects::hw_interest, x
    and #OBJE_BG
    beq no_bg
    lda irq_value_x
    ora #OBJE_BG
    sta irq_value_x
no_bg:
    lda objects::irq_ss_lane_mask
    and irq_bit
    beq no_ss
    lda objects::hw_interest, x
    and #OBJE_SS
    beq no_ss
    lda irq_value_x
    ora #OBJE_SS
    sta irq_value_x
no_ss:
    lda irq_value_x
    beq clear_lane_bits
    ldy objects::hw_owner, x
    cpy #OBJECT_NONE
    beq clear_lane_bits
    lda objects::irq_event_write_id
    beq event_bank_0
    lda objects::irq_events_1, y
    ora irq_value_x
    sta objects::irq_events_1, y
    jmp clear_lane_bits
event_bank_0:
    lda objects::irq_events_0, y
    ora irq_value_x
    sta objects::irq_events_0, y

clear_lane_bits:
    lda irq_clear_lane
    beq attribute_done
    lda sprite_mux_build::lane_clear_table, x
    and objects::irq_bg_lane_mask
    sta objects::irq_bg_lane_mask
    lda sprite_mux_build::lane_clear_table, x
    and objects::irq_ss_lane_mask
    sta objects::irq_ss_lane_mask
attribute_done:
    rts
.endproc

; Select metadata and patch all command absolute-indexed loads for front plan.
.proc select_front_plan
    lda objects::mux_front_plan
    beq select_plan_0
    lda sprite_mux_data::plan1_count
    sta objects::mux_front_command_count
    lda sprite_mux_data::plan1_ref0
    sta objects::mux_front_ref0
    lda sprite_mux_data::plan1_ref1
    sta objects::mux_front_ref1
    lda sprite_mux_data::plan1_ref2
    sta objects::mux_front_ref2
    lda #2
    bne patch_plan
select_plan_0:
    lda sprite_mux_data::plan0_count
    sta objects::mux_front_command_count
    lda sprite_mux_data::plan0_ref0
    sta objects::mux_front_ref0
    lda sprite_mux_data::plan0_ref1
    sta objects::mux_front_ref1
    lda sprite_mux_data::plan0_ref2
    sta objects::mux_front_ref2
    lda #0
patch_plan:
    sta irq_plan_delta                ; page delta: plan 0=0, plan 1=2
    clc
    adc #>sprite_mux_data::plan0_cmd_line
    sta command::load_cmd_line + 2
    lda irq_plan_delta
    clc
    adc #>sprite_mux_data::plan0_cmd_lane
    sta command::load_cmd_lane + 2
    lda irq_plan_delta
    clc
    adc #>sprite_mux_data::plan0_cmd_owner
    sta command::load_cmd_owner + 2
    lda irq_plan_delta
    clc
    adc #>sprite_mux_data::plan0_cmd_interest
    sta command::load_cmd_interest + 2
    lda irq_plan_delta
    clc
    adc #>sprite_mux_data::plan0_cmd_x_lo
    sta command::load_cmd_x + 2
    lda irq_plan_delta
    clc
    adc #>sprite_mux_data::plan0_cmd_y
    sta command::load_cmd_y + 2
    lda irq_plan_delta
    clc
    adc #>sprite_mux_data::plan0_cmd_ptr
    sta command::load_cmd_ptr + 2
    lda irq_plan_delta
    clc
    adc #>sprite_mux_data::plan0_cmd_color
    sta command::load_cmd_color + 2
    ; cmd_enable is not loaded in the IRQ (incremental $D015 — see command).
    lda irq_plan_delta
    clc
    adc #>sprite_mux_data::plan0_cmd_xmsb
    sta command::load_cmd_xmsb + 2

    lda irq_plan_delta
    clc
    adc #>sprite_mux_data::plan0_cmd_xexp
    sta command::load_cmd_xexp + 2
    lda irq_plan_delta
    clc
    adc #>sprite_mux_data::plan0_cmd_yexp
    sta command::load_cmd_yexp + 2
    lda irq_plan_delta
    clc
    adc #>sprite_mux_data::plan0_cmd_multi
    sta command::load_cmd_multi + 2
    lda irq_plan_delta
    clc
    adc #>sprite_mux_data::plan0_cmd_bgprio
    sta command::load_cmd_bgprio + 2
    rts
.endproc

; Rotate the completed IRQ event writer into a stable main-thread reader.
; drain_irq_events clears the read bank before acknowledging it, so the bank
; selected here as the new writer is already empty; IRQ time does no 24-byte
; clearing pass.
.proc rotate_event_banks
    lda objects::irq_event_read_ready
    beq rotate_allowed
    inc objects::mux_event_overrun
    rts
rotate_allowed:
    lda objects::irq_event_write_id
    sta objects::irq_event_read_id
    eor #1
    sta objects::irq_event_write_id
    lda #1
    sta objects::irq_event_read_ready
    rts
.endproc

; Raster line 0: retire prior ownership, rotate events/plans, and signal main.
.proc frame_start
    lda #PROFILE_IRQ_FRAME
    sta objects::profile_marker
    jsr capture_collision_latches
    lda objects::irq_bg_lane_mask
    ora objects::irq_ss_lane_mask
    sta irq_pending_mask
    lda #0
    sta irq_clear_lane
    ldx #0
flush_lane_loop:
    lda sprite_mux_build::lane_bit_table, x
    and irq_pending_mask
    beq flush_lane_next
    jsr attribute_lane
flush_lane_next:
    inx
    cpx #MUX_HW_COUNT
    bne flush_lane_loop

    lda #0
    sta objects::irq_bg_lane_mask
    sta objects::irq_ss_lane_mask
    sta VIC_SPR_ENABLE
    sta VIC_SPR_X_MSB
    sta VIC_SPR_X_EXPAND
    sta VIC_SPR_Y_EXPAND
    sta VIC_SPR_MULTICOLOR
    sta VIC_SPR_BG_PRIORITY
    sta irq_shadow_enable
    sta irq_shadow_xmsb
    sta irq_shadow_xexp
    sta irq_shadow_yexp
    sta irq_shadow_multi
    sta irq_shadow_bgprio
    ; Zero sprite X/Y so a missed enable bit or stale lane cannot paint
    ; last frame's geometry (dogfood: one-frame ghost / jump).
    ldx #0
clear_spr_xy:
    sta $D000, x
    inx
    cpx #16
    bne clear_spr_xy
    lda #OBJECT_NONE
    ldx #0
clear_owner_loop:
    sta objects::hw_owner, x
    lda #0
    sta objects::hw_interest, x
    lda #OBJECT_NONE
    inx
    cpx #MUX_HW_COUNT
    bne clear_owner_loop

    jsr rotate_event_banks

    lda objects::mux_plan_ready
    beq no_plan_swap
    lda objects::mux_front_plan
    sta objects::mux_back_plan
    lda objects::mux_ready_plan
    sta objects::mux_front_plan
    lda #0
    sta objects::mux_plan_ready
    lda #OBJECT_NONE
    sta objects::mux_ready_plan
    jmp plan_selected
no_plan_swap:
    inc objects::mux_plan_miss
plan_selected:
    jsr select_front_plan
    lda #0
    sta irq_command_index

    ; Normalize both standards to 50 gameplay ticks per real second.
    lda objects::logic_accum
    clc
    adc #LOGIC_HZ
    sta objects::logic_accum
    cmp objects::display_hz
    bcc no_logic_tick
    sec
    sbc objects::display_hz
    sta objects::logic_accum
    inc objects::logic_ticks_pending
no_logic_tick:
    inc objects::irq_frame_seq

    lda objects::mux_front_command_count
    beq next_frame_irq
    ldx #0
    jmp schedule_loaded_line
next_frame_irq:
    ; Compare is already zero. Rewriting the current line would retrigger it.
    lda #PROFILE_IRQ_EXIT
    sta objects::profile_marker
    jmp KERNAL_IRQ_EXIT
schedule_loaded_line:
    ; Patched to current plan in select_front_plan.
    jmp command::schedule_line_for_x
.endproc

; One timed lane-load command.
.proc command
    ; command can be entered directly from schedule_run_now when the next
    ; compare is already at/past the beam. Re-ack here as well as in handler:
    ; programming an on-beam compare can latch a new raster source during the
    ; catch-up chain. Leaving it pending makes RTI immediately re-enter the IRQ
    ; after the plan is complete (stale command before the cursor guard;
    ; premature frame_start after it). Coop snap-019 f1210/1221/1222/1228-1246.
    lda #PROFILE_IRQ_COMMAND
    sta objects::profile_marker
    lda #$01
    sta VIC_IRQ_STATUS
    jsr capture_collision_latches
    ldx irq_command_index
load_cmd_lane:
    lda sprite_mux_data::plan0_cmd_lane, x
    sta irq_lane
    tax
    lda #1
    sta irq_clear_lane
    lda sprite_mux_build::lane_bit_table, x
    sta irq_bit
    lda objects::irq_bg_lane_mask
    ora objects::irq_ss_lane_mask
    and irq_bit
    beq old_lane_attributed
    jsr attribute_lane
old_lane_attributed:

    ; Disable the old lane before changing any of its registers.
    lda sprite_mux_build::lane_clear_table, x
    and irq_shadow_enable
    sta irq_shadow_enable
    sta VIC_SPR_ENABLE
    ; Park Y at 0 while reprogramming so a mid-handler glitch cannot show
    ; the previous occupant at the old Y with a partial enable mask.
    txa
    asl a
    tay
    lda #0
    sta $D001, y
    lda #OBJECT_NONE
    sta objects::hw_owner, x
    lda #0
    sta objects::hw_interest, x

    ldx irq_command_index
load_cmd_owner:
    lda sprite_mux_data::plan0_cmd_owner, x
    sta irq_owner
load_cmd_interest:
    lda sprite_mux_data::plan0_cmd_interest, x
    sta irq_interest
load_cmd_x:
    lda sprite_mux_data::plan0_cmd_x_lo, x
    sta irq_value_x
load_cmd_y:
    lda sprite_mux_data::plan0_cmd_y, x
    sta irq_value_y
load_cmd_ptr:
    lda sprite_mux_data::plan0_cmd_ptr, x
    sta irq_value_ptr
load_cmd_color:
    lda sprite_mux_data::plan0_cmd_color, x
    sta irq_value_color

    ; All VIC targets are lane-indexed: ptr/color at +lane, X/Y at +(lane*2).
    ; Indexed stores cost +1 cycle each vs absolute, but drop the cmp ladder
    ; (~30 cycles worst case) and ~100 bytes of near-identical writers.
    ldx irq_lane
    lda irq_value_ptr
    sta SPRITE_PTR_BASE, x
    lda irq_value_color
    sta VIC_SPR_COLOR0, x
    txa
    asl a                           ; X = lane*2 for $D000/$D001 pairs
    tax
    lda irq_value_x
    sta $D000, x
    lda irq_value_y
    sta $D001, x

    ldx irq_command_index
load_cmd_xmsb:
    lda sprite_mux_data::plan0_cmd_xmsb, x
    sta irq_shadow_xmsb
    sta VIC_SPR_X_MSB
load_cmd_xexp:
    lda sprite_mux_data::plan0_cmd_xexp, x
    sta irq_shadow_xexp
    sta VIC_SPR_X_EXPAND
load_cmd_yexp:
    lda sprite_mux_data::plan0_cmd_yexp, x
    sta irq_shadow_yexp
    sta VIC_SPR_Y_EXPAND
load_cmd_multi:
    lda sprite_mux_data::plan0_cmd_multi, x
    sta irq_shadow_multi
    sta VIC_SPR_MULTICOLOR
load_cmd_bgprio:
    lda sprite_mux_data::plan0_cmd_bgprio, x
    sta irq_shadow_bgprio
    sta VIC_SPR_BG_PRIORITY

    ldx irq_lane
    lda irq_owner
    sta objects::hw_owner, x
    lda irq_interest
    sta objects::hw_interest, x

    ; Enable is rebuilt incrementally here, not replaced from plan cmd_enable.
    ; Builder only ORs lane bits (monotonic); frame start clears $D015. Live
    ; shadow = clear the lane we rewrite (above) + OR its bit after program.
    ;
    ; Replacing from plan0_cmd_enable was unsafe when that byte disagreed with
    ; lanes already programmed this frame. Coop snap-013 ~f1160: en $05→$0B
    ; dropped player s2 while Y/ptr still held the E-rail ship; same command
    ; rewrote s0 to C-drone $C2 (brown pop / half-draw). Plan enable table is
    ; still written by the builder for diagnostics / future checks.
    lda irq_shadow_enable
    ora irq_bit
    sta irq_shadow_enable
    sta VIC_SPR_ENABLE

    inc irq_command_index
    ldx irq_command_index
    cpx objects::mux_front_command_count
    bcc schedule_line_for_x
    lda #0
    sta VIC_RASTER
    lda #PROFILE_IRQ_EXIT
    sta objects::profile_marker
    jmp KERNAL_IRQ_EXIT

; Program compare for command X. If the beam is already at/past that line,
; the VIC will not re-fire this frame — run the command in this IRQ instead.
; (Job lines are non-decreasing within a frame, so "current >= target" means
; missed; end-of-plan uses compare 0 and does not take this path.)
schedule_line_for_x:
load_cmd_line:
    lda sprite_mux_data::plan0_cmd_line, x
    sta VIC_RASTER
    cmp VIC_RASTER                  ; A=target vs $D012 current (read ≠ write)
    beq schedule_run_now            ; on the line — do not wait for re-IRQ
    bcs schedule_wait               ; target > current — wait for raster IRQ
schedule_run_now:
    jmp command
schedule_wait:
    lda #PROFILE_IRQ_EXIT
    sta objects::profile_marker
    jmp KERNAL_IRQ_EXIT
.endproc

.endscope
