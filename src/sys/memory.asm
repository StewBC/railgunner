; Memory layout notes and fixed addresses used by RailGunner.
; Assignments only — keep in sync with .segdef in main.asm.

; Segments (see main.asm):
;   ZEROPAGE  $02     noemit variable map
;   BASIC     $0801   SYS stub (10 SYS 2061)
;   CODE      $080d   executable (start = SYS target)
;   TITLE     $4000   title hires source (bitmap + colour matrix)
;   DATA      $6328   strings / tables / sprite frame source
;   OBJECTS   $C000   noemit graphical-object/mux runtime state
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

; Game sprite/runtime regions (VIC bank 0 = $0000–$3FFF):
;   BITMAP_RAM    = $2000   ; title hires dest, 8000 bytes → $2000–$3F3F
;   SPRITE_BLOCK  = $3000   ; installed drone frames (runtime copy)
;   PLAYER_BUF_0  = $3E00   ; sprite pointer $F8 (runtime; zeroed on install)
;   PLAYER_BUF_1  = $3E40   ; sprite pointer $F9
;   OBJECT_STATE  = $C000   ; pool/plans/scratch through $C8FF
;
; Title blit overwrites $2000–$3F3F. video::install_sprite_frames (game-only,
; stage enter) copies spr_frames_src from DATA into $3000 and clears player bufs.
; tst/ demos place their own frames in a SPRITES segment at $3000 instead.
;
; After install (64-byte blocks, multicolour):
;   $3000–$30FF  drone C (small)  left/right/up/down   ptr $C0–$C3
;   $3100–$31FF  drone B (medium) left/right/up/down   ptr $C4–$C7
;   $3200–$32FF  drone A (large)  left/right/up/down   ptr $C8–$CB
;   $3E00–$3E7F  player dynamic buffers                 ptr $F8–$F9
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
;   $C800-$C8FF   scanline bucket heads

CODE_START      = $080d             ; SYS 2061
TITLE_START     = $4000             ; title_bitmap source
TITLE_COLORS_OFF = 8000             ; title_colors = TITLE_START + 8000
DATA_START      = $6328             ; $4000 + 8000 + 1000
SPRITE_BLOCK    = $3000
PLAYER_BUF_0    = $3E00
PLAYER_BUF_1    = $3E40
OBJECT_STATE    = $C000
SPRITE_FRAMES_BYTES = 12 * 64       ; drone bank only (player bufs zeroed)
BITMAP_END      = $3F40             ; first free after 8000-byte bitmap
