; Native16 foreground API: DBR=PBR, D preserved, IRQs enabled.
; Tool9 owns its firmware interrupt path. No raw C026/C027 or game-port IO.
; ReadConfig order follows Apple Toolbox Vol3 erratum26-2, not Vol1.
; input_init returns A=0 success; input_poll requests one packet if idle.
; input_close returns A=0 only when no callback can reference this image and
; the original autopoll mode bit is restored. A=1 means RETAIN this image.
                         longa  on
                         longi  on
input_init               pea    0
                         ldx    #$0609
                         jsl    $E10000
                         pla
                         sta    input_initial_status
                         ldx    #$0209
                         jsl    $E10000
input_start_result       bcc    input_started
                         jmp    input_fail
input_started            lda    #1
                         sta    input_tool_owned
                         pea    1
                         lda    #^input_old_mode
                         pha
                         pea    input_old_mode
                         pea    $000A
                         ldx    #$0A09
                         jsl    $E10000
input_modes_result       bcc    input_read_config
                         jmp    input_fail
input_read_config        lda    #1
                         sta    input_mode_known
                         pea    3
                         lda    #^input_config
                         pha
                         pea    input_config
                         pea    $000B
                         ldx    #$0A09
                         jsl    $E10000
input_config_result      bcc    input_config_ok
                         jmp    input_fail
input_config_ok          lda    input_config
                         and    #$000F
                         bne    input_address_ok
                         lda    #$FF01
                         jmp    input_fail
input_address_ok         ora    #$00C0
                         sta    input_talk
                         lda    input_old_mode
                         and    #1
                         bne    input_init_ok
; Mark our intended change before submitting; command-incomplete may be late.
                         lda    #1
                         sta    input_mode_owned
                         pea    1
                         lda    #^input_mode_bit
                         pha
                         pea    input_mode_bit
                         pea    4
                         ldx    #$0909
                         jsl    $E10000
input_set_mode_result    bcc    input_init_ok
                         jmp    input_fail
input_init_ok            lda    #1
                         sta    input_active
                         lda    #0
                         rts
input_fail               sta    input_fault
                         lda    #1
                         sta    input_closing
                         rts

input_poll               lda    input_active
                         beq    input_poll_done
                         lda    input_closing
                         ora    input_pending
                         ora    input_fault
                         bne    input_poll_done
; Publish pending BEFORE Tool call: completion may precede Tool return.
                         lda    #1
                         sta    input_pending
                         lda    #^input_callback
                         pha
                         pea    input_callback
                         lda    input_talk
                         pha
input_submit             ldx    #$0D09
                         jsl    $E10000
input_submit_result      bcc    input_poll_done
                         cmp    #$0982
                         beq    input_busy
                         sta    input_fault
                         bra    input_poll_done
; Busy proves nonacceptance. Command-incomplete is ambiguous: retain pending
; and callback memory until the actual completion arrives.
input_busy               stz    input_pending
                         inc    input_busy_count
input_poll_done          rts

input_close              lda    #1
                         sta    input_closing
                         lda    input_pending
                         bne    input_close_wait
                         lda    input_mode_owned
                         beq    input_close_tool
                         pea    1
                         lda    #^input_mode_bit
                         pha
                         pea    input_mode_bit
                         pea    5
                         ldx    #$0909
                         jsl    $E10000
                         bcc    input_mode_restored
                         sta    input_cleanup_error
                         bra    input_close_wait
input_mode_restored      stz    input_mode_owned
input_close_tool         lda    input_tool_owned
                         beq    input_close_done
                         lda    input_mode_known
                         beq    input_shutdown_tool
                         pea    1
                         lda    #^input_exit_mode
                         pha
                         pea    input_exit_mode
                         pea    $000A
                         ldx    #$0A09
                         jsl    $E10000
                         bcc    input_verify_mode
                         sta    input_cleanup_error
                         bra    input_close_wait
input_verify_mode        lda    input_exit_mode
                         eor    input_old_mode
                         and    #1
                         beq    input_shutdown_tool
                         lda    #$FF03
                         sta    input_cleanup_error
                         bra    input_close_wait
input_shutdown_tool      ldx    #$0309
                         jsl    $E10000
                         bcc    input_tool_closed
                         sta    input_cleanup_error
                         bra    input_close_wait
input_tool_closed        stz    input_tool_owned
input_close_done         stz    input_active
                         lda    #0
                         rts
input_close_wait         lda    #1
                         rts

; Only this 16-byte copy masks IRQs; no Tool calls inside the section.
input_snapshot           php
                         sei
                         ldx    #14
                         lda    input_fault
                         bne    input_snapshot_neutral
input_snapshot_word      lda    input_held,x
                         sta    input_sampled,x
                         dex
                         dex
                         bpl    input_snapshot_word
                         plp
                         rts
input_snapshot_neutral   lda    #0
input_neutral_word       sta    input_sampled,x
                         dex
                         dex
                         bpl    input_neutral_word
                         plp
                         rts

; Decode the tick-local bitmap. M=X=16, DBR=PBR, A/X scratch.
; Original IIgs ADB keycodes plus C64 WASD/Space controls.
input_decode             stz    input_dirs_value
                         stz    input_fire_value
                         stz    input_key_s_value
                         stz    input_key_i_value
                         stz    input_runstop_value
                         stz    input_leave_value
input_decode_up          lda    input_sampled+7
                         and    #64
                         bne    input_up_set
                         lda    input_sampled+1
                         and    #32
                         beq    input_decode_down
