; Placeholder sprite data. Final assets replace/extend this region.

.align 64
sprite_placeholder:
    .repeat 63
        .byte $00
    .endrepeat
    .byte $00

; Dynamic player compositing buffers (pointers $F8/$F9).
* = PLAYER_BUF_0
player_sprite_buffer_0:
    .res 64
player_sprite_buffer_1:
    .res 64
