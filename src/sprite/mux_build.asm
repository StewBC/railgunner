; Main-thread graphical-object snapshot, priority coloring, and raster jobs.

.segment "OBJECTS"
.scope sprite_mux_data

; Plan 0 / plan 1 are forced to an exact 2-page stride by the .align 256s.
; mux_irq::select_front_plan patches every command-load high byte with a
; single irq_plan_delta of 0 or 2 pages — that only works while field order
; is byte-identical and plan1_* == plan0_* + 512. Guards after plan1 fail
; the assemble if a future field insertion breaks the layout.
;
; Plan 0: $C300-$C4FF.
plan0_cmd_line:       .res MUX_MAX_COMMANDS
plan0_cmd_lane:       .res MUX_MAX_COMMANDS
plan0_cmd_owner:      .res MUX_MAX_COMMANDS
plan0_cmd_interest:   .res MUX_MAX_COMMANDS
plan0_cmd_x_lo:       .res MUX_MAX_COMMANDS
plan0_cmd_y:          .res MUX_MAX_COMMANDS
plan0_cmd_ptr:        .res MUX_MAX_COMMANDS
plan0_cmd_color:      .res MUX_MAX_COMMANDS
plan0_cmd_enable:     .res MUX_MAX_COMMANDS
plan0_cmd_xmsb:       .res MUX_MAX_COMMANDS
.align 256
plan0_cmd_xexp:       .res MUX_MAX_COMMANDS
plan0_cmd_yexp:       .res MUX_MAX_COMMANDS
plan0_cmd_multi:      .res MUX_MAX_COMMANDS
plan0_cmd_bgprio:     .res MUX_MAX_COMMANDS
plan0_count:          .res 1
plan0_valid:          .res 1
plan0_ref0:           .res 1
plan0_ref1:           .res 1
plan0_ref2:           .res 1
plan0_sequence:       .res 1
.align 256

.if plan0_cmd_line .ne (OBJECT_STATE + $0300)
    .byte ERR_mux_plan0_must_start_at_OBJECT_STATE_plus_0300
.endif

; Plan 1: $C500-$C6FF.
plan1_cmd_line:       .res MUX_MAX_COMMANDS
plan1_cmd_lane:       .res MUX_MAX_COMMANDS
plan1_cmd_owner:      .res MUX_MAX_COMMANDS
plan1_cmd_interest:   .res MUX_MAX_COMMANDS
plan1_cmd_x_lo:       .res MUX_MAX_COMMANDS
plan1_cmd_y:          .res MUX_MAX_COMMANDS
plan1_cmd_ptr:        .res MUX_MAX_COMMANDS
plan1_cmd_color:      .res MUX_MAX_COMMANDS
plan1_cmd_enable:     .res MUX_MAX_COMMANDS
plan1_cmd_xmsb:       .res MUX_MAX_COMMANDS
.align 256
plan1_cmd_xexp:       .res MUX_MAX_COMMANDS
plan1_cmd_yexp:       .res MUX_MAX_COMMANDS
plan1_cmd_multi:      .res MUX_MAX_COMMANDS
plan1_cmd_bgprio:     .res MUX_MAX_COMMANDS
plan1_count:          .res 1
plan1_valid:          .res 1
plan1_ref0:           .res 1
plan1_ref1:           .res 1
plan1_ref2:           .res 1
plan1_sequence:       .res 1
.align 256

; Build-time guard: plan1 must sit exactly 2 pages after plan0 (irq_plan_delta=2).
; c64m has no .error — reference an undefined symbol so assemble fails loudly.
.if (plan1_cmd_line - plan0_cmd_line) .ne 512
    .byte ERR_mux_plan_stride_must_be_512
.endif
.if (plan1_cmd_lane - plan0_cmd_lane) .ne 512
    .byte ERR_mux_plan_lane_field_offset
.endif
.if (plan1_cmd_bgprio - plan0_cmd_bgprio) .ne 512
    .byte ERR_mux_plan_bgprio_field_offset
.endif

