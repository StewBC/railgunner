; Lifecycle template for native_game_build.py (not a standalone demo).
; Builder replaces slice hooks and renderer COPY with the production game.
; GS/OS entry M=X=16; lifecycle derived from Force.
; Slice boundary: M=X=16, D=owned bank-zero page, DBR=PBR=NATIVE bank.
                          case   on
                          ALIGN  32768
NATIVE                      START NATIVE
native_entry              anop
                          phb
                          phd
                          php
                          rep    #$30
                          longa  on
                          longi  on
                          cld
                          phk
                          plb
                          tsc
                          clc
                          adc    #4
                          sta    debug_entry_sp
                          lda    1,s
                          and    #$FF
                          sta    debug_entry_p
                          lda    4,s
                          and    #$FF
                          sta    debug_entry_dbr
                          tdc
                          sta    old_dp
                          lda    0
                          sta    saved_caller_dp
                          lda    2
                          sta    saved_caller_dp+2
                          sep    #$20
                          longa  off
                          lda    >$E0C029
                          sta    old_shr
                          lda    >$E0C034
                          and    #$0F
                          sta    old_border
                          lda    >$E0C035
                          sta    old_shadow
                          lda    >$E0C036
                          sta    old_speed
                          rep    #$20
                          longa  on
                          ldx    #$0201
                          jsl    $E10000
                          bcc    tool_started
                          jmp    shutdown
tool_started              lda    #1
                          sta    tool_active
                          pea    0
                          ldx    #$0202
                          jsl    $E10000
                          pla
                          sta    user_id
                          bcc    memory_started
                          jmp    shutdown
memory_started            lda    #1
                          sta    memory_active
; Locked, fixed, page-aligned, no bank crossing, bank 0.
                          pea    0
                          pea    0
                          pea    0
                          pea    256
                          lda    user_id
                          pha
                          pea    $C015
                          pea    0
                          pea    0
                          ldx    #$0902
                          jsl    $E10000
                          pla
                          sta    dp_handle
                          sta    0
                          pla
                          sta    dp_handle+2
                          sta    2
native_alloc_result       bcc    allocated
                          lda    saved_caller_dp
                          sta    0
                          lda    saved_caller_dp+2
                          sta    2
                          jmp    shutdown
allocated                 lda    #1
                          sta    dp_owned
                          lda    [0]
                          sta    debug_dp
                          lda    saved_caller_dp
                          sta    0
                          lda    saved_caller_dp+2
                          sta    2
                          lda    debug_dp
                          tcd
                          ldx    #254
                          lda    #0
clear_dp                  sta    0,x
                          dex
                          dex
                          bpl    clear_dp
                          lda    #native_entry
                          sta    debug_base
                          cmp    #65536-(native_end-native_entry)
                          bcc    core_bank_valid
                          beq    core_bank_valid
                          jmp    shutdown
core_bank_valid           sep    #$20
                          longa  off
                          lda    #^NATIVE
                          sta    debug_base+2
                          lda    >$E0C029
                          sta    old_shr
                          lda    >$E0C034
                          and    #$0F
                          sta    old_border
                          lda    >$E0C036
                          ora    #$80
                          sta    >$E0C036
                          lda    >$E0C035
                          sta    old_shadow
                          ora    #$08
                          sta    >$E0C035
                          lda    #$61
                          sta    >$E0C029
                          lda    #0
                          sta    >$E0C034
                          rep    #$20
                          longa  on
                          ldx    #32766
save_display              lda    >$E12000,x
                          sta    >saved_display,x
                          dex
                          dex
                          bpl    save_display
                          lda    #1
                          sta    display_saved
                          ldx    #$7DFE
                          lda    #0
clear_screen              sta    >$E12000,x
                          dex
                          dex
                          bpl    clear_screen
                          ldx    #254
clear_scbs                sta    >$E19D00,x
                          dex
                          dex
                          bpl    clear_scbs
                          ldx    #30
palette_loop              lda    palette,x
                          sta    >$E19E00,x
                          dex
                          dex
                          bpl    palette_loop
                          jsr    clock_selftest
                          beq    clock_test_good
                          jmp    shutdown
