; Memory layout notes and fixed addresses used by RailGunner.
; Assignments only — keep in sync with .segdef in main.asm.

; Segments (see main.asm):
;   ZEROPAGE  $02     noemit variable map
;   BASIC     $0801   SYS stub (10 SYS 2061)
;   CODE      $080d   executable (start = SYS target)
;   TITLE     $4000   title hires source (bitmap + colour matrix)
;   DATA      $6328   strings / tables (after TITLE)
;
; VIC bank 0 runtime buffers (not PRG-resident source):
;   BITMAP_RAM    $2000   8000-byte hires/multicolour bitmap destination
;   SCREEN_RAM    $0400   text screen / bitmap colour matrix destination
;   COLOR_RAM     $D800   multicolour-bitmap colour nybbles (later)
;
; Launch: tools/agent_session.py assembles, fixes BASIC pointers, pastes RUN
; (agent path); tools/play.sh builds a PRG and autoruns it (user path).

; Default VIC text bank (stock):
;   Screen RAM    $0400
;   Charset ROM   $1000/$1800 (vic sees via $D018)
;   Color RAM     $D800
;   Sprite ptrs   $07F8–$07FF (when sprites used)

; Future fixed regions (not reserved yet):
;   CHARSET_RAM   = $2000   ; collides with bitmap buffer — bank-switch later
;   SPRITE_BLOCK  = $3000

CODE_START      = $080d             ; SYS 2061
TITLE_START     = $4000             ; title_bitmap source
TITLE_COLORS_OFF = 8000             ; title_colors = TITLE_START + 8000
DATA_START      = $6328             ; $4000 + 8000 + 1000