; $C700 scratch. build_slots is sorted order; other arrays use object slot.
build_slots:          .res OBJECT_CAPACITY
build_bottom_lo:      .res OBJECT_CAPACITY
build_bottom_hi:      .res OBJECT_CAPACITY
build_lane:           .res OBJECT_CAPACITY
build_priority:       .res OBJECT_CAPACITY
build_job_release:    .res OBJECT_CAPACITY
build_job_deadline:   .res OBJECT_CAPACITY
build_job_line:       .res OBJECT_CAPACITY
build_scheduled:      .res OBJECT_CAPACITY ; reserved former bucket links
build_candidate_count:.res 1
.align 256

; $C800 reserved former scanline buckets. Keeping the page preserves the
; established $C900 rail/cargo layout while the small-list sort is evaluated.
build_page_8:         .res 256

.endscope
.segment "CODE"

.scope sprite_mux_build

; A=object kind -> A=priority (C=0, B=1, A=2, neutral=3).
; Preserves X because gather owns X as its object-slot index.
.proc priority_for_kind
    cmp #6
    bcc known_kind
    lda #3
    rts
known_kind:
    tay
    lda kind_priority, y
    rts
.endproc

; Gather renderable slots and compute conservative interval endpoints.
.proc gather
    lda #0
    sta sprite_mux_data::build_candidate_count
    ldx #0
gather_loop:
    lda objects::obj_flags, x
    and #(OBJF_ALLOCATED | OBJF_RENDER | OBJF_RETIRING)
    cmp #(OBJF_ALLOCATED | OBJF_RENDER)
    bne gather_next

    lda objects::obj_x_hi, x
    cmp #2
    bcs gather_next

    ; Y too high for mux job deadline (would force RASTER_DEADLINE on whole plan)
    lda objects::obj_y_int, x
    cmp #MUX_MIN_SPRITE_Y
    bcc gather_next

    lda #21
    sta mux_j
    lda objects::obj_sprite_attr, x
    and #OBJA_Y_EXPAND
    beq have_height
    lda #42
    sta mux_j
have_height:
    lda objects::obj_y_int, x
    clc
    adc mux_j                        ; safe when top+height <= 262
    sta mux_k
    lda #0
    adc #0
    sta mux_current_bottom_hi
    beq safe_bottom
    lda mux_k
    cmp #7
    bcs gather_next                  ; below common PAL/NTSC safe range
safe_bottom:
    lda mux_k
    sec
    sbc #1
    sta sprite_mux_data::build_bottom_lo, x
    lda mux_current_bottom_hi
    sbc #0
    sta sprite_mux_data::build_bottom_hi, x

    lda objects::obj_kind, x
    jsr priority_for_kind
    sta sprite_mux_data::build_priority, x
    lda #OBJECT_NONE
    sta sprite_mux_data::build_lane, x

    ldy sprite_mux_data::build_candidate_count
    txa
    sta sprite_mux_data::build_slots, y
    inc sprite_mux_data::build_candidate_count
gather_next:
    inx
    cpx #OBJECT_CAPACITY
    bne gather_loop
    clc
    rts
.endproc

; Insertion-sort build_slots by (priority, Y, logical slot). Processing every
; C interval before B, and every B before A, guarantees a later class can
; always be assigned above every overlapping class in front of it.
.proc sort_candidates
    lda sprite_mux_data::build_candidate_count
    cmp #2
    bcs sort_begin
    rts
sort_begin:
    lda #1
    sta mux_i
sort_outer:
    ldy mux_i
    lda sprite_mux_data::build_slots, y
    sta mux_key
    tax
    lda sprite_mux_data::build_priority, x
    sta mux_key_prio
    lda objects::obj_y_int, x
    sta mux_current_top
    lda mux_i
    sta mux_j

sort_inner:
    lda mux_j
    beq sort_insert
    tay
    dey
    lda sprite_mux_data::build_slots, y
    sta mux_current
    tax

    ; Stop when previous key <= insertion key.
    lda sprite_mux_data::build_priority, x
    cmp mux_key_prio
    bcc sort_insert
    bne sort_shift
    lda objects::obj_y_int, x
    cmp mux_current_top
    bcc sort_insert
    bne sort_shift
    cpx mux_key
    bcc sort_insert

sort_shift:
    lda sprite_mux_data::build_slots, y
    iny
    sta sprite_mux_data::build_slots, y
    dec mux_j
    jmp sort_inner

sort_insert:
    ldy mux_j
    lda mux_key
    sta sprite_mux_data::build_slots, y
    inc mux_i
    lda mux_i
    cmp sprite_mux_data::build_candidate_count
    bcc sort_outer
    rts
