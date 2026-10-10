; SID one-shot SFX — three voices, priority = SFX id (lower wins).
; API: sfx::init (cold), sfx::play (A = SFX_*), sfx::update (every frame).
; play preserves X,Y. No continuous fire / gun spindown.
; Lives in CODE_HI (low CODE is tight against CHARSET $2800).

.segment "CODE_HI"
.scope sfx

; Per-voice runtime (CODE is RAM — safe to mutate)
v_id:     .byte SFX_FREE, SFX_FREE, SFX_FREE
v_phase:  .byte 0, 0, 0               ; step index within effect
v_timer:  .byte 0, 0, 0               ; frames left in current sub-state
v_state:  .byte 0, 0, 0               ; 0=idle path, 1=gate on, 2=gap/release
v_wave:   .byte 0, 0, 0               ; waveform bits (no gate) while active

; Locals for play/update (not re-entrant; main thread only)
play_id:  .byte 0
save_x:   .byte 0
save_y:   .byte 0
upd_i:    .byte 0
steal_v:  .byte 0
steal_id: .byte 0

; ---------------------------------------------------------------------------
; Init — silence SID, free all voices, full volume.
; ---------------------------------------------------------------------------
.proc init
    ldx #2
init_v:
    lda #SFX_FREE
    sta v_id, x
    lda #0
    sta v_phase, x
    sta v_timer, x
    sta v_state, x
    sta v_wave, x
    dex
    bpl init_v

    ; Hard-silence all registers we touch
    lda #0
    sta SID_MODE_VOL
    sta SID_RES_FILT
    sta SID_FC_LO
    sta SID_FC_HI
    ldx #0
init_regs:
    sta SID_V1_FL, x
    inx
    cpx #21                         ; 3 voices × 7
    bcc init_regs

    ; Default pulse width ~50% for any pulse SFX
    lda #$00
    sta SID_V1_PWL
    sta SID_V2_PWL
    sta SID_V3_PWL
    lda #$08
    sta SID_V1_PWH
    sta SID_V2_PWH
    sta SID_V3_PWH

    lda #SID_VOL_MAX
    sta SID_MODE_VOL
    rts
.endproc

; ---------------------------------------------------------------------------
; play — A = SFX id. Drop if no free voice and cannot steal lower priority.
; ---------------------------------------------------------------------------
.proc play
    sta play_id
    stx save_x
    sty save_y

    cmp #SFX_COUNT
    bcs play_done                   ; invalid

    ; Free voice?
    ldx #0
play_find:
    lda v_id, x
    cmp #SFX_FREE
    beq play_use
    inx
    cpx #3
    bcc play_find

    ; Steal highest id (lowest priority) among voices with id > play_id
    lda #$FF
    sta steal_v
    lda #0
    sta steal_id
    ldx #0
play_steal:
    lda v_id, x
    cmp play_id
    bcc play_steal_next             ; higher priority (lower id) — skip
    beq play_steal_next             ; same priority — don't steal peer
    ; candidate: prefer largest id
    ldy steal_v
    cpy #$FF
    beq play_steal_take
    cmp steal_id
    bcc play_steal_next
play_steal_take:
    sta steal_id
    stx steal_v
play_steal_next:
    inx
    cpx #3
    bcc play_steal

    ldx steal_v
    cpx #$FF
    beq play_done                   ; nothing to steal — drop
    jsr voice_cut                   ; X = voice to cut

play_use:
    ; X = voice index — claim from title music if needed
    jsr music::mute_voice
    lda play_id
    sta v_id, x
    lda #0
    sta v_phase, x
    jsr start_step

play_done:
    ldx save_x
    ldy save_y
    lda play_id
    rts
.endproc

; ---------------------------------------------------------------------------
; update — advance all voices one frame (call every main-loop frame).
; ---------------------------------------------------------------------------
.proc update
    ldx #0
upd_loop:
    stx upd_i
    lda v_id, x
    cmp #SFX_FREE
    beq upd_next
    lda v_timer, x
    beq upd_expired
    dec v_timer, x
    ; Optional per-frame pitch slide for swoosh / whoop (state=gate)
    lda v_state, x
    cmp #1
    bne upd_next
    jsr slide_if_needed
    jmp upd_next
upd_expired:
    lda v_state, x
    cmp #1
    beq upd_end_gate
    ; gap/release finished → next step or free
    inc v_phase, x
    jsr start_step
    bcs upd_next                    ; started next step (C clear from start_step = ok)
    jmp upd_next