clock_test_good           jsr    slice_init
                          jsr    clock_init
                          beq    clock_ready
                          jmp    shutdown
clock_ready               anop
                          sep    #$20
                          longa  off
                          lda    #$E1
                          sta    >$E0C029
                          rep    #$20
                          longa  on
                          lda    #1
                          sta    debug_ready
main_loop                 jsr    clock_due
                          lda    debug_misses
                          bne    stopped_slice
                          jsr    slice_tick
stopped_slice             anop
                          sep    #$20
                          longa  off
                          lda    >$E0C000
                          bpl    no_key
                          sta    >$E0C010
                          and    #$7F
                          cmp    #27
                          beq    exit_jump
no_key                    rep    #$20
                          longa  on
                          bra    main_loop
exit_jump                 jmp    shutdown

shutdown                  anop
                          rep    #$30
                          longa  on
                          longi  on
                          sep    #$20
                          longa  off
                          lda    display_saved
                          beq    restore_registers
                          lda    #$61
                          sta    >$E0C029
                          rep    #$20
                          longa  on
                          ldx    #32766
restore_display           lda    >saved_display,x
                          sta    >$E12000,x
                          dex
                          dex
                          bpl    restore_display
                          sep    #$20
                          longa  off
restore_registers         lda    old_shr
                          sta    >$E0C029
                          lda    old_border
                          and    #$0F
                          sta    >$E0C034
                          lda    old_shadow
                          sta    >$E0C035
                          lda    old_speed
                          sta    >$E0C036
                          rep    #$20
                          longa  on
                          lda    old_dp
                          tcd
; MMStartUp returns the existing GS/OS application ID, also used by its
; loaded code and caller stack. Release only our explicitly allocated handle;
; the caller already owns the Tool Locator/MM startup state. QuitGS owns
; the application segments and the caller's Tool Locator/MM lifetime.
                          lda    dp_owned
                          beq    no_dp_dispose
                          lda    dp_handle+2
                          pha
                          lda    dp_handle
                          pha
                          ldx    #$1002
native_dispose_call       jsl    $E10000
                          bcc    dp_disposed
                          sta    debug_cleanup_error
                          bra    no_dp_dispose
dp_disposed               stz    dp_owned
no_dp_dispose             anop
; Restore P last: PLD/PLB modify N/Z. Scratch uses long addressing
; because restoring the caller DBR invalidates CORE-relative access.
                          sep    #$20
                          longa  off
                          pla
                          sta    >exit_status
                          rep    #$20
                          longa  on
                          pld
                          plb
                          sep    #$20
                          longa  off
                          lda    >exit_status
                          pha
                          plp
native_quit               jsl    $E100A8
                          dc     i2'$2029'
                          dc     a4'quit_parameters'
quit_parameters           dc     i2'0'

                          longa  on
                          longi  on
; GAME_RENDERER_INSERT
                          copy   src/iigs/continuous_clock.asm
palette                   dc     i2'$000,$FFF,$632,$7AB,$738,$584,$336,$BC7,$642,$430,$A65,$444,$666,$AD8,$66B,$999'
exit_status               ds     1
saved_caller_dp           ds     4
old_dp                    ds     2
tool_active               dc     i2'0'
memory_active             dc     i2'0'
user_id                   ds     2
dp_handle                 ds     4
dp_owned                  dc     i2'0'
display_saved             dc     i2'0'
old_shr                   ds     1
old_border                ds     1
old_shadow                ds     1
old_speed                 ds     1
debug_signature           dc     c'RGNATIVE'
debug_base                ds     4
debug_dp                  ds     2
debug_cleanup_error       ds     2
debug_entry_sp            ds     2
debug_entry_p             ds     2
debug_entry_dbr           ds     2
debug_ready               ds     2
debug_frames              ds     2
native_end                anop
                          END

; Separate relocatable fast-RAM image; long-addressed by every renderer.
FRAME                     START FRAME
composed                  ENTRY
                          ds     32000
                          END

; Separate relocatable bank, preserved caller SHR pixels/SCBs/palettes.
SAVEDSHR                  START SAVEDSHR
saved_display             ENTRY
                          ds     32768
                          END