.endproc

; Assign one of eight hardware lanes while preserving C<B<A for every
; conservatively Y-overlapping drone pair.
.proc assign_lanes
    lda #0
    sta mux_i
assign_outer:
    lda mux_i
    cmp sprite_mux_data::build_candidate_count
    bcc assign_have
    clc
    rts
assign_have:
    tay
    lda sprite_mux_data::build_slots, y
    sta mux_current
    tax
    lda objects::obj_y_int, x
    sta mux_current_top
    lda sprite_mux_data::build_bottom_lo, x
    sta mux_current_bottom_lo
    lda sprite_mux_data::build_bottom_hi, x
    sta mux_current_bottom_hi
    lda #0
    sta mux_forbidden
    sta mux_min_lane
    sta mux_j

assign_scan_previous:
    lda mux_j
    cmp mux_i
    bcs assign_choose
    tay
    lda sprite_mux_data::build_slots, y
    tax

    ; At eight or fewer candidates there is no reason to multiplex a lane.
    ; Treat every prior candidate as a conflict so each object gets a distinct
    ; hardware sprite. This avoids manufacturing reuse deadlines while VIC-II
    ; lanes are still free.
    lda sprite_mux_data::build_candidate_count
    cmp #(MUX_HW_COUNT + 1)
    bcc assign_overlap

    ; Mux-safe lane conflict (not just pixel overlap). Same-lane reuse needs
    ; upper_bottom + MUX_LANE_SEP <= lower_top (release vs deadline). Pixel-
    ; separated sprites in that dead zone used to share a lane then die in
    ; build_job_windows with RASTER_DEADLINE — freezing the last good plan.
    lda objects::obj_y_int, x
    cmp mux_current_top
    bcc prev_is_above                ; prev_top < cur_top → prev higher on screen
    ; current is above previous (or same top): need cur_bottom+SEP <= prev_top
    lda mux_current_bottom_hi
    bne assign_overlap
    lda mux_current_bottom_lo
    clc
    adc #MUX_LANE_SEP
    bcs assign_overlap
    cmp objects::obj_y_int, x
    bcc assign_prev_next             ; cur_bottom+SEP < prev_top
    beq assign_prev_next
    bne assign_overlap

prev_is_above:
    ; need prev_bottom+SEP <= cur_top
    lda sprite_mux_data::build_bottom_hi, x
    bne assign_overlap
    lda sprite_mux_data::build_bottom_lo, x
    clc
    adc #MUX_LANE_SEP
    bcs assign_overlap
    cmp mux_current_top
    bcc assign_prev_next
    beq assign_prev_next
    ; fall through to conflict

assign_overlap:
    lda sprite_mux_data::build_lane, x
    tay
    lda lane_bit_table, y
    ora mux_forbidden
    sta mux_forbidden

    ; Only drone classes 0..2 impose relative-number constraints.
    ldy mux_current
    lda sprite_mux_data::build_priority, y
    cmp #3
    bcs assign_prev_next
    sta mux_key_prio
    lda sprite_mux_data::build_priority, x
    cmp mux_key_prio
    bcs assign_prev_next
    lda sprite_mux_data::build_lane, x
    clc
    adc #1
    cmp mux_min_lane
    bcc assign_prev_next
    sta mux_min_lane

assign_prev_next:
    inc mux_j
    bne assign_scan_previous

assign_choose:
    ; Drone classes retain lowest-number-first allocation to preserve C<B<A.
    ; Neutral objects have no relative-priority requirement. Prefer their
    ; candidate ordinal modulo eight, then fall back to the first legal lane.
    ldy mux_current
    lda sprite_mux_data::build_priority, y
    cmp #3
    bcc choose_lowest

    lda mux_i
    and #(MUX_HW_COUNT - 1)
    tay
    lda lane_bit_table, y
    and mux_forbidden
    beq lane_found

choose_lowest:
    ldy mux_min_lane
choose_loop:
    cpy #MUX_HW_COUNT
    bcs assign_fail
    lda lane_bit_table, y
    and mux_forbidden
    beq lane_found
    iny
    bne choose_loop
lane_found:
    ldx mux_current
    tya
    sta sprite_mux_data::build_lane, x
    inc mux_i
    jmp assign_outer

