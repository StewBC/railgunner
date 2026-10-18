; Shipping native16 foreground service, DBR=PBR=NATIVE, D=platform page.
; Called by renderer bounded-work hooks and the main foreground loop.
; Preserves physical A/X/Y/P/D/DBR; never touches pending render generations.
; game_* entries are separate-bank native16 JSL wrappers. Input words are
; narrowed explicitly into their zero/one or direction-mask byte mailboxes.
; Tool9 submission happens at most once per due50Hz tick. The callback maintains
; held state between ticks; GAME performs its own edge detection in tick order.
                           longa  on
                           longi  on
renderer_platform_service  anop
platform_service           php
                           pha
                           phx
                           phy
                           phd
                           phb
                           cld
                           phk
                           plb
                           lda    debug_dp
                           tcd
                           lda    platform_fault
                           bne    platform_service_done
                           jsr    clock_due
                           pha
                           lda    clock_fault
                           beq    platform_clock_ok
                           pla
                           lda    #1
                           sta    platform_fault
                           bra    platform_service_done
platform_clock_ok          pla
                           beq    platform_service_done
                           jsr    input_poll
                           jsr    input_snapshot
                           jsr    input_decode
                           lda    input_fault
                           beq    platform_input_ok
                           lda    #2
                           sta    platform_fault
                           bra    platform_service_done
platform_input_ok          lda    input_leave_value
                           beq    platform_game_tick
                           lda    #1
                           sta    platform_quit
                           bra    platform_service_done
platform_game_tick         sep    #$20
                           longa  off
                           lda    input_dirs_value
                           sta    >game_input_dirs
                           lda    input_fire_value
                           sta    >game_input_fire
                           lda    input_key_s_value
                           sta    >game_input_key_s
                           lda    input_key_i_value
                           sta    >game_input_key_i
                           lda    input_runstop_value
                           sta    >game_input_runstop
                           rep    #$20
                           longa  on
                           jsl    game_tick
                           lda    >game_status
                           beq    platform_tick_ok
                           lda    #3
                           sta    platform_fault
                           bra    platform_service_done
platform_tick_ok           inc    platform_ticks
                           bne    platform_service_done
                           inc    platform_ticks+2
platform_service_done      plb
                           pld
                           ply
                           plx
                           pla
                           plp
                           rtl
platform_ticks             ds     4
platform_fault             ds     2
platform_quit              ds     2
