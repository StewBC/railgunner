; Attract frontend: hires graphics page ↔ text menu (15s each).
;
; MODE_TITLE_GFX  — bitmap art; FIRE or timeout → text menu
; MODE_TITLE_TEXT — scores + credits; FIRE → game, S/I → stubs, timeout → gfx

; ---------------------------------------------------------------------------
; Shared: reset 16-bit attract countdown to ATTRACT_FRAMES.
; ---------------------------------------------------------------------------
.proc attract_reset_timer
    lda #<ATTRACT_FRAMES
    sta attract_lo
    lda #>ATTRACT_FRAMES
    sta attract_hi
    rts
.endproc

; Decrement attract timer; SEC if expired (and timer left at 0), else CLC.
.proc attract_tick
    lda attract_lo
    ora attract_hi
    beq attract_expired
    lda attract_lo
    bne attract_dec_lo
    dec attract_hi
attract_dec_lo:
    dec attract_lo
    lda attract_lo
    ora attract_hi
    beq attract_expired
    clc
    rts
attract_expired:
    sec
    rts
.endproc

; ===========================================================================
; Graphics title (hires)
; ===========================================================================

.proc title_gfx_enter
    lda #COL_BLACK
    sta VIC_BORDER
    sta VIC_BG0

    ; VIC bank 0 ($0000–$3FFF): bits 0–1 of $DD00 are inverted select.
    lda CIA2_PRA
    and #%11111100
    ora #%00000011
    sta CIA2_PRA

    jsr title_copy_bitmap
    jsr title_copy_colors

    lda #VIC_CTRL1_BITMAP
    sta VIC_CTRL1
    lda #VIC_CTRL2_HIRES
    sta VIC_CTRL2
    lda #VIC_MEM_BITMAP
    sta VIC_MEM

    jsr attract_reset_timer
    lda #MENU_FIRE_GUARD
    sta mode_timer                  ; ignore held fire from previous page
    rts
.endproc

.proc title_gfx_update
    ; Debounce fire after enter
    lda mode_timer
    beq gfx_fire_ok
    dec mode_timer
    jmp gfx_attract
gfx_fire_ok:
    lda input_fire_edge
    beq gfx_attract
    jsr vic_text_mode
    lda #MODE_TITLE_TEXT
    jsr mode_set
    rts
gfx_attract:
    jsr attract_tick
    bcc gfx_done
    jsr vic_text_mode
    lda #MODE_TITLE_TEXT
    jsr mode_set
gfx_done:
    rts
.endproc

; ---------------------------------------------------------------------------
; Copy title_bitmap (8000) → BITMAP_RAM ($2000).
; ---------------------------------------------------------------------------
.proc title_copy_bitmap
    lda #<title_bitmap
    sta ptr_lo
    lda #>title_bitmap
    sta ptr_hi
    lda #<BITMAP_RAM
    sta print_ptr_lo
    lda #>BITMAP_RAM
    sta print_ptr_hi

    ldx #31                         ; 31×256 = 7936
    ldy #0
bmp_page:
    lda (ptr_lo), y
    sta (print_ptr_lo), y
    iny
    bne bmp_page
    inc ptr_hi
    inc print_ptr_hi
    dex
    bne bmp_page

    ldy #0
bmp_tail:
    lda (ptr_lo), y
    sta (print_ptr_lo), y
    iny
    cpy #64
    bne bmp_tail
    rts
.endproc

; ---------------------------------------------------------------------------
; Copy title_colors (1000) → SCREEN_RAM ($0400) — hires colour matrix.
; ---------------------------------------------------------------------------
.proc title_copy_colors
    lda #<title_colors
    sta ptr_lo
    lda #>title_colors
    sta ptr_hi
    lda #<SCREEN_RAM
    sta print_ptr_lo
    lda #>SCREEN_RAM
    sta print_ptr_hi

    ldx #3                          ; 3×256 = 768
    ldy #0
col_page:
    lda (ptr_lo), y
    sta (print_ptr_lo), y
    iny
    bne col_page
    inc ptr_hi
    inc print_ptr_hi
    dex
    bne col_page

    ldy #0
col_tail:
    lda (ptr_lo), y
    sta (print_ptr_lo), y
    iny
    cpy #(BITMAP_COLOR_SIZE - 768)
    bne col_tail
    rts
.endproc

; ===========================================================================
; Text title (menu + past heroes)
; ===========================================================================

; Layout rows (0-based)
TT_ROW_TITLE    = 0
TT_ROW_HEROES   = 2
TT_ROW_SCORE0   = 3                 ; scores occupy rows 3..12
TT_ROW_FIRE     = 14
TT_ROW_STORY    = 15
TT_ROW_INSTR    = 16
TT_ROW_CODE     = 18
TT_ROW_AI       = 19
TT_ROW_PROD     = 21
TT_ROW_NAME     = 22

; Centred columns for each string ( (40 - len) / 2 )
TT_COL_TITLE    = 14                ; "RAIL GUNNER" = 11
TT_COL_HEROES   = 14                ; "PAST HEROES" = 11
TT_COL_SCORE    = 11                ; " 1.   ---   000000" = 18
TT_COL_FIRE     = 14                ; 12
TT_COL_STORY    = 14                ; 11
TT_COL_INSTR    = 11                ; 18
TT_COL_CODE     = 13                ; 14
TT_COL_AI       = 9                 ; 22
TT_COL_PROD     = 14                ; 11
TT_COL_NAME     = 10                ; 19