assign_fail:
    lda #MUX_ERR_LANE_CAPACITY
    sec
    rts
.endproc

; Stable insertion-sort build_slots by Y. sort_candidates already established
; (priority, Y, slot) order, so preserving equal-Y order yields the required
; (Y, priority, slot) result.
;
; Candidate count is capped at 24 and is normally <= 6. The previous bucket
; sort cleared and scanned all 256 Y buckets every build, costing ~6,900 cycles
; for six candidates in coop snap-021.
.proc order_candidates_by_y
    lda sprite_mux_data::build_candidate_count
    cmp #2
    bcs y_sort_begin
    rts
y_sort_begin:
    lda #1
    sta mux_i
y_sort_outer:
    ldy mux_i
    lda sprite_mux_data::build_slots, y
    sta mux_key
    tax
    lda objects::obj_y_int, x
    sta mux_current_top
    lda mux_i
    sta mux_j

y_sort_inner:
    lda mux_j
    beq y_sort_insert
    tay
    dey
    lda sprite_mux_data::build_slots, y
    tax
    lda objects::obj_y_int, x
    cmp mux_current_top
    bcc y_sort_insert
    beq y_sort_insert                ; stable for equal Y

    lda sprite_mux_data::build_slots, y
    iny
    sta sprite_mux_data::build_slots, y
    dec mux_j
    jmp y_sort_inner

y_sort_insert:
    ldy mux_j
    lda mux_key
    sta sprite_mux_data::build_slots, y
    inc mux_i
    lda mux_i
    cmp sprite_mux_data::build_candidate_count
    bcc y_sort_outer
    rts
.endproc

; In Y order, the most recent occupant of each lane is its predecessor.
.proc build_job_windows
    ldx #0
    lda #OBJECT_NONE
clear_lane_last:
    sta objects::mux_lane_last, x
    inx
    cpx #MUX_HW_COUNT
    bne clear_lane_last

    lda #0
    sta mux_i
window_outer:
    lda mux_i
    cmp sprite_mux_data::build_candidate_count
    bcc window_have
    clc
    rts
window_have:
    tay
    lda sprite_mux_data::build_slots, y
    sta mux_current
    tax

    lda objects::obj_y_int, x
    cmp #MUX_JOB_LINES
    bcc window_fail
    sec
    sbc #MUX_JOB_LINES
    sta sprite_mux_data::build_job_deadline, x

    ldx mux_current
    ldy sprite_mux_data::build_lane, x
    lda objects::mux_lane_last, y
    cmp #OBJECT_NONE
    bne release_after_previous
    lda #MUX_FIRST_JOB_LINE
    sta sprite_mux_data::build_job_release, x
    jmp window_next

release_after_previous:
    tax
    lda sprite_mux_data::build_bottom_hi, x
    bne window_fail
    lda sprite_mux_data::build_bottom_lo, x
    clc
    adc #(MUX_POST_GUARD + 1)
    bcs window_fail
    ldx mux_current
    sta sprite_mux_data::build_job_release, x
window_next:
    ldx mux_current
    ldy sprite_mux_data::build_lane, x
    txa
    sta objects::mux_lane_last, y
    inc mux_i
    jmp window_outer
window_fail:
    lda #MUX_ERR_RASTER_DEADLINE
    sec
    rts
.endproc

; Emit current object (mux_current) as command mux_k into the inactive plan.
.proc emit_current
    ldx mux_current
    lda sprite_mux_data::build_lane, x
    sta mux_lane
    tay
    lda lane_bit_table, y
    sta mux_bit
    lda lane_clear_table, y
    sta mux_clear
    lda mux_shadow_enable
    ora mux_bit
    sta mux_shadow_enable

    ; Replace this lane's five shadow bits. The former helper made five JSRs
    ; and reloaded the lane tables and object attributes on every call.
    lda mux_shadow_xmsb
    and mux_clear
    sta mux_shadow_xmsb
    lda objects::obj_x_hi, x
    and #1
    beq xmsb_done
    lda mux_shadow_xmsb
    ora mux_bit
    sta mux_shadow_xmsb
xmsb_done:

    lda objects::obj_sprite_attr, x
    sta mux_key

    lda mux_shadow_xexp
    and mux_clear
    sta mux_shadow_xexp
    lda mux_key
    and #OBJA_X_EXPAND
    beq xexp_done
    lda mux_shadow_xexp
    ora mux_bit
    sta mux_shadow_xexp
