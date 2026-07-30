; Memory layout notes and fixed addresses used by RailGunner.
; Assignments only — keep in sync with .segdef in main.asm.

; Segments (see main.asm):
;   ZEROPAGE  $02     noemit variable map
;   BASIC     $0801   SYS stub (10 SYS 2061)
;   CODE      $080d   low executable (must end before CHARSET $2800)
;   CHARSET   $2800   2K VIC text font (futura 0..63; bars/bullets overlaid at init)
;   TITLE     $4000   title hires source (bitmap + colour matrix)
;   DATA      $6328   strings / tables / sprite frame source
;   CODE_HI   $7400   overflow game logic (rail damage, cargo; after DATA)
;   OBJECTS   $C000   noemit graphical-object/mux runtime state
;
; VIC bank 0:
;   SCREEN_RAM    $0400   text screen
;   CHARSET_RAM   $2800   = segment CHARSET (PRG-resident; not $2000)
;   COLOR_RAM     $D800
;
; Launch: tools/agent_session.py assembles, fixes BASIC pointers, pastes RUN
; (agent path); tools/play.sh builds a PRG and autoruns it (user path).

; Default VIC text bank (stock):
;   Screen RAM    $0400
;   Charset ROM   $1000/$1800 (vic sees via $D018)
;   Color RAM     $D800
;   Sprite ptrs   $07F8–$07FF (when sprites used)

; VIC bank 0 ($0000–$3FFF) — play + all text UI:
;   CODE          ~$080D–$24xx   (must end before CHARSET $2800)
;   CHARSET_RAM   = $2800   ; 2K font segment (no C64 ROM copy)
;   SPRITE_BLOCK  = $3000   ; drone frames (reinstall each stage enter)
;   PLAYER_BUF_0  = $3E00   ; sprite pointer $F8
;   PLAYER_BUF_1  = $3E40   ; sprite pointer $F9
;
; VIC bank 3 ($C000–$FFFF) — title hires only (parked once at cold init):
;   OBJECT_STATE  = $C000   ; pool/mux runtime (CPU); not shown in title bank
;   TITLE_MATRIX  = $CC00   ; hires colour matrix (1000 bytes)
;   TITLE_BITMAP  = $E000   ; 8000-byte bitmap under KERNAL ROM
;
; Attract: switch CIA2 bank + $D018; no re-copy. Text always uses bank 0 + RAM font.
; tst/ demos place their own frames in a SPRITES segment at $3000 instead.
;
; After cold init + stage sprite install:
;   $2800–$2FFF  character set (0..63 futura; $D7 bars; $F0–$FF bullets)
;   $3000–$30FF  drone C   ptr $C0–$C3
;   $3100–$31FF  drone B   ptr $C4–$C7
;   $3200–$32FF  drone A   ptr $C8–$CB
;   $3300–$333F  parcel    ptr $CC
;   $3E00–$3E7F  player buffers  ptr $F8–$F9
;   $CC00–$CFCF  title colour matrix (idle during play)
;   $E000–$FF3F  title bitmap under KERNAL (idle during play)
;
; OBJECTS exact pages (all 24-byte arrays stay inside one page):
;   $C000-$C0EF   core object SoA (flags through sprite attributes)
;   $C100-$C1EF   velocity/future fields and main pending events
;   $C200-$C22F   IRQ event banks 0/1
;   $C230-$C247   free stack + count
;   $C248-$C257   hardware owner/interest maps
;   $C258-$C26F   collision, plan, video/frame, and diagnostic scalars
;   $C270-$C277   builder last occupant for hardware lanes 0-7
;   $C278         render-state dirty byte
;   $C300-$C4FF   immutable plan 0
;   $C500-$C6FF   immutable plan 1
;   $C700-$C7D8   indexed builder arrays/count
;   $C800-$C8FF   reserved former scanline bucket page
;   $C900-$C9C6   rail damage + cargo state (outside objects::init wipe;
;                  game_init_enter resets it through rail/cargo APIs)

CODE_START      = $080d             ; SYS 2061
TITLE_START     = $4000             ; title_bitmap source
TITLE_COLORS_OFF = 8000             ; title_colors = TITLE_START + 8000
DATA_START      = $6328             ; $4000 + 8000 + 1000
SPRITE_BLOCK    = $3000
PLAYER_BUF_0    = $3E00
PLAYER_BUF_1    = $3E40
OBJECT_STATE    = $C000
SPRITE_FRAMES_BYTES = 27 * 64       ; drones + cargo + add_* + player/drone explode
BITMAP_END      = $3F40             ; first free after 8000-byte bitmap
