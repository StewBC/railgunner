; N1 fixed-tick native core test driver. This is not the game's realtime loop.
; GS/OS entry/exit M=X=16. Driver DBR=PBR, original D. GAME owns a separate
; allocated bank-zero DP and runs M=X=8, DBR=PBR. No video or sound hardware IO.
                    case   on
                    ALIGN  32768
CORETEST            START  CORETEST
core_test_entry     anop
                    phb
                    phd
                    php
                    rep    #$30
                    longa  on
                    longi  on
                    cld
                    phk
                    plb
                    lda    0
                    sta    core_old_scratch
                    lda    2
                    sta    core_old_scratch+2
                    ldx    #$0201
                    jsl    $E10000
                    bcc    core_tool_ok
                    jmp    core_exit
core_tool_ok        pea    0
                    ldx    #$0202
                    jsl    $E10000
                    pla
                    sta    core_user
                    bcc    core_memory_ok
                    jmp    core_exit
core_memory_ok      pea    0
                    pea    0
                    pea    0
                    pea    256
                    lda    core_user
                    pha
                    pea    $C015
                    pea    0
                    pea    0
                    ldx    #$0902
                    jsl    $E10000
                    pla
                    sta    core_handle
                    sta    0
                    pla
                    sta    core_handle+2
                    sta    2
                    bcs    core_alloc_failed
                    lda    #1
                    sta    core_owned
                    lda    [0]
                    sta    core_game_dp
core_alloc_failed   lda    core_old_scratch
                    sta    0
                    lda    core_old_scratch+2
                    sta    2
                    lda    core_owned
                    bne    core_alloc_ok
                    jmp    core_exit
core_alloc_ok       lda    #game_entry
                    sta    core_game_base
                    sep    #$20
                    longa  off
                    lda    #^GAME
                    sta    core_game_base+2
                    rep    #$20
                    longa  on
core_bank_ok        lda    #1
                    sta    core_ready
core_loop           lda    core_request_seq
                    cmp    core_completed_seq
                    beq    core_loop
                    stz    core_status
                    lda    core_command
                    cmp    #255
                    beq    core_exit_jump
                    cmp    #1
                    beq    core_reset
                    cmp    #3
                    beq    core_invoke
                    lda    #4
                    sta    core_status
                    bra    core_complete
core_reset          lda    core_variant
                    beq    core_bare_reset
                    lda    #4
                    sta    core_status
                    bra    core_complete
core_bare_reset     phd
                    lda    core_game_dp
                    tcd
                    ldx    #254
                    lda    #0
core_clear_dp       sta    0,x
                    dex
                    dex
                    bpl    core_clear_dp
                    pld
                    stz    core_frame
                    stz    core_frame+2
core_invoke         jsl    game_entry
core_complete       lda    core_request_seq
                    sta    core_completed_seq
                    bra    core_loop
core_exit_jump      anop
core_exit           lda    core_owned
                    beq    core_restore
                    lda    core_handle+2
                    pha
                    lda    core_handle
                    pha
                    ldx    #$1002
                    jsl    $E10000
                    bcc    core_disposed
                    sta    core_cleanup_error
core_disposed       stz    core_owned
core_restore        lda    core_old_scratch
                    sta    0
                    lda    core_old_scratch+2
                    sta    2
                    sep    #$20
                    longa  off
                    pla
                    sta    >core_exit_status
                    rep    #$20
                    longa  on
                    pld
                    plb
                    sep    #$20
                    longa  off
                    lda    >core_exit_status
                    pha
                    plp
                    longa  on
core_quit           jsl    $E100A8
                    dc     i2'$2029'
                    dc     a4'core_quit_parms'
                    brk
core_quit_parms     dc     i2'0'
core_exit_status    ds     1
core_old_scratch    ds     4
core_user           ds     2
core_handle         ds     4
core_owned          dc     i2'0'
core_cleanup_error  dc     i2'0'
; Publication: caller writes parameters then request_seq last. Driver writes
; result fields before completed_seq; it never mutates a completed result until
; a different request sequence is submitted. All words are little endian.
core_mailbox        dc     c'N1CORE01'
core_ready          dc     i2'0'
core_request_seq    dc     i2'0'
core_completed_seq  dc     i2'0'
core_command        ENTRY
                    dc     i2'0'
core_variant        dc     i2'0'
core_ticks          dc     i2'0'
core_call_id        ENTRY
                    dc     i2'0'
core_arg_a          ENTRY
                    dc     i1'0'
core_arg_x          ENTRY
                    dc     i1'0'
core_arg_y          ENTRY
                    dc     i1'0'
core_arg_carry      ENTRY
                    dc     i1'0'
core_input_dirs     ENTRY
                    dc     i1'0'
core_input_fire     ENTRY
                    dc     i1'0'
core_input_key_s    ENTRY
                    dc     i1'0'
core_input_key_i    ENTRY
                    dc     i1'0'
core_input_runstop  ENTRY
                    dc     i1'0'
                    dc     i1'0'
core_game_base      ds     4
core_game_dp        ENTRY
                    ds     2
core_status         ENTRY
                    dc     i2'0'
core_frame          ds     4
core_ret_a          ENTRY
                    dc     i1'0'
core_ret_x          ENTRY
                    dc     i1'0'
core_ret_y          ENTRY
                    dc     i1'0'
core_ret_p          ENTRY
                    dc     i1'0'
core_mailbox_end    anop
core_test_end       anop
                    END
                    ALIGN  32768
GAME                START  GAME
                    copy   build/iigs/nativecore/core.s
game_end            ENTRY
                    END