xexp_done:

    lda mux_shadow_yexp
    and mux_clear
    sta mux_shadow_yexp
    lda mux_key
    and #OBJA_Y_EXPAND
    beq yexp_done
    lda mux_shadow_yexp
    ora mux_bit
    sta mux_shadow_yexp
yexp_done:

    lda mux_shadow_multi
    and mux_clear
    sta mux_shadow_multi
    lda mux_key
    and #OBJA_MULTICOLOR
    beq multi_done
    lda mux_shadow_multi
    ora mux_bit
    sta mux_shadow_multi
multi_done:

    lda mux_shadow_bgprio
    and mux_clear
    sta mux_shadow_bgprio
    lda mux_key
    and #OBJA_BEHIND_BG
    beq bgprio_done
    lda mux_shadow_bgprio
    ora mux_bit
    sta mux_shadow_bgprio
bgprio_done:

    ; Add owner to this plan's 24-bit reference mask.
    ldx mux_current
    lda objects::object_slot_bit, x
    sta mux_bit
    ldy objects::object_slot_byte, x
    cpy #0
    bne ref_not_0
    lda mux_ref0
    ora mux_bit
    sta mux_ref0
    jmp ref_done
ref_not_0:
    cpy #1
    bne ref_2
    lda mux_ref1
    ora mux_bit
    sta mux_ref1
    jmp ref_done
ref_2:
    lda mux_ref2
    ora mux_bit
    sta mux_ref2
ref_done:

    lda objects::mux_back_plan
    beq emit_plan_0

    ldy mux_k
    lda sprite_mux_data::build_job_line, x
    sta sprite_mux_data::plan1_cmd_line, y
    lda mux_lane
    sta sprite_mux_data::plan1_cmd_lane, y
    txa
    sta sprite_mux_data::plan1_cmd_owner, y
    lda objects::obj_flags, x
    and #(OBJF_BG_INTEREST | OBJF_SS_INTEREST)
    lsr a
    lsr a
    lsr a
    sta sprite_mux_data::plan1_cmd_interest, y
    lda objects::obj_x_lo, x
    sta sprite_mux_data::plan1_cmd_x_lo, y
    lda objects::obj_y_int, x
    sta sprite_mux_data::plan1_cmd_y, y
    lda objects::obj_sprite_ptr, x
    sta sprite_mux_data::plan1_cmd_ptr, y
    lda objects::obj_sprite_color, x
    and #$0f
    sta sprite_mux_data::plan1_cmd_color, y
    lda mux_shadow_enable
    sta sprite_mux_data::plan1_cmd_enable, y
    lda mux_shadow_xmsb
    sta sprite_mux_data::plan1_cmd_xmsb, y
    lda mux_shadow_xexp
    sta sprite_mux_data::plan1_cmd_xexp, y
    lda mux_shadow_yexp
    sta sprite_mux_data::plan1_cmd_yexp, y
    lda mux_shadow_multi
    sta sprite_mux_data::plan1_cmd_multi, y
    lda mux_shadow_bgprio
    sta sprite_mux_data::plan1_cmd_bgprio, y
    rts

emit_plan_0:
    ldy mux_k
    lda sprite_mux_data::build_job_line, x
    sta sprite_mux_data::plan0_cmd_line, y
    lda mux_lane
    sta sprite_mux_data::plan0_cmd_lane, y
    txa
    sta sprite_mux_data::plan0_cmd_owner, y
    lda objects::obj_flags, x
    and #(OBJF_BG_INTEREST | OBJF_SS_INTEREST)
    lsr a
    lsr a
    lsr a
    sta sprite_mux_data::plan0_cmd_interest, y
    lda objects::obj_x_lo, x
    sta sprite_mux_data::plan0_cmd_x_lo, y
    lda objects::obj_y_int, x
    sta sprite_mux_data::plan0_cmd_y, y
    lda objects::obj_sprite_ptr, x
    sta sprite_mux_data::plan0_cmd_ptr, y
    lda objects::obj_sprite_color, x
    and #$0f
    sta sprite_mux_data::plan0_cmd_color, y
    lda mux_shadow_enable
    sta sprite_mux_data::plan0_cmd_enable, y
    lda mux_shadow_xmsb
    sta sprite_mux_data::plan0_cmd_xmsb, y
    lda mux_shadow_xexp
    sta sprite_mux_data::plan0_cmd_xexp, y
    lda mux_shadow_yexp
    sta sprite_mux_data::plan0_cmd_yexp, y
    lda mux_shadow_multi
    sta sprite_mux_data::plan0_cmd_multi, y
    lda mux_shadow_bgprio
    sta sprite_mux_data::plan0_cmd_bgprio, y
    rts
