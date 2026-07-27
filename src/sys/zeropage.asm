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

; Attract loop countdown (16-bit frames remaining on current attract page)
attract_lo:     .res 1
attract_hi:     .res 1

; Text-title score colour wheel
score_color_phase: .res 1           ; 0..9 base index into palette
score_color_tick:  .res 1           ; frames until next rotate

; Menu letter keys (level + edge); S also drives joy-down in play
input_key_s:    .res 1
input_key_i:    .res 1
input_key_s_edge: .res 1
input_key_i_edge: .res 1
input_key_s_prev: .res 1
input_key_i_prev: .res 1

; Typewriter (story screen): source cursor + screen pen + previous cell
type_src_lo:    .res 1
type_src_hi:    .res 1
type_col:       .res 1
type_row:       .res 1
type_prev_col:  .res 1              ; $FF = no previous glyph yet
type_prev_row:  .res 1

; General temps / pointers
tmp0:           .res 1
tmp1:           .res 1
tmp2:           .res 1
ptr_lo:         .res 1
ptr_hi:         .res 1
; screen_print source pointer (dest base is computed into ptr_* once per string)
print_ptr_lo:   .res 1
print_ptr_hi:   .res 1
draw_i:         .res 1              ; playfield draw loops (put_xy clobbers tmp*)
draw_j:         .res 1
