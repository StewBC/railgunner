; Profile-only observer: native M=X16 entry; preserves A/X/Y/P/D/DBR/SP.
; No Tool calls, IRQ masking, renderer calls or gameplay-state writes.
; Onscreen means render-flagged rectangle anchor x=1..343,y=30..249;
; it is not a pixel visibility or occlusion measurement.
 longa on
 longi on
game_observe ENTRY
 php
 rep #$30
 cld
 pha
 phx
 phy
 phd
 phb
 phk
 plb
 lda game_dp
 tcd
 stz game_obs_allocated
 stz game_obs_render
 stz game_obs_onscreen
 ldx #12
 lda #0
go_zero_kind sta game_obs_kind_current,x
 dex
 dex
 bpl go_zero_kind
 ldy #0
go_slot lda objects__obj_flags,y
 and #1
 beq go_not_allocated
 inc game_obs_allocated
go_not_allocated lda objects__obj_flags,y
 and #2
 beq go_next
 inc game_obs_render
 lda objects__obj_kind,y
 and #255
 cmp #6
 bcc go_kind_valid
 lda #6
go_kind_valid asl a
 tax
 inc game_obs_kind_current,x
 lda objects__obj_x_lo,y
 and #255
 sta go_x
 lda objects__obj_x_hi,y
 and #255
 xba
 ora go_x
 beq go_next
 cmp #344
 bcs go_next
 lda objects__obj_y_int,y
 and #255
 cmp #30
 bcc go_next
 cmp #250
 bcs go_next
 inc game_obs_onscreen
go_next iny
 cpy #24
 bcc go_slot
 inc game_obs_samples
 bne go_sample_counted
 inc game_obs_samples+2
go_sample_counted lda game_obs_render
 cmp game_obs_max_render
 bcc go_no_peak
 beq go_no_peak
 jsr go_capture_peak
go_no_peak anop
 lda game_obs_allocated
 cmp game_obs_max_allocated
 bcc go_max_allocated
 sta game_obs_max_allocated
go_max_allocated anop
 lda game_obs_render
 cmp game_obs_max_render
 bcc go_max_render
 sta game_obs_max_render
go_max_render anop
 lda game_obs_onscreen
 cmp game_obs_max_onscreen
 bcc go_max_onscreen
 sta game_obs_max_onscreen
go_max_onscreen anop
 ldx #12
go_kind_max lda game_obs_kind_current,x
 cmp game_obs_kind_max,x
 bcc go_kind_keep
 sta game_obs_kind_max,x
go_kind_keep dex
 dex
 bpl go_kind_max
 plb
 pld
 ply
 plx
 pla
 plp
 rtl
go_capture_peak ldx #0
 ldy #0
go_capture_slot lda objects__obj_x_lo,y
 and #255
 sta go_x
 lda objects__obj_x_hi,y
 and #255
 xba
 ora go_x
 sta game_obs_peak_objects,x
 lda objects__obj_y_int,y
 and #255
 sta game_obs_peak_objects+2,x
 lda objects__obj_sprite_ptr,y
 and #255
 sta game_obs_peak_objects+4,x
 cmp #$f8
 bcc go_nonplayer
 cmp #$fa
 bcs go_nonplayer
 lda native_player_frame
 and #3
 bra go_frame
go_nonplayer lda #0
go_frame sta game_obs_peak_objects+6,x
 lda objects__obj_sprite_color,y
 and #255
 sta game_obs_peak_objects+8,x
 lda objects__obj_sprite_attr,y
 and #255
 sta game_obs_peak_objects+10,x
 lda objects__obj_kind,y
 and #255
 sta game_obs_peak_objects+12,x
 lda objects__obj_flags,y
 and #255
 sta game_obs_peak_objects+14,x
 txa
 clc
 adc #16
 tax
 iny
 cpy #24
 bcc go_capture_slot
 lda native_present
 and #255
 sta game_obs_peak_present
 lda game_mode
 and #255
 sta game_obs_peak_mode
 lda native_player_frame
 and #255
 sta game_obs_peak_player_frame
 lda game_obs_samples
 sta game_obs_peak_sample
 lda game_obs_samples+2
 sta game_obs_peak_sample+2
 rts
game_obs_allocated ENTRY
 ds 2
game_obs_render ENTRY
 ds 2
game_obs_onscreen ENTRY
 ds 2
game_obs_max_allocated ENTRY
 ds 2
game_obs_max_render ENTRY
 ds 2
game_obs_max_onscreen ENTRY
 ds 2
game_obs_kind_current ENTRY
 ds 14
game_obs_kind_max ENTRY
 ds 14
game_obs_samples ENTRY
 ds 4
game_obs_peak_objects ENTRY
 ds 384
game_obs_peak_present ENTRY
 ds 2
game_obs_peak_mode ENTRY
 ds 2
game_obs_peak_player_frame ENTRY
 ds 2
game_obs_peak_sample ENTRY
 ds 4
go_x ds 2