.endproc

; Deadlines are object_top-MUX_JOB_LINES, so build_slots Y order is EDF order.
; A lane-reuse job can have a late release even when a later-deadline job on a
; different lane is ready now. Do useful work that fits wholly in that idle gap
; before jumping to the future release. The old linear walk jumped immediately,
; then rejected the ready job after the cursor had passed its deadline.
.proc schedule_and_emit
    lda #MUX_FIRST_JOB_LINE
    sta mux_cursor
    lda #0
    sta mux_i
    sta mux_k
    sta mux_ref0
    sta mux_ref1
    sta mux_ref2
    sta mux_shadow_enable
    sta mux_shadow_xmsb
    sta mux_shadow_xexp
    sta mux_shadow_yexp
    sta mux_shadow_multi
    sta mux_shadow_bgprio

    ; build_scheduled is indexed by logical object slot.
    lda #0
    sta mux_j
    lda sprite_mux_data::build_candidate_count
    beq schedule_outer
schedule_clear:
    ldy mux_j
    lda sprite_mux_data::build_slots, y
    tax
    lda #0
    sta sprite_mux_data::build_scheduled, x
    inc mux_j
    lda mux_j
    cmp sprite_mux_data::build_candidate_count
    bcc schedule_clear

schedule_outer:
    lda mux_i
    cmp sprite_mux_data::build_candidate_count
    bcc schedule_find_first
    clc
    rts

; Find the earliest-deadline unscheduled job.
schedule_find_first:
    lda #0
    sta mux_j
schedule_find_loop:
    ldy mux_j
    lda sprite_mux_data::build_slots, y
    tax
    lda sprite_mux_data::build_scheduled, x
    beq schedule_first_found
    inc mux_j
    jmp schedule_find_loop

schedule_first_found:
    stx mux_best_slot
    lda sprite_mux_data::build_job_release, x
    cmp mux_cursor
    bcc schedule_use_first
    beq schedule_use_first

    ; The EDF job is released in the future. If one complete ready job fits
    ; before that release, schedule the earliest-deadline such job now.
    sta mux_best_value
    cmp sprite_mux_data::build_job_deadline, x
    bcc schedule_gap_room
    beq schedule_gap_room
    jmp schedule_fail

schedule_gap_room:
    lda mux_cursor
    clc
    adc #MUX_JOB_LINES
    bcs schedule_wait_first
    cmp mux_best_value
    bcc schedule_scan_gap
    beq schedule_scan_gap

schedule_wait_first:
    lda mux_best_value
    sta mux_cursor
schedule_use_first:
    ldx mux_best_slot
    jmp schedule_have_slot

schedule_scan_gap:
    inc mux_j
schedule_gap_loop:
    lda mux_j
    cmp sprite_mux_data::build_candidate_count
    bcs schedule_wait_first
    tay
    lda sprite_mux_data::build_slots, y
    tax
    lda sprite_mux_data::build_scheduled, x
    bne schedule_gap_next
    lda sprite_mux_data::build_job_release, x
    cmp mux_cursor
    bcc schedule_have_slot
    beq schedule_have_slot
schedule_gap_next:
    inc mux_j
    jmp schedule_gap_loop

schedule_have_slot:
    stx mux_current
    lda mux_cursor
    cmp sprite_mux_data::build_job_release, x
    bcs schedule_have_start
    lda sprite_mux_data::build_job_release, x
schedule_have_start:
    cmp sprite_mux_data::build_job_deadline, x
    bcc job_start_ok
    beq job_start_ok
    jmp schedule_fail
job_start_ok:
    sta sprite_mux_data::build_job_line, x
    clc
    adc #MUX_JOB_LINES
    bcc cursor_ok
    lda #$ff
