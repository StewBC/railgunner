; Stage init / re-init — player to cross centre, wave counter, draw field.

.proc stage_init_enter
    lda #COL_LT_BLUE
    sta VIC_BORDER

    lda #0
    sta wave

    ; Centre of cross (char coords; design uses intersection)
    lda #19
    sta player_col
    lda #12
    sta player_row

    jsr screen_draw_playfield
    jsr video::init_sprite_palette
    jsr video::install_sprite_frames
    jsr stage_spawn_demo_drones

    lda #MODE_PLAY
    jsr mode_set
    rts
.endproc

.proc stage_init_update
    rts
.endproc

; ---------------------------------------------------------------------------
; Temporary PLAY art harness (not gameplay).
; Six multicolour drones so all sizes/facings are visible:
;   UL quarter centre  — C small
;   UR quarter centre  — B medium
;   LR quarter centre  — A large
;   LL quarter centre  — C/B/A stacked (small / medium / large)
; play_update cycles left→right→up→down every DEMO_ANIM_PERIOD frames.
; VIC sprite coords (not char cells).
; ---------------------------------------------------------------------------

.proc stage_spawn_demo_drones
    lda #0
    sta demo_anim_dir

    ; UL — small
    lda #OBJ_DRONE_C
    ldx #DEMO_X_LEFT
    ldy #DEMO_Y_TOP
    jsr demo_spawn_one
    ; UR — medium
    lda #OBJ_DRONE_B
    ldx #DEMO_X_RIGHT
    ldy #DEMO_Y_TOP
    jsr demo_spawn_one
    ; LR — large (Y staggered vs stack so mux jobs fit before deadline)
    lda #OBJ_DRONE_A
    ldx #DEMO_X_RIGHT
    ldy #DEMO_Y_LR
    jsr demo_spawn_one
    ; LL stack: small / medium / large
    lda #OBJ_DRONE_C
    ldx #DEMO_X_LEFT
    ldy #DEMO_Y_STACK0
    jsr demo_spawn_one
    lda #OBJ_DRONE_B
    ldx #DEMO_X_LEFT
    ldy #DEMO_Y_STACK1
    jsr demo_spawn_one
    lda #OBJ_DRONE_A
    ldx #DEMO_X_LEFT
    ldy #DEMO_Y_STACK2
    jsr demo_spawn_one
    rts
.endproc

; A=kind, X=vic_x_lo (hi cleared), Y=vic_y_int. C set on pool full (ignored).
.proc demo_spawn_one
    sta tmp0                        ; kind
    stx tmp1                        ; x
    sty tmp2                        ; y
    jsr objects::alloc
    bcs spawn_fail

    lda tmp0
    sta objects::obj_kind, x

    ; colour by kind
    cmp #OBJ_DRONE_A
    bne not_a
    lda #SPR_COLOR_DRONE_A
    jmp have_color
not_a:
    cmp #OBJ_DRONE_B
    bne not_b
    lda #SPR_COLOR_DRONE_B
    jmp have_color
not_b:
    lda #SPR_COLOR_DRONE_C
have_color:
    sta objects::obj_sprite_color, x

    lda #OBJA_MULTICOLOR
    sta objects::obj_sprite_attr, x

    lda tmp1
    sta objects::obj_x_lo, x
    lda #0
    sta objects::obj_x_hi, x
    sta objects::obj_x_frac, x
    sta objects::obj_y_frac, x
    lda tmp2
    sta objects::obj_y_int, x

    ; facing from demo_anim_dir (0 at first stage enter)
    jsr demo_ptr_for_slot
    sta objects::obj_sprite_ptr, x

    lda objects::obj_flags, x
    ora #OBJF_RENDER
    sta objects::obj_flags, x
spawn_fail:
    rts
.endproc

; X = object slot. A ← VIC sprite pointer for kind + demo_anim_dir.
; C base $70, B $74, A $78; then + dir (left/right/up/down).
.proc demo_ptr_for_slot
    lda #3
    sec
    sbc objects::obj_kind, x        ; A→2, B→1, C→0
    asl a
    asl a                           ; ×4
    clc
    adc #SPR_PTR_DRONE_C_LEFT
    clc
    adc demo_anim_dir
    rts
.endproc

; Write current demo_anim_dir into every renderable drone slot.
.proc demo_apply_facings
    ldx #1
apply_slots:
    lda objects::obj_flags, x
    and #(OBJF_ALLOCATED | OBJF_RENDER)
    cmp #(OBJF_ALLOCATED | OBJF_RENDER)
    bne apply_next
    lda objects::obj_kind, x
    beq apply_next                  ; skip player
    cmp #OBJ_BONUS
    bcs apply_next                  ; only drones A/B/C (kinds 1..3)
    jsr demo_ptr_for_slot
    sta objects::obj_sprite_ptr, x
apply_next:
    inx
    cpx #OBJECT_CAPACITY
    bne apply_slots
    jsr objects::mark_dirty
    rts
.endproc

; Advance facing every DEMO_ANIM_PERIOD logic ticks; refresh all drone ptrs.
.proc demo_anim_tick
    lda demo_anim_timer
    beq anim_fire
    dec demo_anim_timer
    bne anim_done
anim_fire:
    lda #DEMO_ANIM_PERIOD
    sta demo_anim_timer
    lda demo_anim_dir
    clc
    adc #1
    and #3
    sta demo_anim_dir
    jsr demo_apply_facings
anim_done:
    rts
.endproc