upd_end_gate:
    ; Open gate → release / inter-note gap
    jsr voice_gate_off
    lda #2
    sta v_state, x
    jsr gap_for_phase               ; → A = gap frames
    sta v_timer, x
upd_next:
    ldx upd_i
    inx
    cpx #3
    bcc upd_loop
    rts
.endproc

; ---------------------------------------------------------------------------
; start_step — X = voice, v_id/v_phase set. CLC = running; SEC = freed.
; ---------------------------------------------------------------------------
.proc start_step
    lda v_id, x
    asl a
    tay
    lda step_ptrs, y
    sta ptr_lo
    lda step_ptrs + 1, y
    sta ptr_hi
    lda v_phase, x
    sta tmp0
    ; Each step = 7 bytes; skip phase * 7
    lda #0
    sta tmp1
    lda tmp0
    beq ss_at
ss_mul:
    lda tmp1
    clc
    adc #7
    sta tmp1
    dec tmp0
    bne ss_mul
ss_at:
    ldy tmp1
    lda (ptr_lo), y                 ; freq_lo; $00 and next $00 and wave $00 = end
    sta tmp0
    iny
    lda (ptr_lo), y                 ; freq_hi
    sta tmp1
    iny
    lda (ptr_lo), y                 ; wave
    bne ss_live
    ; end of sequence
    jsr voice_free
    sec
    rts
ss_live:
    sta v_wave, x
    iny
    lda (ptr_lo), y                 ; ad
    sta tmp2
    iny
    lda (ptr_lo), y                 ; sr
    pha
    iny
    lda (ptr_lo), y                 ; gate frames
    sta v_timer, x
    iny
    ; gap stored for later (gap_for_phase re-reads table) — ignore here
    pla
    jsr voice_write                 ; A=sr, tmp0=fl, tmp1=fh, tmp2=ad, v_wave
    lda #1
    sta v_state, x
    clc
    rts
.endproc

; After gate ends: gap frames from current step's byte 6.
.proc gap_for_phase
    lda v_id, x
    asl a
    tay
    lda step_ptrs, y
    sta ptr_lo
    lda step_ptrs + 1, y
    sta ptr_hi
    lda v_phase, x
    sta tmp0
    lda #0
    sta tmp1
    lda tmp0
    beq gf_at
gf_mul:
    lda tmp1
    clc
    adc #7
    sta tmp1
    dec tmp0
    bne gf_mul
gf_at:
    ldy tmp1
    iny
    iny
    iny
    iny
    iny
    iny                             ; +6 = gap
    lda (ptr_lo), y
    rts
.endproc

; Mild upward slide on parcel swoosh / wave whoop while gate on.
.proc slide_if_needed
    lda v_id, x
    cmp #SFX_PARCEL
    beq slide_up
    cmp #SFX_WAVE
    beq slide_up
    cmp #SFX_HEAL
    beq slide_up
    rts
slide_up:
    ; add ~$40 to 16-bit freq each frame
    jsr voice_base_addr             ; → ptr = voice base
    ldy #0
    lda (ptr_lo), y
    clc
    adc #$40
    sta (ptr_lo), y
    iny
    lda (ptr_lo), y
    adc #0
    sta (ptr_lo), y
    rts
.endproc

; ---------------------------------------------------------------------------
; Voice register helpers — X = voice 0..2
; ---------------------------------------------------------------------------
.proc voice_base_addr
    lda #0
    sta ptr_hi
    txa
    sta ptr_lo
    asl a                           ; *2
    clc
    adc ptr_lo                      ; *3
    asl a                           ; *6
    clc
    adc ptr_lo                      ; *7
    clc
    adc #<SID_V1_FL
    sta ptr_lo
    lda #>SID_V1_FL
    adc #0
    sta ptr_hi
    rts
.endproc

; Write freq/ad/sr/wave+gate. A=sr, tmp0=fl, tmp1=fh, tmp2=ad, v_wave,x
.proc voice_write
    pha                             ; sr
    jsr voice_base_addr
    ldy #0
    lda tmp0
    sta (ptr_lo), y                 ; FL
    iny
    lda tmp1
    sta (ptr_lo), y                 ; FH
    ldy #5
    lda tmp2
    sta (ptr_lo), y                 ; AD
    iny
    pla
    sta (ptr_lo), y                 ; SR
    ; Gate on with waveform
    ldy #4
    lda v_wave, x
    ora #SID_GATE
    sta (ptr_lo), y
    rts