input_up_set             lda    input_dirs_value
                         ora    #1
                         sta    input_dirs_value
input_decode_down        lda    input_sampled+7
                         and    #32
                         bne    input_down_set
                         lda    input_sampled+0
                         and    #2
                         beq    input_decode_left
input_down_set           lda    input_dirs_value
                         ora    #2
                         sta    input_dirs_value
input_decode_left        lda    input_sampled+7
                         and    #8
                         bne    input_left_set
                         lda    input_sampled+0
                         and    #1
                         beq    input_decode_right
input_left_set           lda    input_dirs_value
                         ora    #4
                         sta    input_dirs_value
input_decode_right       lda    input_sampled+7
                         and    #16
                         bne    input_right_set
                         lda    input_sampled+0
                         and    #4
                         beq    input_decode_fire
input_right_set          lda    input_dirs_value
                         ora    #8
                         sta    input_dirs_value
input_decode_fire        lda    input_sampled+6
                         and    #2
                         beq    input_decode_key_s
                         lda    #1
                         sta    input_fire_value
input_decode_key_s       lda    input_sampled+0
                         and    #2
                         beq    input_decode_key_i
                         lda    #1
                         sta    input_key_s_value
input_decode_key_i       lda    input_sampled+4
                         and    #4
                         beq    input_decode_runstop
                         lda    #1
                         sta    input_key_i_value
input_decode_runstop     lda    input_sampled+6
                         and    #32
                         beq    input_decode_leave
                         lda    #1
                         sta    input_runstop_value
input_decode_leave       lda    input_sampled+6
                         and    #64
                         beq    input_decode_done
                         lda    input_sampled+1
                         and    #16
                         beq    input_decode_done
                         lda    #1
                         sta    input_leave_value
input_decode_done        rts

; Tool9 completion enters E=0,M=X=8. Save full physical A/X/Y, DP, DBR,
; and P. After pushes, the firmware packet data pointer is at stack-DP+14.
; Restoring P precedes CLC, as required by Apple's completion contract.
                         longa  off
                         longi  off
input_callback           php
                         rep    #$30
                         longa  on
                         longi  on
                         pha
                         phx
                         phy
                         phb
                         phd
                         phk
                         plb
                         tsc
                         tcd
                         sep    #$30
                         longa  off
                         longi  off
                         ldy    #0
                         lda    [14],y
                         beq    input_callback_done
; ROM buffer[0] is N-1 (0 means no packet); data are stored in reverse
; wire order. Apple Vol1 p3-8 example also starts at count+1 and decrements.
                         cmp    #8
                         bcc    input_packet_valid
                         lda    #1
                         sta    input_fault
                         bra    input_callback_done
input_packet_valid       inc    a
                         sta    input_packet_count
                         cmp    #2
                         bne    input_packet_loop_start
                         iny
                         lda    [14],y
                         cmp    #$7F
                         bne    input_packet_loop_start
                         iny
                         lda    [14],y
                         cmp    #$7F
                         bne    input_packet_loop_start
; Power/reset packet is not an ordinary pair of control keys.
                         ldx    #15
                         lda    #0
input_reset_held         sta    input_held,x
                         dex
                         bpl    input_reset_held
                         inc    input_reset_packets
                         bra    input_callback_done
input_packet_loop_start  ldy    input_packet_count
input_packet_loop        lda    [14],y
                         cmp    #$FF
                         beq    input_packet_next
                         sta    input_event
                         rep    #$20
                         longa  on
                         inc    input_event_counter
                         sep    #$20
                         longa  off
                         and    #7
                         tax
                         lda    input_masks,x
                         sta    input_mask
                         lda    input_event
                         and    #$7F
                         lsr    a
                         lsr    a
                         lsr    a
                         tax
                         lda    input_event
                         bmi    input_release
                         lda    input_held,x
                         ora    input_mask
                         sta    input_held,x
                         bra    input_packet_next
input_release            lda    input_mask
                         eor    #$FF
                         and    input_held,x
                         sta    input_held,x
input_packet_next        dey
                         bne    input_packet_loop
input_callback_done      rep    #$30
                         longa  on
                         longi  on
                         inc    input_packet_counter
                         stz    input_pending
                         pld
                         plb
                         ply
                         plx
                         pla
                         plp
                         clc
                         rtl
                         longa  on
                         longi  on
input_state              anop
input_initial_status     dc     i2'0'
input_tool_owned         dc     i2'0'
input_mode_owned         dc     i2'0'
input_active             dc     i2'0'
input_closing            dc     i2'0'
input_pending            dc     i2'0'
input_fault              dc     i2'0'
input_cleanup_error      dc     i2'0'
input_busy_count         dc     i2'0'
input_packet_counter     dc     i2'0'
input_event_counter      dc     i2'0'
input_talk               dc     i2'0'
input_old_mode           dc     i2'0'
input_mode_known         dc     i2'0'
input_exit_mode          dc     i2'0'
input_config             dc     i4'0'
input_mode_bit           dc     i2'1'
input_packet_count       dc     i1'0'
input_event              dc     i1'0'
input_mask               dc     i1'0'
input_reset_packets      dc     i1'0'
input_held               ds     16
input_sampled            ds     16
input_dirs_value         dc     i2'0'
input_fire_value         dc     i2'0'
input_key_s_value        dc     i2'0'
input_key_i_value        dc     i2'0'
input_runstop_value      dc     i2'0'
input_leave_value        dc     i2'0'
input_masks              dc     i1'1,2,4,8,16,32,64,128'
input_state_end          anop
