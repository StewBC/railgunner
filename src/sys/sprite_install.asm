; Game-only: copy drone frame SOURCE from DATA into VIC bank $3000.
;
; Not shared with tst/ demos. Demos assemble frames into their own SPRITES
; segment at $3000 and never reference spr_frames_src. Keep this file out of
; the demo include set so mux harnesses stay decoupled from game art.

.scope video

; Copy spr_frames_src into SPRITE_BLOCK and clear player compositing buffers.
; Call on stage enter (title bitmap wipes $2000–$3F3F).
; Exact byte count (SPRITE_FRAMES_BYTES; not necessarily whole pages).
.proc install_sprite_frames
    lda #<spr_frames_src
    sta ptr_lo
    lda #>spr_frames_src
    sta ptr_hi
    lda #<SPRITE_BLOCK
    sta print_ptr_lo
    lda #>SPRITE_BLOCK
    sta print_ptr_hi

    lda #<SPRITE_FRAMES_BYTES
    sta mux_j                       ; count lo
    lda #>SPRITE_FRAMES_BYTES
    sta mux_i                       ; count hi
    ldy #0
copy_loop:
    lda mux_i
    ora mux_j
    beq copy_done
    lda (ptr_lo), y
    sta (print_ptr_lo), y
    lda mux_j
    bne copy_dec_lo
    dec mux_i
copy_dec_lo:
    dec mux_j
    iny
    bne copy_loop
    inc ptr_hi
    inc print_ptr_hi
    jmp copy_loop
copy_done:

    ; Clear player buffers at $3E00 / $3E40
    lda #0
    tax
clear_player:
    sta PLAYER_BUF_0, x
    sta PLAYER_BUF_1, x
    inx
    cpx #64
    bne clear_player
    rts
.endproc

.endscope
