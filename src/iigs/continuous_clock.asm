; Native16 foreground clock. DBR=PBR, D=owned bank-zero page.
; Reserve DP $20..$23 for the documented GetAddr(tickCnt=5) pointer.
; No IRQ ownership, no acknowledgements, no C runtime. Call only with IRQs on.
; clock_init: A=0 success, 1 failure. clock_due: A=0/1 simulation tick due.
; Counters and clock_time are 32-bit little endian, in raster-line units.
; NTSC physical clock:14,318,180 masterticks/s,912 masterticks/scanline.
; One NTSC frame (262 lines, approximately59.92Hz) per gameplay tick.
                          longa on
                          longi on
clock_init                jsr clock_reset
                          php
                          sep #$20
                          longa off
                          pla
                          and #4
                          rep #$20
                          longa on
                          and #$ff
                          bne clock_init_bad
                          sep #$20
                          longa off
                          lda >$E0C041
                          and #8
                          rep #$20
                          longa on
                          and #$ff
                          beq clock_init_bad
                          phb
                          phd
                          pea 0
                          pea 0
                          pea 5
                          ldx #$1603
                          jsl $E10000
                          pla
                          sta $20
                          pla
                          sta $22
                          pld
                          plb
                          lda $20
                          ora $22
                          beq clock_init_bad
                          jsr clock_sample
                          lda clock_fault
                          bne clock_init_bad
                          jsr clock_arm_vbl
                          lda #0
                          rts
clock_init_bad            lda #1
                          sta clock_fault
                          rts

clock_reset               ldx #clock_state_end-clock_state-2
                          lda #0
clock_zero                sta clock_state,x
                          dex
                          dex
                          bpl clock_zero
                          rts
clock_arm                 clc
                          lda clock_time
                          adc #262
                          sta clock_next
                          lda clock_time+2
                          adc #0
                          sta clock_next+2
                          stz clock_fraction
                          rts

; Align production deadlines with the OS VBL epoch (physical scanline192).
; Relative clock_arm remains available for arithmetic diagnostics.
clock_arm_vbl             lda clock_line
                          cmp #192
                          bcc clock_arm_before_vbl
                          sbc #192
                          bra clock_arm_phase
clock_arm_before_vbl      clc
                          adc #70
clock_arm_phase           sta clock_arm_offset
                          lda #262
                          sec
                          sbc clock_arm_offset
                          clc
                          adc clock_time
                          sta clock_next
                          lda clock_time+2
                          adc #0
                          sta clock_next+2
                          stz clock_fraction
                          rts

clock_due                 lda clock_fault
                          bne clock_not_due
                          php
                          sep #$20
                          longa off
                          pla
                          and #4
                          rep #$20
                          longa on
                          and #$ff
                          bne clock_due_bad
                          jsr clock_read_tick
                          lda clock_checked_valid
                          beq clock_due_sample
                          lda clock_check_tick
                          cmp clock_checked_tick
                          bne clock_due_sample
                          lda clock_check_tick+2
                          cmp clock_checked_tick+2
                          beq clock_not_due
; Cache the epoch accepted by the full sampler, never the speculative read.
; Public profiling calls to clock_sample deliberately cannot alter this cache.
clock_due_sample          jsr clock_sample
                          lda clock_fault
                          bne clock_not_due
                          jsr clock_dispatch
                          pha
                          lda clock_fault
                          bne clock_due_uncached
                          lda clock_before
                          sta clock_checked_tick
                          lda clock_before+2
                          sta clock_checked_tick+2
                          lda #1
                          sta clock_checked_valid
clock_due_uncached        pla
                          rts
clock_due_bad             lda #1
                          sta clock_fault
clock_not_due             lda #0
                          rts

; Coherent32-bit OS tick read. High/low/high retries a low-word carry race.
; Scratch is private to this gate, separate from the public sample workspace.
clock_read_tick           ldy #2
                          lda [$20],y
                          sta clock_check_tick+2
                          lda [$20]
                          sta clock_check_tick
                          lda [$20],y
                          cmp clock_check_tick+2
                          bne clock_read_tick
                          rts

; Separate arithmetic engine for native deterministic self-test. clock_time is
; supplied, no hardware calls. Deliver at most one tick; count/drop the rest.
clock_dispatch            stz clock_due_count
clock_dispatch_loop       sec
                          lda clock_time
                          sbc clock_next
                          lda clock_time+2
                          sbc clock_next+2
                          bmi clock_dispatch_done
                          inc clock_due_count
                          lda clock_due_count
                          cmp #65
                          bcs clock_due_bad
                          jsr clock_advance
                          bra clock_dispatch_loop
