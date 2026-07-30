; Full 2K VIC text font @ CHARSET_RAM ($2800) — segment CHARSET.
; Glyphs 0..63  text (futura)
; Glyphs $40..$6E UDG pack (rails, bars, bullets, life) — see const.asm map
; Remainder zero.
;
; Source atlas: assets/charset/railgunner_charset.png (16×7 cells = 112 glyphs)

chr_font_base:
    .incbin "../../assets/charset/railgunner_charset.bin"
