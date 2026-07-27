; Hardware and game constants (shared).
; Included early from main.asm — assignments only, no code emit.

; ---------------------------------------------------------------------------
; VIC / CIA / memory map
; ---------------------------------------------------------------------------
SCREEN_RAM      = $0400
COLOR_RAM       = $D800
BITMAP_RAM      = $2000             ; 8KB VIC bitmap buffer (bank 0)
VIC_BORDER      = $D020
VIC_BG0         = $D021
VIC_CTRL1       = $D011
VIC_CTRL2       = $D016
VIC_MEM         = $D018
VIC_SPR_X_MSB   = $D010
VIC_SPR_ENABLE  = $D015
VIC_SPR_Y_EXPAND = $D017
VIC_IRQ_STATUS  = $D019
VIC_IRQ_ENABLE  = $D01A
VIC_SPR_BG_PRIORITY = $D01B
VIC_SPR_MULTICOLOR = $D01C
VIC_SPR_X_EXPAND = $D01D
VIC_SPR_SPR_COLL = $D01E
VIC_SPR_BG_COLL = $D01F
VIC_RASTER      = $D012
VIC_SPR_MC0     = $D025
VIC_SPR_MC1     = $D026
VIC_SPR_COLOR0  = $D027
CIA1_PRA        = $DC00             ; joy port 2 / keyboard columns
CIA1_PRB        = $DC01             ; joy port 1 / keyboard rows
CIA1_DDRA       = $DC02
CIA1_DDRB       = $DC03
CIA1_ICR        = $DC0D
CIA2_PRA        = $DD00             ; VIC bank select (bits 0–1 inverted)
CIA2_ICR        = $DD0D
IRQ_VECTOR_LO   = $0314
IRQ_VECTOR_HI   = $0315
KERNAL_IRQ_EXIT = $EA81
SPRITE_PTR_BASE = SCREEN_RAM + $03F8

; VIC defaults / modes
VIC_DEN         = %00010000         ; $D011 bit 4 — display enable
VIC_DEN_MASK    = %11101111         ; AND mask to clear DEN (avoid unary ~ width)
VIC_CTRL1_TEXT  = $1b               ; text, DEN, 25 rows, yscroll 3
VIC_CTRL1_BITMAP = $3b              ; bitmap (BMM), DEN, 25 rows, yscroll 3
; Same as above with DEN clear (mode switch while blanked)
VIC_CTRL1_TEXT_BLANK   = VIC_CTRL1_TEXT & VIC_DEN_MASK
VIC_CTRL1_BITMAP_BLANK = VIC_CTRL1_BITMAP & VIC_DEN_MASK
VIC_CTRL2_HIRES = $08               ; 40 cols, multicolour off
VIC_MEM_TEXT    = $14               ; screen $0400, charset ROM $1000
VIC_MEM_BITMAP  = $18               ; screen $0400, bitmap $2000
BITMAP_SIZE     = 8000              ; 320×200 / 8
BITMAP_COLOR_SIZE = 1000            ; 40×25 colour matrix

; Joystick port 2 bits (active low on PRA)
JOY_UP          = %00000001
JOY_DOWN        = %00000010
JOY_LEFT        = %00000100
JOY_RIGHT       = %00001000
JOY_FIRE        = %00010000

; Keyboard matrix (CIA1): write select on PRA ($DC00), read on PRB ($DC01).
; On the C64 / c64m, PRA selects the matrix "row" index and PRB returns
; "column" bits (active-low). Key positions match c64m keyboard.c {row,col}:
;   key   row  col   → PRA clear bit   PRB test bit
;   W      1    1
;   A      1    2
;   S      1    5
;   D      2    2
;   Space  7    4      ($7F / $10 — classic "space bar" test)
KEY_SEL_W       = %11111101         ; ~(1<<1)
KEY_BIT_W       = %00000010         ;  (1<<1)
KEY_SEL_A       = %11111101         ; ~(1<<1)
KEY_BIT_A       = %00000100         ;  (1<<2)
KEY_SEL_S       = %11111101         ; ~(1<<1)
KEY_BIT_S       = %00100000         ;  (1<<5)
KEY_SEL_D       = %11111011         ; ~(1<<2)
KEY_BIT_D       = %00000100         ;  (1<<2)
KEY_SEL_SPACE   = %01111111         ; ~(1<<7)
KEY_BIT_SPACE   = %00010000         ;  (1<<4)
; I key (c64m keyboard.c {row,col} = {4,1})
KEY_SEL_I       = %11101111         ; ~(1<<4)
KEY_BIT_I       = %00000010         ;  (1<<1)
; S is KEY_SEL_S / KEY_BIT_S above (also used as joy-down)

; Screen geometry
SCREEN_W        = 40
SCREEN_H        = 25
SCREEN_SIZE     = 1000              ; 40 * 25

