; Tool9 raw keyboard probe. Owns/restores autopoll bit; no video/audio writes.
; GS/OS entry M=X=16; save caller D/DBR/P and its four scratch bytes.
                          case on
                          ALIGN 32768
ADBPROBE                  START ADBPROBE
probe_entry               phb
                          phd
                          php
                          rep #$30
                          longa on
                          longi on
                          cld
                          phk
                          plb
                          lda 0
                          sta probe_scratch
                          lda 2
                          sta probe_scratch+2
                          ldx #$0201
                          jsl $E10000
                          bcs probe_failed
                          cli
probe_setup_entry         jsr probe_test_prepare
                          cmp #0
                          beq probe_setup_ok
                          lda probe_test_error
                          jmp probe_failed
probe_setup_ok            jsr input_init
                          lda input_fault
                          sta probe_error
                          lda input_initial_status
                          sta probe_initial_status
                          lda input_old_mode
                          sta probe_modes
                          lda input_config
                          sta probe_config
                          lda input_config+2
                          sta probe_config+2
                          bra probe_ready_set
probe_failed              sta probe_error
probe_ready_set           lda #1
                          sta probe_ready
probe_wait                lda probe_command
                          cmp #255
                          beq probe_closing
                          sep #$20
                          longa off
                          lda >$E0C019
                          and #$80
                          cmp probe_vbl
                          beq probe_no_poll
                          sta probe_vbl
                          cmp #$80
                          bne probe_no_poll
                          rep #$20
                          longa on
                          jsr input_poll
                          jsr input_snapshot
                          jsr input_decode
                          bra probe_wait
probe_no_poll             rep #$20
                          longa on
                          bra probe_wait
probe_closing             jsr input_close
                          bne probe_closing
                          jsr probe_test_finish
                          bne probe_closing
                          lda input_cleanup_error
                          sta probe_cleanup_error
probe_restore             lda probe_scratch
                          sta 0
                          lda probe_scratch+2
                          sta 2
                          sep #$20
                          longa off
                          pla
                          sta >probe_exit_p
                          rep #$20
                          longa on
                          pld
                          plb
                          sep #$20
                          longa off
                          lda >probe_exit_p
                          pha
                          plp
                          longa on
probe_quit                jsl $E100A8
                          dc i2'$2029'
                          dc a4'probe_quit_parms'
                          brk
probe_quit_parms          dc i2'0'
probe_exit_p              ds 1
probe_scratch             ds 4
probe_owned               dc i2'0'
probe_signature           dc c'RGADB001'
probe_ready               dc i2'0'
probe_command             dc i2'0'
probe_error               dc i2'0'
probe_cleanup_error       dc i2'0'
probe_initial_status      dc i2'0'
probe_modes               dc i2'0'
probe_config              dc i4'0'
probe_vbl                 dc i1'0'
; Optional diagnostic-only ownership setup. Default mask0 has no Tool calls.
; Used to exercise input_init when autopoll was already disabled, while the
; fixture separately restores the real caller's original mode on final exit.
probe_test_prepare        lda probe_test_mode_mask
                          bne probe_test_prepare_go
                          lda #0
                          rts
probe_test_prepare_go     jsr probe_test_start
                          bcs probe_test_fail
                          pea 1
                          lda #^probe_test_caller_mode
                          pha
                          pea probe_test_caller_mode
                          pea $000A
                          ldx #$0A09
                          jsl $E10000
                          bcs probe_test_fail
                          lda probe_test_caller_mode
                          eor #$FFFF
                          and probe_test_mode_mask
                          sta probe_test_owned_mask
                          pea 1
                          lda #^probe_test_mode_mask
                          pha
                          pea probe_test_mode_mask
                          pea 4
                          ldx #$0909
                          jsl $E10000
                          bcs probe_test_fail
                          ldx #$0309
                          jsl $E10000
                          bcs probe_test_fail
                          stz probe_test_tool_owned
                          lda #0
                          rts
probe_test_start          lda probe_test_tool_owned
                          bne probe_test_start_ok
                          ldx #$0209
                          jsl $E10000
                          bcs probe_test_start_done
                          lda #1
                          sta probe_test_tool_owned
probe_test_start_ok       clc
probe_test_start_done     rts
probe_test_fail           sta probe_test_error
                          lda #1
                          rts
probe_test_finish         lda probe_test_mode_mask
                          bne probe_test_finish_go
                          lda #0
                          rts
probe_test_finish_go      jsr probe_test_start
                          bcs probe_test_fail
                          pea 1
                          lda #^probe_test_owned_mask
                          pha
                          pea probe_test_owned_mask
                          pea 5
                          ldx #$0909
                          jsl $E10000
                          bcs probe_test_fail
                          pea 1
                          lda #^probe_test_exit_mode
                          pha
                          pea probe_test_exit_mode
                          pea $000A
                          ldx #$0A09
                          jsl $E10000
                          bcs probe_test_fail
                          lda probe_test_exit_mode
                          eor probe_test_caller_mode
                          and #$FF
                          beq probe_test_finish_ok
                          lda #$FF04
                          bra probe_test_fail
probe_test_finish_ok      ldx #$0309
                          jsl $E10000
                          bcs probe_test_fail
                          stz probe_test_tool_owned
                          stz probe_test_owned_mask
                          lda #0
                          rts
probe_test_mode_mask      dc i2'0'
probe_test_caller_mode    dc i2'0'
probe_test_owned_mask     dc i2'0'
probe_test_tool_owned     dc i2'0'
probe_test_exit_mode      dc i2'0'
probe_test_error          dc i2'0'
                          copy src/iigs/input.asm
probe_end                 anop
                          END
