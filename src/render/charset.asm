; Character set @ CHARSET_RAM ($2800) — PRG-resident (segment CHARSET).
; Full font including UDGs is loaded from assets/charset/railgunner_charset.bin.
; No C64 ROM copy; no bar/bullet overlay (baked into the atlas).

; ---------------------------------------------------------------------------
; charset_install — cold init (once). Font already at $2800 from PRG load.
; ---------------------------------------------------------------------------
.proc charset_install
    rts
.endproc