clock_dispatch_done       lda clock_due_count
                          beq clock_not_due
                          inc clock_delivered
                          bne clock_delivered_ok
                          inc clock_delivered+2
clock_delivered_ok        lda clock_due_count
                          cmp #2
                          bcc clock_no_drop_detail
                          lda clock_time
                          sta clock_drop_time
                          lda clock_time+2
                          sta clock_drop_time+2
                          lda clock_gap
                          sta clock_drop_gap
                          lda clock_gap+2
                          sta clock_drop_gap+2
                          lda clock_line
                          sta clock_drop_line
clock_no_drop_detail      lda clock_due_count
                          dec a
                          clc
                          adc clock_dropped
                          sta clock_dropped
                          lda clock_dropped+2
                          adc #0
                          sta clock_dropped+2
                          lda #1
                          rts
clock_advance             lda #262
                          clc
                          adc clock_next
                          sta clock_next
                          lda clock_next+2
                          adc #0
                          sta clock_next+2
                          rts

; Counter/raster/counter bracket. C046 is ALWAYS a byte read, never C047.
; Stable C02E/F word reads are delegated to native raster_line; never C030.
clock_sample              lda #4096
                          sta clock_attempts
clock_sample_retry        ldy #0
                          lda [$20]
                          sta clock_before
                          ldy #2
                          lda [$20],y
                          sta clock_before+2
                          sep #$20
                          longa off
                          lda >$E0C046
                          and #8
                          rep #$20
                          longa on
                          and #$ff
                          sta clock_pending
                          jsr raster_line
                          sta clock_line
                          sep #$20
                          longa off
                          lda >$E0C046
                          and #8
                          rep #$20
                          longa on
                          and #$ff
                          ora clock_pending
                          bne clock_sample_again
                          lda [$20]
                          cmp clock_before
                          bne clock_sample_again
                          ldy #2
                          lda [$20],y
                          cmp clock_before+2
                          beq clock_sample_stable
clock_sample_again        dec clock_attempts
                          bne clock_sample_retry
                          jmp clock_due_bad
clock_sample_stable       lda clock_before
                          sta clock_value
                          lda clock_before+2
                          sta clock_value+2
                          stz clock_time
                          stz clock_time+2
                          lda #262
                          sta clock_bits
; Multiply the actual 32-bit OS VBL count by262 modulo2^32. Foreground only.
clock_multiply            lsr clock_bits
                          bcc clock_no_add
                          clc
                          lda clock_time
                          adc clock_value
                          sta clock_time
                          lda clock_time+2
                          adc clock_value+2
                          sta clock_time+2
clock_no_add              asl clock_value
                          rol clock_value+2
                          lda clock_bits
                          bne clock_multiply
                          lda clock_line
                          cmp #192
                          bcc clock_before_vbl
                          sbc #192
                          bra clock_phase_ready
clock_before_vbl          clc
                          adc #70
clock_phase_ready         clc
                          adc clock_time
                          sta clock_time
                          lda clock_time+2
                          adc #0
                          sta clock_time+2
                          lda clock_sample_ready
                          beq clock_first_sample
                          sec
                          lda clock_time
                          sbc clock_last
                          sta clock_gap
                          lda clock_time+2
                          sbc clock_last+2
                          sta clock_gap+2
                          bpl clock_gap_valid
                          inc clock_backwards
                          lda #1
                          sta clock_fault
                          bra clock_first_sample
clock_gap_valid           lda clock_gap+2
                          beq clock_gap_low
                          lda #$ffff
                          bra clock_gap_compare
clock_gap_low             lda clock_gap
clock_gap_compare         cmp clock_max_gap
                          bcc clock_first_sample
                          sta clock_max_gap
clock_first_sample        inc clock_publish_seq
                          lda clock_time
                          sta clock_last
                          lda clock_time+2
                          sta clock_last+2
                          inc clock_publish_seq
                          lda #1
                          sta clock_sample_ready
                          rts

; Native self-test exercises the real deadline engine, including drops and
; 32-bit wrap, without altering hardware. Call before clock_init; A=0 pass.
clock_selftest            jsr clock_reset
                          jsr clock_arm
                          lda #261
                          sta clock_time
                          jsr clock_dispatch
                          cmp #0
                          beq clock_test_ok_1
                          jmp clock_test_bad