.endproc

.proc voice_gate_off
    jsr voice_base_addr
    ldy #4
    lda v_wave, x                   ; same wave, gate clear → release
    sta (ptr_lo), y
    rts
.endproc

.proc voice_cut
    ; Steal path: new SFX follows immediately — keep music muted on X.
    jsr voice_base_addr
    ldy #4
    lda #0
    sta (ptr_lo), y                 ; force silent
    lda #SFX_FREE
    sta v_id, x
    lda #0
    sta v_state, x
    sta v_timer, x
    sta v_phase, x
    rts
.endproc

.proc voice_free
    jsr voice_base_addr
    ldy #4
    lda #0
    sta (ptr_lo), y
    lda #SFX_FREE
    sta v_id, x
    lda #0
    sta v_state, x
    sta v_timer, x
    sta v_phase, x
    jsr music::unmute_voice         ; title music may reclaim this voice
    rts
.endproc

; ---------------------------------------------------------------------------
; Step tables — 7 bytes/step: fl, fh, wave, ad, sr, gate_frames, gap_frames
; wave = 0 ends the effect (fl/fh ignored).
; ---------------------------------------------------------------------------

; 0 UI fire — soft mid pulse, short staccato acknowledge
steps_ui_fire:
    .byte $00, $0E, SID_WAVE_PULSE, $00, $81, 1, 2
    .byte 0, 0, 0, 0, 0, 0, 0

; 1 HS tick — short high click
steps_hs_tick:
    .byte $00, $28, SID_WAVE_PULSE, $00, $84, 1, 2
    .byte 0, 0, 0, 0, 0, 0, 0

; 2 Wave whoop ×3 — rising pulse bursts
steps_wave:
    .byte $00, $0C, SID_WAVE_PULSE, $11, $88, 6, 3
    .byte $00, $10, SID_WAVE_PULSE, $11, $88, 6, 3
    .byte $00, $14, SID_WAVE_PULSE, $11, $88, 7, 6
    .byte 0, 0, 0, 0, 0, 0, 0

; 3 Mine clink — bright short pulse
steps_mine:
    .byte $00, $38, SID_WAVE_PULSE, $00, $96, 2, 4
    .byte $80, $2A, SID_WAVE_PULSE, $00, $85, 1, 3
    .byte 0, 0, 0, 0, 0, 0, 0

; 4 Parcel swoosh — quick rising triangle
steps_parcel:
    .byte $00, $08, SID_WAVE_TRI, $11, $78, 8, 4
    .byte 0, 0, 0, 0, 0, 0, 0

; 5 Player die — noise rumble ~ explode length (7×8 ≈ 56f) + tail
steps_player_die:
    .byte $00, $0A, SID_WAVE_NOISE, $2A, $8A, 48, 16
    .byte 0, 0, 0, 0, 0, 0, 0

; 6 Extra life — cha-ching arpeggio
steps_extra:
    .byte $00, $1C, SID_WAVE_PULSE, $11, $88, 4, 2
    .byte $00, $24, SID_WAVE_PULSE, $11, $88, 4, 2
    .byte $00, $2E, SID_WAVE_PULSE, $11, $A8, 6, 6
    .byte 0, 0, 0, 0, 0, 0, 0

; 7 Rail heal — quick rising swish
steps_heal:
    .byte $00, $12, SID_WAVE_TRI, $00, $86, 5, 4
    .byte 0, 0, 0, 0, 0, 0, 0

; 8 Drone die — very short noise pop
steps_drone_die:
    .byte $00, $14, SID_WAVE_NOISE, $00, $94, 3, 3
    .byte 0, 0, 0, 0, 0, 0, 0

; 9 Parcel collect — friendly high ping (non-extra)
steps_ping:
    .byte $00, $30, SID_WAVE_TRI, $00, $A6, 2, 1
    .byte $00, $3C, SID_WAVE_TRI, $00, $96, 3, 4
    .byte 0, 0, 0, 0, 0, 0, 0

step_ptrs:
    .word steps_ui_fire
    .word steps_hs_tick
    .word steps_wave
    .word steps_mine
    .word steps_parcel
    .word steps_player_die
    .word steps_extra
    .word steps_heal
    .word steps_drone_die
    .word steps_ping

.endscope
