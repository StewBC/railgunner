; Futuristic 8×8 font — screencodes 0..63 (512 bytes), then zero-fill to 2K.
; Lives in segment CHARSET @ CHARSET_RAM ($2800). No C64 ROM copy.
; Glyphs 64..255 blank until UDG overlays (bars $D7, bullets $F0) install.
;
; Atlas source: assets/fonts/screencode_0_63_futura_8x8.png
; Binary:       assets/fonts/screencode_0_63_futura_8x8.bin

chr_font_base:
    .incbin "../../assets/fonts/screencode_0_63_futura_8x8.bin"
CHR_FONT_GLYPHS = 64
CHR_FONT_BYTES  = CHR_FONT_GLYPHS * 8   ; 512

    .res CHARSET_SIZE - CHR_FONT_BYTES, 0
