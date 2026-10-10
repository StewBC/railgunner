; Title music player — 3-voice pattern loop (Ride of the Valkyries sketch).
; Plays on GFX + text title; SFX may steal voices (music advances in silence).
; API: music::start_title, music::stop, music::update,
;      music::mute_voice (X), music::unmute_voice (X)
; Lives in CODE_HI.

.segment "CODE_HI"
.scope music

music_active:   .byte 0
v_mute:         .byte 0, 0, 0       ; 1 = SFX holds this voice
v_pos:          .byte 0, 0, 0       ; byte index into track (multiples of 3)
v_timer:        .byte 0, 0, 0       ; frames left on current note
v_cur_lo:       .byte 0, 0, 0       ; last note freq (for re-apply after unmute)
v_cur_hi:       .byte 0, 0, 0
v_cur_wave:     .byte 0, 0, 0
upd_i:          .byte 0

; Per-voice static voice settings (wave, AD, SR)
; 0 = melody pulse bright, 1 = harmony pulse softer, 2 = bass triangle
v_wave_tbl:     .byte SID_WAVE_PULSE, SID_WAVE_PULSE, SID_WAVE_TRI
v_ad_tbl:       .byte $21, $21, $11
v_sr_tbl:       .byte $A8, $98, $C8

track_lo:
    .byte <music_track0, <music_track1, <music_track2
track_hi:
    .byte >music_track0, >music_track1, >music_track2

; ---------------------------------------------------------------------------
; start_title — begin loop if not already playing (GFX↔text keep running).
; ---------------------------------------------------------------------------
.proc start_title
    lda music_active
    bne st_done
    lda #1
    sta music_active
    ldx #2
st_clr:
    lda #0
    sta v_mute, x
    sta v_pos, x
    sta v_timer, x
    sta v_cur_lo, x
    sta v_cur_hi, x
    dex
    bpl st_clr
    ; Load first note on each voice immediately
    ldx #0
st_first:
    jsr load_next_note
    jsr apply_voice
    inx
    cpx #3
    bcc st_first
st_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; stop — end title music; silence voices not held by SFX.
; ---------------------------------------------------------------------------
.proc stop
    lda music_active
    beq stop_done
    lda #0
    sta music_active
    ldx #2
stop_v:
    lda v_mute, x
    bne stop_next                   ; SFX owns SID for this voice
    jsr silence_voice
stop_next:
    lda #0
    sta v_mute, x
    sta v_timer, x
    sta v_pos, x
    dex
    bpl stop_v
stop_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; mute_voice / unmute_voice — X = voice 0..2 (called from sfx).
; ---------------------------------------------------------------------------
.proc mute_voice
    lda #1
    sta v_mute, x
    rts
.endproc

.proc unmute_voice
    lda #0
    sta v_mute, x
    lda music_active
    beq um_done
    ; Re-apply current note under SFX-free voice
    jsr apply_voice
um_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; update — every frame while active. Advances all tracks; writes unmuted only.
; ---------------------------------------------------------------------------
.proc update
    lda music_active
    beq mu_done
    ldx #0
mu_loop:
    stx upd_i
    lda v_timer, x
    beq mu_expired
    dec v_timer, x
    jmp mu_next
mu_expired:
    jsr load_next_note
    jsr apply_voice
mu_next:
    ldx upd_i
    inx
    cpx #3
    bcc mu_loop
mu_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; load_next_note — X = voice. Reads track at v_pos; handles $FF loop.
; Sets v_timer, v_cur_*.
; ---------------------------------------------------------------------------
.proc load_next_note
    lda track_lo, x
    sta ptr_lo
    lda track_hi, x
    sta ptr_hi
ln_read:
    ldy v_pos, x
    lda (ptr_lo), y
    cmp #$FF
    bne ln_note
    ; loop
    lda #0
    sta v_pos, x
    tay
    lda (ptr_lo), y
ln_note:
    sta v_timer, x                  ; duration
    iny
    lda (ptr_lo), y
    sta v_cur_lo, x
    iny
    lda (ptr_lo), y
    sta v_cur_hi, x
    iny
    tya
    sta v_pos, x
    lda v_wave_tbl, x
    sta v_cur_wave, x
    rts
.endproc

; ---------------------------------------------------------------------------
; apply_voice — X = voice. If muted or inactive, skip SID write.
; Rest (freq 0,0): gate off. Else gate on with voice settings.
; ---------------------------------------------------------------------------
.proc apply_voice
    lda music_active
    beq av_done
    lda v_mute, x
    bne av_done
    ; SFX may still own the channel — only write if sfx voice free
    lda sfx::v_id, x
    cmp #SFX_FREE
    bne av_done

    jsr voice_base
    lda v_cur_lo, x
    ora v_cur_hi, x
    beq av_rest

    ; Note on
    ldy #0
    lda v_cur_lo, x
    sta (ptr_lo), y
    iny
    lda v_cur_hi, x
    sta (ptr_lo), y
    ; pulse width ~50% (harmless for triangle)
    ldy #2
    lda #$00
    sta (ptr_lo), y
    iny
    lda #$08
    sta (ptr_lo), y
    ldy #5
    lda v_ad_tbl, x
    sta (ptr_lo), y
    iny
    lda v_sr_tbl, x
    sta (ptr_lo), y
    ; gate on: first clear gate then set (SID retrigger hygiene)
    ldy #4
    lda v_cur_wave, x
    sta (ptr_lo), y
    ora #SID_GATE
    sta (ptr_lo), y
    rts

av_rest:
    ldy #4
    lda #0
    sta (ptr_lo), y
av_done:
    rts
.endproc

.proc silence_voice
    jsr voice_base
    ldy #4
    lda #0
    sta (ptr_lo), y
    rts
.endproc

.proc voice_base
    lda #0
    sta ptr_hi
    txa
    sta ptr_lo
    asl a
    clc
    adc ptr_lo
    asl a
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

.endscope

.include "../data/music_valkyrie.asm"
