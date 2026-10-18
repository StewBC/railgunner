; Production capture ABI. All state is in the renderer's bank-local segment.
; Producer fills rc_live_* only, between logic calls; capture is foreground-only.
; M=X=16, DBR=renderer code bank; A/X/flags clobbered; no DP/tool/E1 accesses.
; Each snapshot is exactly2388bytes:
; +0 glyph plane1000 bytes; +1000 color plane1000bytes;
; +2000 24 slot-ordered descriptors16bytes each; +2384 present16; +2386 mode16.
; Descriptor offsets: +0 rawVICX16; +2 zeroextendedVICY; +4 sprite_ptr;
; +6 player_frame&3; +8 color; +10 attr; +12 kind; +14 flags.
; player_frame is zero for non-F8/F9 pointers to avoid unrelated animation damage.
; Except X and the explicitly masked frame, fields are zeroextended source8bits.
; Mutable live producer storage is NEVER rendered. Pending remains immutable
; until committed; rc_capture returns1 and preserves it while rc_pending=1.
; Call rc_publish ONLY after an admitted full E1 generation has completed.
; This module does not publish or clear pending merely because composition ends.
; Publish services every256words AFTERE1completion; hook must not reenter renderer.
; Capture cannot service midcopy: liveproducer could change and tear snapshot.
; Caller services immediatelybefore the bounded2388byte atomic capture.
                       longa  on
                       longi  on
rc_reset               stz    rc_pending
                       stz    rc_display_valid
                       stz    rc_generation
                       stz    rc_display_generation
                       rts
rc_capture             lda    rc_pending
                       beq    rc_capture_free
                       lda    #1
                       rts
rc_capture_free        ldx    #2386
rc_capture_word        lda    >rc_live,x
                       sta    >rc_candidate,x
                       dex
                       dex
                       bpl    rc_capture_word
                       inc    rc_generation
                       lda    #1
                       sta    rc_pending
                       lda    #0
                       rts
rc_publish             lda    rc_pending
                       bne    rc_publish_ready
                       lda    #1
                       rts
rc_publish_ready       ldx    #2386
rc_publish_word        lda    >rc_candidate,x
                       sta    >rc_displayed,x
                       txa
                       and    #511
                       bne    rc_publish_no_service
                       jsr    render_service
rc_publish_no_service  dex
                       dex
                       bpl    rc_publish_word
                       lda    rc_generation
                       sta    rc_display_generation
                       lda    #1
                       sta    rc_display_valid
                       stz    rc_pending
                       lda    #0
                       rts
rc_pending             ds     2
rc_display_valid       ds     2
rc_generation          ds     2
rc_display_generation  ds     2
rc_live                anop
rc_live_glyphs         ENTRY
                       ds     1000
rc_live_colors         ENTRY
                       ds     1000
rc_live_objects        ENTRY
                       ds     384
rc_live_present        ENTRY
                       ds     2
rc_live_mode           ENTRY
                       ds     2
rc_live_end            anop
rc_candidate           anop
rc_candidate_glyphs    ds     1000
rc_candidate_colors    ds     1000
rc_candidate_objects   ds     384
rc_candidate_present   ds     2
rc_candidate_mode      ds     2
rc_candidate_end       anop
rc_displayed           anop
rc_displayed_glyphs    ds     1000
rc_displayed_colors    ds     1000
rc_displayed_objects   ds     384
rc_displayed_present   ds     2
rc_displayed_mode      ds     2
rc_displayed_end       anop