.proc title_text_enter
    jsr vic_text_mode               ; text mode, black border/bg, clear

    ; --- static lines ---
    lda #<str_title
    sta ptr_lo
    lda #>str_title
    sta ptr_hi
    ldx #TT_COL_TITLE
    ldy #TT_ROW_TITLE
    jsr screen_print
    lda #COL_YELLOW
    ldy #TT_ROW_TITLE
    jsr screen_color_row

    lda #<str_past_heroes
    sta ptr_lo
    lda #>str_past_heroes
    sta ptr_hi
    ldx #TT_COL_HEROES
    ldy #TT_ROW_HEROES
    jsr screen_print
    lda #COL_CYAN
    ldy #TT_ROW_HEROES
    jsr screen_color_row

    ; Ten score lines
    lda #0
    sta draw_i
tt_score_draw:
    lda draw_i
    asl a
    tax
    lda hs_line_ptrs, x
    sta ptr_lo
    lda hs_line_ptrs + 1, x
    sta ptr_hi
    ldx #TT_COL_SCORE
    lda draw_i
    clc
    adc #TT_ROW_SCORE0
    tay
    jsr screen_print
    inc draw_i
    lda draw_i
    cmp #10
    bcc tt_score_draw

    lda #<str_fire_to_play
    sta ptr_lo
    lda #>str_fire_to_play
    sta ptr_hi
    ldx #TT_COL_FIRE
    ldy #TT_ROW_FIRE
    jsr screen_print
    lda #COL_WHITE
    ldy #TT_ROW_FIRE
    jsr screen_color_row

    lda #<str_s_for_story
    sta ptr_lo
    lda #>str_s_for_story
    sta ptr_hi
    ldx #TT_COL_STORY
    ldy #TT_ROW_STORY
    jsr screen_print
    lda #COL_LT_GREEN
    ldy #TT_ROW_STORY
    jsr screen_color_row

    lda #<str_i_for_instructions
    sta ptr_lo
    lda #>str_i_for_instructions
    sta ptr_hi
    ldx #TT_COL_INSTR
    ldy #TT_ROW_INSTR
    jsr screen_print
    lda #COL_LT_GREEN
    ldy #TT_ROW_INSTR
    jsr screen_color_row

    lda #<str_code_art_by
    sta ptr_lo
    lda #>str_code_art_by
    sta ptr_hi
    ldx #TT_COL_CODE
    ldy #TT_ROW_CODE
    jsr screen_print
    lda #COL_LT_GRAY
    ldy #TT_ROW_CODE
    jsr screen_color_row

    lda #<str_credits_ai
    sta ptr_lo
    lda #>str_credits_ai
    sta ptr_hi
    ldx #TT_COL_AI
    ldy #TT_ROW_AI
    jsr screen_print
    lda #COL_LT_BLUE
    ldy #TT_ROW_AI
    jsr screen_color_row

    lda #<str_produced_by
    sta ptr_lo
    lda #>str_produced_by
    sta ptr_hi
    ldx #TT_COL_PROD
    ldy #TT_ROW_PROD
    jsr screen_print
    lda #COL_LT_GRAY
    ldy #TT_ROW_PROD
    jsr screen_color_row

    lda #<str_producer
    sta ptr_lo
    lda #>str_producer
    sta ptr_hi
    ldx #TT_COL_NAME
    ldy #TT_ROW_NAME
    jsr screen_print
    lda #COL_PURPLE
    ldy #TT_ROW_NAME
    jsr screen_color_row

    lda #0
    sta score_color_phase
    sta score_color_tick
    jsr title_text_color_scores

    jsr attract_reset_timer
    lda #MENU_FIRE_GUARD
    sta mode_timer
    rts
.endproc

.proc title_text_update
    ; Colour wheel for past-heroes rows
    jsr title_text_rotate_colors

    ; Fire guard after enter / return from gfx
    lda mode_timer
    beq tt_input
    dec mode_timer
    jmp tt_attract
tt_input:
    lda input_fire_edge
    beq tt_try_s
    lda #MODE_GAME_INIT
    jsr mode_set
    rts
tt_try_s:
    lda input_key_s_edge
    beq tt_try_i
    lda #MODE_STORY
    jsr mode_set
    rts
tt_try_i:
    lda input_key_i_edge
    beq tt_attract
    lda #MODE_INSTRUCTIONS
    jsr mode_set
    rts
tt_attract:
    jsr attract_tick
    bcc tt_done
    lda #MODE_TITLE_GFX
    jsr mode_set
tt_done:
    rts
.endproc

; Advance score colour phase every SCORE_COLOR_PERIOD frames; repaint rows.
.proc title_text_rotate_colors
    inc score_color_tick
    lda score_color_tick
    cmp #SCORE_COLOR_PERIOD
    bcc rotate_done
    lda #0
    sta score_color_tick
    inc score_color_phase
    lda score_color_phase
    cmp #10
    bcc rotate_paint
    lda #0
    sta score_color_phase
rotate_paint:
    jsr title_text_color_scores
rotate_done:
    rts
.endproc

.proc title_text_color_scores
    lda #0
    sta draw_i
tt_col_loop:
    ; colour index = (phase + row) mod 10
    lda score_color_phase
    clc
    adc draw_i
tt_col_mod:
    cmp #10
    bcc tt_col_ok
    sec
    sbc #10
    jmp tt_col_mod
tt_col_ok:
    tax
    lda score_color_table, x
    pha
    lda draw_i
    clc
    adc #TT_ROW_SCORE0
    tay
    pla
    jsr screen_color_row
    inc draw_i
    lda draw_i
    cmp #10
    bcc tt_col_loop
    rts
.endproc

; 10 bright colours for the heroes wheel (readable on black)
score_color_table:
    .byte COL_RED
    .byte COL_ORANGE
    .byte COL_YELLOW
    .byte COL_LT_GREEN
    .byte COL_GREEN
    .byte COL_CYAN
    .byte COL_LT_BLUE
    .byte COL_PURPLE
    .byte COL_LT_RED
    .byte COL_LT_GRAY