cursor_ok:
    sta mux_cursor
    jsr emit_current
    ldx mux_current
    lda #1
    sta sprite_mux_data::build_scheduled, x
    inc mux_i
    inc mux_k
    jmp schedule_outer

schedule_fail:
    lda #MUX_ERR_RASTER_DEADLINE
    sec
    rts
.endproc

; Commit metadata to the inactive buffer after every command succeeds.
.proc finish_plan
    inc objects::mux_build_seq
    lda objects::mux_back_plan
    beq finish_0
    lda sprite_mux_data::build_candidate_count
    sta sprite_mux_data::plan1_count
    lda #1
    sta sprite_mux_data::plan1_valid
    lda mux_ref0
    sta sprite_mux_data::plan1_ref0
    lda mux_ref1
    sta sprite_mux_data::plan1_ref1
    lda mux_ref2
    sta sprite_mux_data::plan1_ref2
    lda objects::mux_build_seq
    sta sprite_mux_data::plan1_sequence
    jmp finish_common
finish_0:
    lda sprite_mux_data::build_candidate_count
    sta sprite_mux_data::plan0_count
    lda #1
    sta sprite_mux_data::plan0_valid
    lda mux_ref0
    sta sprite_mux_data::plan0_ref0
    lda mux_ref1
    sta sprite_mux_data::plan0_ref1
    lda mux_ref2
    sta sprite_mux_data::plan0_ref2
    lda objects::mux_build_seq
    sta sprite_mux_data::plan0_sequence
finish_common:
    lda objects::mux_back_plan
    sta objects::mux_build_valid_plan
    lda #MUX_OK
    sta objects::mux_last_error
    clc
    rts
.endproc

; Public build ABI: C clear complete inactive plan; C set A=MUX_ERR_*.
.proc build
    lda #PROFILE_MUX_GATE
    sta objects::profile_marker
    lda objects::mux_plan_ready
    beq build_start
    ; Ready plan still waiting for line-0 swap — not a hard failure.
    ; Do NOT clear mux_build_valid_plan (a successful build may be waiting
    ; to publish once ready drops; stomping it caused permanent PLAN_BUSY).
    lda #PROFILE_MUX_BUSY
    sta objects::profile_marker
    lda #MUX_ERR_PLAN_BUSY
    sta objects::mux_last_error
    sec
    rts
build_start:
    lda #PROFILE_MUX_GATHER
    sta objects::profile_marker
    jsr gather
    bcs build_fail
    lda #PROFILE_MUX_SORT
    sta objects::profile_marker
    jsr sort_candidates
    lda #PROFILE_MUX_ASSIGN
    sta objects::profile_marker
    jsr assign_lanes
    bcs build_fail
    lda #PROFILE_MUX_Y_ORDER
    sta objects::profile_marker
    jsr order_candidates_by_y
    lda #PROFILE_MUX_WINDOWS
    sta objects::profile_marker
    jsr build_job_windows
    bcs build_fail
    lda #PROFILE_MUX_EMIT
    sta objects::profile_marker
    jsr schedule_and_emit
    bcs build_fail
    lda #PROFILE_MUX_FINISH
    sta objects::profile_marker
    jmp finish_plan
build_fail:
    sta objects::mux_last_error
    lda #PROFILE_MUX_FAIL
    sta objects::profile_marker
    ldx #OBJECT_NONE
    stx objects::mux_build_valid_plan
    sec
    rts
.endproc

; Publish the most recent successful build for the next line-0 IRQ.
.proc publish
    lda objects::mux_plan_ready
    bne publish_busy
    lda objects::mux_build_valid_plan
    cmp objects::mux_back_plan
    bne publish_busy
    php
    sei
    lda objects::mux_back_plan
    sta objects::mux_ready_plan
    lda #1
    sta objects::mux_plan_ready
    lda #OBJECT_NONE
    sta objects::mux_build_valid_plan
    plp
    clc
    rts
publish_busy:
    lda #MUX_ERR_PLAN_BUSY
    sta objects::mux_last_error
    sec
    rts
.endproc

kind_priority:
    ; player, A, B, C, BONUS, EFFECT — lower = drawn front
    .byte 3,2,1,0,0,3

lane_bit_table:
    .byte $01,$02,$04,$08,$10,$20,$40,$80
lane_clear_table:
    .byte $FE,$FD,$FB,$F7,$EF,$DF,$BF,$7F

.endscope