clock_test_ok_1 anop
                          lda #262
                          sta clock_time
                          jsr clock_dispatch
                          cmp #1
                          beq clock_test_ok_2
                          jmp clock_test_bad
clock_test_ok_2 anop
                          lda clock_next
                          cmp #524
                          beq clock_test_ok_3
                          jmp clock_test_bad
clock_test_ok_3 anop
                          lda #524
                          sta clock_time
                          jsr clock_dispatch
                          cmp #1
                          beq clock_test_ok_4
                          jmp clock_test_bad
clock_test_ok_4 anop
                          lda clock_next
                          cmp #786
                          beq clock_test_ok_5
                          jmp clock_test_bad
clock_test_ok_5 anop
                          lda #1310
                          sta clock_time
                          jsr clock_dispatch
                          cmp #1
                          beq clock_test_ok_6
                          jmp clock_test_bad
clock_test_ok_6 anop
                          lda clock_dropped
                          cmp #2
                          beq clock_test_ok_7
                          jmp clock_test_bad
clock_test_ok_7 anop
                          lda clock_delivered
                          cmp #3
                          beq clock_test_ok_8
                          jmp clock_test_bad
clock_test_ok_8 anop
                          lda clock_next
                          cmp #1572
                          beq clock_test_ok_9
                          jmp clock_test_bad
clock_test_ok_9 anop
                          jsr clock_reset
                          jsr clock_arm
                          ldy #2280
clock_test_physical_loop  lda clock_next
                          sta clock_time
                          lda clock_next+2
                          sta clock_time+2
                          jsr clock_dispatch
                          cmp #1
                          beq clock_test_physical_delivered
                          jmp clock_test_bad
clock_test_physical_delivered dey
                          bne clock_test_physical_loop
                          lda clock_time
                          cmp #$1d70
                          beq clock_test_physical_low
                          jmp clock_test_bad
clock_test_physical_low   lda clock_time+2
                          cmp #$0009
                          beq clock_test_physical_high
                          jmp clock_test_bad
clock_test_physical_high  lda clock_delivered
                          cmp #2280
                          beq clock_test_physical_count
                          jmp clock_test_bad
clock_test_physical_count lda clock_dropped
                          ora clock_dropped+2
                          beq clock_test_physical_no_drop
                          jmp clock_test_bad
clock_test_physical_no_drop jsr clock_reset
                          lda #$ff00
                          sta clock_time
                          lda #$ffff
                          sta clock_time+2
                          jsr clock_arm
                          lda clock_next
                          cmp #$0006
                          beq clock_test_ok_10
                          jmp clock_test_bad
clock_test_ok_10 anop
                          lda clock_next+2
                          beq clock_test_ok_11
                          jmp clock_test_bad
clock_test_ok_11 anop
                          lda #$0005
                          sta clock_time
                          stz clock_time+2
                          jsr clock_dispatch
                          cmp #0
                          beq clock_test_ok_12
                          jmp clock_test_bad
clock_test_ok_12 anop
                          inc clock_time
                          jsr clock_dispatch
                          cmp #1
                          beq clock_test_ok_13
                          jmp clock_test_bad
clock_test_ok_13 anop
                          jsr clock_reset
                          lda #0
                          rts
clock_test_bad            lda #1
                          sta clock_test_status
                          rts

clock_state               anop
clock_time                ds 4
clock_last                ds 4
clock_sample_ready        ds 2
clock_delivered           ds 4
clock_dropped             ds 4
clock_backwards           ds 2
clock_fault               ds 2
clock_next                ds 4
clock_fraction            ds 2
clock_before              ds 4
clock_line                ds 2
clock_pending             ds 2
clock_attempts            ds 2
clock_value               ds 4
clock_bits                ds 2
clock_due_count           ds 2
clock_test_status         ds 2
; Diagnostics only: scanner-line gap between successful foreground samples.
; Max saturates at65535; last-drop fields identify the sample delivering backlog.
; Odd only while publishing clock_last; readers take one state-block snapshot
; and retry odd sequence values. clock_time itself is multiplication scratch.
clock_publish_seq         ds 2
clock_gap                 ds 4
clock_max_gap             ds 2
clock_drop_time           ds 4
clock_drop_gap            ds 4
clock_drop_line           ds 2
clock_checked_tick        ds 4
clock_checked_valid       ds 2
clock_check_tick          ds 4
clock_arm_offset          ds 2
clock_state_end           anop
