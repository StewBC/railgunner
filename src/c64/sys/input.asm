; Input: normalize dirs + fire from joystick port 2 AND keyboard WASD/Space.
;
; Hardware paths (OR'd together):
;   - Joystick port 2 on CIA1 PRA bits 0-4 (also host joy / c64m joy-emu if on port 2)
;   - Joystick port 1 fire on PRB bit 4 (if user maps emu stick to port 1)
;   - Keyboard matrix WASD + Space
;
; c64m "keyboard joystick" layout is a user preference; the game does not require it.

.proc input_poll
    lda #0
    sta input_dirs
    sta input_fire
    sta input_fire_edge
    sta input_key_s
    sta input_key_i
    sta input_key_s_edge
    sta input_key_i_edge
    sta input_runstop
    sta input_runstop_edge

    ; CIA direction: PA out (matrix select + joy2 sense), PB in (matrix + joy1)
    lda #$ff
    sta CIA1_DDRA
    lda #$00
    sta CIA1_DDRB

    ; --- Joystick port 2 (PRA, active low) ---------------------------------
    lda #$ff
    sta CIA1_PRA
    lda CIA1_PRA
    eor #$ff                        ; 1 = pressed
    tax
    and #(JOY_UP | JOY_DOWN | JOY_LEFT | JOY_RIGHT)
    sta input_dirs
    txa
    and #JOY_FIRE
    beq joy2_fire_done
    lda #1
    sta input_fire
joy2_fire_done:

    ; --- Joystick port 1 fire (PRB bit 4) — optional / emu on port 1 -------
    lda CIA1_PRB
    eor #$ff
    and #JOY_FIRE
    beq joy1_fire_done
    lda #1
    sta input_fire
joy1_fire_done:

    ; --- Keyboard matrix --------------------------------------------------
    jsr input_scan_keyboard

    ; Idle PRA high (joy2 release / KERNAL-friendly)
    lda #$ff
    sta CIA1_PRA

    ; Rising edge on fire
    lda input_fire
    beq save_fire_prev
    lda input_fire_prev
    bne save_fire_prev
    lda #1
    sta input_fire_edge
save_fire_prev:
    lda input_fire
    sta input_fire_prev

    ; Rising edge on S / I (title menu)
    lda input_key_s
    beq save_s_prev
    lda input_key_s_prev
    bne save_s_prev
    lda #1
    sta input_key_s_edge
save_s_prev:
    lda input_key_s
    sta input_key_s_prev

    lda input_key_i
    beq save_i_prev
    lda input_key_i_prev
    bne save_i_prev
    lda #1
    sta input_key_i_edge
save_i_prev:
    lda input_key_i
    sta input_key_i_prev

    ; Rising edge on RUN/STOP
    lda input_runstop
    beq save_runstop_prev
    lda input_runstop_prev
    bne save_runstop_prev
    lda #1
    sta input_runstop_edge
save_runstop_prev:
    lda input_runstop
    sta input_runstop_prev

    inc frame_count
    rts
.endproc

; Scan WASD + Space + I + RUN/STOP; OR into dirs/fire; set menu keys.
; PRA = select (0-bit), PRB = data (0 = down). Clobbers A,X.
.proc input_scan_keyboard
    ; W/A/S share select row 1 — one strobe, one PRB read (same idiom as Space/RUNSTOP)
    lda #KEY_SEL_W                  ; == KEY_SEL_A == KEY_SEL_S
    sta CIA1_PRA
    lda CIA1_PRB
    tax
    and #KEY_BIT_W
    bne not_w
    lda input_dirs
    ora #JOY_UP
    sta input_dirs
not_w:
    txa
    and #KEY_BIT_A
    bne not_a
    lda input_dirs
    ora #JOY_LEFT
    sta input_dirs
not_a:
    txa
    and #KEY_BIT_S
    bne not_s
    lda input_dirs
    ora #JOY_DOWN
    sta input_dirs
    lda #1
    sta input_key_s
not_s:
    ; D → right (own row)
    lda #KEY_SEL_D
    sta CIA1_PRA
    lda CIA1_PRB
    and #KEY_BIT_D
    bne not_d
    lda input_dirs
    ora #JOY_RIGHT
    sta input_dirs
not_d:
    ; I → instructions (menu only; not a play control)
    lda #KEY_SEL_I
    sta CIA1_PRA
    lda CIA1_PRB
    and #KEY_BIT_I
    bne not_i
    lda #1
    sta input_key_i
not_i:
    ; Space → fire  and  RUN/STOP → kill switch (same matrix row 7)
    lda #KEY_SEL_SPACE
    sta CIA1_PRA
    lda CIA1_PRB
    tax
    and #KEY_BIT_SPACE
    bne not_space
    lda #1
    sta input_fire
not_space:
    txa
    and #KEY_BIT_RUNSTOP
    bne not_runstop
    lda #1
    sta input_runstop
not_runstop:
    rts
.endproc
