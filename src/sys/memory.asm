; Memory layout notes and fixed addresses used by RailGunner.
; Assignments only — keep in sync with .segdef in main.asm.

; Segments (see main.asm):
;   ZEROPAGE  $02     noemit variable map
;   BASIC     $0801   SYS stub (10 SYS 2061)
;   CODE      $080d   executable (start = SYS target)
;   DATA      $2000   strings / tables (grows; relocate if code expands)
;
; Launch: tools/launch_railgunner.py assembles, fixes VARTAB=$080D, pastes RUN.

; Default VIC text bank (stock):
;   Screen RAM    $0400
;   Charset ROM   $1000/$1800 (vic sees via $D018)
;   Color RAM     $D800
;   Sprite ptrs   $07F8–$07FF (when sprites used)

; Future fixed regions (not reserved yet):
;   CHARSET_RAM   = $2000   ; if relocating DATA, pick free block
;   SPRITE_BLOCK  = $3000

CODE_START      = $080d             ; SYS 2061
DATA_START      = $2000
