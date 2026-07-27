; Bullet user-defined characters — 8 glyphs × 8 bytes (hires, 1 bit/pixel).
; Installed over ROM copy at CHARSET_RAM (screen codes SC_BULLET_V0..H3).
;
; Pixel legend (one row): bit7 = left … bit0 = right.
;   ...OO...  = %00011000   (2px blob, centred for vertical travel)
;
; Vertical: 2 rows tall, walks top→bottom across the cell (phases 0..3).
; Horizontal: 2 cols wide, walks left→right (phases 0..3), vertically centred.
;
; Playback order (bullets consumer):
;   DOWN  / RIGHT : phase 0 → 1 → 2 → 3
;   UP    / LEFT  : phase 3 → 2 → 1 → 0
;
; Layout is contiguous from chr_bullet_udg (= chr_bullet_v0) for 64 bytes.

chr_bullet_udg:

; --- Vertical phase 0: rows 0–1 (top; first when firing DOWN) ---
chr_bullet_v0:
    .byte %00011000
    .byte %00011000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000

; phase 1: rows 2–3
chr_bullet_v1:
    .byte %00000000
    .byte %00000000
    .byte %00011000
    .byte %00011000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000

; phase 2: rows 4–5
chr_bullet_v2:
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00011000
    .byte %00011000
    .byte %00000000
    .byte %00000000

; phase 3: rows 6–7 (bottom; first when firing UP)
chr_bullet_v3:
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00011000
    .byte %00011000

; --- Horizontal phase 0: cols 0–1 (left; first when firing RIGHT) ---
chr_bullet_h0:
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %11000000
    .byte %11000000
    .byte %00000000
    .byte %00000000
    .byte %00000000

; phase 1: cols 2–3
chr_bullet_h1:
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00110000
    .byte %00110000
    .byte %00000000
    .byte %00000000
    .byte %00000000

; phase 2: cols 4–5
chr_bullet_h2:
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00001100
    .byte %00001100
    .byte %00000000
    .byte %00000000
    .byte %00000000

; phase 3: cols 6–7 (right; first when firing LEFT)
chr_bullet_h3:
    .byte %00000000
    .byte %00000000
    .byte %00000000
    .byte %00000011
    .byte %00000011
    .byte %00000000
    .byte %00000000
    .byte %00000000

CHR_BULLET_UDG_BYTES = SC_BULLET_COUNT * 8
