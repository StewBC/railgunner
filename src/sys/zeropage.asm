; Zero-page map — single owner of ZP layout.
; Included under .segment "ZEROPAGE" (noemit).

; Mode / frame
game_mode:      .res 1              ; MODE_* constant
frame_count:    .res 1              ; free-running low byte (poll ticks)

; Input (normalized)
input_dirs:     .res 1              ; bit0=U bit1=D bit2=L bit3=R (1 = pressed)
input_fire:     .res 1              ; 1 = fire held
input_fire_edge:.res 1              ; 1 = fire pressed this frame (edge)
input_fire_prev:.res 1              ; previous frame fire (edge detect)

; Session state
score0:         .res 1              ; BCD or binary digits later; 3 bytes raw for now
score1:         .res 1
score2:         .res 1
lives:          .res 1
health:         .res 1
ammo:           .res 1
level:          .res 1
wave:           .res 1

; Player placeholder (char coords for later)
player_col:     .res 1
player_row:     .res 1

; Mode-local timers / scratch
mode_timer:     .res 1
mode_state:     .res 1

; General temps / pointers
tmp0:           .res 1
tmp1:           .res 1
tmp2:           .res 1
ptr_lo:         .res 1
ptr_hi:         .res 1
; screen_print (screen_put_xy reuses ptr_* and tmp*)
print_ptr_lo:   .res 1
print_ptr_hi:   .res 1
print_col:      .res 1              ; base column (must survive put_xy)
print_row:      .res 1              ; base row
draw_i:         .res 1              ; playfield draw loops (put_xy clobbers tmp*)
draw_j:         .res 1