; Default text colours (VIC colour nybbles)
COL_BLACK       = $00
COL_WHITE       = $01
COL_RED         = $02
COL_CYAN        = $03
COL_PURPLE      = $04
COL_GREEN       = $05
COL_BLUE        = $06
COL_YELLOW      = $07
COL_ORANGE      = $08
COL_BROWN       = $09
COL_LT_RED      = $0A
COL_DK_GRAY     = $0B
COL_GRAY        = $0C
COL_LT_GREEN    = $0D
COL_LT_BLUE     = $0E
COL_LT_GRAY     = $0F

; ---------------------------------------------------------------------------
; Game mode IDs (game_mode ZP)
; ---------------------------------------------------------------------------
MODE_TITLE_GFX  = 0                 ; hires art attract page
MODE_GAME_INIT  = 1
MODE_STAGE_INIT = 2
MODE_PLAY       = 3
MODE_NEXT_WAVE  = 4
MODE_NEXT_LEVEL = 5
MODE_NEXT_LIFE  = 6
MODE_GAME_OVER  = 7
MODE_HISCORE    = 8
MODE_TITLE_TEXT = 9                 ; text menu + high scores (primary frontend)
MODE_STORY      = 10                ; placeholder
MODE_INSTRUCTIONS = 11              ; placeholder
MODE_COUNT      = 12

; Alias: cold-start / return-from-game frontend entry
MODE_TITLE      = MODE_TITLE_TEXT

; ---------------------------------------------------------------------------
; Session defaults (roadmap placeholders)
; ---------------------------------------------------------------------------
START_LIVES     = 3
START_HEALTH    = 8                 ; bar-driven later; stub full pool
START_AMMO      = 8
START_LEVEL     = 1
WAVES_PER_LEVEL = 20

; Play stub: frames to wait before FIRE ends the session (PAL ~1s)
PLAY_FIRE_DELAY = 50

; Attract loop: text ↔ graphics (PAL 50Hz × 15s)
ATTRACT_SECONDS = 15
ATTRACT_HZ      = 50
ATTRACT_FRAMES  = ATTRACT_SECONDS * ATTRACT_HZ   ; 750

; Score-row colour wheel step (frames per shift; ~5 Hz on PAL)
SCORE_COLOR_PERIOD = 10

; ---------------------------------------------------------------------------
; Video cadence
; ---------------------------------------------------------------------------
VIDEO_PAL       = 0
VIDEO_NTSC      = 1
LOGIC_HZ        = 50
PAL_DISPLAY_HZ  = 50
NTSC_DISPLAY_HZ = 60

; ---------------------------------------------------------------------------
; Graphical-object pool
; ---------------------------------------------------------------------------
OBJECT_CAPACITY = 24
OBJECT_LAST     = OBJECT_CAPACITY - 1
OBJECT_FREE_CAPACITY = OBJECT_CAPACITY - 1
OBJECT_NONE     = $FF

OBJ_PLAYER      = 0
OBJ_DRONE_A     = 1                ; large, back
OBJ_DRONE_B     = 2                ; medium
OBJ_DRONE_C     = 3                ; small, front
OBJ_BONUS       = 4
OBJ_EFFECT      = 5

OBJF_ALLOCATED  = %00000001
OBJF_RENDER     = %00000010
OBJF_RETIRING   = %00000100
OBJF_BG_INTEREST = %00001000
OBJF_SS_INTEREST = %00010000

OBJA_MULTICOLOR = %00000001
OBJA_X_EXPAND   = %00000010
OBJA_Y_EXPAND   = %00000100
OBJA_BEHIND_BG  = %00001000

OBJE_BG         = %00000001
OBJE_SS         = %00000010

OBJ_ERR_POOL_FULL   = 1
OBJ_ERR_PLAYER_FIXED = 2

; ---------------------------------------------------------------------------
; Sprite mux
; ---------------------------------------------------------------------------
MUX_HW_COUNT        = 8
MUX_MAX_COMMANDS    = OBJECT_CAPACITY
MUX_FRAME_IRQ_LINES = 28
MUX_FIRST_JOB_LINE  = 28
MUX_JOB_LINES       = 9
MUX_POST_GUARD      = 1

MUX_OK                  = 0
MUX_ERR_TOO_MANY_VISIBLE = 1
MUX_ERR_LANE_CAPACITY   = 2
MUX_ERR_PRIORITY        = 3
MUX_ERR_RASTER_DEADLINE = 4
MUX_ERR_COMMAND_CAPACITY = 5
MUX_ERR_PLAN_BUSY       = 6
MUX_ERR_BAD_COORDINATE  = 7

; Ignore fire for a few frames after entering a menu (held-button bleed)
MENU_FIRE_GUARD = 20

; Story typewriter
STORY_MARGIN_X  = 1                 ; left-justified inset
STORY_START_Y   = 0
STORY_TYPE_DELAY = 1                ; frames between glyphs (~50% faster than 2)
STORY_STATE_TYPING = 0
STORY_STATE_DONE   = 1

; Screen codes for placeholder art
SC_SPACE        = $20
SC_STAR         = $2A               ; "*" player stand-in
SC_PLUS         = $2B               ; "+"
SC_DASH         = $2D               ; "-" horizontal rail stand-in
SC_ZERO         = $30
SC_VBAR         = $5D               ; "|" vertical bar (vertical rail stand-in)
